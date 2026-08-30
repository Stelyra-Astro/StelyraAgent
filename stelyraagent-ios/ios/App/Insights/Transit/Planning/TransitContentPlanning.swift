import AstroCore
import Foundation

enum TransitClaimMode: String, Equatable, Sendable {
    case full
    case short
    case aggregate
    case technical
}

enum TransitEvidenceRole: String, Equatable, Hashable, Sendable {
    case primary
    case primaryWindow
    case supportingWindow
    case supporting
    case longCycle
    case currentCycle
    case dailyCycle
    case cycleCalendar
    case timeline
    case path
    case pathEvent
    case lifeArea
    case active
    case activeWindow
    case activeSignIngress
    case activeHouseIngress
    case activeStationRetrograde
    case activeStationDirect
}

enum TransitStorySignalRoleID: String, CaseIterable, Equatable, Hashable, Sendable {
    case expanding
    case structuring
    case disrupting
    case stabilizing
    case supporting
}

enum TransitIntegratedThemeID: String, CaseIterable, Equatable, Hashable, Sendable {
    case expansionStructure = "expansion-structure"
    case focusedExpansion = "focused-expansion"
    case durableStructure = "durable-structure"
    case steadyRealignment = "steady-realignment"
}

enum TransitThemeID: String, CaseIterable, Equatable, Sendable {
    case careerRestructuring = "career.restructuring"
    case careerVisibility = "career.visibility"
    case commitmentDeepening = "commitment.deepening"
    case communicationFriction = "communication.friction"
    case communicationOpening = "communication.opening"
    case confidenceExpansion = "confidence.expansion"
    case directionAlignment = "direction.alignment"
    case directionReorientation = "direction.reorientation"
    case directionTurningPoint = "direction.turning-point"
    case emotionalDisruption = "emotional.disruption"
    case emotionalSensitivity = "emotional.sensitivity"
    case emotionalStability = "emotional.stability"
    case emotionalWeight = "emotional.weight"
    case healingIntegration = "healing.integration"
    case homeAdjustment = "home.adjustment"
    case identityReconstruction = "identity.reconstruction"
    case identityReinvention = "identity.reinvention"
    case imaginationOpening = "imagination.opening"
    case independenceGrowth = "independence.growth"
    case learningExpansion = "learning.expansion"
    case mentalClarity = "mental.clarity"
    case mentalReview = "mental.review"
    case momentumBlocked = "momentum.blocked"
    case momentumRising = "momentum.rising"
    case moneyReview = "money.review"
    case relationshipBoundaries = "relationship.boundaries"
    case relationshipFreedom = "relationship.freedom"
    case relationshipIntensity = "relationship.intensity"
    case relationshipOpening = "relationship.opening"
    case responsibilityPressure = "responsibility.pressure"
    case routineDisruption = "routine.disruption"
    case socialBoundaries = "social.boundaries"
    case socialExpansion = "social.expansion"
    case structureBuilding = "structure.building"
    case transformationRelease = "transformation.release"
    case trustDeepening = "trust.deepening"
    case uncertaintyFog = "uncertainty.fog"
    case valuesReassessment = "values.reassessment"
}

enum TransitCopySlot: String, CaseIterable, Equatable, Sendable {
    case integratedStory
    case signalRole
    case cycleChapter
    case planetPathShort
    case lifeAreaShort
    case activeTransitShort
}

enum TransitCycleBand: String, Equatable, Sendable {
    case longTerm
    case current
    case daily

    init(movingID: String) {
        switch CelestialBody(rawValue: movingID) {
        case .saturn, .uranus, .neptune, .pluto:
            self = .longTerm
        case .moon, .mercury, .venus, .mars, .sun:
            self = .daily
        default:
            self = .current
        }
    }
}

enum TransitTimelineContract {
    static let defaultRangeDays = 30
    static let rangeDays = [30, 7, 365]
    static let maximumRangeDays = 365
}

enum TransitCycleContract {
    static let minimumLongTermDuration: TimeInterval = 60 * 86_400
}

struct TransitAspectFact: Equatable, Sendable {
    let factID: String
    let movingID: String
    let referenceID: String
    let kind: AspectKind
    let orbDegrees: Double
    let phase: AspectPhase
    let strength: Double
    let movingLongitude: Double
    let referenceLongitude: Double
    let natalHouse: Int
    let cycleBand: TransitCycleBand
    let classicalContext: ClassicalTransitAspectContext?

    init(
        factID: String,
        movingID: String,
        referenceID: String,
        kind: AspectKind,
        orbDegrees: Double,
        phase: AspectPhase,
        strength: Double,
        movingLongitude: Double,
        referenceLongitude: Double,
        natalHouse: Int,
        cycleBand: TransitCycleBand,
        classicalContext: ClassicalTransitAspectContext? = nil
    ) {
        self.factID = factID
        self.movingID = movingID
        self.referenceID = referenceID
        self.kind = kind
        self.orbDegrees = orbDegrees
        self.phase = phase
        self.strength = strength
        self.movingLongitude = movingLongitude
        self.referenceLongitude = referenceLongitude
        self.natalHouse = natalHouse
        self.cycleBand = cycleBand
        self.classicalContext = classicalContext
    }
}

struct ClassicalTransitAspectContext: Equatable, Sendable {
    let movingScore: Double
    let movingConditions: [TraditionalCondition]
    let receptionFromMoving: Bool
    let receptionFromReference: Bool
}

