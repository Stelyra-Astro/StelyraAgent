#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import re
import shutil
from copy import deepcopy
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / "ios" / "PrivateContent"
UI_DIR = ROOT / "ios" / "Localization" / "UI"
RESOURCES = ROOT / "ios" / "App" / "Resources"

TARGET_LOCALES = ["fr", "es", "de", "it", "pt-BR", "tr", "ko"]
FULL_CHART_LOCALES = ["de", "it", "pt-BR", "tr", "ko"]
DELTA_CHART_LOCALES = ["fr", "es"]
RUNTIME_PREFIXES = ("shared.", "modern.", "classical.", "contracts.")
PLACEHOLDER_RE = re.compile(r"\{\{[A-Za-z][A-Za-z0-9]*\}\}")


def read_json(path: Path):
    return json.loads(path.read_text(encoding="utf-8"))


def write_json(path: Path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def flatten_strings(value, prefix=""):
    out = {}
    if isinstance(value, dict):
        for key, child in value.items():
            next_prefix = f"{prefix}.{key}" if prefix else key
            out.update(flatten_strings(child, next_prefix))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            next_prefix = f"{prefix}[{index}]"
            out.update(flatten_strings(child, next_prefix))
    elif isinstance(value, str):
        out[prefix] = value
    return out


def placeholders(value: str):
    return sorted(PLACEHOLDER_RE.findall(value))


def make_area_target(source: dict, locale: str):
    target = deepcopy(source)
    target["locale"] = locale
    for entry in target.get("entries", []):
        entry["translationStatus"] = "needs-translation"
    return target


def runtime_strings(catalog: dict):
    flattened = flatten_strings(catalog)
    return {path: text for path, text in flattened.items() if path.startswith(RUNTIME_PREFIXES)}


def make_delta(source: dict, existing: dict, locale: str):
    source_runtime = runtime_strings(source)
    existing_runtime = runtime_strings(existing)
    missing = []
    for path in sorted(set(source_runtime) - set(existing_runtime)):
        missing.append({
            "path": path,
            "english": source_runtime[path],
            "placeholders": placeholders(source_runtime[path]),
            "translation": "",
        })
    return {
        "schemaVersion": 1,
        "locale": locale,
        "baseVersion": existing.get("version"),
        "targetVersion": source.get("version"),
        "mode": "delta",
        "entries": missing,
    }


def pt_ui_worklist():
    entries = []
    for path in sorted(UI_DIR.glob("*.json")):
        data = read_json(path)
        for key, value in data.items():
            en = value.get("en")
            pt = value.get("pt-BR")
            if not isinstance(en, str):
                continue
            # Values already deliberately translated (e.g. Você / Laços) are not re-sent.
            if pt is None or pt == en:
                entries.append({
                    "file": path.name,
                    "key": key,
                    "english": en,
                    "placeholders": placeholders(en),
                    "translation": "",
                })
    return {
        "schemaVersion": 1,
        "locale": "pt-BR",
        "mode": "ui-delta",
        "entries": entries,
    }


def write_validator(out: Path):
    validator = r'''#!/usr/bin/env python3
import json, re
from pathlib import Path

ROOT = Path(__file__).resolve().parent
PH = re.compile(r"\{\{[A-Za-z][A-Za-z0-9]*\}\}")
AREA_LOCALES = ["fr", "es", "de", "it", "pt-BR", "tr", "ko"]
FULL_CHART_LOCALES = ["de", "it", "pt-BR", "tr", "ko"]
DELTA_CHART_LOCALES = ["fr", "es"]
RUNTIME_PREFIXES = ("shared.", "modern.", "classical.", "contracts.")
USER_COPY_PREFIXES = ("shared.", "modern.", "classical.")

def p(text): return sorted(PH.findall(text or ""))

def fail(msg):
    print("ERROR:", msg)
    raise SystemExit(1)

def require(path):
    if not path.exists():
        fail(f"Missing completed translation: {path.relative_to(ROOT)}")
    return path

def flatten_strings(value, prefix=""):
    out = {}
    if isinstance(value, dict):
        for key, child in value.items():
            next_prefix = f"{prefix}.{key}" if prefix else key
            out.update(flatten_strings(child, next_prefix))
    elif isinstance(value, list):
        for index, child in enumerate(value):
            next_prefix = f"{prefix}[{index}]"
            out.update(flatten_strings(child, next_prefix))
    elif isinstance(value, str):
        out[prefix] = value
    return out

for area in ["today", "ask"]:
    source = json.loads((ROOT / area / "Content-en.json").read_text(encoding="utf-8"))
    source_by_key = {e["contentKey"]: e for e in source["entries"]}
    for locale in AREA_LOCALES:
        file = require(ROOT / area / "completed" / f"Content-{locale}.json")
        data = json.loads(file.read_text(encoding="utf-8"))
        if data.get("locale") != locale: fail(f"{file}: wrong locale")
        if data.get("area") != area: fail(f"{file}: wrong area")
        by_key = {e["contentKey"]: e for e in data.get("entries", [])}
        if set(by_key) != set(source_by_key): fail(f"{file}: contentKey coverage differs")
        changed = 0
        for key, src in source_by_key.items():
            dst = by_key[key]
            if dst.get("translationStatus") != "approved": fail(f"{file}: {key} not approved")
            for field in ["summary", "detail"]:
                if p(dst.get(field)) != p(src.get(field)): fail(f"{file}: placeholder mismatch {key}.{field}")
                if dst.get(field) != src.get(field): changed += 1
        if changed == 0: fail(f"{file}: appears untranslated")

english_path = ROOT / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json"
english_catalog = json.loads(english_path.read_text(encoding="utf-8"))
english_strings = {
    path: text for path, text in flatten_strings(english_catalog).items()
    if path.startswith(RUNTIME_PREFIXES)
}
english_user_copy = {
    path: text for path, text in english_strings.items()
    if path.startswith(USER_COPY_PREFIXES)
}
for locale in FULL_CHART_LOCALES:
    file = require(ROOT / "charts" / "completed" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json")
    data = json.loads(file.read_text(encoding="utf-8"))
    if data.get("locale") != locale: fail(f"{file}: wrong locale")
    if data.get("status") != "approved": fail(f"{file}: top-level status must be approved")
    target_strings = {
        path: text for path, text in flatten_strings(data).items()
        if path.startswith(RUNTIME_PREFIXES)
    }
    if set(target_strings) != set(english_strings): fail(f"{file}: runtime string path coverage differs")
    for path, src in english_strings.items():
        if p(target_strings[path]) != p(src): fail(f"{file}: placeholder mismatch {path}")
    changed = sum(target_strings[path] != src for path, src in english_user_copy.items())
    if changed == 0: fail(f"{file}: appears untranslated")

for locale in DELTA_CHART_LOCALES:
    delta = require(ROOT / "charts" / f"{locale}-delta-completed.json")
    data = json.loads(delta.read_text(encoding="utf-8"))
    if data.get("locale") != locale: fail(f"{delta}: wrong locale")
    for entry in data.get("entries", []):
        if not entry.get("translation"): fail(f"{delta}: blank translation {entry.get('path')}")
        if p(entry["translation"]) != entry.get("placeholders", []): fail(f"{delta}: placeholder mismatch {entry.get('path')}")

ui = require(ROOT / "ui" / "pt-BR-worklist-completed.json")
data = json.loads(ui.read_text(encoding="utf-8"))
if data.get("locale") != "pt-BR": fail(f"{ui}: wrong locale")
for entry in data.get("entries", []):
    if not entry.get("translation"): fail(f"{ui}: blank translation {entry.get('key')}")
    if p(entry["translation"]) != entry.get("placeholders", []): fail(f"{ui}: placeholder mismatch {entry.get('key')}")

help_en = (ROOT / "ui" / "abc-life-areas-help-en.md").read_text(encoding="utf-8").strip()
help_pt = require(ROOT / "ui" / "abc-life-areas-help-pt-BR.md").read_text(encoding="utf-8").strip()
if not help_pt or help_pt == help_en: fail("ui/abc-life-areas-help-pt-BR.md: appears untranslated")

terms_en = json.loads((ROOT / "ui" / "AstroTerms-en.json").read_text(encoding="utf-8"))
terms_path = require(ROOT / "ui" / "AstroTerms-pt-BR.json")
terms_pt = json.loads(terms_path.read_text(encoding="utf-8"))
if terms_pt.get("locale") != "pt-BR": fail(f"{terms_path}: wrong locale")
en_terms = flatten_strings(terms_en)
pt_terms = flatten_strings(terms_pt)
term_paths = {path for path in en_terms if path != "locale"}
if {path for path in pt_terms if path != "locale"} != term_paths: fail(f"{terms_path}: term path coverage differs")
if not any(pt_terms[path] != en_terms[path] for path in term_paths): fail(f"{terms_path}: appears untranslated")

print("Translation package validation passed.")
'''
    path = out / "validate-translations.py"
    path.write_text(validator, encoding="utf-8")
    path.chmod(0o755)


def write_apply_script(out: Path):
    source = ROOT / "scripts" / "translation-apply-template.py"
    destination = out / "apply-translations.py"
    shutil.copy2(source, destination)
    destination.chmod(0o755)


def write_prompt(out: Path, manifest: dict):
    prompt = f"""# StelyraAgent translation instructions

Translate only the supplied English user-facing text. Do not alter astrology facts, JSON keys, object structure, arrays, IDs, sourceRevision values, enum/raw values, contract selectors, or numeric values.

## Non-negotiable rules

1. Preserve every `{{{{variable}}}}` exactly, including spelling and braces.
2. Preserve JSON structure and key order where practical.
3. Use natural consumer-facing language for an astrology app; avoid literal machine phrasing.
4. Do not add astrology facts, interpretations, warnings, or explanations that are absent from the English source.
5. For Today/Ask completed files, change each translated entry's `translationStatus` to `approved` only after translating both `summary` and `detail`.
6. For full chart catalogs, set `locale` to the target locale and set top-level `status` to `approved` only after all user-facing strings under `shared`, `modern`, and `classical` are translated. Do not change `contracts` structure or rule IDs; translate contract strings only where they are actual display copy.
7. FR/ES chart work is delta-only. Translate only the `translation` field in `fr-delta.json` / `es-delta.json`; never change `path`, `english`, or `placeholders`.
8. PT-BR UI work is delta-only. Translate only the `translation` field in `ui/pt-BR-worklist.json`.
9. Korean tone should be concise and natural for mobile UI; Turkish/German/Italian/Portuguese/French/Spanish should avoid unnecessarily long button labels.

## Work included

- Today: EN -> FR / ES / DE / IT / PT-BR / TR / KO
- Ask: EN -> FR / ES / DE / IT / PT-BR / TR / KO
- Chart Copy Catalog full translation: DE / IT / PT-BR / TR / KO
- Chart Copy Catalog delta translation: FR / ES ({manifest['charts']['fr']['missingStringPaths']} strings each)
- Fixed UI delta: PT-BR entries still identical to English
- Ask Life Areas help markdown: EN -> PT-BR
- AstroTerms: EN -> PT-BR

Place full DE/IT/PT-BR/TR/KO chart catalogs in `charts/completed/` using their existing filenames. Place Today/Ask outputs in each area's `completed/` directory. Save FR/ES deltas as `charts/fr-delta-completed.json` and `charts/es-delta-completed.json`, PT-BR UI as `ui/pt-BR-worklist-completed.json`, and translated PT-BR help/AstroTerms as `ui/abc-life-areas-help-pt-BR.md` and `ui/AstroTerms-pt-BR.json`.

Run `python3 validate-translations.py` after translation. Then run `python3 apply-translations.py --repo /path/to/stelyraagent-ios` to merge deltas, copy completed files, and rebuild runtime resources.
"""
    (out / "TRANSLATION_PROMPT.md").write_text(prompt, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", required=True)
    args = parser.parse_args()
    out = Path(args.output).resolve()
    if out.exists():
        shutil.rmtree(out)
    out.mkdir(parents=True)

    today_en = PRIVATE / "today" / "Content-en.json"
    ask_en = PRIVATE / "ask" / "Content-en.json"
    charts_en = PRIVATE / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json"
    charts_fr = PRIVATE / "charts" / "StelyraAgent_Copy_Catalog_fr_v2_three-layers.json"
    charts_es = PRIVATE / "charts" / "StelyraAgent_Copy_Catalog_es_v2_three-layers.json"

    for src, area in [(today_en, "today"), (ask_en, "ask")]:
        source = read_json(src)
        (out / area).mkdir(parents=True, exist_ok=True)
        shutil.copy2(src, out / area / "Content-en.json")
        (out / area / "targets").mkdir(parents=True, exist_ok=True)
        (out / area / "completed").mkdir(parents=True, exist_ok=True)
        for locale in TARGET_LOCALES:
            write_json(out / area / "targets" / f"Content-{locale}.json", make_area_target(source, locale))

    source_catalog = read_json(charts_en)
    (out / "charts").mkdir(parents=True, exist_ok=True)
    (out / "charts" / "completed").mkdir(parents=True, exist_ok=True)
    shutil.copy2(charts_en, out / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json")
    for locale in FULL_CHART_LOCALES:
        target = deepcopy(source_catalog)
        target["locale"] = locale
        target["status"] = "translation_required"
        write_json(out / "charts" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json", target)

    manifest = {
        "schemaVersion": 1,
        "locales": TARGET_LOCALES,
        "today": {"source": "today/Content-en.json", "targets": TARGET_LOCALES},
        "ask": {"source": "ask/Content-en.json", "targets": TARGET_LOCALES},
        "charts": {},
    }
    for locale, existing_path in [("fr", charts_fr), ("es", charts_es)]:
        delta = make_delta(source_catalog, read_json(existing_path), locale)
        write_json(out / "charts" / f"{locale}-delta.json", delta)
        shutil.copy2(existing_path, out / "charts" / f"{locale}-base.json")
        manifest["charts"][locale] = {"mode": "delta", "missingStringPaths": len(delta["entries"])}
    for locale in FULL_CHART_LOCALES:
        manifest["charts"][locale] = {"mode": "full", "source": "StelyraAgent_Copy_Catalog_en_v2_three-layers.json"}

    ui_work = pt_ui_worklist()
    write_json(out / "ui" / "pt-BR-worklist.json", ui_work)
    manifest["ui"] = {"pt-BRUntranslatedEntries": len(ui_work["entries"])}

    help_en = RESOURCES / "Help" / "abc-life-areas-help-en.md"
    if help_en.exists():
        (out / "ui").mkdir(parents=True, exist_ok=True)
        shutil.copy2(help_en, out / "ui" / "abc-life-areas-help-en.md")
    terms_en = RESOURCES / "AstroTerms-en.json"
    if terms_en.exists():
        shutil.copy2(terms_en, out / "ui" / "AstroTerms-en.json")

    write_json(out / "manifest.json", manifest)
    write_validator(out)
    write_apply_script(out)
    write_prompt(out, manifest)
    print(json.dumps(manifest, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
