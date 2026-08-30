#!/usr/bin/env python3
"""Build the deterministic, read-only iOS global location database."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import sqlite3
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Iterable


SCHEMA_VERSION = "2"
GEONAMES_COLUMNS = 19


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument("--lock-manifest", type=Path, required=True)
    parser.add_argument("--geonames", type=Path, required=True)
    parser.add_argument("--timezones", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--license-output", type=Path, required=True)
    return parser.parse_args()


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def locked_dataset(manifest: dict[str, Any], dataset_id: str, path: Path) -> dict[str, Any]:
    try:
        dataset = manifest["active"][dataset_id]
        artifacts = dataset["artifacts"]
    except (KeyError, TypeError) as error:
        raise ValueError(f"lock manifest lacks {dataset_id}") from error

    artifact = next(
        (
            item
            for item in artifacts
            if Path(str(item.get("path", ""))).name == path.name
            or Path(str(item.get("path", ""))).resolve() == path.resolve()
        ),
        artifacts[0] if len(artifacts) == 1 else None,
    )
    if artifact is None:
        raise ValueError(f"lock manifest has no artifact matching {path}")
    actual_size = path.stat().st_size
    actual_hash = sha256(path)
    if actual_size != int(artifact["size_bytes"]):
        raise ValueError(f"size mismatch for {path}: {actual_size}")
    if actual_hash != artifact["sha256"]:
        raise ValueError(f"SHA-256 mismatch for {path}: {actual_hash}")
    return dataset


def normalized_names(values: Iterable[str]) -> str:
    unique: list[str] = []
    seen: set[str] = set()
    for raw in values:
        value = " ".join(raw.strip().split())
        folded = value.casefold()
        if not value or folded in seen:
            continue
        seen.add(folded)
        unique.append(value)
    return " ".join(unique)


def create_schema(database: sqlite3.Connection) -> None:
    database.executescript(
        """
        PRAGMA page_size = 4096;
        PRAGMA journal_mode = OFF;
        PRAGMA synchronous = OFF;
        PRAGMA temp_store = MEMORY;
        CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        ) WITHOUT ROWID;
        CREATE TABLE places (
            id INTEGER PRIMARY KEY,
            name TEXT NOT NULL,
            ascii_name TEXT NOT NULL,
            country_code TEXT NOT NULL,
            admin1_code TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            population INTEGER NOT NULL,
            timezone_index INTEGER NOT NULL REFERENCES timezones(id)
        );
        CREATE TABLE timezones (
            id INTEGER PRIMARY KEY,
            identifier TEXT NOT NULL UNIQUE
        );
        CREATE INDEX places_coordinates ON places(latitude, longitude);
        CREATE VIRTUAL TABLE place_search USING fts5(
            names,
            content='',
            detail=none,
            tokenize = 'unicode61 remove_diacritics 2'
        );
        """
    )


def geonames_lines(archive_path: Path) -> Iterable[tuple[int, list[str]]]:
    with zipfile.ZipFile(archive_path) as archive:
        members = sorted(
            name for name in archive.namelist() if name.lower().endswith(".txt")
        )
        if len(members) != 1:
            raise ValueError("GeoNames ZIP must contain exactly one text member")
        with archive.open(members[0]) as raw:
            for line_number, raw_line in enumerate(raw, start=1):
                columns = raw_line.decode("utf-8").rstrip("\n").split("\t")
                if len(columns) != GEONAMES_COLUMNS:
                    raise ValueError(
                        f"GeoNames row {line_number} has {len(columns)} columns"
                    )
                yield line_number, columns


def missing_timezone_points(archive_path: Path) -> dict[int, tuple[float, float]]:
    missing: dict[int, tuple[float, float]] = {}
    for _, columns in geonames_lines(archive_path):
        if not columns[17].strip():
            missing[int(columns[0])] = (float(columns[5]), float(columns[4]))
    return missing


def point_in_ring(longitude: float, latitude: float, ring: list[Any]) -> bool:
    inside = False
    previous_longitude, previous_latitude = float(ring[-1][0]), float(ring[-1][1])
    for value in ring:
        current_longitude, current_latitude = float(value[0]), float(value[1])
        crosses = (current_latitude > latitude) != (previous_latitude > latitude)
        if crosses:
            intersection = (
                (previous_longitude - current_longitude)
                * (latitude - current_latitude)
                / (previous_latitude - current_latitude)
                + current_longitude
            )
            if longitude < intersection:
                inside = not inside
        previous_longitude, previous_latitude = current_longitude, current_latitude
    return inside


def point_in_polygon(longitude: float, latitude: float, rings: Any) -> bool:
    if not isinstance(rings, list) or not rings:
        raise ValueError("timezone polygon has no rings")
    for ring in rings:
        if not isinstance(ring, list) or len(ring) < 4:
            raise ValueError("timezone polygon contains an invalid ring")
        for point in ring:
            validate_point(point)
    outer = rings[0]
    outer_longitudes = [validate_point(point)[0] for point in outer]
    normalized = max(outer_longitudes) - min(outer_longitudes) > 180
    if normalized:
        longitude = longitude if longitude >= 0 else longitude + 360
        rings = [
            [
                [point[0] if point[0] >= 0 else point[0] + 360, point[1]]
                for point in ring
            ]
            for ring in rings
        ]
    if not point_in_ring(longitude, latitude, rings[0]):
        return False
    return not any(point_in_ring(longitude, latitude, hole) for hole in rings[1:])


def resolve_missing_timezones(
    archive_path: Path, missing: dict[int, tuple[float, float]]
) -> dict[int, str]:
    if not missing:
        return {}
    with zipfile.ZipFile(archive_path) as archive:
        members = sorted(
            name for name in archive.namelist() if name.lower().endswith(".json")
        )
        preferred = [name for name in members if Path(name).name == "combined.json"]
        if len(preferred) == 1:
            member = preferred[0]
        elif len(members) == 1:
            member = members[0]
        else:
            raise ValueError("timezone ZIP must contain combined.json")
        with archive.open(member) as handle:
            document = json.load(handle)
    if document.get("type") != "FeatureCollection" or not isinstance(
        document.get("features"), list
    ):
        raise ValueError("timezone source must be a FeatureCollection")

    matches: dict[int, set[str]] = {place_id: set() for place_id in missing}
    for feature in document["features"]:
        properties = feature.get("properties")
        geometry = feature.get("geometry")
        timezone_id = properties.get("tzid") if isinstance(properties, dict) else None
        if not isinstance(timezone_id, str) or not isinstance(geometry, dict):
            raise ValueError("timezone feature lacks tzid or geometry")
        coordinates = geometry.get("coordinates")
        if geometry.get("type") == "Polygon":
            polygons = [coordinates]
        elif geometry.get("type") == "MultiPolygon":
            polygons = coordinates
        else:
            raise ValueError(f"unsupported timezone geometry: {geometry.get('type')}")
        if not isinstance(polygons, list):
            raise ValueError("timezone geometry has invalid coordinates")
        for place_id, (longitude, latitude) in missing.items():
            if any(point_in_polygon(longitude, latitude, polygon) for polygon in polygons):
                matches[place_id].add(timezone_id)

    resolved: dict[int, str] = {}
    for place_id, timezone_ids in matches.items():
        if len(timezone_ids) != 1:
            raise ValueError(
                f"GeoNames place {place_id} matched {len(timezone_ids)} timezones"
            )
        resolved[place_id] = next(iter(timezone_ids))
    return resolved


def import_places(
    database: sqlite3.Connection,
    archive_path: Path,
    timezone_overrides: dict[int, str],
) -> tuple[int, int]:
    count = 0
    timezone_indices: dict[str, int] = {}
    for line_number, columns in geonames_lines(archive_path):
                place_id = int(columns[0])
                name = columns[1].strip()
                ascii_name = columns[2].strip() or name
                aliases = columns[3].split(",")
                latitude = float(columns[4])
                longitude = float(columns[5])
                country_code = columns[8].strip().upper()
                population = int(columns[14] or 0)
                timezone_id = columns[17].strip() or timezone_overrides.get(place_id, "")
                if not name or len(country_code) != 2:
                    raise ValueError(f"GeoNames row {line_number} lacks required fields")
                if not timezone_id:
                    raise ValueError(f"GeoNames row {line_number} has no timezone")
                if not -90 <= latitude <= 90 or not -180 <= longitude < 180:
                    raise ValueError(f"GeoNames row {line_number} has invalid coordinates")
                timezone_index = timezone_indices.get(timezone_id)
                if timezone_index is None:
                    timezone_index = len(timezone_indices) + 1
                    timezone_indices[timezone_id] = timezone_index
                    database.execute(
                        "INSERT INTO timezones(id, identifier) VALUES (?, ?)",
                        (timezone_index, timezone_id),
                    )
                database.execute(
                    "INSERT INTO places VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",
                    (
                        place_id,
                        name,
                        ascii_name,
                        country_code,
                        columns[10].strip(),
                        latitude,
                        longitude,
                        population,
                        timezone_index,
                    ),
                )
                database.execute(
                    "INSERT INTO place_search(rowid, names) VALUES (?, ?)",
                    (place_id, normalized_names((name, ascii_name, *aliases))),
                )
                count += 1
    return count, len(timezone_indices)


def validate_point(point: Any) -> tuple[float, float]:
    if not isinstance(point, list) or len(point) < 2:
        raise ValueError("timezone geometry contains an invalid point")
    longitude = float(point[0])
    latitude = float(point[1])
    if not -180 <= longitude <= 180 or not -90 <= latitude <= 90:
        raise ValueError("timezone geometry contains out-of-range coordinates")
    return longitude, latitude


def write_licenses(path: Path, geonames_version: str, timezone_version: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        "\n".join(
            [
                "Offline Location Data",
                "",
                f"GeoNames {geonames_version}",
                "Copyright GeoNames contributors. Licensed under CC BY 4.0.",
                "https://www.geonames.org/",
                "",
                f"Timezone Boundary Builder {timezone_version}",
                "Copyright Timezone Boundary Builder and OpenStreetMap contributors.",
                "Database output licensed under ODbL 1.0.",
                "https://github.com/evansiroky/timezone-boundary-builder",
                "https://www.openstreetmap.org/copyright",
                "",
            ]
        ),
        encoding="utf-8",
    )


def build(args: argparse.Namespace) -> dict[str, Any]:
    manifest = json.loads(args.lock_manifest.read_text(encoding="utf-8"))
    geonames = locked_dataset(manifest, "geonames", args.geonames)
    timezones = locked_dataset(
        manifest, "timezone_boundary_builder", args.timezones
    )
    args.output.parent.mkdir(parents=True, exist_ok=True)

    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{args.output.name}.", suffix=".tmp", dir=args.output.parent
    )
    os.close(descriptor)
    temporary = Path(temporary_name)
    temporary.unlink()
    try:
        with sqlite3.connect(temporary) as database:
            create_schema(database)
            missing = missing_timezone_points(args.geonames)
            timezone_overrides = resolve_missing_timezones(args.timezones, missing)
            place_count, timezone_count = import_places(
                database, args.geonames, timezone_overrides
            )
            metadata = {
                "schema_version": SCHEMA_VERSION,
                "geonames_version": str(geonames["version"]),
                "geonames_sha256": sha256(args.geonames),
                "timezone_version": str(timezones["version"]),
                "timezone_sha256": sha256(args.timezones),
                "place_count": str(place_count),
                "timezone_count": str(timezone_count),
                "timezone_backfill_count": str(len(timezone_overrides)),
            }
            database.executemany(
                "INSERT INTO metadata(key, value) VALUES (?, ?)",
                sorted(metadata.items()),
            )
            database.commit()
            database.execute("INSERT INTO place_search(place_search) VALUES ('optimize')")
            database.commit()
            database.execute("VACUUM")
        temporary.replace(args.output)
    finally:
        temporary.unlink(missing_ok=True)

    write_licenses(
        args.license_output,
        str(geonames["version"]),
        str(timezones["version"]),
    )
    return {
        "output": str(args.output),
        "place_count": place_count,
        "timezone_count": timezone_count,
        "timezone_backfill_count": len(timezone_overrides),
        "size_bytes": args.output.stat().st_size,
    }


def main() -> int:
    result = build(parse_args())
    print(json.dumps(result, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
