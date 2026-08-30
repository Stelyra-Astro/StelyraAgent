from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App"

def text(rel: str) -> str:
    return (APP / rel).read_text()

def test_agent_is_the_default_root_surface():
    root = text("RootView.swift")
    assert "case agent" in root
    assert "@State private var selection: RootTab = .agent" in root
    assert "StelyraAgentChatView" in root

def test_phase1_capabilities_and_relationship_mapping_are_frozen():
    source = text("Agent/AgentCapabilityCatalog.swift")
    for capability in [
        "you.natal", "you.transit", "you.secondary",
        "relationship.synastry", "relationship.composite", "relationship.composite_transit",
    ]:
        assert capability in source
    assert ".synastryA" in source and ".synastryB" in source
    assert ".compositeTransit" in source

def test_theme_catalog_contains_all_eight_frozen_themes():
    source = text("Agent/AgentThemeCatalog.swift")
    for title in [
        "Love & Relationships", "Career & Purpose", "Money & Growth", "Family & Home",
        "Self & Wellbeing", "Creativity & Expression", "Learning & Exploration", "Life Direction",
    ]:
        assert title in source

def test_agent_chart_storage_separates_logical_assets_from_physical_fingerprint_files():
    source = text("Agent/AgentChartAssetStore.swift")
    assert "ConversationChartAsset" in source
    assert "AgentChartArtifactFile" in source
    assert "semanticFingerprint" in source
    assert "fileExists(atPath:" in source
    assert "same chart kind" not in source.lower()

def test_agent_api_uses_pause_resume_endpoints_from_spec():
    source = text("Agent/AgentAPIClient.swift")
    for endpoint in ["/v1/runs", "/actions", "/ack", "/cancel", "/v1/capabilities", "/v1/runtime-config"]:
        assert endpoint in source

def test_storekit_listener_covers_updates_and_unfinished_without_finishing_before_server_ack():
    source = text("Agent/AgentStoreKitCoordinator.swift")
    assert "Transaction.updates" in source
    assert "Transaction.unfinished" in source
    assert "await reconcile" in source
    assert "await transaction.finish()" in source
    assert source.index("await reconcile") < source.index("await transaction.finish()")

def test_reset_and_delete_copy_explicitly_says_remaining_credits_are_not_recoverable():
    source = text("Agent/StelyraAgentAccountView.swift")
    assert "Remaining Credits will not be recoverable after reset." in source
    assert "Remaining Credits will not be recoverable after account deletion." in source

def test_project_has_independent_agent_runtime_configuration():
    project = (ROOT / "ios" / "project.yml").read_text()
    assert "STELYRAAGENT_RUNTIME_BASE_URL" in project
    assert "INFOPLIST_KEY_CFBundleDisplayName: StelyraAgent" in project

def test_agent_account_client_covers_apple_auth_session_account_and_iap_endpoints():
    source = text("Agent/AgentAPIClient.swift")
    for endpoint in [
        "/v1/auth/apple", "/v1/auth/refresh", "/v1/auth/logout",
        "/v1/account/reset", "/v1/account", "/v1/credits", "/v1/iap/reconcile",
    ]:
        assert endpoint in source
    assert "DELETE" in source


def test_agent_credentials_are_persisted_in_keychain_not_userdefaults():
    source = text("Agent/AgentCredentialStore.swift")
    assert "import Security" in source
    assert "kSecClassGenericPassword" in source
    assert "SecItemAdd" in source
    assert "SecItemCopyMatching" in source
    assert "UserDefaults" not in source


def test_sign_in_with_apple_uses_nonce_and_runtime_exchange():
    source = text("Agent/AgentAccountCoordinator.swift")
    assert "import AuthenticationServices" in source
    assert "SHA256" in source
    assert "request.nonce" in source
    assert "identityToken" in source
    assert "authorizationCode" in source
    assert "signInWithApple" in source


def test_storekit_sends_jws_to_runtime_and_tracks_true_pending_purchases():
    source = text("Agent/AgentStoreKitCoordinator.swift")
    assert "jwsRepresentation" in source
    assert "appAccountToken" in source
    assert ".pending" in source
    assert "pendingProductIDs" in source
    assert "await transaction.finish()" in source


def test_account_reset_delete_preflight_mentions_pending_apple_purchase():
    source = text("Agent/StelyraAgentAccountView.swift")
    assert "hasPendingPurchase" in source
    assert "purchase still pending with Apple" in source
    assert "won't cancel the App Store transaction" in source


def test_native_interaction_model_and_resume_surface_exist():
    models = text("Agent/AgentModels.swift")
    coordinator = text("Agent/AgentRunCoordinator.swift")
    chat = text("Agent/StelyraAgentChatView.swift")
    assert "enum AgentInteractionKind" in models
    for kind in ["analysisChoice", "clarifyIntent", "requiredInput", "planReview"]:
        assert kind in models
    assert "pendingInteraction" in coordinator
    assert "submitInteraction" in coordinator
    assert "AgentInteractionView" in chat
    assert "plan_review" in models


