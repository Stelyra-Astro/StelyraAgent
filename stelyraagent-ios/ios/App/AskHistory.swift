import AstroCore
import Foundation

struct HorarySession: Codable, Equatable {
    let mode: HoraryQuestionMode
    let question: String
    let createdAt: Date
    let locationName: String
    let timezoneID: String
    let snapshot: ChartSnapshot
    let analysis: HoraryAnalysis?
    let choices: [HoraryChoiceResult]
    let timingCandidates: [ElectionTimingCandidate]
    let significators: [HorarySignificatorAssessment]

    init(
        mode: HoraryQuestionMode,
        question: String,
        createdAt: Date,
        locationName: String,
        timezoneID: String,
        snapshot: ChartSnapshot,
        analysis: HoraryAnalysis?,
        choices: [HoraryChoiceResult],
        timingCandidates: [ElectionTimingCandidate],
        significators: [HorarySignificatorAssessment] = []
    ) {
        self.mode = mode
        self.question = question
        self.createdAt = createdAt
        self.locationName = locationName
        self.timezoneID = timezoneID
        self.snapshot = snapshot
        self.analysis = analysis
        self.choices = choices
        self.timingCandidates = timingCandidates
        self.significators = significators
    }
}

struct AskHistoryEntry: Codable, Identifiable, Equatable {
    static let currentSchemaVersion = 2

    let schemaVersion: Int
    let id: String
    let mode: String
    let question: String
    let answerTitle: String
    let answerText: String
    let createdAt: Date
    let locationName: String
    let significators: [String]
    let session: HorarySession?

    init(
        schemaVersion: Int = Self.currentSchemaVersion,
        id: String,
        mode: String,
        question: String,
        answerTitle: String,
        answerText: String,
        createdAt: Date,
        locationName: String,
        significators: [String],
        session: HorarySession? = nil
    ) {
        self.schemaVersion = schemaVersion
        self.id = id
        self.mode = mode
        self.question = question
        self.answerTitle = answerTitle
        self.answerText = answerText
        self.createdAt = createdAt
        self.locationName = locationName
        self.significators = significators
        self.session = session
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case id
        case mode
        case question
        case answerTitle
        case answerText
        case createdAt
        case locationName
        case significators
        case session
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        id = try container.decode(String.self, forKey: .id)
        mode = try container.decode(String.self, forKey: .mode)
        question = try container.decode(String.self, forKey: .question)
        answerTitle = try container.decode(String.self, forKey: .answerTitle)
        answerText = try container.decode(String.self, forKey: .answerText)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        locationName = try container.decode(String.self, forKey: .locationName)
        significators = try container.decodeIfPresent([String].self, forKey: .significators) ?? []
        session = try container.decodeIfPresent(HorarySession.self, forKey: .session)
    }

    static func == (lhs: AskHistoryEntry, rhs: AskHistoryEntry) -> Bool { lhs.id == rhs.id }
}

final class AskHistoryStore: @unchecked Sendable {
    static let shared = AskHistoryStore()
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.url = base.appendingPathComponent("AskHistory.json")
    }

    func removeAll() {
        try? FileManager.default.removeItem(at: url)
    }

    func load() -> [AskHistoryEntry] {
        guard let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([AskHistoryEntry].self, from: data)
        else {
            return []
        }
        return entries.sorted { $0.createdAt > $1.createdAt }
    }

    func append(_ entry: AskHistoryEntry, limit: Int = 100) {
        var entries = load()
        entries.removeAll { $0.id == entry.id }
        entries.append(entry)
        entries.sort { $0.createdAt > $1.createdAt }
        if entries.count > limit {
            entries = Array(entries.prefix(limit))
        }
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        }
    }

    func remove(id: String) {
        var entries = load()
        entries.removeAll { $0.id == id }
        if entries.isEmpty {
            removeAll()
        } else if let data = try? JSONEncoder().encode(entries) {
            try? data.write(
                to: url,
                options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            )
        }
    }
}
