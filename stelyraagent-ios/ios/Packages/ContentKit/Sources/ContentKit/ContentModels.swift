import Foundation

public enum InterpretationTechnique: String, Codable, CaseIterable, Sendable {
    case natal
    case currentSky = "current-sky"
    case transit
    case secondary
    case solarReturn = "solar-return"
    case synastry
}

public enum InterpretationLayer: String, Codable, CaseIterable, Sendable {
    case core
    case supportive
    case pressure
    case advice
    case timing
    case transition
    case atmosphere
    case empty
}

public enum InterpretationTone: String, Codable, CaseIterable, Sendable {
    case supportive
    case challenging
    case transition
    case neutral
}

public struct InterpretationSignal: Codable, Equatable, Sendable {
    public let id: String
    public let rank: Int
    public let strength: Double
    public let pointID: String?
    public let referencePointID: String?
    public let signID: String?
    public let house: Int?
    public let aspectID: String?
    public let phaseID: String?
    public let tone: InterpretationTone?
    public let tags: Set<String>
    public let values: [String: String]

    public init(
        id: String,
        rank: Int,
        strength: Double,
        pointID: String? = nil,
        referencePointID: String? = nil,
        signID: String? = nil,
        house: Int? = nil,
        aspectID: String? = nil,
        phaseID: String? = nil,
        tone: InterpretationTone? = nil,
        tags: Set<String> = [],
        values: [String: String] = [:]
    ) {
        self.id = id
        self.rank = rank
        self.strength = strength
        self.pointID = pointID
        self.referencePointID = referencePointID
        self.signID = signID
        self.house = house
        self.aspectID = aspectID
        self.phaseID = phaseID
        self.tone = tone
        self.tags = tags
        self.values = values
    }
}

public struct InterpretationContext: Codable, Equatable, Sendable {
    public let technique: InterpretationTechnique
    public let cardID: String
    public let locale: String
    public let preset: String?
    public let signals: [InterpretationSignal]
    public let values: [String: String]

    public init(
        technique: InterpretationTechnique,
        cardID: String,
        locale: String,
        signals: [InterpretationSignal],
        preset: String? = nil,
        values: [String: String] = [:]
    ) {
        self.technique = technique
        self.cardID = cardID
        self.locale = locale
        self.preset = preset
        self.signals = signals.sorted {
            $0.rank == $1.rank ? $0.strength > $1.strength : $0.rank < $1.rank
        }
        self.values = values
    }
}

public struct CorpusSelector: Codable, Equatable, Sendable {
    public var techniques: Set<InterpretationTechnique>?
    public var cardIDs: Set<String>?
    public var pointIDs: Set<String>?
    public var referencePointIDs: Set<String>?
    public var signIDs: Set<String>?
    public var houses: Set<Int>?
    public var aspectIDs: Set<String>?
    public var phaseIDs: Set<String>?
    public var tones: Set<InterpretationTone>?
    public var presets: Set<String>?
    public var requiredTags: Set<String>?

    public init(
        techniques: Set<InterpretationTechnique>? = nil,
        cardIDs: Set<String>? = nil,
        pointIDs: Set<String>? = nil,
        referencePointIDs: Set<String>? = nil,
        signIDs: Set<String>? = nil,
        houses: Set<Int>? = nil,
        aspectIDs: Set<String>? = nil,
        phaseIDs: Set<String>? = nil,
        tones: Set<InterpretationTone>? = nil,
        presets: Set<String>? = nil,
        requiredTags: Set<String>? = nil
    ) {
        self.techniques = techniques
        self.cardIDs = cardIDs
        self.pointIDs = pointIDs
        self.referencePointIDs = referencePointIDs
        self.signIDs = signIDs
        self.houses = houses
        self.aspectIDs = aspectIDs
        self.phaseIDs = phaseIDs
        self.tones = tones
        self.presets = presets
        self.requiredTags = requiredTags
    }
}

public struct CorpusEntry: Codable, Equatable, Sendable {
    public let id: String
    public let locale: String
    public let layer: InterpretationLayer
    public let selector: CorpusSelector
    public let summary: String
    public let detail: String
    public let priority: Int
    public let deduplicationGroup: String?
    public let sourceRevision: String
    public let status: String

    public init(
        id: String,
        locale: String,
        layer: InterpretationLayer,
        selector: CorpusSelector,
        summary: String,
        detail: String,
        priority: Int = 0,
        deduplicationGroup: String? = nil,
        sourceRevision: String,
        status: String
    ) {
        self.id = id
        self.locale = locale
        self.layer = layer
        self.selector = selector
        self.summary = summary
        self.detail = detail
        self.priority = priority
        self.deduplicationGroup = deduplicationGroup
        self.sourceRevision = sourceRevision
        self.status = status
    }
}

