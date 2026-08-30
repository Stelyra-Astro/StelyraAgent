#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
from pathlib import Path

PACKAGE = Path(__file__).resolve().parent
FULL_CHART_LOCALES = ["de", "it", "pt-BR", "tr", "ko"]
DELTA_CHART_LOCALES = ["fr", "es"]
AREA_LOCALES = ["fr", "es", "de", "it", "pt-BR", "tr", "ko"]
TOKEN_RE = re.compile(r"([^.[\]]+)|\[(\d+)\]")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def path_tokens(path: str):
    tokens = []
    for match in TOKEN_RE.finditer(path):
        key, index = match.groups()
        tokens.append(int(index) if index is not None else key)
    return tokens


def set_path(root, path: str, value):
    tokens = path_tokens(path)
    current = root
    for token in tokens[:-1]:
        current = current[token]
    current[tokens[-1]] = value


def require(path: Path):
    if not path.exists():
        raise SystemExit(f"Missing completed translation: {path.relative_to(PACKAGE)}")
    return path


def run(cmd, cwd):
    print("+", " ".join(str(part) for part in cmd))
    subprocess.run(cmd, cwd=cwd, check=True)


def main():
    parser = argparse.ArgumentParser(description="Apply completed StelyraAgent translations into a source checkout")
    parser.add_argument("--repo", required=True, help="Path to the StelyraAgent source checkout")
    args = parser.parse_args()
    repo = Path(args.repo).resolve()
    private = repo / "ios" / "PrivateContent"
    ui_dir = repo / "ios" / "Localization" / "UI"
    resources = repo / "ios" / "App" / "Resources"
    if not (repo / "ios" / "App").exists():
        raise SystemExit(f"Not an StelyraAgent checkout: {repo}")

    run(["python3", str(PACKAGE / "validate-translations.py")], PACKAGE)

    for area in ["today", "ask"]:
        for locale in AREA_LOCALES:
            src = require(PACKAGE / area / "completed" / f"Content-{locale}.json")
            destination = private / area / src.name
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(src, destination)

    completed_charts = PACKAGE / "charts" / "completed"
    for locale in FULL_CHART_LOCALES:
        name = f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json"
        destination = private / "charts" / name
        destination.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(require(completed_charts / name), destination)

    english_catalog = read_json(PACKAGE / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json")
    for locale in DELTA_CHART_LOCALES:
        base = read_json(PACKAGE / "charts" / f"{locale}-base.json")
        delta = read_json(require(PACKAGE / "charts" / f"{locale}-delta-completed.json"))
        for entry in delta.get("entries", []):
            translation = entry.get("translation")
            if not translation:
                raise SystemExit(f"Blank {locale} translation: {entry.get('path')}")
            set_path(base, entry["path"], translation)
        base["version"] = english_catalog.get("version")
        base["locale"] = locale
        base["status"] = "approved"
        write_json(private / "charts" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json", base)

    ui_completed = read_json(require(PACKAGE / "ui" / "pt-BR-worklist-completed.json"))
    by_file = {}
    for entry in ui_completed.get("entries", []):
        translation = entry.get("translation")
        if not translation:
            raise SystemExit(f"Blank PT-BR UI translation: {entry.get('file')}::{entry.get('key')}")
        by_file.setdefault(entry["file"], {})[entry["key"]] = translation
    for file_name, translations in by_file.items():
        path = ui_dir / file_name
        data = read_json(path)
        for key, translated in translations.items():
            if key not in data:
                raise SystemExit(f"Unknown UI key: {file_name}::{key}")
            data[key]["pt-BR"] = translated
        write_json(path, data)

    shutil.copy2(
        require(PACKAGE / "ui" / "abc-life-areas-help-pt-BR.md"),
        resources / "Help" / "abc-life-areas-help-pt-BR.md",
    )
    shutil.copy2(
        require(PACKAGE / "ui" / "AstroTerms-pt-BR.json"),
        resources / "AstroTerms-pt-BR.json",
    )

    run(["node", "scripts/build-ios-localization.mjs"], repo)
    run(["node", "scripts/build-ios-private-content.mjs", "--build"], repo)
    run(["node", "scripts/build-ios-private-content.mjs", "--validate"], repo)
    print("Completed translations applied and generated resources rebuilt.")


if __name__ == "__main__":
    main()
