from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App"

def text(rel: str) -> str:
    return (APP / rel).read_text()


def test_create_run_uses_server_model_id_and_no_longer_sends_client_credit_amount():
    source = text("Agent/AgentAPIClient.swift")
    assert 'case modelID = "model_id"' in source
    request_slice = source.split('private struct AgentCreateRunRequest', 1)[1].split('private struct AgentSubmitActionRequest', 1)[0]
    assert 'creditsRequired' not in request_slice
    assert 'func models() async throws -> [AgentModelOption]' in source


def test_chat_exposes_server_approved_model_picker_with_credit_tier():
    source = text("Agent/StelyraAgentChatView.swift")
    assert 'selectedModelID' in source
    assert 'availableModels' in source
    assert 'creditsRequired' in source
    assert 'await loadModels()' in source


def test_run_coordinator_forwards_selected_model_id_but_not_provider_or_price():
    source = text("Agent/AgentRunCoordinator.swift")
    assert 'modelID: String?' in source
    assert 'modelID: modelID' in source
    assert 'providerModel' not in source
    assert 'creditsRequired' not in source