struct TransitWindowFact: Equatable, Sendable {
    let factID: String
    let sourceAspectFactID: String?
    let movingID: String
    let referenceID: String
    let kind: AspectKind
    let movingLongitude: Double
    let natalHouse: Int
    let start: Date
    let exact: Date
    let end: Date
    let repeatExact: Date?
    let nextExact: Date?
    let passIndex: Int
    let passCount: Int
    let returning: Bool
    let timeZoneIdentifier: String
    let cycleBand: TransitCycleBand

    var exactDates: [Date] {
        Array(Set([exact] + [repeatExact, nextExact].compactMap { $0 })).sorted()
    }

    var eventWindow: ChartEventData.TransitWindow? {
        guard let first = CelestialBody(rawValue: movingID),
              let second = CelestialBody(rawValue: referenceID)
        else { return nil }
        return ChartEventData.TransitWindow(
            first: first,
            second: second,
            kind: kind,
            firstLongitude: movingLongitude,
            start: start,
            exact: exact,
            end: end,
            repeatExact: repeatExact,
            nextExact: nextExact,
            passIndex: passIndex,
            passCount: passCount,
            returning: returning
        )
    }
}

enum TransitPlanetEventKind: String, CaseIterable, Equatable, Hashable, Sendable {
    case signIngress
    case houseIngress
    case stationRetrograde
    case stationDirect

    init(_ kind: ChartEventData.TransitPlanetEvent.Kind) {
        self = switch kind {
        case .signIngress: .signIngress
        case .houseIngress: .houseIngress
        case .stationRetrograde: .stationRetrograde
        case .stationDirect: .stationDirect
        }
    }
}

struct TransitPlanetEventFact: Equatable, Sendable {
    let factID: String
    let body: CelestialBody
    let kind: TransitPlanetEventKind
    let timestamp: Date
    let timeZoneIdentifier: String
    let fromIndex: Int?
    let toIndex: Int?
}

struct TransitPlanetPlacementFact: Equatable, Sendable {
    let factID: String
    let body: CelestialBody
    let longitudeDegrees: Double
    let signIndex: Int
    let degreeInSign: Double
    let natalHouse: Int
    let retrograde: Bool
    let longitudeSpeedDegreesPerDay: Double
    let classicalScore: Double?
    let classicalConditions: [TraditionalCondition]

    init(
        factID: String,
        body: CelestialBody,
        longitudeDegrees: Double,
        signIndex: Int,
        degreeInSign: Double,
        natalHouse: Int,
        retrograde: Bool,
        longitudeSpeedDegreesPerDay: Double,
        classicalScore: Double? = nil,
        classicalConditions: [TraditionalCondition] = []
    ) {
        self.factID = factID
        self.body = body
        self.longitudeDegrees = longitudeDegrees
        self.signIndex = signIndex
        self.degreeInSign = degreeInSign
        self.natalHouse = natalHouse
        self.retrograde = retrograde
        self.longitudeSpeedDegreesPerDay = longitudeSpeedDegreesPerDay
        self.classicalScore = classicalScore
        self.classicalConditions = classicalConditions
    }
}

struct TransitLifeAreaFact: Equatable, Sendable {
    let factID: String
    let house: Int
    let normalizedScore: Double
    let contributingFactIDs: [String]
}

struct TransitCalendarFact: Equatable, Sendable {
    let factID: String
    let date: Date
    let score: Int
    let sourceFactIDs: [String]
    let timeZoneIdentifier: String
}

enum TransitTimelineEntryKind: Equatable, Sendable {
    case aspect(AspectKind)
    case houseResidence(Int)
    case signIngress(Int)
    case stationRetrograde
    case stationDirect
}

struct TransitTimelineEntry: Equatable, Sendable {
    let id: String
    let sourceFactIDs: [String]
    let movingBody: CelestialBody
    let referenceBody: CelestialBody?
    let kind: TransitTimelineEntryKind
    let start: Date
    let exactDates: [Date]
    let end: Date?
    let timeZoneIdentifier: String
}

