import AstroCore
import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case english = "en"
    case simplifiedChinese = "zh-Hans"
    case spanish = "es"
    case french = "fr"
    case turkish = "tr"
    case german = "de"
    case italian = "it"
    case portugueseBrazil = "pt-BR"
    case korean = "ko"

    var id: String { rawValue }

    static func matchingSystemLanguage(_ identifier: String?) -> AppLanguage {
        guard let identifier else { return .english }
        let normalized = identifier.replacingOccurrences(of: "_", with: "-").lowercased()
        if normalized == "zh" || normalized.hasPrefix("zh-") { return .simplifiedChinese }
        if normalized == "en" || normalized.hasPrefix("en-") { return .english }
        if normalized == "es" || normalized.hasPrefix("es-") { return .spanish }
        if normalized == "fr" || normalized.hasPrefix("fr-") { return .french }
        if normalized == "tr" || normalized.hasPrefix("tr-") { return .turkish }
        if normalized == "de" || normalized.hasPrefix("de-") { return .german }
        if normalized == "it" || normalized.hasPrefix("it-") { return .italian }
        if normalized == "pt" || normalized.hasPrefix("pt-") { return .portugueseBrazil }
        if normalized == "ko" || normalized.hasPrefix("ko-") { return .korean }
        return .english
    }

    var title: String {
        let key = switch self {
        case .english: "language.english"
        case .simplifiedChinese: "language.simplified-chinese"
        case .spanish: "language.spanish"
        case .french: "language.french"
        case .turkish: "language.turkish"
        case .german: "language.german"
        case .italian: "language.italian"
        case .portugueseBrazil: "language.portuguese-brazil"
        case .korean: "language.korean"
        }
        return localized(key, language: self)
    }

    /// Reviewed content domains are explicit. A language is never inferred from
    /// another domain's coverage: each shipped locale owns its chart, Today and Ask copy.
    var chartContentLanguage: AppLanguage { self }
    var todayContentLanguage: AppLanguage { self }
    var askContentLanguage: AppLanguage { self }

    /// AI reports are generated in the language selected in the app, even
    /// when reviewed local card copy falls back to another corpus language.
    var reportRequestLanguage: AppLanguage { self }
}

enum AppAppearance: String, CaseIterable, Identifiable, Codable {
    case system
    case light
    case dark

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .system: localized("settings.system", language: language)
        case .light: localized("settings.light", language: language)
        case .dark: localized("settings.dark", language: language)
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

enum AppFontSize: String, CaseIterable, Identifiable, Codable {
    case small
    case standard
    case large
    case extraLarge

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .small: localized("settings.small", language: language)
        case .standard: localized("settings.standard", language: language)
        case .large: localized("settings.large", language: language)
        case .extraLarge: localized("settings.extra-large", language: language)
        }
    }

    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .small: .medium
        case .standard: .large
        case .large: .xLarge
        case .extraLarge: .xxLarge
        }
    }
}