public struct CorpusQuery: Codable, Equatable, Sendable {
    public let layers: Set<InterpretationLayer>
    public let signalRanks: Set<Int>?
    public let requiredTags: Set<String>?
    public let limit: Int

    public init(
        layers: Set<InterpretationLayer>,
        signalRanks: Set<Int>? = nil,
        requiredTags: Set<String>? = nil,
        limit: Int = 1
    ) {
        self.layers = layers
        self.signalRanks = signalRanks
        self.requiredTags = requiredTags
        self.limit = limit
    }
}

public struct CompositionBinding: Codable, Equatable, Sendable {
    public let name: String
    public let query: CorpusQuery
    public let required: Bool

    public init(name: String, query: CorpusQuery, required: Bool = true) {
        self.name = name
        self.query = query
        self.required = required
    }
}

public struct CompositionRule: Codable, Equatable, Sendable {
    public let id: String
    public let technique: InterpretationTechnique
    public let cardID: String
    public let summaryTemplate: String
    public let detailTemplate: String
    public let bindings: [CompositionBinding]
    public let summaryCharacterRange: ClosedRange<Int>?
    public let detailCharacterRange: ClosedRange<Int>?

    enum CodingKeys: String, CodingKey {
        case id, technique, cardID, summaryTemplate, detailTemplate, bindings
        case summaryMinimum, summaryMaximum, detailMinimum, detailMaximum
    }

    public init(
        id: String,
        technique: InterpretationTechnique,
        cardID: String,
        summaryTemplate: String,
        detailTemplate: String,
        bindings: [CompositionBinding],
        summaryCharacterRange: ClosedRange<Int>? = nil,
        detailCharacterRange: ClosedRange<Int>? = nil
    ) {
        self.id = id
        self.technique = technique
        self.cardID = cardID
        self.summaryTemplate = summaryTemplate
        self.detailTemplate = detailTemplate
        self.bindings = bindings
        self.summaryCharacterRange = summaryCharacterRange
        self.detailCharacterRange = detailCharacterRange
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        technique = try values.decode(InterpretationTechnique.self, forKey: .technique)
        cardID = try values.decode(String.self, forKey: .cardID)
        summaryTemplate = try values.decode(String.self, forKey: .summaryTemplate)
        detailTemplate = try values.decode(String.self, forKey: .detailTemplate)
        bindings = try values.decode([CompositionBinding].self, forKey: .bindings)
        if let minimum = try values.decodeIfPresent(Int.self, forKey: .summaryMinimum),
           let maximum = try values.decodeIfPresent(Int.self, forKey: .summaryMaximum)
        {
            summaryCharacterRange = minimum ... maximum
        } else {
            summaryCharacterRange = nil
        }
        if let minimum = try values.decodeIfPresent(Int.self, forKey: .detailMinimum),
           let maximum = try values.decodeIfPresent(Int.self, forKey: .detailMaximum)
        {
            detailCharacterRange = minimum ... maximum
        } else {
            detailCharacterRange = nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(id, forKey: .id)
        try values.encode(technique, forKey: .technique)
        try values.encode(cardID, forKey: .cardID)
        try values.encode(summaryTemplate, forKey: .summaryTemplate)
        try values.encode(detailTemplate, forKey: .detailTemplate)
        try values.encode(bindings, forKey: .bindings)
        try values.encodeIfPresent(summaryCharacterRange?.lowerBound, forKey: .summaryMinimum)
        try values.encodeIfPresent(summaryCharacterRange?.upperBound, forKey: .summaryMaximum)
        try values.encodeIfPresent(detailCharacterRange?.lowerBound, forKey: .detailMinimum)
        try values.encodeIfPresent(detailCharacterRange?.upperBound, forKey: .detailMaximum)
    }
}

public struct InterpretationContentPack: Codable, Equatable, Sendable {
    public let schemaVersion: Int
    public let contentVersion: String
    public let locale: String
    public let entries: [CorpusEntry]
    public let rules: [CompositionRule]

    public init(
        schemaVersion: Int,
        contentVersion: String,
        locale: String,
        entries: [CorpusEntry],
        rules: [CompositionRule]
    ) {
        self.schemaVersion = schemaVersion
        self.contentVersion = contentVersion
        self.locale = locale
        self.entries = entries
        self.rules = rules
    }
}

public struct InterpretationResult: Equatable, Sendable {
    public let title: String?
    public let summary: String
    public let detail: String
    public let evidenceIDs: [String]
    public let ruleID: String
    public let contentVersion: String

    public init(
        title: String? = nil,
        summary: String,
        detail: String,
        evidenceIDs: [String],
        ruleID: String,
        contentVersion: String
    ) {
        self.title = title
        self.summary = summary
        self.detail = detail
        self.evidenceIDs = evidenceIDs
        self.ruleID = ruleID
        self.contentVersion = contentVersion
    }
}