enum TransitTimelineProjection {
    static func entries(from evidence: [TransitPlannedEvidence]) -> [TransitTimelineEntry] {
        let windows = evidence.compactMap { item -> TransitWindowFact? in
            guard case let .window(window) = item.fact else { return nil }
            return window
        }
        let events = evidence.compactMap { item -> TransitPlanetEventFact? in
            guard case let .planetEvent(event) = item.fact else { return nil }
            return event
        }

        var entries = windows.compactMap { window -> TransitTimelineEntry? in
            guard let movingBody = CelestialBody(rawValue: window.movingID),
                  let referenceBody = CelestialBody(rawValue: window.referenceID)
            else { return nil }
            return TransitTimelineEntry(
                id: window.factID,
                sourceFactIDs: TransitFact.window(window).sourceFactIDs,
                movingBody: movingBody,
                referenceBody: referenceBody,
                kind: .aspect(window.kind),
                start: window.start,
                exactDates: window.exactDates,
                end: window.end,
                timeZoneIdentifier: window.timeZoneIdentifier
            )
        }

        let houseEventsByBody = Dictionary(
            grouping: events.filter { $0.kind == .houseIngress },
            by: \TransitPlanetEventFact.body
        )
        for bodyEvents in houseEventsByBody.values {
            let sorted = bodyEvents.sorted(by: eventOrder)
            for (index, event) in sorted.enumerated() {
                guard let house = event.toIndex else { continue }
                let next = sorted.indices.contains(index + 1) ? sorted[index + 1] : nil
                entries.append(
                    TransitTimelineEntry(
                        id: event.factID,
                        sourceFactIDs: [event.factID] + [next?.factID].compactMap { $0 },
                        movingBody: event.body,
                        referenceBody: nil,
                        kind: .houseResidence(house),
                        start: event.timestamp,
                        exactDates: [],
                        end: next?.timestamp,
                        timeZoneIdentifier: event.timeZoneIdentifier
                    )
                )
            }
        }

        entries += events.compactMap { event -> TransitTimelineEntry? in
            let kind: TransitTimelineEntryKind
            switch event.kind {
            case .houseIngress:
                return nil
            case .signIngress:
                guard let sign = event.toIndex else { return nil }
                kind = .signIngress(sign)
            case .stationRetrograde:
                kind = .stationRetrograde
            case .stationDirect:
                kind = .stationDirect
            }
            return TransitTimelineEntry(
                id: event.factID,
                sourceFactIDs: [event.factID],
                movingBody: event.body,
                referenceBody: nil,
                kind: kind,
                start: event.timestamp,
                exactDates: [event.timestamp],
                end: nil,
                timeZoneIdentifier: event.timeZoneIdentifier
            )
        }

        return entries.sorted {
            if $0.start != $1.start { return $0.start < $1.start }
            return $0.id < $1.id
        }
    }

    private static func eventOrder(_ lhs: TransitPlanetEventFact, _ rhs: TransitPlanetEventFact) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.factID < rhs.factID
    }
}

enum TransitFact: Equatable, Sendable {
    case aspect(TransitAspectFact)
    case window(TransitWindowFact)
    case planetEvent(TransitPlanetEventFact)
    case placement(TransitPlanetPlacementFact)
    case lifeArea(TransitLifeAreaFact)
    case calendar(TransitCalendarFact)

    var factID: String {
        switch self {
        case let .aspect(fact): fact.factID
        case let .window(fact): fact.factID
        case let .planetEvent(fact): fact.factID
        case let .placement(fact): fact.factID
        case let .lifeArea(fact): fact.factID
        case let .calendar(fact): fact.factID
        }
    }

    var sourceFactIDs: [String] {
        switch self {
        case let .aspect(fact):
            [fact.factID]
        case let .window(fact):
            [fact.factID] + [fact.sourceAspectFactID].compactMap { $0 }
        case let .planetEvent(fact):
            [fact.factID]
        case let .placement(fact):
            [fact.factID]
        case let .lifeArea(fact):
            [fact.factID] + fact.contributingFactIDs
        case let .calendar(fact):
            [fact.factID] + fact.sourceFactIDs
        }
    }
}

struct TransitPlannedEvidence: Equatable, Sendable {
    let fact: TransitFact
    let claimMode: TransitClaimMode
    let role: TransitEvidenceRole
}

struct TransitThemeInput: Equatable, Sendable {
    let signalID: String
    let sourceFactIDs: [String]
    let movingID: String?
    let referenceID: String?
    let aspectKind: AspectKind?
    let tone: String
    let house: Int?
    let roleID: String
    let classicalThemeID: ClassicalTransitThemeID?

    init(
        signalID: String,
        sourceFactIDs: [String],
        movingID: String?,
        referenceID: String?,
        aspectKind: AspectKind?,
        tone: String,
        house: Int?,
        roleID: String,
        classicalThemeID: ClassicalTransitThemeID? = nil
    ) {
        self.signalID = signalID
        self.sourceFactIDs = sourceFactIDs
        self.movingID = movingID
        self.referenceID = referenceID
        self.aspectKind = aspectKind
        self.tone = tone
        self.house = house
        self.roleID = roleID
        self.classicalThemeID = classicalThemeID
    }
}

struct TransitStorySignalAssignment: Equatable, Sendable {
    let signalID: String
    let signalRole: TransitStorySignalRoleID
    let movingID: String
    let lifeAreas: [Int]
    let sourceFactIDs: [String]
}

enum TransitCardEmptyState: String, Equatable, Sendable {
    case showInsufficientFacts
}

struct CardEvidencePlan: Equatable, Sendable {
    let scopeID: String
    let preset: String
    let cardID: String
    let evidence: [TransitPlannedEvidence]
    let primaryFactID: String?
    let themeInputs: [TransitThemeInput]
    let signalRoles: [TransitStorySignalAssignment]
    let integratedThemeID: TransitIntegratedThemeID?
    let classicalSignalRoles: [ClassicalTransitStorySignalAssignment]
    let classicalIntegratedThemeID: ClassicalTransitIntegratedThemeID?
    let copySlot: TransitCopySlot?
    let emptyState: TransitCardEmptyState

    var factIDs: [String] { evidence.map(\.fact.factID) }
    var sourceFactIDs: [String] {
        Array(Set(evidence.flatMap(\.fact.sourceFactIDs))).sorted()
    }
}

struct TransitContentPlan: Equatable, Sendable {
    static let cardIDs = [
        "current-story",
        "current-cycles",
        "transit-timeline",
        "planet-paths",
        "life-areas",
        "active-transits",
    ]