enum LunarPhaseGeometry {
    static func elongation(sunLongitude: Double, moonLongitude: Double) -> Double {
        let raw = (moonLongitude - sunLongitude).truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    static func illuminationFraction(elongation: Double) -> Double {
        let normalized = elongation.truncatingRemainder(dividingBy: 360)
        return (1 - cos(normalized * .pi / 180)) / 2
    }
}

func localized(_ key: String, language: AppLanguage) -> String {
    guard let localizationPath = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
          let localizationBundle = Bundle(path: localizationPath)
    else {
        assertionFailure("Missing localization bundle for \(language.rawValue)")
        return key
    }
    let value = localizationBundle.localizedString(forKey: key, value: nil, table: "Localizable")
    if value == key {
        assertionFailure("Missing localization key: \(key) [\(language.rawValue)]")
    }
    return value
}

func localizedTemplate(
    _ key: String,
    substitutions: [String: String],
    language: AppLanguage
) -> String {
    let template = localized(key, language: language)
    let rendered = substitutions.reduce(template) { result, substitution in
        result.replacingOccurrences(of: "{{\(substitution.key)}}", with: substitution.value)
    }
    if rendered.range(of: #"\{\{[A-Za-z][A-Za-z0-9]*\}\}"#, options: .regularExpression) != nil {
        assertionFailure("Missing localization substitution for key: \(key)")
    }
    return rendered
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

enum ChartKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case natal
    case currentSky
    case transit
    case synastry
    case solarReturn
    case secondary
    case tertiary
    case lunarReturn
    case solarArc
    case relocation
    case twelfthHarmonic
    case thirteenthHarmonic

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("insight.secondary.natal", language: language)
        case .currentSky: localized("chart-kind.current-sky.short", language: language)
        case .transit: localized("settings.transits", language: language)
        case .secondary: localized("settings.progressed", language: language)
        case .solarReturn: localized("settings.solar-return", language: language)
        case .synastry: localized("settings.synastry", language: language)
        case .tertiary: localized("chart-kind.tertiary", language: language)
        case .lunarReturn: localized("chart-kind.lunar-return", language: language)
        case .solarArc: localized("chart-kind.solar-arc", language: language)
        case .relocation: localized("chart-kind.relocation", language: language)
        case .twelfthHarmonic: localized("chart-kind.twelfth-harmonic", language: language)
        case .thirteenthHarmonic: localized("chart-kind.thirteenth-harmonic", language: language)
        }
    }

    func eyebrow(language: AppLanguage) -> String {
        switch self {
        case .natal: localized("settings.birth-chart", language: language)
        case .currentSky: localized("chart-kind.current-sky.eyebrow", language: language)
        case .transit: localized("settings.natal-current-sky", language: language)
        case .secondary: localized("settings.secondary-progressions", language: language)
        case .solarReturn: localized("settings.solar-return.8f89f6c", language: language)
        case .synastry: localized("settings.synastry.b8a5a20", language: language)
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            title(language: language)
        }
    }

    var definition: ChartDefinition { ChartDefinitionRegistry.definition(for: self) }

    static var coreCases: [ChartKind] {
        allCases.filter { $0.definition.isCoreShortcut }
    }

    static var advancedCases: [ChartKind] {
        allCases.filter { $0.definition.isAdvanced }
    }

    var isAdvancedChart: Bool { definition.isAdvanced }
    var supportsInsightCards: Bool { definition.insightMode == .plannedLocalCards }

    var isComparison: Bool { self == .transit || self == .secondary || self == .synastry }
    var usesReferenceWheel: Bool { definition.usesReferenceWheel }
    var usesReferenceAspects: Bool { definition.usesReferenceAspects }

    var contentPrefix: String { definition.contentPrefix }
}

extension RelationshipChartKind {
    static let bondsFixedShortcuts: [RelationshipChartKind] = [.composite, .synastryA, .compositeTransit]

    var needsTargetDate: Bool {
        switch self {
        case .compositeTransit, .compositeSecondary, .compositeTertiary,
             .compositeSecondaryCompare, .compositeTertiaryCompare,
             .davisonTransit, .davisonSecondary, .davisonTertiary,
             .marksSecondary, .marksTertiary:
            true
        case .synastryA, .synastryB, .composite, .davison, .marksA, .marksB:
            false
        }
    }

    var supportsMidpointAlgorithm: Bool {
        switch self {
        case .davison, .davisonTransit, .davisonSecondary, .davisonTertiary,
             .marksA, .marksB, .marksSecondary, .marksTertiary:
            true
        default:
            false
        }
    }

    var supportsTransitLocation: Bool {
        switch self {
        case .compositeTransit, .davisonTransit:
            true
        default:
            false
        }
    }

    var usesComparisonWheel: Bool {
        switch self {
        case .synastryA, .synastryB, .compositeTransit,
             .compositeSecondaryCompare, .compositeTertiaryCompare, .davisonTransit:
            true
        default:
            false
        }
    }

