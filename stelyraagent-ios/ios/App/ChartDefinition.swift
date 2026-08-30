import Foundation

enum ChartParameterPresentation: String, Sendable {
    case birthData
    case dateTimeLocation
    case transitWindow
    case targetDateBirthLocation
    case targetDateLocation
    case targetDateDerivedNatal
    case returnYearLocation
    case people
    case location
    case derivedNatal
}

enum ChartParameterField: String, Hashable, Sendable {
    case birthData
    case dateTime
    case targetDate
    case rangeDays
    case returnYear
    case location
    case people
}

enum ChartInsightMode: String, Sendable {
    case plannedLocalCards
    case aiReportOnly
}

enum ChartCalculationMode: String, Sendable {
    case eagerCore
    case onDemandAdvanced
}

enum ChartDiscoverySection: String, Sendable {
    case core
    case progressionsDirections
    case returns
    case derivedLocation
}

enum ChartFamily: String, Sendable {
    case natal
    case sky
    case progressionDirection
    case returns
    case relationship
    case derivedLocation
}

struct ChartDefinition: Sendable {
    let discoverySection: ChartDiscoverySection
    let contentPrefix: String
    let systemImage: String
    let family: ChartFamily
    let calculationMode: ChartCalculationMode
    let parameterFields: Set<ChartParameterField>
    let parameterPresentation: ChartParameterPresentation
    let insightMode: ChartInsightMode
    let localCardIDs: [String]
    let usesReferenceWheel: Bool
    let usesReferenceAspects: Bool
    let isCoreShortcut: Bool

    var isAdvanced: Bool { calculationMode == .onDemandAdvanced }
}

enum ChartDefinitionRegistry {
    static func definition(for chart: ChartKind) -> ChartDefinition {
        switch chart {
        case .natal:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "natal",
                systemImage: "person.crop.circle",
                family: .natal,
                calculationMode: .eagerCore,
                parameterFields: [.birthData],
                parameterPresentation: .birthData,
                insightMode: .plannedLocalCards,
                localCardIDs: ["natal-interpretation", "emotional-needs", "love-connection", "career-direction", "strengths-growth", "element-balance", "house-emphasis", "chart-signature", "planet-placements", "key-aspects"],
                usesReferenceWheel: false,
                usesReferenceAspects: false,
                isCoreShortcut: true
            )
        case .currentSky:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "current-sky",
                systemImage: "sparkles",
                family: .sky,
                calculationMode: .eagerCore,
                parameterFields: [.dateTime, .location],
                parameterPresentation: .dateTimeLocation,
                insightMode: .plannedLocalCards,
                localCardIDs: ["sky-overview", "moon-now", "aspect-pattern", "planetary-motion", "sign-changes", "element-climate", "upcoming-7-days"],
                usesReferenceWheel: false,
                usesReferenceAspects: false,
                isCoreShortcut: true
            )
        case .transit:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "transit",
                systemImage: "arrow.triangle.2.circlepath",
                family: .sky,
                calculationMode: .eagerCore,
                parameterFields: [.dateTime, .rangeDays, .location],
                parameterPresentation: .transitWindow,
                insightMode: .plannedLocalCards,
                localCardIDs: ["current-story", "current-cycles", "transit-timeline", "planet-paths", "life-areas", "active-transits"],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: true
            )
        case .synastry:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "synastry",
                systemImage: "person.2",
                family: .relationship,
                calculationMode: .eagerCore,
                parameterFields: [.people],
                parameterPresentation: .people,
                insightMode: .plannedLocalCards,
                localCardIDs: ["relationship-overview", "perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: true
            )
        case .solarReturn:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "solar-return",
                systemImage: "sun.max",
                family: .returns,
                calculationMode: .eagerCore,
                parameterFields: [.returnYear, .location],
                parameterPresentation: .returnYearLocation,
                insightMode: .plannedLocalCards,
                localCardIDs: ["year-theme", "year-anchors", "priority-areas", "year-dynamics", "year-timeline", "natal-overlay", "year-aspects"],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: true
            )
        case .secondary:
            ChartDefinition(
                discoverySection: .core,
                contentPrefix: "secondary",
                systemImage: "clock.arrow.circlepath",
                family: .progressionDirection,
                calculationMode: .eagerCore,
                parameterFields: [.targetDate],
                parameterPresentation: .targetDateBirthLocation,
                insightMode: .plannedLocalCards,
                localCardIDs: ["developmental-chapter", "progressed-moon", "identity-development", "turning-points", "areas-maturing", "timeline"],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: true
            )
        case .tertiary:
            ChartDefinition(
                discoverySection: .progressionsDirections,
                contentPrefix: "tertiary",
                systemImage: "clock.badge.checkmark",
                family: .progressionDirection,
                calculationMode: .onDemandAdvanced,
                parameterFields: [.targetDate],
                parameterPresentation: .targetDateBirthLocation,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: false
            )
        case .lunarReturn:
            ChartDefinition(
                discoverySection: .returns,
                contentPrefix: "lunar-return",
                systemImage: "moon.stars",
                family: .returns,
                calculationMode: .onDemandAdvanced,
                parameterFields: [.targetDate, .location],
                parameterPresentation: .targetDateLocation,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: false
            )
        case .solarArc:
            ChartDefinition(
                discoverySection: .progressionsDirections,
                contentPrefix: "solar-arc",
                systemImage: "sunrise",
                family: .progressionDirection,
                calculationMode: .onDemandAdvanced,
                parameterFields: [.targetDate],
                parameterPresentation: .targetDateDerivedNatal,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: false,
                usesReferenceAspects: true,
                isCoreShortcut: false
            )
        case .relocation:
            ChartDefinition(
                discoverySection: .derivedLocation,
                contentPrefix: "relocation",
                systemImage: "mappin.and.ellipse",
                family: .derivedLocation,
                calculationMode: .onDemandAdvanced,
                parameterFields: [.location],
                parameterPresentation: .location,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: false,
                usesReferenceAspects: false,
                isCoreShortcut: false
            )
        case .twelfthHarmonic:
            ChartDefinition(
                discoverySection: .derivedLocation,
                contentPrefix: "twelfth-harmonic",
                systemImage: "circle.grid.2x2",
                family: .derivedLocation,
                calculationMode: .onDemandAdvanced,
                parameterFields: [],
                parameterPresentation: .derivedNatal,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: false
            )
        case .thirteenthHarmonic:
            ChartDefinition(
                discoverySection: .derivedLocation,
                contentPrefix: "thirteenth-harmonic",
                systemImage: "circle.grid.3x3",
                family: .derivedLocation,
                calculationMode: .onDemandAdvanced,
                parameterFields: [],
                parameterPresentation: .derivedNatal,
                insightMode: .aiReportOnly,
                localCardIDs: [],
                usesReferenceWheel: true,
                usesReferenceAspects: true,
                isCoreShortcut: false
            )
        }
    }
    static func charts(in section: ChartDiscoverySection) -> [ChartKind] {
        ChartKind.allCases.filter { definition(for: $0).discoverySection == section }
    }

}
