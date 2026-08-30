import Foundation

enum AgentDraftContextKind: String, Codable, Sendable {
    case theme
    case chart
    case person
    case asset
}

struct AgentDraftContextChip: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: AgentDraftContextKind
    let value: String
    let title: String

    init(id: UUID = UUID(), kind: AgentDraftContextKind, value: String, title: String) {
        self.id = id
        self.kind = kind
        self.value = value
        self.title = title
    }
}

enum AgentMessageKind: String, Codable, Sendable {
    case userMessage
    case assistantMessage
    case interaction
    case chartReference
    case systemNotice
}

struct AgentConversationMessage: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let kind: AgentMessageKind
    let text: String
    let createdAt: Date
    let chartAssetIDs: [UUID]

    init(
        id: UUID = UUID(),
        kind: AgentMessageKind,
        text: String,
        createdAt: Date = Date(),
        chartAssetIDs: [UUID] = []
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.createdAt = createdAt
        self.chartAssetIDs = chartAssetIDs
    }
}

struct AgentPersistedRuntimeCheckpoint: Equatable, Sendable {
    let runID: String
    let question: String
    let chartAssetIDs: [UUID]
}

struct AgentConversation: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var title: String
    let createdAt: Date
    var updatedAt: Date
    var messages: [AgentConversationMessage]
    var chartAssetRefs: [UUID]
    var analysisRefs: [UUID]
    var localSummary: String?
    var runtimeMetadata: [String: String]

    static func new(id: UUID = UUID(), now: Date = Date()) -> AgentConversation {
        AgentConversation(
            id: id,
            title: "StelyraAgent",
            createdAt: now,
            updatedAt: now,
            messages: [],
            chartAssetRefs: [],
            analysisRefs: [],
            localSummary: nil,
            runtimeMetadata: [:]
        )
    }
}

struct ConversationChartAsset: Identifiable, Codable, Equatable, Sendable {
    let assetID: UUID
    let conversationID: UUID
    let semanticFingerprint: String
    let chartKind: String
    let subjectRefs: [String]
    let displaySubjects: [String]
    let locationSummary: String?
    let timeSummary: String?
    let resolution: String?
    let createdAt: Date
    var usedByMessageIDs: [UUID]

    var id: UUID { assetID }
}

struct AgentChartArtifactFile: Codable, Equatable, Sendable {
    let semanticFingerprint: String
    let schemaVersion: Int
    let calculationSchemaVersion: Int
    let payload: Data
    let createdAt: Date
    var lastAccessedAt: Date
}

struct AgentAnalysisAsset: Identifiable, Codable, Equatable, Sendable {
    let analysisID: UUID
    let runtimeRunID: String?
    let conversationID: UUID
    let userQuestion: String
    let analysisPlanJSON: Data?
    let chartAssetRefs: [UUID]
    let keyEvidenceRefs: [String]
    let finalAnswer: String
    let createdAt: Date

    var id: UUID { analysisID }
}

enum AgentRunStatus: String, Codable, Sendable {
    case created
    case reasoning
    case requiresAction = "requires_action"
    case waitingForClient = "waiting_for_client"
    case resuming
    case finalizing
    case completed
    case failed
    case cancelled
    case expired
    case acknowledged
}

enum AgentJSONValue: Codable, Equatable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case object([String: AgentJSONValue])
    case array([AgentJSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() { self = .null }
        else if let value = try? container.decode(Bool.self) { self = .bool(value) }
        else if let value = try? container.decode(Double.self) { self = .number(value) }
        else if let value = try? container.decode(String.self) { self = .string(value) }
        else if let value = try? container.decode([String: AgentJSONValue].self) { self = .object(value) }
        else { self = .array(try container.decode([AgentJSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .string(value): try container.encode(value)
        case let .number(value): try container.encode(value)
        case let .bool(value): try container.encode(value)
        case let .object(value): try container.encode(value)
        case let .array(value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

enum AgentInteractionKind: String, Codable, Sendable {
    case analysisChoice = "analysis_choice"
    case clarifyIntent = "clarify_intent"
    case requiredInput = "required_input"
    case planReview = "plan_review"
}

struct AgentInteractionField: Identifiable, Equatable, Sendable {
    let id: String
    let label: String
    let type: String
    let required: Bool
    let options: [String]
}

struct AgentInteraction: Identifiable, Equatable, Sendable {
    let actionID: String
    let kind: AgentInteractionKind
    let prompt: String
    let options: [String]
    let fields: [AgentInteractionField]

    var id: String { actionID }

    static func decode(action: AgentRunActionEnvelope) -> AgentInteraction? {
        guard action.type == "interaction",
              case let .object(interaction)? = action.payload["interaction"],
              case let .string(kindRaw)? = interaction["kind"],
              let kind = AgentInteractionKind(rawValue: kindRaw),
              case let .string(prompt)? = interaction["prompt"] else { return nil }

        let options: [String]
        if case let .array(values)? = interaction["options"] {
            options = values.compactMap { value in
                guard case let .string(text) = value else { return nil }
                return text
            }
        } else {
            options = []
        }

        let fields: [AgentInteractionField]
        if case let .array(values)? = interaction["fields"] {
            fields = values.compactMap { value in
                guard case let .object(field) = value else { return nil }
                let fieldID = string(field["id"]) ?? string(field["key"]) ?? string(field["name"])
                guard let fieldID else { return nil }
                let label = string(field["label"]) ?? fieldID
                let type = string(field["type"]) ?? "text"
                let required = bool(field["required"]) ?? false
                let fieldOptions: [String]
                if case let .array(rawOptions)? = field["options"] {
                    fieldOptions = rawOptions.compactMap { string($0) }
                } else {
                    fieldOptions = []
                }
                return AgentInteractionField(id: fieldID, label: label, type: type, required: required, options: fieldOptions)
            }
        } else {
            fields = []
        }

        return AgentInteraction(actionID: action.id, kind: kind, prompt: prompt, options: options, fields: fields)
    }

    private static func string(_ value: AgentJSONValue?) -> String? {
        guard case let .string(text)? = value else { return nil }
        return text
    }

    private static func bool(_ value: AgentJSONValue?) -> Bool? {
        guard case let .bool(flag)? = value else { return nil }
        return flag
    }
}