    var isSynastry: Bool {
        switch self {
        case .synastryA, .synastryB: true
        default: false
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .synastryA, .synastryB: localized("relationship.synastry", language: language)
        case .composite: localized("relationship.composite", language: language)
        case .compositeTransit: localized("relationship.transits", language: language)
        case .compositeSecondary: localized("relationship.composite-secondary", language: language)
        case .compositeTertiary: localized("relationship.composite-tertiary", language: language)
        case .compositeSecondaryCompare: localized("relationship.composite-secondary-compare", language: language)
        case .compositeTertiaryCompare: localized("relationship.composite-tertiary-compare", language: language)
        case .davison: localized("relationship.davison", language: language)
        case .davisonTransit: localized("relationship.davison-transit", language: language)
        case .davisonSecondary: localized("relationship.davison-secondary", language: language)
        case .davisonTertiary: localized("relationship.davison-tertiary", language: language)
        case .marksA: localized("relationship.marks-a", language: language)
        case .marksB: localized("relationship.marks-b", language: language)
        case .marksSecondary: localized("relationship.marks-secondary", language: language)
        case .marksTertiary: localized("relationship.marks-tertiary", language: language)
        }
    }

    var reportScope: String { "relationship.\(rawValue)" }
}

enum ChartViewMode: String, CaseIterable, Identifiable {
    case wheel = "Wheel"
    case aspects = "Aspects"
    var id: String { rawValue }
}

extension CalculationPreset {
    static let consumerCases: [CalculationPreset] = [.modern, .classical]

    func title(language: AppLanguage) -> String {
        switch self {
        case .modern: localized("settings.modern", language: language)
        case .classical: localized("settings.classical", language: language)
        case .special: localized("settings.special", language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .modern: localized("settings.tropical-placidus", language: language)
        case .classical: localized("settings.traditional-alcabitius", language: language)
        case .special: localized("settings.whole-sign", language: language)
        }
    }
}

struct UserProfile: Codable, Equatable {
    var name: String
    var birthDateUTC: Date
    var placeName: String
    var timezoneID: String
    var latitude: Double
    var longitude: Double
    var avatarData: Data? = nil

    static let sample = UserProfile(
        name: "Elena Hart",
        birthDateUTC: Date(timeIntervalSince1970: 705_824_400),
        placeName: "Paris, France",
        timezoneID: "Europe/Paris",
        latitude: 48.8566,
        longitude: 2.3522
    )

    var initials: String {
        name.split(separator: " ")
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }

    var location: GeographicLocation {
        GeographicLocation(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}

enum PersonRelationship: String, CaseIterable, Codable, Identifiable {
    case partner
    case family
    case friend
    case colleague
    case other

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .partner: localized("settings.partner", language: language)
        case .family: localized("settings.family", language: language)
        case .friend: localized("settings.friend", language: language)
        case .colleague: localized("settings.colleague", language: language)
        case .other: localized("settings.other", language: language)
        }
    }
}

/// A single, auditable calculation context.  Screens, insight builders and AI
/// generation must all consume this value so a parameter change cannot update
/// one layer while leaving another layer stale.
struct ChartContext: Codable, Equatable, Sendable {
    let chartKind: ChartKind
    let primaryPersonID: String
    let comparisonPersonID: String?
    let preset: CalculationPreset
    let locale: AppLanguage
    let target: ChartTarget
}

struct ChartLocationSelection: Codable, Equatable, Sendable {
    let placeName: String
    let timezoneID: String
    let latitude: Double
    let longitude: Double

    var geographicLocation: GeographicLocation {
        GeographicLocation(latitudeDegrees: latitude, longitudeDegrees: longitude)
    }
}

enum ChartTarget: Codable, Equatable, Sendable {
    case natal
    case currentSky(instant: Date, location: ChartLocationSelection, usesLiveDefault: Bool)
    case transit(instant: Date, location: ChartLocationSelection, rangeDays: Int, usesLiveDefault: Bool)
    case secondary(targetDate: Date, usesLiveDefault: Bool)
    case solarReturn(year: Int, location: ChartLocationSelection)
    case synastry
    case tertiary(targetDate: Date, usesLiveDefault: Bool)
    case lunarReturn(targetDate: Date, location: ChartLocationSelection, usesLiveDefault: Bool)
    case solarArc(targetDate: Date, usesLiveDefault: Bool)
    case relocation(location: ChartLocationSelection)
    case twelfthHarmonic
    case thirteenthHarmonic
}

struct SavedPerson: Identifiable, Codable, Equatable {
    var id: UUID
    var profile: UserProfile
    var relationship: PersonRelationship

