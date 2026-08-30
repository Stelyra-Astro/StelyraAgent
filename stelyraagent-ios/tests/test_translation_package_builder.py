from pathlib import Path
import json
import subprocess

ROOT = Path(__file__).resolve().parents[1]


def test_translation_package_builder_outputs_exact_missing_worklists(tmp_path):
    out = tmp_path / "translation-package"
    subprocess.run([
        "python3", str(ROOT / "scripts" / "build-translation-package.py"),
        "--output", str(out),
    ], check=True, cwd=ROOT)

    manifest = json.loads((out / "manifest.json").read_text(encoding="utf-8"))
    assert manifest["locales"] == ["fr", "es", "de", "it", "pt-BR", "tr", "ko"]
    assert manifest["today"]["source"] == "today/Content-en.json"
    assert manifest["ask"]["source"] == "ask/Content-en.json"
    assert manifest["charts"]["fr"]["mode"] == "delta"
    assert manifest["charts"]["es"]["mode"] == "delta"
    assert manifest["charts"]["fr"]["missingStringPaths"] == 107
    assert manifest["charts"]["es"]["missingStringPaths"] == 107
    for locale in ["de", "it", "pt-BR", "tr", "ko"]:
        assert manifest["charts"][locale]["mode"] == "full"
        assert (out / "charts" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json").exists()
    assert (out / "today" / "Content-en.json").exists()
    assert (out / "ask" / "Content-en.json").exists()
    assert (out / "charts" / "fr-delta.json").exists()
    assert (out / "charts" / "es-delta.json").exists()
    assert (out / "ui" / "pt-BR-worklist.json").exists()
    assert (out / "TRANSLATION_PROMPT.md").exists()
    assert (out / "validate-translations.py").exists()

def test_translation_package_includes_validation_and_apply_handoff(tmp_path):
    out = tmp_path / "translation-package"
    subprocess.run([
        "python3", str(ROOT / "scripts" / "build-translation-package.py"),
        "--output", str(out),
    ], check=True, cwd=ROOT)
    assert (out / "apply-translations.py").exists()
    prompt = (out / "TRANSLATION_PROMPT.md").read_text(encoding="utf-8")
    assert "charts/completed" in prompt
    assert "apply-translations.py" in prompt

def test_translation_validator_rejects_incomplete_handoff(tmp_path):
    out = tmp_path / "translation-package"
    subprocess.run([
        "python3", str(ROOT / "scripts" / "build-translation-package.py"),
        "--output", str(out),
    ], check=True, cwd=ROOT)

    result = subprocess.run(
        ["python3", str(out / "validate-translations.py")],
        cwd=out,
        text=True,
        capture_output=True,
    )
    assert result.returncode != 0
    assert "Missing completed translation" in (result.stdout + result.stderr)


def test_translation_validator_rejects_untouched_full_chart_catalog(tmp_path):
    out = tmp_path / "translation-package"
    subprocess.run([
        "python3", str(ROOT / "scripts" / "build-translation-package.py"),
        "--output", str(out),
    ], check=True, cwd=ROOT)

    # Populate every required completion with structurally valid placeholders so
    # the validator reaches the full-catalog semantic completeness check.
    for area in ["today", "ask"]:
        source = json.loads((out / area / "Content-en.json").read_text(encoding="utf-8"))
        for locale in ["fr", "es", "de", "it", "pt-BR", "tr", "ko"]:
            target = json.loads(json.dumps(source))
            target["locale"] = locale
            for entry in target["entries"]:
                entry["translationStatus"] = "approved"
                entry["summary"] = "Translated " + entry["summary"]
                entry["detail"] = "Translated " + entry["detail"]
            (out / area / "completed" / f"Content-{locale}.json").write_text(
                json.dumps(target, ensure_ascii=False), encoding="utf-8"
            )

    for locale in ["fr", "es"]:
        delta = json.loads((out / "charts" / f"{locale}-delta.json").read_text(encoding="utf-8"))
        for entry in delta["entries"]:
            entry["translation"] = "Translated " + entry["english"]
        (out / "charts" / f"{locale}-delta-completed.json").write_text(
            json.dumps(delta, ensure_ascii=False), encoding="utf-8"
        )

    ui = json.loads((out / "ui" / "pt-BR-worklist.json").read_text(encoding="utf-8"))
    for entry in ui["entries"]:
        entry["translation"] = "Translated " + entry["english"]
    (out / "ui" / "pt-BR-worklist-completed.json").write_text(
        json.dumps(ui, ensure_ascii=False), encoding="utf-8"
    )
    (out / "ui" / "abc-life-areas-help-pt-BR.md").write_text("Traduzido", encoding="utf-8")
    terms = json.loads((out / "ui" / "AstroTerms-en.json").read_text(encoding="utf-8"))
    terms["locale"] = "pt-BR"
    (out / "ui" / "AstroTerms-pt-BR.json").write_text(json.dumps(terms), encoding="utf-8")

    english = json.loads((out / "charts" / "StelyraAgent_Copy_Catalog_en_v2_three-layers.json").read_text(encoding="utf-8"))
    for locale in ["de", "it", "pt-BR", "tr", "ko"]:
        target = json.loads(json.dumps(english))
        target["locale"] = locale
        target["status"] = "approved"
        (out / "charts" / "completed" / f"StelyraAgent_Copy_Catalog_{locale}_v2_three-layers.json").write_text(
            json.dumps(target, ensure_ascii=False), encoding="utf-8"
        )

    result = subprocess.run(
        ["python3", str(out / "validate-translations.py")],
        cwd=out,
        text=True,
        capture_output=True,
    )
    assert result.returncode != 0
    assert "appears untranslated" in (result.stdout + result.stderr)
