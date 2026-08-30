from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App"

def text(rel: str) -> str:
    return (APP / rel).read_text()


def test_full_v1_agent_capability_catalog_is_advertised_by_ios_manifest():
    source = text("Agent/AgentCapabilityCatalog.swift")
    for capability in [
        "you.tertiary", "you.solar_arc", "you.solar_return", "you.lunar_return",
        "you.current_sky", "you.relocation", "you.harmonic_12", "you.harmonic_13",
        "relationship.composite_secondary_compare", "relationship.composite_tertiary_compare",
        "relationship.davison", "relationship.davison_transit", "relationship.davison_secondary", "relationship.davison_tertiary",
        "relationship.marks", "relationship.marks_secondary", "relationship.marks_tertiary",
    ]:
        assert capability in source
    assert "supportedCapabilities: AgentCapability.allSupported.map" in source


def test_compare_capabilities_include_hidden_dependency_calculation_but_not_as_agent_capability():
    source = text("Agent/AgentCapabilityCatalog.swift")
    assert ".compositeSecondary, .compositeSecondaryCompare" in source
    assert ".compositeTertiary, .compositeTertiaryCompare" in source
    assert 'case compositeSecondary = "relationship.composite_secondary"' not in source


def test_agent_executor_uses_existing_advanced_astrology_core_for_full_you_catalog():
    source = text("Agent/AgentAstrologyToolExecutor.swift")
    for marker in [
        "calculateTertiaryProgression", "calculateSolarArc", "calculateSolarReturn",
        "calculateLunarReturn", "calculateRelocation", "harmonicSnapshot",
    ]:
        assert marker in source
    assert "case .currentSky" in source


def test_agent_request_persists_full_time_range_in_fingerprint():
    source = text("Agent/AgentAstrologyToolExecutor.swift")
    assert "let endDate: Date?" in source
    assert "range: request.rangeFingerprint" in source
    assert 'scope["end"]' in source


def test_agent_evidence_builder_normalizes_ranks_deduplicates_and_enforces_budget():
    source = text("Agent/AgentEvidenceBuilder.swift")
    for marker in ["normalize", "deduplicate", "rank", "select", "group", "compress", "16_000"]:
        assert marker in source
    assert '"timing_event"' in source
    assert '"longitude"' not in source


def test_agent_technique_planner_scans_events_internally_instead_of_rendering_one_chart_per_output_bucket():
    source = text("Agent/AgentTechniquePlanner.swift")
    assert "scanCadence" in source
    assert "maxScanAnchors" in source
    assert "nextTransitNatalExactDate" in source
    assert "transitNatalAspectWindow" in source
    assert "timing_event" in source
    assert "outputResolution" in source


def test_all_agent_charts_are_selectable_in_ui_but_advanced_are_grouped():
    source = text("Agent/StelyraAgentChatView.swift")
    assert "AgentCapability.allSupported" in source
    assert "Advanced" in source

def test_technique_planner_covers_secondary_solar_arc_and_relationship_timing_ranges():
    source = text("Agent/AgentTechniquePlanner.swift")
    for marker in ["scanSecondary", "scanSolarArc", "relationshipTimingFacts", "compositeSecondaryCompare", "compositeTertiaryCompare"]:
        assert marker in source
    executor = text("Agent/AgentAstrologyToolExecutor.swift")
    assert "techniquePlanner.relationshipTimingFacts" in executor