    static func new(using owner: UserProfile) -> SavedPerson {
        SavedPerson(
            id: UUID(),
            profile: UserProfile(
                name: "",
                birthDateUTC: owner.birthDateUTC,
                placeName: owner.placeName,
                timezoneID: owner.timezoneID,
                latitude: owner.latitude,
                longitude: owner.longitude
            ),
            relationship: .friend
        )
    }
}

struct InsightFact: Identifiable, Equatable {
    /// Stable within a card and across launches. It is also the evidence ID sent
    /// to the relay; UUIDs here would make otherwise identical reports miss the
    /// local cache.
    let id: String
    let metricLabel: String
    let calculatedValue: String
    let interpretationKey: String?
    let interpretationVariables: [String: String]
    let sourceFactIDs: [String]
    let visualRole: String?
    let technicalDetail: String?
    let interpretation: String?
    var emphasis: InsightTone = .neutral
    var progress: Double? = nil
    var symbol: String? = nil
    var category: String? = nil
    var markers: [Double]? = nil

    init(
        id: String,
        metricLabel: String,
        calculatedValue: String,
        interpretationKey: String? = nil,
        interpretationVariables: [String: String] = [:],
        sourceFactIDs: [String] = [],
        visualRole: String? = nil,
        technicalDetail: String? = nil,
        interpretation: String? = nil,
        emphasis: InsightTone = .neutral,
        progress: Double? = nil,
        symbol: String? = nil,
        category: String? = nil,
        markers: [Double]? = nil
    ) {
        self.id = id
        self.metricLabel = metricLabel
        self.calculatedValue = calculatedValue
        self.interpretationKey = interpretationKey
        self.interpretationVariables = interpretationVariables
        self.sourceFactIDs = sourceFactIDs.isEmpty ? [id] : sourceFactIDs
        self.visualRole = visualRole
        self.technicalDetail = technicalDetail
        self.interpretation = interpretation
        self.emphasis = emphasis
        self.progress = progress
        self.symbol = symbol
        self.category = category
        self.markers = markers
    }

