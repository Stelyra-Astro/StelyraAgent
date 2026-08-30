import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/build-ios-private-content.mjs"


def test_private_content_builder_generates_unique_runtime_names_and_available_catalogs(tmp_path):
    output = tmp_path / "PrivateContent"
    result = subprocess.run(
        ["node", str(SCRIPT), "--build", "--output", str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    assert (output / "PrivateContent-today-en.json").exists()
    assert (output / "PrivateContent-today-zh-Hans.json").exists()
    assert (output / "PrivateContent-ask-en.json").exists()
    assert (output / "PrivateContent-ask-zh-Hans.json").exists()
    assert (output / "CopyCatalog-en.json").exists()
    assert (output / "CopyCatalog-fr.json").exists()
    today = json.loads((output / "PrivateContent-today-en.json").read_text(encoding="utf-8"))
    ask = json.loads((output / "PrivateContent-ask-en.json").read_text(encoding="utf-8"))
    assert today["area"] == "today"
    assert ask["area"] == "ask"


def test_project_has_private_content_folder_resource_for_future_locale_imports():
    project = (ROOT / "ios/StelyraAgent.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
    assert "PrivateContent in Resources" in project
    assert "path = PrivateContent;" in project
