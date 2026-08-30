import Combine
import Foundation

struct AgentChartFingerprintInput: Encodable, Sendable {
    let chartKind: String
    let subjects: [String]
    let birthDataIdentityHashes: [String]
    let targetDate: Date?
    let targetLocation: String?
    let preset: String
    let range: String?
    let resolution: String?
    let calculationSchemaVersion: Int
}

enum AgentChartFingerprint {
    static func make(_ input: AgentChartFingerprintInput) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return SHA256Digest.hash(try encoder.encode(input)).hex
    }
}

@MainActor
final class AgentChartAssetStore: ObservableObject {
    @Published private(set) var assets: [ConversationChartAsset] = []

    private let indexURL: URL
    private let artifactDirectory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(directory: URL? = nil) {
        let base = directory ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let root = base.appendingPathComponent("StelyraAgent/ChartAssets", isDirectory: true)
        indexURL = root.appendingPathComponent("assets.json")
        artifactDirectory = root.appendingPathComponent("Artifacts", isDirectory: true)
        try? FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        reloadIndex()
    }

    func assets(for conversationID: UUID) -> [ConversationChartAsset] {
        assets.filter { $0.conversationID == conversationID }.sorted { $0.createdAt > $1.createdAt }
    }

    @discardableResult
    func addLogicalAsset(
        conversationID: UUID,
        semanticFingerprint: String,
        chartKind: String,
        subjectRefs: [String],
        displaySubjects: [String],
        locationSummary: String?,
        timeSummary: String?,
        resolution: String?
    ) -> ConversationChartAsset {
        let asset = ConversationChartAsset(
            assetID: UUID(),
            conversationID: conversationID,
            semanticFingerprint: semanticFingerprint,
            chartKind: chartKind,
            subjectRefs: subjectRefs,
            displaySubjects: displaySubjects,
            locationSummary: locationSummary,
            timeSummary: timeSummary,
            resolution: resolution,
            createdAt: Date(),
            usedByMessageIDs: []
        )
        assets.append(asset)
        persistIndex()
        return asset
    }

    @discardableResult
    func savePhysicalArtifact(_ artifact: AgentChartArtifactFile) -> Bool {
        let destination = artifactURL(semanticFingerprint: artifact.semanticFingerprint)
        if FileManager.default.fileExists(atPath: destination.path) { return true }
        do {
            let data = try encoder.encode(artifact)
            try data.write(to: destination, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            return false
        }
    }

    func physicalArtifact(semanticFingerprint: String) -> AgentChartArtifactFile? {
        let url = artifactURL(semanticFingerprint: semanticFingerprint)
        guard let data = try? Data(contentsOf: url),
              var artifact = try? decoder.decode(AgentChartArtifactFile.self, from: data),
              artifact.semanticFingerprint == semanticFingerprint
        else { return nil }
        artifact.lastAccessedAt = Date()
        if let refreshed = try? encoder.encode(artifact) { try? refreshed.write(to: url, options: [.atomic]) }
        return artifact
    }

    func computedPayload(for asset: ConversationChartAsset) -> AgentComputedChartPayload? {
        guard let artifact = physicalArtifact(semanticFingerprint: asset.semanticFingerprint) else { return nil }
        return try? decoder.decode(AgentComputedChartPayload.self, from: artifact.payload)
    }

    func removeConversationAssets(_ conversationID: UUID) {
        assets.removeAll { $0.conversationID == conversationID }
        persistIndex()
    }

    func removeAll() {
        let root = indexURL.deletingLastPathComponent()
        try? FileManager.default.removeItem(at: root)
        try? FileManager.default.createDirectory(at: artifactDirectory, withIntermediateDirectories: true)
        assets = []
    }

    private func artifactURL(semanticFingerprint: String) -> URL {
        artifactDirectory.appendingPathComponent(semanticFingerprint + ".json")
    }

    private func reloadIndex() {
        guard let data = try? Data(contentsOf: indexURL), let decoded = try? decoder.decode([ConversationChartAsset].self, from: data) else { return }
        assets = decoded
    }

    private func persistIndex() {
        guard let data = try? encoder.encode(assets) else { return }
        try? data.write(to: indexURL, options: [.atomic])
    }
}
