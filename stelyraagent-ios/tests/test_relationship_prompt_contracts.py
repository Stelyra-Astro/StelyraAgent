import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROMPTS = ROOT / "ios/PrivateContent/prompts/RelationshipReportPrompts-en.json"


def test_relationship_prompt_registry_covers_all_16_calculation_kinds_and_forbids_recalculation():
    rel_source = (ROOT / "ios/Packages/AstroCore/Sources/AstroCore/RelationshipCharts.swift").read_text(encoding="utf-8")
    raw_values = re.findall(r'^\s*case\s+\w+\s*=\s*"([^"]+)"', rel_source, flags=re.M)[:16]
    assert len(raw_values) == 16
    data = json.loads(PROMPTS.read_text(encoding="utf-8"))
    assert data["version"] == 1
    assert data["basePrompt"]["factsPolicy"]
    assert "Never recalculate" in data["basePrompt"]["factsPolicy"]
    prompts = data["prompts"]
    assert set(prompts) == {f"relationship.{raw}" for raw in raw_values}
    for key, prompt in prompts.items():
        assert prompt["techniqueMeaning"]
        assert prompt["interpretationFocus"]
        assert prompt["doNotConfuseWith"]
        assert prompt["sections"]


def test_comparison_and_directional_relationship_prompts_keep_technique_semantics_distinct():
    prompts = json.loads(PROMPTS.read_text(encoding="utf-8"))["prompts"]
    assert "direction" in prompts["relationship.synastry-a"]["techniqueMeaning"].lower()
    assert "direction" in prompts["relationship.synastry-b"]["techniqueMeaning"].lower()
    assert "mathematical midpoint" in prompts["relationship.composite"]["techniqueMeaning"].lower()
    assert "time-space midpoint" in prompts["relationship.davison"]["techniqueMeaning"].lower()
    assert "radix composite" in prompts["relationship.composite-secondary-compare"]["techniqueMeaning"].lower()
    assert "marks" in prompts["relationship.marks-a"]["techniqueMeaning"].lower()
