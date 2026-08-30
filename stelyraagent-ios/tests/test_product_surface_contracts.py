from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[1]


def read(path: str) -> str:
    return (ROOT / path).read_text(encoding="utf-8")


def test_app_language_has_nine_locales_and_domain_specific_content_languages():
    source = read("ios/App/Models.swift")
    for raw in ["en", "zh-Hans", "es", "fr", "de", "it", "pt-BR", "tr", "ko"]:
        assert f'= "{raw}"' in source
    assert "corpusLanguage" not in source
    for name in ["chartContentLanguage", "todayContentLanguage", "askContentLanguage", "reportRequestLanguage"]:
        assert name in source


def test_localization_builder_has_nine_locales():
    source = read("scripts/build-ios-localization.mjs")
    assert '"pt-BR"' in source
    assert "AstroTerms-pt-BR.json" in source or "pt-BR" in source
    fragments = ROOT / "ios/Localization/UI"
    for path in fragments.glob("*.json"):
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, entry in data.items():
            assert set(entry) == {"en", "zh", "es", "fr", "tr", "de", "it", "pt-BR", "ko"}, (path.name, key)


def test_you_and_bonds_fixed_shortcuts_are_explicit_and_synastry_not_in_you():
    source = read("ios/App/ChartsView.swift")
    assert "enum ChartsSpace" in source
    assert "case you" in source and "case bonds" in source
    compact = re.sub(r"\s+", "", source)
    assert "[.natal,.transit,.secondary]" in compact
    assert "[.composite,.synastryA,.compositeTransit]" in compact
    assert "relationship.more" in source


def test_reports_have_you_bonds_and_all_relationship_report_ids():
    source = read("ios/App/ReportsView.swift")
    assert "ReportSpace" in source
    assert "relationshipReportTargets" in source
    rel = read("ios/Packages/AstroCore/Sources/AstroCore/RelationshipCharts.swift")
    kinds = re.findall(r"^\s*case\s+(\w+)\s*=\s*\"[^\"]+\"", rel, flags=re.M)
    assert len(kinds) == 16
    for kind in kinds:
        assert f".{kind}" in source


def test_cancel_subscription_uses_native_storekit_management_sheet():
    source = read("ios/App/ProfileView.swift")
    assert "commerce.cancel-subscription" in source
    assert "manageSubscriptionsSheet" in source


def test_today_content_error_is_not_misclassified_as_chart_calculation_error():
    source = read("ios/App/AppModel.swift")
    assert "todayContentErrorMessage" in source
    assert "ConsumerContentError" in source
    # Local chart calculation error remains for actual calculation failures.
    assert 'localized("app.error.local-chart-calculation"' in source
    # Today dashboard creation must route through a content-specific boundary.
    assert "makeTodayDashboard" in source


def test_chart_cards_do_not_depend_on_legacy_private_corpus_provider():
    model = read("ios/App/AppModel.swift")
    assert "corpusProviders" not in model
    assert "CorpusContentProvider(language:" not in model
    assert "content: nil" in model


def test_portuguese_language_title_and_help_resource_are_registered():
    core = json.loads((ROOT / "ios/Localization/UI/core.json").read_text(encoding="utf-8"))
    assert core["language.portuguese-brazil"]["pt-BR"] == "Português (Brasil)"
    source = read("ios/App/SynastryView.swift")
    assert 'case .portugueseBrazil: "pt-BR"' in source


def test_portuguese_terms_are_bundled_and_known_region_is_registered():
    project = read("ios/StelyraAgent.xcodeproj/project.pbxproj")
    assert "AstroTerms-pt-BR.json in Resources" in project
    assert '"pt-BR",' in project


def test_today_view_surfaces_content_error_separately_from_calculation_error():
    source = read("ios/App/TodayView.swift")
    assert "todayContentErrorMessage" in source
    assert "model.errorMessage" in source

def test_relationship_report_and_chart_state_are_cleared_with_existing_reset_flows():
    source = read("ios/App/AppModel.swift")
    assert "relationshipAIContent = [:]" in source
    assert "generatingRelationships = []" in source
    assert "relationshipArtifacts = [:]" in source
    assert "relationshipLoadStates = [:]" in source