    let scopeID: String
    let anchorDate: Date
    let timeZoneIdentifier: String
    let rangeDays: Int
    let preset: String
    let cards: [CardEvidencePlan]

    func card(_ cardID: String) -> CardEvidencePlan? {
        cards.first { $0.cardID == cardID }
    }
}

struct TransitFactBundle: Equatable, Sendable {
    let scopeID: String
    let anchorDate: Date
    let timeZoneIdentifier: String
    let rangeDays: Int
    let preset: String
    let crossAspects: [TransitAspectFact]
    let transitWindows: [TransitWindowFact]
    let aspectWindowFactIDs: [String: [String]]
    let planetEvents: [TransitPlanetEventFact]
    let planetPlacements: [TransitPlanetPlacementFact]
    let lifeAreaScores: [TransitLifeAreaFact]
    let transitCalendar: [TransitCalendarFact]
}

enum TransitFactBundleBuilder {
    static func build(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        crossAspects: [ChartAspect],
        transitWindows: [ChartEventData.TransitWindow],
        planetEvents: [ChartEventData.TransitPlanetEvent],
        transitCalendar: [TransitCalendarDay],
        rangeDays: Int,
        preset: String,
        timeZone: TimeZone
    ) -> TransitFactBundle {
        let normalizedRangeDays = max(1, min(rangeDays, TransitTimelineContract.maximumRangeDays))
        let scopeID = makeScopeID(
            snapshot: snapshot,
            natal: natal,
            crossAspects: crossAspects,
            preset: preset,
            timeZoneIdentifier: timeZone.identifier,
            rangeDays: normalizedRangeDays
        )
        let prefix = "transit.\(scopeID)"
        let aspectFacts = crossAspects.map { aspect in
            let movingBody = CelestialBody(rawValue: aspect.firstID)
            let referenceBody = CelestialBody(rawValue: aspect.secondID)
            let classicalContext: ClassicalTransitAspectContext?
            if preset == CalculationPreset.classical.rawValue,
               let movingBody,
               HoraryEngine.traditionalPlanets.contains(movingBody)
            {
                let movingSignIndex = Int(aspect.firstLongitude / 30) % 12
                let referenceSignIndex = Int(aspect.secondLongitude / 30) % 12
                classicalContext = ClassicalTransitAspectContext(
                    movingScore: HoraryEngine.assess(movingBody, in: snapshot).score,
                    movingConditions: HoraryEngine.assess(movingBody, in: snapshot).conditions,
                    receptionFromMoving: referenceBody.map {
                        HoraryEngine.reception(from: movingBody, to: $0, fromSignIndex: movingSignIndex).isPresent
                    } ?? false,
                    receptionFromReference: referenceBody.map { referenceBody in
                        HoraryEngine.reception(from: referenceBody, to: movingBody, fromSignIndex: referenceSignIndex).isPresent
                    } ?? false
                )
            } else {
                classicalContext = nil
            }
            return TransitAspectFact(
                factID: "\(prefix).aspect.\(aspect.firstID).\(aspect.kind.rawValue).\(aspect.secondID)",
                movingID: aspect.firstID,
                referenceID: aspect.secondID,
                kind: aspect.kind,
                orbDegrees: aspect.orbDegrees,
                phase: aspect.phase,
                strength: aspect.strength,
                movingLongitude: aspect.firstLongitude,
                referenceLongitude: aspect.secondLongitude,
                natalHouse: natal?.house(containing: aspect.firstLongitude) ?? 0,
                cycleBand: TransitCycleBand(movingID: aspect.firstID),
                classicalContext: classicalContext
            )
        }
        let aspectByKey = Dictionary(
            uniqueKeysWithValues: aspectFacts.map {
                (aspectKey($0.movingID, $0.kind, $0.referenceID), $0.factID)
            }
        )
        let windowFacts = transitWindows.map { window in
            let exactTimestamp = Int(window.exact.timeIntervalSince1970.rounded())
            return TransitWindowFact(
                factID: "\(prefix).window.\(window.first.rawValue).\(window.kind.rawValue).\(window.second.rawValue).\(exactTimestamp)",
                sourceAspectFactID: aspectByKey[aspectKey(window.first.rawValue, window.kind, window.second.rawValue)],
                movingID: window.first.rawValue,
                referenceID: window.second.rawValue,
                kind: window.kind,
                movingLongitude: window.firstLongitude,
                natalHouse: natal?.house(containing: window.firstLongitude) ?? 0,
                start: window.start,
                exact: window.exact,
                end: window.end,
                repeatExact: window.repeatExact,
                nextExact: window.nextExact,
                passIndex: window.passIndex,
                passCount: window.passCount,
                returning: window.returning,
                timeZoneIdentifier: timeZone.identifier,
                cycleBand: TransitCycleBand(movingID: window.first.rawValue)
            )
        }
        let aspectWindowFactIDs = Dictionary(
            grouping: windowFacts.compactMap { window -> (String, String)? in
                guard let aspectFactID = window.sourceAspectFactID else { return nil }
                return (aspectFactID, window.factID)
            },
            by: \.0
        ).mapValues { links in
            links.map(\.1).sorted()
        }
        let planetEventFacts = planetEvents.map { event in
            let timestamp = Int(event.date.timeIntervalSince1970.rounded())
            return TransitPlanetEventFact(
                factID: "\(prefix).planet-event.\(event.body.rawValue).\(event.kind.rawValue).\(timestamp)",
                body: event.body,
                kind: TransitPlanetEventKind(event.kind),
                timestamp: event.date,
                timeZoneIdentifier: event.timeZoneIdentifier,
                fromIndex: event.fromIndex,
                toIndex: event.toIndex
            )
        }
        let placementFacts = snapshot.points.map { point in
            let assessment = preset == CalculationPreset.classical.rawValue
                && HoraryEngine.traditionalPlanets.contains(point.body)
                ? HoraryEngine.assess(point.body, in: snapshot)
                : nil
            return TransitPlanetPlacementFact(
                factID: "\(prefix).placement.\(point.id)",
                body: point.body,
                longitudeDegrees: point.longitudeDegrees,
                signIndex: point.signIndex,
                degreeInSign: point.degreeInSign,
                natalHouse: natal?.house(containing: point.longitudeDegrees) ?? 0,
                retrograde: point.retrograde,
                longitudeSpeedDegreesPerDay: point.position.longitudeSpeedDegreesPerDay,
                classicalScore: assessment?.score,
                classicalConditions: assessment?.conditions ?? []
            )
        }
        let lifeAreaFacts = makeLifeAreaFacts(
            prefix: prefix,
            placements: placementFacts,
            aspects: aspectFacts
        )
        let calendarFacts = makeCalendarFacts(
            prefix: prefix,
            days: transitCalendar,
            timeZone: timeZone
        )
        return TransitFactBundle(
            scopeID: scopeID,
            anchorDate: snapshot.utcDate,
            timeZoneIdentifier: timeZone.identifier,
            rangeDays: normalizedRangeDays,
            preset: preset,
            crossAspects: aspectFacts,
            transitWindows: windowFacts,
            aspectWindowFactIDs: aspectWindowFactIDs,
            planetEvents: planetEventFacts,
            planetPlacements: placementFacts,
            lifeAreaScores: lifeAreaFacts,
            transitCalendar: calendarFacts
        )
    }

