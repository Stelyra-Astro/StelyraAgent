import AstroCore
import Foundation

enum AgentCapability: String, CaseIterable, Codable, Sendable, Identifiable {
    case natal = "you.natal"
    case transit = "you.transit"
    case secondary = "you.secondary"
    case tertiary = "you.tertiary"
    case solarArc = "you.solar_arc"
    case solarReturn = "you.solar_return"
    case lunarReturn = "you.lunar_return"
    case currentSky = "you.current_sky"
    case relocation = "you.relocation"
    case harmonic12 = "you.harmonic_12"
    case harmonic13 = "you.harmonic_13"

    case synastry = "relationship.synastry"
    case composite = "relationship.composite"
    case compositeTransit = "relationship.composite_transit"
    case compositeSecondaryCompare = "relationship.composite_secondary_compare"
    case compositeTertiaryCompare = "relationship.composite_tertiary_compare"
    case davison = "relationship.davison"
    case davisonTransit = "relationship.davison_transit"
    case davisonSecondary = "relationship.davison_secondary"
    case davisonTertiary = "relationship.davison_tertiary"
    case marks = "relationship.marks"
    case marksSecondary = "relationship.marks_secondary"
    case marksTertiary = "relationship.marks_tertiary"

    var id: String { rawValue }

    static let phase1: [AgentCapability] = [.natal, .transit, .secondary, .synastry, .composite, .compositeTransit]
    static let allSupported: [AgentCapability] = Array(allCases)

    var isRelationship: Bool { rawValue.hasPrefix("relationship.") }

    var isAdvanced: Bool {
        switch self {
        case .harmonic12, .harmonic13,
             .davison, .davisonTransit, .davisonSecondary, .davisonTertiary,
             .marks, .marksSecondary, .marksTertiary:
            true
        default:
            false
        }
    }

    var displayTitle: String {
        switch self {
        case .natal: "Natal"
        case .transit: "Transit"
        case .secondary: "Secondary"
        case .tertiary: "Tertiary"
        case .solarArc: "Solar Arc"
        case .solarReturn: "Solar Return"
        case .lunarReturn: "Lunar Return"
        case .currentSky: "Current Sky"
        case .relocation: "Relocation"
        case .harmonic12: "Harmonic 12"
        case .harmonic13: "Harmonic 13"
        case .synastry: "Synastry"
        case .composite: "Composite"
        case .compositeTransit: "Relationship Transit"
        case .compositeSecondaryCompare: "Composite Secondary Compare"
        case .compositeTertiaryCompare: "Composite Tertiary Compare"
        case .davison: "Davison"
        case .davisonTransit: "Davison Transit"
        case .davisonSecondary: "Davison Secondary"
        case .davisonTertiary: "Davison Tertiary"
        case .marks: "Marks"
        case .marksSecondary: "Marks Secondary"
        case .marksTertiary: "Marks Tertiary"
        }
    }

    var chartKind: ChartKind? {
        switch self {
        case .natal: .natal
        case .transit: .transit
        case .secondary: .secondary
        case .tertiary: .tertiary
        case .solarArc: .solarArc
        case .solarReturn: .solarReturn
        case .lunarReturn: .lunarReturn
        case .currentSky: .currentSky
        case .relocation: .relocation
        case .harmonic12: .twelfthHarmonic
        case .harmonic13: .thirteenthHarmonic
        default: nil
        }
    }

    /// Includes hidden dependency calculations for Compare capabilities. The
    /// dependencies remain implementation details and are never advertised in
    /// the Agent-facing capability manifest.
    var relationshipKinds: [RelationshipChartKind] {
        switch self {
        case .synastry: [.synastryA, .synastryB]
        case .composite: [.composite]
        case .compositeTransit: [.compositeTransit]
        case .compositeSecondaryCompare: [.compositeSecondary, .compositeSecondaryCompare]
        case .compositeTertiaryCompare: [.compositeTertiary, .compositeTertiaryCompare]
        case .davison: [.davison]
        case .davisonTransit: [.davisonTransit]
        case .davisonSecondary: [.davisonSecondary]
        case .davisonTertiary: [.davisonTertiary]
        case .marks: [.marksA, .marksB]
        case .marksSecondary: [.marksSecondary, .marksSecondary]
        case .marksTertiary: [.marksTertiary, .marksTertiary]
        default: []
        }
    }

    func perspective(at relationshipIndex: Int) -> RelationshipPerspective? {
        switch self {
        case .marksSecondary, .marksTertiary:
            relationshipIndex == 0 ? .first : .second
        default:
            nil
        }
    }

    func relationshipArtifactContributesEvidence(kind: RelationshipChartKind) -> Bool {
        switch self {
        case .compositeSecondaryCompare: kind == .compositeSecondaryCompare
        case .compositeTertiaryCompare: kind == .compositeTertiaryCompare
        default: true
        }
    }
}

struct AgentCapabilityManifest: Codable, Equatable, Sendable {
    let capabilityManifestVersion: Int
    let supportedCapabilities: [String]
    let clientVersion: String
    let calculationSchemaVersion: Int

    static func current(clientVersion: String) -> AgentCapabilityManifest {
        AgentCapabilityManifest(
            capabilityManifestVersion: 2,
            supportedCapabilities: AgentCapability.allSupported.map(\.rawValue),
            clientVersion: clientVersion,
            calculationSchemaVersion: 2
        )
    }
}
