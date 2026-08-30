import Foundation

@MainActor
final class AgentRunCoordinator: ObservableObject {
    @Published private(set) var activeRun: AgentRunResponse?
    @Published private(set) var pendingInteraction: AgentInteraction?
    @Published private(set) var isWorking = false
    @Published private(set) var errorMessage: String?

    private let client: AgentAPIClient
    private let toolExecutor: AgentAstrologyToolExecutor
    private let conversations: AgentConversationStore
    private let analysisStore: AgentAnalysisAssetStore
    private var resumeContext: ResumeContext?
    private var accumulatedChartAssetIDs: [UUID] = []

    private struct ResumeContext {
        let conversationID: UUID
        let question: String
        let localContext: AgentLocalContextSnapshot
    }

    init(
        client: AgentAPIClient,
        toolExecutor: AgentAstrologyToolExecutor,
        conversations: AgentConversationStore,
        analysisStore: AgentAnalysisAssetStore
    ) {
        self.client = client
        self.toolExecutor = toolExecutor
        self.conversations = conversations
        self.analysisStore = analysisStore
    }

    func availableModels() async throws -> [AgentModelOption] {
        try await client.models()
    }

    func send(
        question: String,
        chips: [AgentDraftContextChip],
        conversationID: UUID,
        localContext: AgentLocalContextSnapshot,
        clientVersion: String,
        modelID: String? = nil
    ) async {
        guard !question.trimmed.isEmpty else { return }
        isWorking = true
        errorMessage = nil
        pendingInteraction = nil
        resumeContext = ResumeContext(conversationID: conversationID, question: question, localContext: localContext)
        accumulatedChartAssetIDs = []
        let localMemory = AgentLocalMemoryBuilder.build(
            conversation: conversations.conversation(id: conversationID),
            analyses: analysisStore.analyses(for: conversationID)
        )
        conversations.append(.init(kind: .userMessage, text: question), to: conversationID)
        do {
            let run = try await client.createRun(
                question: question,
                manifest: .current(clientVersion: clientVersion),
                draftContext: chips,
                modelID: modelID,
                localMemory: localMemory
            )
            conversations.setActiveRuntimeCheckpoint(
                runID: run.runID,
                question: question,
                chartAssetIDs: [],
                for: conversationID
            )
            try await process(run)
        } catch {
            failLocally(error, conversationID: conversationID)
        }
    }

    func resumePersistedRun(
        conversationID: UUID,
        localContext: AgentLocalContextSnapshot
    ) async {
        guard !isWorking,
              let checkpoint = conversations.activeRuntimeCheckpoint(for: conversationID) else { return }
        isWorking = true
        errorMessage = nil
        pendingInteraction = nil
        resumeContext = ResumeContext(
            conversationID: conversationID,
            question: checkpoint.question,
            localContext: localContext
        )
        accumulatedChartAssetIDs = checkpoint.chartAssetIDs
        do {
            let run = try await client.getRun(checkpoint.runID)
            try await process(run)
        } catch {
            failLocally(error, conversationID: conversationID)
        }
    }

    func submitInteraction(result: [String: AgentJSONValue]) async {
        guard let interaction = pendingInteraction,
              let run = activeRun,
              let context = resumeContext else { return }
        isWorking = true
        errorMessage = nil
        do {
            pendingInteraction = nil
            let resumed = try await client.submitAction(
                runID: run.runID,
                actionID: interaction.actionID,
                result: result
            )
            try await process(resumed)
        } catch {
            failLocally(error, conversationID: context.conversationID)
        }
    }

    func cancelPendingRun() async {
        guard let run = activeRun else { return }
        let conversationID = resumeContext?.conversationID
        do { _ = try await client.cancel(runID: run.runID) } catch { }
        if let conversationID { conversations.clearActiveRuntimeCheckpoint(for: conversationID) }
        pendingInteraction = nil
        resumeContext = nil
        isWorking = false
    }