    static func makeScopeID(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        crossAspects: [ChartAspect],
        preset: String,
        timeZoneIdentifier: String,
        rangeDays: Int
    ) -> String {
        let aspectSeed = crossAspects
            .map { "\($0.id):\($0.phase.rawValue):\(Int(($0.orbDegrees * 10_000).rounded()))" }
            .sorted()
            .joined(separator: ",")
        let values = [
            String(Int((snapshot.utcDate.timeIntervalSince1970 * 1_000).rounded())),
            String(Int(((natal?.utcDate.timeIntervalSince1970 ?? 0) * 1_000).rounded())),
            String(Int((snapshot.location.latitudeDegrees * 1_000_000).rounded())),
            String(Int((snapshot.location.longitudeDegrees * 1_000_000).rounded())),
            preset,
            timeZoneIdentifier,
            String(rangeDays),
            aspectSeed,
        ]
        return String(SHA256Digest.hash(Data(values.joined(separator: "|").utf8)).hex.prefix(16))
    }

    private static func makeLifeAreaFacts(
        prefix: String,
        placements: [TransitPlanetPlacementFact],
        aspects: [TransitAspectFact]
    ) -> [TransitLifeAreaFact] {
        var scores = [Double](repeating: 0, count: 12)
        var contributors = [[String]](repeating: [], count: 12)
        for placement in placements where (1 ... 12).contains(placement.natalHouse) {
            let index = placement.natalHouse - 1
            scores[index] += placement.retrograde ? 0.75 : 0.5
            contributors[index].append(placement.factID)
        }
        for aspect in aspects where (1 ... 12).contains(aspect.natalHouse) {
            let index = aspect.natalHouse - 1
            scores[index] += max(0.1, aspect.strength)
            contributors[index].append(aspect.factID)
        }
        let maximum = scores.max() ?? 0
        return scores.enumerated().map { index, score in
            return TransitLifeAreaFact(
                factID: "\(prefix).life-area.\(index + 1)",
                house: index + 1,
                normalizedScore: maximum > 0 ? score / maximum : 0,
                contributingFactIDs: contributors[index].sorted()
            )
        }
    }

    private static func makeCalendarFacts(
        prefix: String,
        days: [TransitCalendarDay],
        timeZone: TimeZone
    ) -> [TransitCalendarFact] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return days.map { day in
            let date = calendar.startOfDay(for: day.date)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            let dateID = String(
                format: "%04d-%02d-%02d",
                components.year ?? 0,
                components.month ?? 0,
                components.day ?? 0
            )
            return TransitCalendarFact(
                factID: "\(prefix).calendar.\(dateID)",
                date: date,
                score: day.score,
                sourceFactIDs: day.sourceFactIDs.sorted(),
                timeZoneIdentifier: timeZone.identifier
            )
        }
    }

    static func calendarSourceFactID(
        scopeID: String,
        date: Date,
        aspect: ChartAspect,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let dateID = String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
        return "transit.\(scopeID).calendar-source.\(dateID).aspect.\(aspect.firstID).\(aspect.kind.rawValue).\(aspect.secondID)"
    }

    private static func aspectKey(_ movingID: String, _ kind: AspectKind, _ referenceID: String) -> String {
        "\(movingID).\(kind.rawValue).\(referenceID)"
    }
}

enum TransitContentPlanner {
    static func plan(_ bundle: TransitFactBundle) -> TransitContentPlan {
        if bundle.preset == CalculationPreset.classical.rawValue {
            return ClassicalTransitPlanningStrategy.plan(bundle)
        }
        return planModern(bundle)
    }