    // Compatibility names used by the existing visual components while the
    // product-facing model remains explicit.
    var label: String { metricLabel }
    var value: String { calculatedValue }
    var note: String? { interpretation }
}

struct TransitCalendarDay: Codable, Equatable, Sendable {
    let date: Date
    let score: Int
    let sourceFactIDs: [String]
}

enum InsightTone: String, Equatable {
    case supportive
    case challenging
    case transition
    case neutral
}

enum TransitPathState: Equatable {
    case direct
    case retrograde
    case next
}

struct TransitPlanetPathRow: Identifiable, Equatable {
    let id: String
    let sourceFactIDs: [String]
    let body: CelestialBody
    let house: Int
    let symbol: String
    let title: String
    let detail: String
    let state: TransitPathState
    let timing: String
}

struct TransitLifeAreaRow: Identifiable, Equatable {
    let id: String
    let sourceFactIDs: [String]
    let title: String
    let activity: String
    let triggerCount: Int
    let progress: Double
}

struct TransitCyclePresentation: Equatable {
    let roleID: String
    let fallbackTitle: String
    let tags: [String]
    let sourceFactIDs: [String]
}

enum TransitActiveStatus: Equatable {
    case applying
    case returning
    case ingress
    case separating
    case exact
    case retrograde
    case direct
}

struct TransitTechnicalField: Identifiable, Equatable {
    let id: String
    let label: String
    let value: String
}

struct TransitActiveRow: Identifiable, Equatable {
    let id: String
    let sourceFactIDs: [String]
    let symbol: String
    let title: String
    let detail: String
    let category: String
    let status: TransitActiveStatus
    let technicalValue: String
    let fields: [TransitTechnicalField]
}

enum InsightVisual: Equatable {
    case natalCore
    case rankedThemes
    case strengthOrbit(supportive: Int, challenging: Int, neutral: Int)
    case blindSpot
    case growthPath
    case skyOverview(phase: Double, activity: Int, cycles: [Double])
    case themeCards
    case needsCard
    case eventTimeline
    case dateEvents
    case structureMap(supportive: Int, challenging: Int, neutral: Int)
    case domainBars([Double])
    case observation
    case evolution
    case planetTable
    case activityGauge(value: Int, supportive: Int, adjustment: Int)
    case transitOverview(intensity: Int, rhythm: [Double])
    case gantt
    case transitTimeline(
        entries: [TransitTimelineEntry],
        calendar: [TransitCalendarFact],
        anchorDate: Date,
        initialRangeDays: Int,
        timeZoneIdentifier: String
    )
    case balanceRing(supportive: Int, challenging: Int, neutral: Int)
    case houseRadar([Double])
    case actionGuidance
    case arcTimeline
    case doubleRing
    case calendar([Int])
    case progressedStage(phase: Double, moonProgress: Double, sunProgress: Double)
    case progressedThemes(supportive: Int, challenging: Int, neutral: Int)
    case turningTimeline
    case comparison
    // V2 prototype visuals (six-chart redesign)
    case signatureTrio(ruler: String, dominant: String, orientation: String)
    case placementList
    case aspectList
    case storyWeave(expanding: String, structuring: String, result: String)
    case cycleTabs(
        long: TransitCyclePresentation?,
        current: TransitCyclePresentation?,
        daily: TransitCyclePresentation?
    )
    case transitPlanetPaths([TransitPlanetPathRow])
    case transitLifeAreas([TransitLifeAreaRow])
    case transitActiveRows([TransitActiveRow])
    case positionRows
    case areaRows
    case phaseDial(phase: Double, illumination: Double)
    case motionList
    case elementRows
    case stageFlow(old: String, transition: String, emerging: String)
    case moonProgress(progress: Double)
    case identityCompare(natal: String, progressed: String)
    case turningRows
    case yearOrbit
    case anchorGrid
    case dualInsight(opening: String, demand: String, openingLabel: String, demandLabel: String)
    case edgeDual(opening: String, demand: String)
    case quarterTabs
    case overlayCompare
    case natalOverlay(firstLabel: String, firstValue: String, secondLabel: String, secondValue: String)
    case bondOrbit(SynastryOverviewPresentation)
    case perspectiveTabs(SynastryPerspectivePresentation)
    case connectionGrid
    case pathFlow
    case synastryConnectionGrid(SynastryConnectionGridKind)
    case synastryPathFlow
    case synastryChemistry
    case synastryHouseOverlayRows(SynastryPairPresentation)
    case synastryInterAspectRows(SynastryPairPresentation)
}

enum SynastryOverviewDimensionID: String, CaseIterable, Equatable, Sendable {
    case communication
    case emotionalPace
    case chemistry
}

enum SynastryOverviewDimensionState: String, CaseIterable, Equatable, Sendable {
    case strong
    case steady
    case active
    case mixed
    case different
    case quiet
}

struct SynastryOverviewDimension: Equatable, Sendable {
    let id: SynastryOverviewDimensionID
    let state: SynastryOverviewDimensionState
    let sourceFactIDs: [String]
}

struct SynastryOverviewPresentation: Equatable, Sendable {
    let firstName: String
    let secondName: String
    let dimensions: [SynastryOverviewDimension]
}

struct SynastryPairPresentation: Equatable, Sendable {
    let firstName: String
    let secondName: String
}

struct SynastryPerspectivePresentation: Equatable, Sendable {
    let pair: SynastryPairPresentation
    let firstSourceFactIDs: [String]
    let secondSourceFactIDs: [String]
}

enum SynastryConnectionGridKind: Equatable, Sendable {
    case emotional
    case commitment
}

struct InsightCardModel: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String
    let visual: InsightVisual
    let facts: [InsightFact]
    /// Optional card-level conclusion from the private content pack.
    let conclusionKey: String?
    let conclusion: String
    let text: CardTextModel?
    let scopeID: String?

    init(
        id: String,
        title: String,
        icon: String,
        visual: InsightVisual,
        facts: [InsightFact],
        conclusionKey: String? = nil,
        conclusion: String,
        text: CardTextModel? = nil,
        scopeID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.visual = visual
        self.facts = facts
        self.conclusionKey = conclusionKey
        self.conclusion = conclusion
        self.text = text
        self.scopeID = scopeID
    }