    private func process(_ initialRun: AgentRunResponse) async throws {
        guard let context = resumeContext else { throw AgentAPIClient.ClientError.invalidResponse }
        var run = initialRun
        activeRun = run

        while true {
            switch run.status {
            case .requiresAction, .waitingForClient:
                guard let action = run.action else { throw AgentAPIClient.ClientError.invalidResponse }
                if action.type == "astrology_tool", action.tool == "request_astrology_evidence" {
                    let result: [String: AgentJSONValue]
                    do {
                        result = try await toolExecutor.execute(
                            actionPayload: action.payload,
                            conversationID: context.conversationID,
                            context: context.localContext
                        )
                        appendChartReference(from: result, conversationID: context.conversationID)
                    } catch {
                        result = toolErrorResult(error)
                    }
                    run = try await client.submitAction(runID: run.runID, actionID: action.id, result: result)
                    activeRun = run
                } else if let interaction = AgentInteraction.decode(action: action) {
                    pendingInteraction = interaction
                    conversations.append(.init(kind: .interaction, text: interaction.prompt), to: context.conversationID)
                    isWorking = false
                    return
                } else {
                    throw AgentAPIClient.ClientError.invalidResponse
                }

            case .completed:
                let answer = text(from: run.finalAnswer) ?? "Analysis completed."
                conversations.append(.init(kind: .assistantMessage, text: answer), to: context.conversationID)
                let analysis = analysisStore.save(
                    runtimeRunID: run.runID,
                    conversationID: context.conversationID,
                    userQuestion: context.question,
                    analysisPlanJSON: nil,
                    chartAssetRefs: accumulatedChartAssetIDs,
                    keyEvidenceRefs: [],
                    finalAnswer: answer
                )
                conversations.addAnalysisRef(analysis.analysisID, to: context.conversationID)
                if let title = title(from: run.finalAnswer), !title.trimmed.isEmpty {
                    conversations.setTitle(title, for: context.conversationID)
                } else {
                    conversations.setFallbackTitle(from: context.question, for: context.conversationID)
                }
                _ = try await client.acknowledge(runID: run.runID)
                conversations.clearActiveRuntimeCheckpoint(for: context.conversationID)
                activeRun = try? await client.getRun(run.runID)
                pendingInteraction = nil
                resumeContext = nil
                isWorking = false
                return

            case .failed, .cancelled, .expired:
                conversations.clearActiveRuntimeCheckpoint(for: context.conversationID)
                throw NSError(
                    domain: "StelyraAgentRun",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: run.failureReason ?? "The analysis could not be completed."]
                )

            case .created, .reasoning, .resuming, .finalizing:
                try await Task.sleep(for: .milliseconds(250))
                run = try await client.getRun(run.runID)
                activeRun = run

            case .acknowledged:
                conversations.clearActiveRuntimeCheckpoint(for: context.conversationID)
                pendingInteraction = nil
                resumeContext = nil
                isWorking = false
                return
            }
        }
    }

    private func toolErrorResult(_ error: Error) -> [String: AgentJSONValue] {
        let code: String
        if let toolError = error as? AgentAstrologyToolExecutor.ToolError {
            code = toolError.code
        } else {
            code = "local_calculation_failed"
        }
        return [
            "error": .object([
                "code": .string(code),
                "message": .string(error.localizedDescription),
                "recoverable": .bool(true),
            ]),
        ]
    }

    private func appendChartReference(from result: [String: AgentJSONValue], conversationID: UUID) {
        guard case let .array(rawIDs)? = result["chart_asset_ids"] else { return }
        let assetIDs = rawIDs.compactMap { value -> UUID? in
            guard case let .string(raw) = value else { return nil }
            return UUID(uuidString: raw)
        }
        guard !assetIDs.isEmpty else { return }
        for assetID in assetIDs where !accumulatedChartAssetIDs.contains(assetID) {
            accumulatedChartAssetIDs.append(assetID)
        }
        if let context = resumeContext {
            conversations.setActiveRuntimeCheckpoint(
                runID: activeRun?.runID ?? "",
                question: context.question,
                chartAssetIDs: accumulatedChartAssetIDs,
                for: conversationID
            )
        }
        let label = assetIDs.count == 1 ? "1 chart analyzed" : "\(assetIDs.count) charts analyzed"
        conversations.append(.init(kind: .chartReference, text: label, chartAssetIDs: assetIDs), to: conversationID)
    }

    private func text(from value: AgentJSONValue?) -> String? {
        guard let value else { return nil }
        switch value {
        case let .string(text): return text
        case let .object(object):
            if case let .string(text)? = object["text"] { return text }
            if case let .string(text)? = object["answer"] { return text }
            return nil
        default: return nil
        }
    }

    private func title(from value: AgentJSONValue?) -> String? {
        guard case let .object(object)? = value,
              case let .string(title)? = object["title"] else { return nil }
        return title
    }

    private func failLocally(_ error: Error, conversationID: UUID) {
        errorMessage = error.localizedDescription
        conversations.append(.init(kind: .systemNotice, text: error.localizedDescription), to: conversationID)
        isWorking = false
    }
}