    private static func planModern(_ bundle: TransitFactBundle) -> TransitContentPlan {
        var ledger = EvidenceUsageLedger()
        let aspects = bundle.crossAspects.sorted(by: aspectOrder)
        let rangeEnd = planningRangeEnd(for: bundle)
        let windows = bundle.transitWindows
            .filter { $0.end >= bundle.anchorDate && $0.start <= rangeEnd }
            .sorted(by: windowOrder)
        let planetEvents = bundle.planetEvents
            .filter { $0.timestamp >= bundle.anchorDate && $0.timestamp <= rangeEnd }
            .sorted(by: planetEventOrder)
        let placements = bundle.planetPlacements.sorted(by: placementOrder)
        let lifeAreas = bundle.lifeAreaScores.sorted(by: lifeAreaOrder)

        let storyFacts = storyFacts(from: aspects)
        let storyEvidence = storyFacts.enumerated().compactMap { index, fact in
            ledger.claim(
                .aspect(fact),
                mode: index == 0 ? .full : .short,
                role: index == 0 ? .primary : .supporting
            )
        }
        let storyAspectIDs = Set(storyFacts.map(\.factID))
        let storyWindowEvidence = windows.compactMap { window -> TransitPlannedEvidence? in
            guard let aspectFactID = window.sourceAspectFactID,
                  storyAspectIDs.contains(aspectFactID)
            else { return nil }
            return ledger.claim(
                .window(window),
                mode: .technical,
                role: aspectFactID == storyFacts.first?.factID ? .primaryWindow : .supportingWindow
            )
        }
        let calendar = bundle.transitCalendar.sorted {
            $0.date == $1.date ? $0.factID < $1.factID : $0.date < $1.date
        }
        let cycleEvidence = cyclePlans(
            windows: windows,
            aspects: aspects,
            calendar: calendar,
            anchorDate: bundle.anchorDate,
            ledger: &ledger
        )
        var timelineEvidence = windows.compactMap {
            ledger.claim(.window($0), mode: .technical, role: .timeline)
        }
        timelineEvidence += planetEvents.compactMap {
            ledger.claim(.planetEvent($0), mode: .technical, role: .timeline)
        }
        timelineEvidence += calendar.compactMap {
            ledger.claim(.calendar($0), mode: .technical, role: .timeline)
        }
        var pathEvidence = placements.compactMap {
            ledger.claim(.placement($0), mode: .technical, role: .path)
        }
        pathEvidence += planetEvents.compactMap {
            ledger.claim(.planetEvent($0), mode: .technical, role: .pathEvent)
        }
        let areaEvidence = lifeAreas.compactMap {
            ledger.claim(.lifeArea($0), mode: .aggregate, role: .lifeArea)
        }
        var activeEvidence = aspects.compactMap {
            ledger.claim(.aspect($0), mode: .short, role: .active)
        }
        let activeAspectIDs = Set(activeEvidence.map(\.fact.factID))
        activeEvidence += windows.compactMap { window in
            guard let sourceAspectFactID = window.sourceAspectFactID,
                  activeAspectIDs.contains(sourceAspectFactID)
            else { return nil }
            return ledger.claim(.window(window), mode: .technical, role: .activeWindow)
        }
        activeEvidence += planetEvents.compactMap { event in
            ledger.claim(
                .planetEvent(event),
                mode: .short,
                role: activeRole(for: event.kind)
            )
        }

        let storyAssignments = storyFacts.map { fact in
            let linkedWindowIDs = windows
                .filter { $0.sourceAspectFactID == fact.factID }
                .map(\.factID)
            return TransitStorySignalAssignment(
                signalID: signalID(for: fact),
                signalRole: storySignalRole(for: fact),
                movingID: fact.movingID,
                lifeAreas: [fact.natalHouse],
                sourceFactIDs: [fact.factID] + linkedWindowIDs
            )
        }
        let integratedThemeID = integratedThemeID(for: storyFacts)

        let cards = [
            makePlan(
                scopeID: bundle.scopeID,
                preset: bundle.preset,
                cardID: "current-story",
                evidence: storyEvidence + storyWindowEvidence,
                copySlot: .integratedStory,
                signalRoles: storyAssignments,
                integratedThemeID: integratedThemeID
            ),
            makePlan(scopeID: bundle.scopeID, preset: bundle.preset, cardID: "current-cycles", evidence: cycleEvidence, copySlot: .cycleChapter),
            makePlan(scopeID: bundle.scopeID, preset: bundle.preset, cardID: "transit-timeline", evidence: timelineEvidence, copySlot: nil),
            makePlan(scopeID: bundle.scopeID, preset: bundle.preset, cardID: "planet-paths", evidence: pathEvidence, copySlot: .planetPathShort),
            makePlan(scopeID: bundle.scopeID, preset: bundle.preset, cardID: "life-areas", evidence: areaEvidence, copySlot: .lifeAreaShort),
            makePlan(scopeID: bundle.scopeID, preset: bundle.preset, cardID: "active-transits", evidence: activeEvidence, copySlot: .activeTransitShort),
        ]
        return TransitContentPlan(
            scopeID: bundle.scopeID,
            anchorDate: bundle.anchorDate,
            timeZoneIdentifier: bundle.timeZoneIdentifier,
            rangeDays: bundle.rangeDays,
            preset: bundle.preset,
            cards: cards
        )
    }

