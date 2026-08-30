from __future__ import annotations

import hashlib
import json
import sqlite3
import subprocess
import sys
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
BUILDER = ROOT / "scripts" / "build-ios-offline-locations.py"


def _geonames_row(
    geonames_id: int,
    name: str,
    ascii_name: str,
    aliases: str,
    latitude: float,
    longitude: float,
    country: str,
    population: int,
    timezone: str,
) -> str:
    return "\t".join(
        [
            str(geonames_id),
            name,
            ascii_name,
            aliases,
            str(latitude),
            str(longitude),
            "P",
            "PPLC",
            country,
            "",
            "01",
            "",
            "",
            "",
            str(population),
            "",
            "",
            timezone,
            "2026-07-19",
        ]
    )


def _polygon(tzid: str, west: float, south: float, east: float, north: float) -> dict:
    return {
        "type": "Feature",
        "properties": {"tzid": tzid},
        "geometry": {
            "type": "Polygon",
            "coordinates": [
                [
                    [west, south],
                    [east, south],
                    [east, north],
                    [west, north],
                    [west, south],
                ]
            ],
        },
    }


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    digest.update(path.read_bytes())
    return digest.hexdigest()


def test_builder_emits_all_places_with_deduplicated_timezones(tmp_path: Path) -> None:
    places_zip = tmp_path / "cities500.zip"
    with zipfile.ZipFile(places_zip, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr(
            "cities500.txt",
            "\n".join(
                [
                    _geonames_row(
                        2988507,
                        "Paris",
                        "Paris",
                        "巴黎,Parigi",
                        48.85341,
                        2.3488,
                        "FR",
                        2_138_551,
                        "Europe/Paris",
                    ),
                    _geonames_row(
                        1795565,
                        "Shenzhen",
                        "Shenzhen",
                        "深圳,深圳市",
                        22.54554,
                        114.0683,
                        "CN",
                        17_494_398,
                        "Asia/Shanghai",
                    ),
                    _geonames_row(
                        13672716,
                        "Gulou",
                        "Gulou",
                        "鼓楼",
                        34.79281,
                        114.34073,
                        "CN",
                        0,
                        "",
                    ),
                    _geonames_row(
                        999,
                        "Dateline",
                        "Dateline",
                        "",
                        0.0,
                        179.5,
                        "FJ",
                        500,
                        "",
                    ),
                ]
            )
            + "\n",
        )

    timezone_zip = tmp_path / "timezones.zip"
    document = {
        "type": "FeatureCollection",
        "features": [
            _polygon("Europe/Paris", 1.0, 47.0, 4.0, 50.0),
            _polygon("Asia/Shanghai", 110.0, 20.0, 118.0, 40.0),
            {
                "type": "Feature",
                "properties": {"tzid": "Pacific/Fiji"},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[
                        [179.0, -1.0], [-179.0, -1.0], [-179.0, 1.0],
                        [179.0, 1.0], [179.0, -1.0],
                    ]],
                },
            },
        ],
    }
    with zipfile.ZipFile(timezone_zip, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("combined.json", json.dumps(document))

    manifest = tmp_path / "manifest.json"
    manifest.write_text(
        json.dumps(
            {
                "schema_version": 1,
                "active": {
                    "geonames": {
                        "version": "fixture-cities",
                        "license_identifier": "CC-BY-4.0",
                        "artifacts": [
                            {
                                "path": str(places_zip),
                                "sha256": _sha256(places_zip),
                                "size_bytes": places_zip.stat().st_size,
                            }
                        ],
                    },
                    "timezone_boundary_builder": {
                        "version": "fixture-timezones",
                        "license_identifier": "ODbL-1.0",
                        "artifacts": [
                            {
                                "path": str(timezone_zip),
                                "sha256": _sha256(timezone_zip),
                                "size_bytes": timezone_zip.stat().st_size,
                            }
                        ],
                    },
                },
            }
        ),
        encoding="utf-8",
    )

    output = tmp_path / "OfflineLocations.sqlite3"
    licenses = tmp_path / "OfflineLocationData-LICENSES.txt"
    result = subprocess.run(
        [
            sys.executable,
            str(BUILDER),
            "--lock-manifest",
            str(manifest),
            "--geonames",
            str(places_zip),
            "--timezones",
            str(timezone_zip),
            "--output",
            str(output),
            "--license-output",
            str(licenses),
        ],
        cwd=ROOT,
        capture_output=True,
        text=True,
        check=False,
    )

    assert result.returncode == 0, result.stderr
    first_bytes = output.read_bytes()
    assert "GeoNames" in licenses.read_text(encoding="utf-8")
    assert "Timezone Boundary Builder" in licenses.read_text(encoding="utf-8")

    with sqlite3.connect(output) as database:
        assert database.execute("PRAGMA integrity_check").fetchone() == ("ok",)
        metadata = dict(database.execute("SELECT key, value FROM metadata"))
        assert metadata["schema_version"] == "2"
        assert metadata["geonames_version"] == "fixture-cities"
        assert metadata["timezone_version"] == "fixture-timezones"
        assert metadata["place_count"] == "4"
        assert metadata["timezone_count"] == "3"
        assert metadata["timezone_backfill_count"] == "2"

        paris = database.execute(
            "SELECT p.name, t.identifier FROM place_search s "
            "JOIN places p ON p.id = s.rowid "
            "JOIN timezones t ON t.id = p.timezone_index "
            "WHERE place_search MATCH ?",
            ('"巴黎"*',),
        ).fetchall()
        assert paris == [("Paris", "Europe/Paris")]
        assert database.execute(
            "SELECT t.identifier FROM places p "
            "JOIN timezones t ON t.id = p.timezone_index WHERE p.id = 13672716"
        ).fetchone() == ("Asia/Shanghai",)
        tables = {
            row[0]
            for row in database.execute(
                "SELECT name FROM sqlite_master WHERE type IN ('table', 'view')"
            )
        }
        assert "timezone_parts" not in tables
        assert "timezone_bounds" not in tables
        search_schema = database.execute(
            "SELECT sql FROM sqlite_master WHERE name = 'place_search'"
        ).fetchone()[0]
        assert "content=''" in search_schema
        assert "places_population" not in {
            row[0] for row in database.execute("SELECT name FROM sqlite_master")
        }

    subprocess.run(
        [
            sys.executable,
            str(BUILDER),
            "--lock-manifest",
            str(manifest),
            "--geonames",
            str(places_zip),
            "--timezones",
            str(timezone_zip),
            "--output",
            str(output),
            "--license-output",
            str(licenses),
        ],
        cwd=ROOT,
        check=True,
    )
    assert output.read_bytes() == first_bytes