    // Compatibility for views still referring to the former summary field.
    var summary: String { conclusion }
}

/// Reviewed consumer copy selected from a normalized Copy Catalog. Technical
/// labels remain separate so a fact template can never become interpretation.
struct CardTextModel: Codable, Equatable, Sendable {
    let sectionLabel: String?
    let cardLabel: String
    let headline: String?
    let body: String?
    let secondaryBody: String?
    let areaLabel: String?
    let statusLabel: String?
    let technicalLabel: String?
    let startLabel: String?
    let endLabel: String?
    let themeID: String?
    let sourceFactIDs: [String]
    let copyPackID: String?
    let scopeID: String?
    let roleTexts: [CardRoleText]?
    let cycleTexts: [TransitCycleText]?
}

struct CardRoleText: Codable, Equatable, Sendable {
    let roleID: String
    let text: String
    let sourceFactIDs: [String]
}

struct TransitCycleText: Codable, Equatable, Sendable {
    let roleID: String
    let headline: String
    let body: String
    let sourceFactIDs: [String]
}

struct InsightCardLoadState {
    let cards: [InsightCardModel]
    let errorMessage: String?

    static func loaded(_ cards: [InsightCardModel]) -> Self {
        Self(cards: cards, errorMessage: nil)
    }

    static func unavailable(_ message: String) -> Self {
        Self(cards: [], errorMessage: message)
    }
}

struct HoraryOverlay: Equatable {
    let highlightedHouses: Set<Int>
    let planetLabels: [CelestialBody: String]
    let keyAspectIDs: Set<String>

    static let empty = HoraryOverlay(
        highlightedHouses: [],
        planetLabels: [:],
        keyAspectIDs: []
    )
}

struct DailySignal: Identifiable, Equatable {
    enum Category: String {
        case happeningToday
        case activeNow
    }

    enum Source: String {
        case sky = "Current Sky"
        case transit = "Transit"
        case secondary = "Progressed"
    }

    let id: String
    let category: Category
    let source: Source
    let title: String
    let subtitle: String
    let tone: InsightTone
    let strength: Int
    let eventDate: Date?
    let peakDate: Date?

    init(
        id: String,
        category: Category,
        source: Source,
        title: String,
        subtitle: String,
        tone: InsightTone,
        strength: Int,
        eventDate: Date?,
        peakDate: Date? = nil
    ) {
        self.id = id
        self.category = category
        self.source = source
        self.title = title
        self.subtitle = subtitle
        self.tone = tone
        self.strength = strength
        self.eventDate = eventDate
        self.peakDate = peakDate
    }
}

enum Zodiac {
    static let englishNames = [
        "Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo",
        "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces",
    ]

    static let chineseNames = [
        "白羊座", "金牛座", "双子座", "巨蟹座", "狮子座", "处女座",
        "天秤座", "天蝎座", "射手座", "摩羯座", "水瓶座", "双鱼座",
    ]

    static let names = englishNames
    static let termKeys = [
        "aries", "taurus", "gemini", "cancer", "leo", "virgo",
        "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
    ]
    static let symbols = ["♈︎", "♉︎", "♊︎", "♋︎", "♌︎", "♍︎", "♎︎", "♏︎", "♐︎", "♑︎", "♒︎", "♓︎"]

    static func name(index: Int, language: AppLanguage) -> String {
        AstroTerms.value("zodiac", termKeys[index], language: language)
    }

    static func position(_ point: ChartPoint, language: AppLanguage = .english) -> String {
        "\(name(index: point.signIndex, language: language)) \(formatDegree(point.degreeInSign))\(point.retrograde ? " ℞" : "")"
    }

    static func formatDegree(_ value: Double) -> String {
        let degrees = Int(value)
        let minutes = Int((value - Double(degrees)) * 60)
        return "\(degrees)°\(String(format: "%02d", minutes))′"
    }
}

func bodyName(_ body: CelestialBody, language: AppLanguage) -> String {
    AstroTerms.value("bodies", body.rawValue, language: language)
}

func aspectKindName(_ kind: AspectKind, language: AppLanguage) -> String {
    AstroTerms.value("aspects", kind.rawValue, language: language)
}