    private static func cyclePlans(
        windows: [TransitWindowFact],
        aspects: [TransitAspectFact],
        calendar: [TransitCalendarFact],
        anchorDate: Date,
        ledger: inout EvidenceUsageLedger
    ) -> [TransitPlannedEvidence] {
        let roles: [(TransitCycleBand, TransitEvidenceRole)] = [
            (.longTerm, .longCycle),
            (.current, .currentCycle),
            (.daily, .dailyCycle),
        ]
        var evidence = roles.compactMap { band, role -> TransitPlannedEvidence? in
            let activeWindow = windows.first { window in
                guard window.cycleBand == band,
                      window.start <= anchorDate,
                      window.end >= anchorDate
                else { return false }
                return band != .longTerm
                    || window.end.timeIntervalSince(window.start) >= TransitCycleContract.minimumLongTermDuration
            }
            if let window = activeWindow {
                return ledger.claim(.window(window), mode: .aggregate, role: role)
            }
            guard let aspect = aspects.first(where: { $0.cycleBand == band }) else { return nil }
            return ledger.claim(.aspect(aspect), mode: .aggregate, role: role)
        }
        evidence += calendar.prefix(TransitTimelineContract.defaultRangeDays).compactMap {
            ledger.claim(.calendar($0), mode: .aggregate, role: .cycleCalendar)
        }
        return evidence
    }

    private static func makePlan(
        scopeID: String,
        preset: String,
        cardID: String,
        evidence: [TransitPlannedEvidence],
        copySlot: TransitCopySlot?,
        signalRoles: [TransitStorySignalAssignment] = [],
        integratedThemeID: TransitIntegratedThemeID? = nil
    ) -> CardEvidencePlan {
        let primary = evidence.first { $0.role != .cycleCalendar }
        let themeInputs = evidence.compactMap { item -> TransitThemeInput? in
            switch item.fact {
            case .aspect, .placement, .lifeArea:
                themeInput(from: item.fact, roleID: item.role.rawValue)
            case .planetEvent where item.role != .pathEvent:
                themeInput(from: item.fact, roleID: item.role.rawValue)
            case .planetEvent:
                nil
            case .window where item.role != .primaryWindow && item.role != .supportingWindow && item.role != .activeWindow:
                themeInput(from: item.fact, roleID: item.role.rawValue)
            case .window, .calendar:
                nil
            }
        }
        return CardEvidencePlan(
            scopeID: scopeID,
            preset: preset,
            cardID: cardID,
            evidence: evidence,
            primaryFactID: primary?.fact.factID,
            themeInputs: themeInputs,
            signalRoles: signalRoles,
            integratedThemeID: integratedThemeID,
            classicalSignalRoles: [],
            classicalIntegratedThemeID: nil,
            copySlot: copySlot,
            emptyState: .showInsufficientFacts
        )
    }

