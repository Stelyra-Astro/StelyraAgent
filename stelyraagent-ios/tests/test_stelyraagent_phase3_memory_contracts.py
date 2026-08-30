from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "ios" / "App" / "Agent"

def source(name: str) -> str:
    return (APP / name).read_text()


def test_local_memory_builder_is_structured_bounded_and_does_not_upload_full_conversation():
    text = source("AgentLocalMemoryBuilder.swift")
    for field in ["conversationGoal", "chartAssetRefs", "previousConclusions", "analysisRefs"]:
        assert field in text
    assert "prefix(3)" in text or "prefix(3" in text
    assert "prefix(600)" in text or "600" in text
    assert "conversation.messages" not in text or ".map(\\.text)" not in text
    assert "systemInstruction" not in text


def test_create_run_sends_only_structured_local_memory_snapshot():
    text = source("AgentAPIClient.swift")
    request_slice = text.split("private struct AgentCreateRunRequest", 1)[1].split("private struct AgentSubmitActionRequest", 1)[0]
    assert "localMemory" in request_slice
    assert 'case localMemory = "local_memory"' in request_slice
    create_slice = text.split("func createRun(", 1)[1].split("func models()", 1)[0]
    assert "localMemory:" in create_slice


def test_run_coordinator_builds_memory_before_appending_current_user_message():
    text = source("AgentRunCoordinator.swift")
    build = text.index("AgentLocalMemoryBuilder")
    append = text.index("conversations.append(.init(kind: .userMessage")
    assert build < append
    assert "localMemory: localMemory" in text
