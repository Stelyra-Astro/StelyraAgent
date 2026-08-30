import Combine
import Foundation

@MainActor
final class AgentConversationStore: ObservableObject {
    @Published private(set) var conversations: [AgentConversation] = []

    private let directory: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("StelyraAgent/Conversations", isDirectory: true)
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        reload()
    }

    func conversation(id: UUID) -> AgentConversation? {
        conversations.first { $0.id == id }
    }

    @discardableResult
    func createConversation() -> AgentConversation {
        let value = AgentConversation.new()
        conversations.insert(value, at: 0)
        persist(value)
        return value
    }

    func upsert(_ conversation: AgentConversation) {
        var value = conversation
        value.updatedAt = Date()
        conversations.removeAll { $0.id == value.id }
        conversations.append(value)
        conversations.sort { $0.updatedAt > $1.updatedAt }
        persist(value)
    }

    func append(_ message: AgentConversationMessage, to conversationID: UUID) {
        guard var conversation = conversation(id: conversationID) else { return }
        conversation.messages.append(message)
        conversation.updatedAt = message.createdAt
        for assetID in message.chartAssetIDs where !conversation.chartAssetRefs.contains(assetID) {
            conversation.chartAssetRefs.append(assetID)
        }
        upsert(conversation)
    }

    func setTitle(_ title: String, for conversationID: UUID) {
        guard var conversation = conversation(id: conversationID) else { return }
        conversation.title = String(title.prefix(80))
        upsert(conversation)
    }

    func setFallbackTitle(from question: String, for conversationID: UUID) {
        guard let current = conversation(id: conversationID), current.title == "StelyraAgent" else { return }
        let words = question
            .split(whereSeparator: { $0.isWhitespace })
            .prefix(7)
            .map(String.init)
        let title = words.joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return }
        setTitle(String(title.prefix(64)), for: conversationID)
    }

    func addAnalysisRef(_ analysisID: UUID, to conversationID: UUID) {
        guard var conversation = conversation(id: conversationID) else { return }
        if !conversation.analysisRefs.contains(analysisID) { conversation.analysisRefs.append(analysisID) }
        upsert(conversation)
    }

    func setActiveRuntimeCheckpoint(
        runID: String,
        question: String,
        chartAssetIDs: [UUID],
        for conversationID: UUID
    ) {
        guard var conversation = conversation(id: conversationID) else { return }
        conversation.runtimeMetadata["active_run_id"] = runID
        conversation.runtimeMetadata["active_run_question"] = question
        conversation.runtimeMetadata["active_run_chart_asset_ids"] = chartAssetIDs.map(\.uuidString).joined(separator: ",")
        upsert(conversation)
    }

    func activeRuntimeCheckpoint(for conversationID: UUID) -> AgentPersistedRuntimeCheckpoint? {
        guard let conversation = conversation(id: conversationID),
              let runID = conversation.runtimeMetadata["active_run_id"], !runID.isEmpty,
              let question = conversation.runtimeMetadata["active_run_question"], !question.isEmpty else { return nil }
        let chartAssetIDs = conversation.runtimeMetadata["active_run_chart_asset_ids"]
            .map { raw in raw.split(separator: ",").compactMap { UUID(uuidString: String($0)) } } ?? []
        return AgentPersistedRuntimeCheckpoint(runID: runID, question: question, chartAssetIDs: chartAssetIDs)
    }

    func clearActiveRuntimeCheckpoint(for conversationID: UUID) {
        guard var conversation = conversation(id: conversationID) else { return }
        conversation.runtimeMetadata.removeValue(forKey: "active_run_id")
        conversation.runtimeMetadata.removeValue(forKey: "active_run_question")
        conversation.runtimeMetadata.removeValue(forKey: "active_run_chart_asset_ids")
        upsert(conversation)
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        conversations = []
    }

    private func reload() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        conversations = files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(AgentConversation.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    private func persist(_ conversation: AgentConversation) {
        guard let data = try? encoder.encode(conversation) else { return }
        try? data.write(to: directory.appendingPathComponent(conversation.id.uuidString + ".json"), options: [.atomic])
    }
}