    private static func planningRangeEnd(for bundle: TransitFactBundle) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: bundle.timeZoneIdentifier) ?? .current
        return calendar.date(byAdding: .day, value: bundle.rangeDays, to: bundle.anchorDate)
            ?? bundle.anchorDate.addingTimeInterval(Double(bundle.rangeDays) * 86_400)
    }

    private static func storySignalRole(for fact: TransitAspectFact) -> TransitStorySignalRoleID {
        switch CelestialBody(rawValue: fact.movingID) {
        case .jupiter:
            .expanding
        case .saturn:
            .structuring
        case .uranus, .pluto:
            .disrupting
        case .moon where fact.kind.supportive:
            .stabilizing
        case .venus where fact.kind.supportive:
            .stabilizing
        default:
            fact.kind.challenging ? .disrupting : .supporting
        }
    }

    private static func storyFacts(from aspects: [TransitAspectFact]) -> [TransitAspectFact] {
        var selected: [TransitAspectFact] = []
        for body in [CelestialBody.jupiter, .saturn] {
            if let fact = aspects.first(where: { $0.movingID == body.rawValue }) {
                selected.append(fact)
            }
        }
        for fact in aspects where selected.count < 3 && !selected.contains(where: { $0.factID == fact.factID }) {
            selected.append(fact)
        }
        return selected
    }

    private static func themeInput(from fact: TransitFact, roleID: String) -> TransitThemeInput {
        switch fact {
        case let .aspect(aspect):
            return TransitThemeInput(
                signalID: "transit.signal.aspect.\(aspect.movingID).\(aspect.kind.rawValue).\(aspect.referenceID).\(aspect.phase.rawValue)",
                sourceFactIDs: [aspect.factID],
                movingID: aspect.movingID,
                referenceID: aspect.referenceID,
                aspectKind: aspect.kind,
                tone: tone(for: aspect.kind),
                house: aspect.natalHouse,
                roleID: roleID
            )
        case let .window(window):
            return TransitThemeInput(
                signalID: "transit.signal.window.\(window.movingID).\(window.kind.rawValue).\(window.referenceID).\(Int(window.exact.timeIntervalSince1970.rounded()))",
                sourceFactIDs: [window.factID],
                movingID: window.movingID,
                referenceID: window.referenceID,
                aspectKind: window.kind,
                tone: tone(for: window.kind),
                house: window.natalHouse,
                roleID: roleID
            )
        case let .planetEvent(event):
            return TransitThemeInput(
                signalID: "transit.signal.planet-event.\(event.body.rawValue).\(event.kind.rawValue).\(Int(event.timestamp.timeIntervalSince1970.rounded()))",
                sourceFactIDs: [event.factID],
                movingID: event.body.rawValue,
                referenceID: nil,
                aspectKind: nil,
                tone: "neutral",
                house: event.kind == .houseIngress ? event.toIndex : nil,
                roleID: roleID
            )
        case let .placement(placement):
            return TransitThemeInput(
                signalID: "transit.signal.placement.\(placement.body.rawValue)",
                sourceFactIDs: [placement.factID],
                movingID: placement.body.rawValue,
                referenceID: nil,
                aspectKind: nil,
                tone: placement.retrograde ? "challenging" : "neutral",
                house: placement.natalHouse,
                roleID: roleID
            )
        case let .lifeArea(area):
            return TransitThemeInput(
                signalID: "transit.signal.life-area.\(area.house)",
                sourceFactIDs: [area.factID],
                movingID: nil,
                referenceID: nil,
                aspectKind: nil,
                tone: "neutral",
                house: area.house,
                roleID: roleID
            )
        case let .calendar(day):
            return TransitThemeInput(
                signalID: "transit.signal.calendar.\(Int(day.date.timeIntervalSince1970))",
                sourceFactIDs: [day.factID],
                movingID: nil,
                referenceID: nil,
                aspectKind: nil,
                tone: "neutral",
                house: nil,
                roleID: roleID
            )
        }
    }

    private static func signalID(for aspect: TransitAspectFact) -> String {
        "transit.signal.aspect.\(aspect.movingID).\(aspect.kind.rawValue).\(aspect.referenceID).\(aspect.phase.rawValue)"
    }

    private static func integratedThemeID(for aspects: [TransitAspectFact]) -> TransitIntegratedThemeID? {
        guard !aspects.isEmpty else { return nil }
        let hasSupport = aspects.contains { $0.kind.supportive }
        let hasChallenge = aspects.contains { $0.kind.challenging }
        if hasSupport && hasChallenge { return .expansionStructure }
        if hasSupport { return .focusedExpansion }
        if hasChallenge { return .durableStructure }
        return .steadyRealignment
    }

    private static func activeRole(for kind: TransitPlanetEventKind) -> TransitEvidenceRole {
        switch kind {
        case .signIngress: .activeSignIngress
        case .houseIngress: .activeHouseIngress
        case .stationRetrograde: .activeStationRetrograde
        case .stationDirect: .activeStationDirect
        }
    }

    private static func tone(for kind: AspectKind) -> String {
        if kind.supportive { return "supportive" }
        if kind.challenging { return "challenging" }
        return "neutral"
    }

    private static func aspectOrder(_ lhs: TransitAspectFact, _ rhs: TransitAspectFact) -> Bool {
        if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
        if lhs.orbDegrees != rhs.orbDegrees { return lhs.orbDegrees < rhs.orbDegrees }
        return lhs.factID < rhs.factID
    }

    private static func windowOrder(_ lhs: TransitWindowFact, _ rhs: TransitWindowFact) -> Bool {
        if lhs.exact != rhs.exact { return lhs.exact < rhs.exact }
        return lhs.factID < rhs.factID
    }

    private static func planetEventOrder(_ lhs: TransitPlanetEventFact, _ rhs: TransitPlanetEventFact) -> Bool {
        if lhs.timestamp != rhs.timestamp { return lhs.timestamp < rhs.timestamp }
        return lhs.factID < rhs.factID
    }

    private static func placementOrder(_ lhs: TransitPlanetPlacementFact, _ rhs: TransitPlanetPlacementFact) -> Bool {
        let lhsPriority = placementPriority(lhs)
        let rhsPriority = placementPriority(rhs)
        if lhsPriority != rhsPriority { return lhsPriority > rhsPriority }
        return lhs.factID < rhs.factID
    }

    private static func placementPriority(_ fact: TransitPlanetPlacementFact) -> Int {
        var score = 0
        switch fact.body {
        case .saturn, .uranus, .neptune, .pluto: score += 50
        default: break
        }
        if fact.body == .moon { score -= 30 }
        if fact.degreeInSign > 27 { score += 20 }
        if fact.retrograde { score += 10 }
        return score
    }

    private static func lifeAreaOrder(_ lhs: TransitLifeAreaFact, _ rhs: TransitLifeAreaFact) -> Bool {
        if lhs.normalizedScore != rhs.normalizedScore { return lhs.normalizedScore > rhs.normalizedScore }
        return lhs.house < rhs.house
    }

    private struct EvidenceUsageLedger {
        private var fullClaims = Set<String>()

        mutating func claim(
            _ fact: TransitFact,
            mode: TransitClaimMode,
            role: TransitEvidenceRole
        ) -> TransitPlannedEvidence? {
            if mode == .full, !fullClaims.insert(fact.factID).inserted {
                return nil
            }
            return TransitPlannedEvidence(fact: fact, claimMode: mode, role: role)
        }
    }
}

extension TransitContentPlan: ChartContentPlanProtocol {
    var orderedCardIDs: [String] { cards.map(\.cardID) }

    func evidenceFactIDs(for cardID: String) -> [String] {
        card(cardID)?.sourceFactIDs ?? []
    }
}
