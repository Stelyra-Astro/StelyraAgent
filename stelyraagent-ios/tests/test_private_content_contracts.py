from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]
PRIVATE = ROOT / "ios/PrivateContent"
LOCALES = ["en", "zh-Hans", "es", "fr", "de", "it", "pt-BR", "tr", "ko"]


def placeholders(value: str):
    return sorted(re.findall(r"\{\{[A-Za-z][A-Za-z0-9]*\}\}", value))


def test_authoritative_today_and_ask_baselines_and_all_available_translations_have_parity():
    for area in ["today", "ask"]:
        for required in ["en", "zh-Hans"]:
            assert (PRIVATE / area / f"Content-{required}.json").exists()
        reference_data = json.loads((PRIVATE / area / "Content-en.json").read_text(encoding="utf-8"))
        reference = {item["contentKey"]: item for item in reference_data["entries"]}
        for locale in LOCALES:
            path = PRIVATE / area / f"Content-{locale}.json"
            if not path.exists():
                continue
            data = json.loads(path.read_text(encoding="utf-8"))
            assert data["schemaVersion"] == 1
            assert data["locale"] == locale
            assert data["area"] == area
            entries = {item["contentKey"]: item for item in data["entries"]}
            assert set(entries) == set(reference)
            assert all(item.get("translationStatus") == "approved" for item in entries.values())
            for key in reference:
                assert placeholders(entries[key]["summary"]) == placeholders(reference[key]["summary"]), (locale, key, "summary")
                assert placeholders(entries[key]["detail"]) == placeholders(reference[key]["detail"]), (locale, key, "detail")


def test_authoritative_chart_catalogs_preserve_existing_locales_and_known_fr_es_delta():
    required = ["en", "zh-Hans", "es", "fr"]
    for locale in required:
        assert (PRIVATE / "charts" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json").exists()

    def flatten(value, prefix=""):
        out = {}
        if isinstance(value, dict):
            for key, child in value.items():
                p = f"{prefix}.{key}" if prefix else key
                out.update(flatten(child, p))
        elif isinstance(value, list):
            for i, child in enumerate(value):
                out.update(flatten(child, f"{prefix}[{i}]"))
        elif isinstance(value, str):
            out[prefix] = value
        return out

    en_data = json.loads((PRIVATE / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json").read_text(encoding="utf-8"))
    en = flatten(en_data)
    checked_prefixes = ("shared.", "modern.", "classical.", "contracts.")
    en_runtime = {k: v for k, v in en.items() if k.startswith(checked_prefixes)}

    # Chinese is the only non-English authoritative catalog currently complete
    # against the latest English runtime paths.
    zh = json.loads((PRIVATE / "charts" / "StelyraAgent_Copy_Catalog_zh-Hans_v2_three-layers.json").read_text(encoding="utf-8"))
    zh_runtime = {k: v for k, v in flatten(zh).items() if k.startswith(checked_prefixes)}
    assert set(zh_runtime) == set(en_runtime)
    for key in en_runtime:
        assert placeholders(zh_runtime[key]) == placeholders(en_runtime[key]), ("zh-Hans", key)

    # FR/ES are approved historical catalogs but each lacks 107 strings added
    # to the latest English classical-transit corpus. They are intentionally
    # preserved and repaired through the translation delta package.
    for locale in ["fr", "es"]:
        data = json.loads((PRIVATE / "charts" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json").read_text(encoding="utf-8"))
        runtime = {k: v for k, v in flatten(data).items() if k.startswith(checked_prefixes)}
        assert set(runtime).issubset(set(en_runtime))
        assert len(set(en_runtime) - set(runtime)) == 107
        for key in runtime:
            assert placeholders(runtime[key]) == placeholders(en_runtime[key]), (locale, key)