def test_local_astrology_tool_failures_are_submitted_as_structured_action_results():
    executor = text("Agent/AgentAstrologyToolExecutor.swift")
    coordinator = text("Agent/AgentRunCoordinator.swift")
    assert "var code: String" in executor
    for code in [
        '"malformed_request"', '"unsupported_capability"', '"missing_subject"',
        '"relationship_needs_two_subjects"', '"missing_location"', '"missing_ephemeris"',
    ]:
        assert code in executor
    assert "toolErrorResult" in coordinator
    assert '"error"' in coordinator
    assert '"code"' in coordinator
    assert "submitAction" in coordinator


def test_agent_tool_accepts_spec_date_only_time_scope_values():
    source = text("Agent/AgentAstrologyToolExecutor.swift")
    assert "parseAgentDate" in source
    assert 'dateFormat = "yyyy-MM-dd"' in source
    assert "en_US_POSIX" in source


def test_agent_asset_opens_full_chart_detail_from_persisted_physical_artifact():
    store = text("Agent/AgentChartAssetStore.swift")
    view = text("Agent/AgentAssetsView.swift")
    executor = text("Agent/AgentAstrologyToolExecutor.swift")
    assert "func computedPayload(for asset:" in store
    assert "AgentChartDetailView" in view
    assert "NavigationLink" in view
    for section in ["Wheel", "Positions", "Aspects", "Houses", "Calculation details"]:
        assert section in view
    assert "private struct AgentComputedChartPayload" not in executor


def test_completed_run_persists_local_analysis_asset_and_has_title_fallback():
    store = text("Agent/AgentAnalysisAssetStore.swift") if (APP / "Agent/AgentAnalysisAssetStore.swift").exists() else ""
    coordinator = text("Agent/AgentRunCoordinator.swift")
    conversations = text("Agent/AgentConversationStore.swift")
    chat = text("Agent/StelyraAgentChatView.swift")
    assert "final class AgentAnalysisAssetStore" in store
    assert "func save(" in store
    assert "analysisStore.save" in coordinator
    assert "addAnalysisRef" in conversations
    assert "setFallbackTitle" in conversations
    assert "AgentAnalysisAssetStore()" in chat
    assert "analyses.removeAll()" in chat


def test_plan_review_cancel_releases_the_run_instead_of_resubmitting_a_decline_loop():
    chat = text("Agent/StelyraAgentChatView.swift")
    assert "interaction.kind == .planReview" in chat
    assert "cancelPendingRun" in chat


def test_agent_requires_explicit_local_ai_data_consent_before_first_runtime_analysis():
    chat = text("Agent/StelyraAgentChatView.swift")
    assert "Allow AI Analysis" in chat
    assert "model.aiConsentGranted" in chat
    assert "model.grantAIConsent()" in chat
    for phrase in [
        "birth date and time", "birth city", "selected people", "calculated astrology evidence", "active analysis",
    ]:
        assert phrase in chat


def test_account_page_loads_runtime_purchase_history_and_subscription_status():
    api = text("Agent/AgentAPIClient.swift")
    coordinator = text("Agent/AgentAccountCoordinator.swift")
    view = text("Agent/StelyraAgentAccountView.swift")
    assert "struct AgentPurchaseRecord" in api
    assert 'path: "/v1/purchases"' in api
    assert 'path: "/v1/subscription"' in api
    assert "purchaseHistory" in coordinator
    assert "subscriptionStatus" in coordinator
    assert "NavigationLink(\"Purchase History\")" in view
    assert "LabeledContent(\"Subscription\"" in view

def test_reset_delete_require_verified_unfinished_storekit_preflight_before_server_account_mutation():
    storekit = text("Agent/AgentStoreKitCoordinator.swift")
    view = text("Agent/StelyraAgentAccountView.swift")
    assert "prepareForAccountDestructiveAction" in storekit
    assert "unresolvedVerifiedTransactionIDs" in storekit
    assert "canProceed" in storekit
    assert "await storeKit.prepareForAccountDestructiveAction()" in view
    reset_call = view.index("try await account.resetAccount()")
    delete_call = view.index("try await account.deleteAccount()")
    first_preflight = view.index("await storeKit.prepareForAccountDestructiveAction()")
    second_preflight = view.index("await storeKit.prepareForAccountDestructiveAction()", first_preflight + 1)
    assert first_preflight < reset_call
    assert second_preflight < delete_call

def test_active_run_checkpoint_is_persisted_locally_and_resumed_after_app_restart():
    models = text("Agent/AgentModels.swift")
    store = text("Agent/AgentConversationStore.swift")
    coordinator = text("Agent/AgentRunCoordinator.swift")
    chat = text("Agent/StelyraAgentChatView.swift")
    assert "AgentPersistedRuntimeCheckpoint" in models
    assert "setActiveRuntimeCheckpoint" in store
    assert "activeRuntimeCheckpoint" in store
    assert "clearActiveRuntimeCheckpoint" in store
    assert "resumePersistedRun" in coordinator
    assert "setActiveRuntimeCheckpoint" in coordinator
    assert "clearActiveRuntimeCheckpoint" in coordinator
    assert "await runs.resumePersistedRun" in chat