def test_relationship_invalidation_also_invalidates_relationship_report_state():
    source = read("ios/App/AppModel.swift")
    assert "relationshipAIContent[kind.rawValue] = .empty" in source
    block = source[source.index("private func invalidateAllRelationshipCharts"):source.index("func clearReports")]
    assert "relationshipAIContent.removeAll()" in block

def test_synastry_direction_is_a_single_bonds_surface_with_a_b_switch():
    source = read("ios/App/ChartsView.swift")
    assert 'relationship.synastry-direction' in source
    assert 'model.selectRelationshipChart(.synastryA)' in source
    assert 'model.selectRelationshipChart(.synastryB)' in source
    # Reverse synastry is reachable via the direction control, not another More tile.
    assert 'kinds: [.synastryB]' not in source


def test_reverse_synastry_report_has_a_distinct_display_title():
    source = read("ios/App/ReportsView.swift")
    assert 'relationshipReportTitle' in source
    assert 'relationship.synastry-reverse' in source

def test_reverse_synastry_keeps_the_fixed_synastry_shortcut_selected():
    source = read("ios/App/ChartsView.swift")
    assert "isRelationshipShortcutSelected" in source
    assert "selectedRelationshipChart.isSynastry" in source

def test_relationship_report_params_only_include_technique_relevant_overrides():
    models = read("ios/App/Models.swift")
    app_model = read("ios/App/AppModel.swift")
    assert "supportsTransitLocation" in models
    assert "if kind.supportsTransitLocation" in app_model
    assert "if kind.supportsMidpointAlgorithm" in app_model

def test_reverse_synastry_generation_sheet_uses_reverse_title():
    source = read("ios/App/ReportsView.swift")
    block = source[source.index("struct RelationshipReportGenerationSheet"):]
    assert "relationshipReportDisplayTitle" in block
    assert 'relationship.synastry-reverse' in block

def test_bonds_synastry_uses_its_own_premium_card_locking_rule():
    source = read("ios/App/ChartsView.swift")
    block = source[source.index("private func shouldLockCard"):source.index("private var showsPremiumPreview")]
    assert "chartsSpace == .bonds" in block
    assert "model.selectedChart" in block

def test_portuguese_help_resource_is_bundled_for_the_registered_help_code():
    project = read("ios/StelyraAgent.xcodeproj/project.pbxproj")
    assert "abc-life-areas-help-pt-BR.md in Resources" in project
    assert (ROOT / "ios/App/Resources/Help/abc-life-areas-help-pt-BR.md").exists()

def test_relationship_generation_sheet_only_shows_relevant_parameters():
    source = read("ios/App/ReportsView.swift")
    block = source[source.index("struct RelationshipReportGenerationSheet"):]
    assert "kind.supportsMidpointAlgorithm" in block
    assert "kind.supportsTransitLocation" in block

def test_shared_relationship_parameter_changes_invalidate_all_affected_cached_kinds():
    source = read("ios/App/AppModel.swift")
    target_block = source[source.index("func setRelationshipTargetDate"):source.index("func resetRelationshipTargetDate")]
    assert "RelationshipChartKind.allCases" in target_block
    assert ".needsTargetDate" in target_block
    location_block = source[source.index("func setRelationshipLocation"):source.index("func setRelationshipMidpointAlgorithm")]
    assert "RelationshipChartKind.allCases" in location_block
    assert ".supportsTransitLocation" in location_block
    midpoint_block = source[source.index("func setRelationshipMidpointAlgorithm"):source.index("func setRelationshipPerspective")]
    assert "RelationshipChartKind.allCases" in midpoint_block
    assert ".supportsMidpointAlgorithm" in midpoint_block
    perspective_block = source[source.index("func setRelationshipPerspective"):source.index("func ensureRelationshipChartCalculated")]
    assert ".marksSecondary" in perspective_block and ".marksTertiary" in perspective_block
    assert "invalidateRelationshipChart" in perspective_block
