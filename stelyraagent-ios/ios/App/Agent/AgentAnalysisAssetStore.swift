import Combine
import Foundation

@MainActor
final class AgentAnalysisAssetStore: ObservableObject {
    @Published private(set) var analyses: [AgentAnalysisAsset] = []

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.directory = base.appendingPathComponent("StelyraAgent/Analyses", isDirectory: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? FileManager.default.createDirectory(at: self.directory, withIntermediateDirectories: true)
        reload()
    }

    func analyses(for conversationID: UUID) -> [AgentAnalysisAsset] {
        analyses.filter { $0.conversationID == conversationID }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func save(
        runtimeRunID: String,
        conversationID: UUID,
        userQuestion: String,
        analysisPlanJSON: Data?,
        chartAssetRefs: [UUID],
        keyEvidenceRefs: [String],
        finalAnswer: String
    ) -> AgentAnalysisAsset {
        if let existing = analyses.first(where: { $0.runtimeRunID == runtimeRunID }) {
            return existing
        }
        let asset = AgentAnalysisAsset(
            analysisID: UUID(),
            runtimeRunID: runtimeRunID,
            conversationID: conversationID,
            userQuestion: userQuestion,
            analysisPlanJSON: analysisPlanJSON,
            chartAssetRefs: Array(Set(chartAssetRefs)),
            keyEvidenceRefs: Array(Set(keyEvidenceRefs)),
            finalAnswer: finalAnswer,
            createdAt: Date()
        )
        analyses.append(asset)
        persist(asset)
        return asset
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: directory)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        analyses = []
    }

    private func reload() {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        analyses = files.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(AgentAnalysisAsset.self, from: data)
        }.sorted { $0.createdAt > $1.createdAt }
    }

    private func persist(_ analysis: AgentAnalysisAsset) {
        guard let data = try? encoder.encode(analysis) else { return }
        try? data.write(
            to: directory.appendingPathComponent(analysis.analysisID.uuidString + ".json"),
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
