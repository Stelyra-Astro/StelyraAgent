import json
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "ios/PrivateContent/charts/StelyraAgent_Copy_Catalog_en_v2_three-layers.json"
SCRIPT = ROOT / "scripts/build-ios-copy-catalog.mjs"


def test_builder_converts_authoritative_v2_source_to_runtime_catalog(tmp_path):
    output = tmp_path / "CopyCatalog-en.json"
    result = subprocess.run(
        ["node", str(SCRIPT), "--build", str(SOURCE), str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert result.returncode == 0, result.stderr or result.stdout
    runtime = json.loads(output.read_text(encoding="utf-8"))
    assert runtime["schemaVersion"] == 2
    assert runtime["contentVersion"] == "2.0.2"
    assert runtime["locale"] == "en"
    assert runtime["status"] == "approved"
    assert len(runtime["contracts"]) == 51
    assert set(runtime["themeRulesByPreset"]) == {"modern", "classical"}
    paths = {entry["sourcePath"]: entry for entry in runtime["entries"]}
    assert paths["shared.lifeAreas.1"]["value"] == "Identity & self-direction"
    template = paths["shared.technical.templates.planetInSignHouse"]
    assert [item["name"] for item in template["variables"]] == ["planet", "sign", "houseLabel"]
    assert [item["type"] for item in template["variables"]] == ["body", "sign", "house"]
    assert paths["modern.synastry.perspectives.mental-activation.headline"]["variables"] == [
        {"name": "otherName", "type": "personName"}
    ]


def test_runtime_validator_accepts_builder_output(tmp_path):
    output = tmp_path / "CopyCatalog-en.json"
    subprocess.run(["node", str(SCRIPT), "--build", str(SOURCE), str(output)], cwd=ROOT, check=True)
    result = subprocess.run(
        ["node", str(SCRIPT), "--validate-runtime", str(output)],
        cwd=ROOT,
        text=True,
        capture_output=True,
    )
    assert result.returncode == 0, result.stderr or result.stdout
