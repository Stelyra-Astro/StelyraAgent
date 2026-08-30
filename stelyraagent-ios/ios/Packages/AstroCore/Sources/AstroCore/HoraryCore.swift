import Foundation

public enum HoraryQuestionMode: String, Sendable, Codable {
    case yesNo
    case choice
    case timing
}

public enum TraditionalCondition: String, Sendable, Codable, CaseIterable {
    case domicile
    case exaltation
    case detriment
    case fall
    case angular
    case succedent
    case cadent
    case retrograde
    case cazimi
    case combust
    case underBeams
}

public struct HoraryScoreComponent: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let value: Double

    public init(id: String, value: Double) {
        self.id = id
        self.value = value
    }
}

public struct HoraryPlanetAssessment: Sendable, Equatable, Identifiable, Codable {
    public let body: CelestialBody
    public let house: Int
    public let signIndex: Int
    public let score: Double
    public let conditions: [TraditionalCondition]

    public var id: String { body.id }
}

public struct HoraryReception: Sendable, Equatable, Codable {
    public let from: CelestialBody
    public let to: CelestialBody
    public let byDomicile: Bool
    public let byExaltation: Bool

    public var isPresent: Bool { byDomicile || byExaltation }
}

public struct HoraryMoonCondition: Sendable, Equatable, Codable {
    public let isVoidOfCourse: Bool
    public let nextAspect: ChartAspect?
    public let hoursUntilNextAspect: Double?
}

public enum HoraryPerfectionKind: String, Sendable, Equatable, Codable {
    case direct
    case translation
    case collection
}

public enum HoraryPerfectionStatus: String, Sendable, Equatable, Codable {
    case completes
    case prevented
    case delayed
    case none
    case ambiguous
}

public enum HoraryInterruptionKind: String, Sendable, Equatable, Codable {
    case signChange
    case refranation
    case prohibition
}

public struct HoraryPerfectionPath: Sendable, Equatable, Codable {
    public let kind: HoraryPerfectionKind
    public let exactDate: Date
    public let aspectKind: AspectKind
    public let distanceDegrees: Double
    public let mediator: CelestialBody?
}

public struct HoraryPerfectionInterruption: Sendable, Equatable, Codable {
    public let kind: HoraryInterruptionKind
    public let date: Date
    public let body: CelestialBody
}

public struct HoraryPerfectionAssessment: Sendable, Equatable, Codable {
    public let status: HoraryPerfectionStatus
    public let primaryPath: HoraryPerfectionPath?
    public let interruptions: [HoraryPerfectionInterruption]

    public static let none = HoraryPerfectionAssessment(
        status: .none,
        primaryPath: nil,
        interruptions: []
    )
}

public enum HoraryJudgmentVerdict: String, Sendable, Equatable, Codable {
    case yes
    case no
    case noClearJudgment
}

public struct HoraryJudgment: Sendable, Equatable, Codable {
    public let verdict: HoraryJudgmentVerdict
    public let perfection: HoraryPerfectionAssessment
}

public struct HoraryAnalysis: Sendable, Equatable, Codable {
    public let querentHouse: Int
    public let targetHouse: Int
    public let querentRuler: CelestialBody
    public let targetRuler: CelestialBody
    public let querent: HoraryPlanetAssessment
    public let target: HoraryPlanetAssessment
    public let relationship: ChartAspect?
    public let receptionFromQuerent: HoraryReception
    public let receptionFromTarget: HoraryReception
    public let moon: HoraryMoonCondition
    public let score: Double
    public let components: [HoraryScoreComponent]
    public let judgment: HoraryJudgment?

    public init(
        querentHouse: Int,
        targetHouse: Int,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody,
        querent: HoraryPlanetAssessment,
        target: HoraryPlanetAssessment,
        relationship: ChartAspect?,
        receptionFromQuerent: HoraryReception,
        receptionFromTarget: HoraryReception,
        moon: HoraryMoonCondition,
        score: Double,
        components: [HoraryScoreComponent],
        judgment: HoraryJudgment? = nil
    ) {
        self.querentHouse = querentHouse
        self.targetHouse = targetHouse
        self.querentRuler = querentRuler
        self.targetRuler = targetRuler
        self.querent = querent
        self.target = target
        self.relationship = relationship
        self.receptionFromQuerent = receptionFromQuerent
        self.receptionFromTarget = receptionFromTarget
        self.moon = moon
        self.score = score
        self.components = components
        self.judgment = judgment
    }
}

public struct HoraryChoiceCandidate: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let label: String
    public let house: Int
    public let relatedHouses: [Int]
    public let originalIndex: Int

    public init(
        id: UUID = UUID(),
        label: String,
        house: Int,
        relatedHouses: [Int] = [],
        originalIndex: Int = 0
    ) {
        self.id = id
        self.label = label
        self.house = house
        self.relatedHouses = relatedHouses.filter { $0 != house }
        self.originalIndex = originalIndex
    }
}

public struct HoraryChoiceResult: Sendable, Equatable, Identifiable, Codable {
    public let id: UUID
    public let label: String
    public let house: Int
    public let relatedHouses: [Int]
    public let ruler: CelestialBody
    public let supportScore: Double
    public let analysis: HoraryAnalysis
    public let originalIndex: Int
    public let isTiedForLead: Bool

    public init(
        id: UUID,
        label: String,
        house: Int,
        relatedHouses: [Int],
        ruler: CelestialBody,
        supportScore: Double,
        analysis: HoraryAnalysis,
        originalIndex: Int,
        isTiedForLead: Bool = false
    ) {
        self.id = id
        self.label = label
        self.house = house
        self.relatedHouses = relatedHouses
        self.ruler = ruler
        self.supportScore = supportScore
        self.analysis = analysis
        self.originalIndex = originalIndex
        self.isTiedForLead = isTiedForLead
    }
}

public enum HoraryChoiceSignificatorMode: Sendable, Equatable {
    case sharedPrimary(house: Int)
    case independentPrimary
}

public enum TimingPrecision: String, Sendable, Codable, CaseIterable {
    case day
    case week
    case month
}

public struct ElectionTimingRequest: Sendable, Equatable {
    public let targetHouse: Int
    public let relatedHouses: [Int]
    public let startDate: Date
    public let endDate: Date
    public let location: GeographicLocation
    public let timeZone: TimeZone
    public let calendarIdentifier: Calendar.Identifier
    public let precision: TimingPrecision

    public init(
        targetHouse: Int,
        relatedHouses: [Int] = [],
        startDate: Date,
        endDate: Date,
        location: GeographicLocation,
        timeZone: TimeZone,
        calendarIdentifier: Calendar.Identifier = .gregorian,
        precision: TimingPrecision
    ) {
        self.targetHouse = targetHouse
        self.relatedHouses = relatedHouses.filter { $0 != targetHouse }
        self.startDate = startDate
        self.endDate = endDate
        self.location = location
        self.timeZone = timeZone
        self.calendarIdentifier = calendarIdentifier
        self.precision = precision
    }
}

public struct ElectionTimingCandidate: Sendable, Equatable, Identifiable, Codable {
    public let id: String
    public let interval: DateInterval
    public let peakDate: Date
    public let score: Double
    public let snapshot: ChartSnapshot
    public let analysis: HoraryAnalysis

    public init(
        id: String,
        interval: DateInterval,
        peakDate: Date,
        score: Double,
        snapshot: ChartSnapshot,
        analysis: HoraryAnalysis
    ) {
        self.id = id
        self.interval = interval
        self.peakDate = peakDate
        self.score = score
        self.snapshot = snapshot
        self.analysis = analysis
    }
}

public enum ElectionTimingError: Error, Sendable, Equatable, LocalizedError {
    case invalidRange
    case rangeTooLong
    case noCandidates

    public var errorDescription: String? {
        switch self {
        case .invalidRange: "The timing search range is invalid."
        case .rangeTooLong: "The timing search range exceeds the supported limit."
        case .noCandidates: "No timing candidates could be calculated."
        }
    }
}

public enum HoraryEngine {
    public static let traditionalPlanets: [CelestialBody] = [
        .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn,
    ]

    public static func ruler(ofSign signIndex: Int) -> CelestialBody {
        switch normalizedSign(signIndex) {
        case 0: .mars
        case 1: .venus
        case 2: .mercury
        case 3: .moon
        case 4: .sun
        case 5: .mercury
        case 6: .venus
        case 7: .mars
        case 8: .jupiter
        case 9: .saturn
        case 10: .saturn
        default: .jupiter
        }
    }

    public static func ruler(ofHouse house: Int, in snapshot: ChartSnapshot) -> CelestialBody {
        guard let cusp = snapshot.houses.first(where: { $0.number == house }) else {
            return .mars
        }
        return ruler(ofSign: Int(normalizeDegrees(cusp.cuspDegrees) / 30))
    }

    public static func assess(
        _ body: CelestialBody,
        in snapshot: ChartSnapshot
    ) -> HoraryPlanetAssessment {
        guard let point = snapshot.point(body) else {
            return HoraryPlanetAssessment(
                body: body,
                house: 0,
                signIndex: 0,
                score: 0,
                conditions: []
            )
        }
        let sign = point.signIndex
        let house = snapshot.house(containing: point.longitudeDegrees)
        var score = 0.0
        var conditions: [TraditionalCondition] = []

        if ruler(ofSign: sign) == body {
            score += 15
            conditions.append(.domicile)
        } else if ruler(ofSign: oppositeSign(sign)) == body {
            score -= 12
            conditions.append(.detriment)
        }
        if exaltationRuler(ofSign: sign) == body {
            score += 12
            conditions.append(.exaltation)
        } else if exaltationRuler(ofSign: oppositeSign(sign)) == body {
            score -= 15
            conditions.append(.fall)
        }

        if [1, 4, 7, 10].contains(house) {
            score += 10
            conditions.append(.angular)
        } else if [2, 5, 8, 11].contains(house) {
            score += 5
            conditions.append(.succedent)
        } else {
            score -= 5
            conditions.append(.cadent)
        }

        if point.retrograde {
            score -= 8
            conditions.append(.retrograde)
        }

        if body != .sun, let sun = snapshot.point(.sun) {
            let distance = angularDistance(point.longitudeDegrees, sun.longitudeDegrees)
            if distance <= 17.0 / 60.0 {
                score += 12
                conditions.append(.cazimi)
            } else if distance <= 8.5 {
                score -= 15
                conditions.append(.combust)
            } else if distance <= 17 {
                score -= 8
                conditions.append(.underBeams)
            }
        }

        return HoraryPlanetAssessment(
            body: body,
            house: house,
            signIndex: sign,
            score: score,
            conditions: conditions
        )
    }

    public static func reception(
        from: CelestialBody,
        to: CelestialBody,
        in snapshot: ChartSnapshot
    ) -> HoraryReception {
        let sign = snapshot.point(from)?.signIndex ?? 0
        return reception(from: from, to: to, fromSignIndex: sign)
    }

    public static func reception(
        from: CelestialBody,
        to: CelestialBody,
        fromSignIndex: Int
    ) -> HoraryReception {
        return HoraryReception(
            from: from,
            to: to,
            byDomicile: ruler(ofSign: fromSignIndex) == to,
            byExaltation: exaltationRuler(ofSign: fromSignIndex) == to
        )
    }

    public static func analyze(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        targetRuler override: CelestialBody? = nil,
        relatedHouses: [Int] = []
    ) -> HoraryAnalysis {
        let querentRuler = ruler(ofHouse: 1, in: snapshot)
        let targetRuler = override ?? ruler(ofHouse: targetHouse, in: snapshot)
        let querent = assess(querentRuler, in: snapshot)
        let target = assess(targetRuler, in: snapshot)
        let relationship = validTraditionalAspects(in: snapshot).first {
            Set([$0.firstID, $0.secondID]) == Set([querentRuler.id, targetRuler.id])
        }
        let fromQuerent = reception(from: querentRuler, to: targetRuler, in: snapshot)
        let fromTarget = reception(from: targetRuler, to: querentRuler, in: snapshot)
        let moon = moonCondition(in: snapshot)

        var components: [HoraryScoreComponent] = []
        let relationshipScore = querentRuler == targetRuler
            ? 30
            : scoreRelationship(relationship)
        components.append(.init(id: "significator-relationship", value: relationshipScore))

        let receptionScore: Double
        if fromQuerent.isPresent, fromTarget.isPresent {
            receptionScore = 20
        } else if fromQuerent.isPresent || fromTarget.isPresent {
            receptionScore = 10
        } else {
            receptionScore = 0
        }
        components.append(.init(id: "reception", value: receptionScore))

        var moonScore = moon.isVoidOfCourse ? -15.0 : 5.0
        if let next = moon.nextAspect {
            if [querentRuler.id, targetRuler.id].contains(next.firstID)
                || [querentRuler.id, targetRuler.id].contains(next.secondID)
            {
                moonScore += next.kind.supportive || next.kind == .conjunction ? 10 : -5
            }
        }
        components.append(.init(id: "moon", value: moonScore))

        let strengthScore = clamp((querent.score + target.score) / 4, lower: -10, upper: 10)
        components.append(.init(id: "strength", value: strengthScore))

        let relatedRulers = Set(relatedHouses.filter { $0 != targetHouse }.map {
            ruler(ofHouse: $0, in: snapshot)
        })
        if !relatedRulers.isEmpty {
            let average = relatedRulers
                .map { assess($0, in: snapshot).score }
                .reduce(0, +) / Double(relatedRulers.count)
            components.append(
                .init(id: "related-area-support", value: clamp(average / 6, lower: -5, upper: 5))
            )
        }

        let raw = 50 + components.reduce(0) { $0 + $1.value }
        return HoraryAnalysis(
            querentHouse: 1,
            targetHouse: targetHouse,
            querentRuler: querentRuler,
            targetRuler: targetRuler,
            querent: querent,
            target: target,
            relationship: relationship,
            receptionFromQuerent: fromQuerent,
            receptionFromTarget: fromTarget,
            moon: moon,
            score: clamp(raw, lower: 0, upper: 100),
            components: components
        )
    }

    public static func judgedAnalysis(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        targetRuler override: CelestialBody? = nil,
        relatedHouses: [Int] = [],
        calculator: SwissEphemerisCalculator
    ) async throws -> HoraryAnalysis {
        let base = analyze(
            snapshot: snapshot,
            targetHouse: targetHouse,
            targetRuler: override,
            relatedHouses: relatedHouses
        )
        let perfection = try await calculator.resolveHoraryPerfection(
            snapshot: snapshot,
            querentRuler: base.querentRuler,
            targetRuler: base.targetRuler
        )
        let verdict: HoraryJudgmentVerdict
        switch perfection.status {
        case .completes: verdict = .yes
        case .prevented: verdict = .no
        case .delayed, .none, .ambiguous: verdict = .noClearJudgment
        }
        return HoraryAnalysis(
            querentHouse: base.querentHouse,
            targetHouse: base.targetHouse,
            querentRuler: base.querentRuler,
            targetRuler: base.targetRuler,
            querent: base.querent,
            target: base.target,
            relationship: base.relationship,
            receptionFromQuerent: base.receptionFromQuerent,
            receptionFromTarget: base.receptionFromTarget,
            moon: base.moon,
            score: base.score,
            components: base.components,
            judgment: HoraryJudgment(verdict: verdict, perfection: perfection)
        )
    }

    public static func analyzeChoices(
        snapshot: ChartSnapshot,
        candidates: [HoraryChoiceCandidate],
        mode: HoraryChoiceSignificatorMode = .independentPrimary
    ) -> [HoraryChoiceResult] {
        let analyses = candidates.map { candidate in
            let assignedRuler: CelestialBody?
            if case let .sharedPrimary(house) = mode,
               let cusp = snapshot.houses.first(where: { $0.number == house })
            {
                let signIndex = Int(normalizeDegrees(cusp.cuspDegrees) / 30)
                let rulers = triplicityRulers(ofSign: signIndex, isDayChart: isDayChart(snapshot))
                assignedRuler = candidate.originalIndex < rulers.count
                    ? rulers[candidate.originalIndex]
                    : nil
            } else {
                assignedRuler = nil
            }
            return (
                candidate,
                analyze(
                    snapshot: snapshot,
                    targetHouse: candidate.house,
                    targetRuler: assignedRuler,
                    relatedHouses: candidate.relatedHouses
                )
            )
        }
        return analyses.map { item in
            let candidate = item.0
            let analysis = item.1
            return HoraryChoiceResult(
                id: candidate.id,
                label: candidate.label,
                house: candidate.house,
                relatedHouses: candidate.relatedHouses,
                ruler: analysis.targetRuler,
                supportScore: analysis.score,
                analysis: analysis,
                originalIndex: candidate.originalIndex
            )
        }
        .sorted {
            if abs($0.supportScore - $1.supportScore) > 0.000_001 {
                return $0.supportScore > $1.supportScore
            }
            return $0.label.localizedStandardCompare($1.label) == .orderedAscending
        }
    }

    public static func judgedChoices(
        snapshot: ChartSnapshot,
        candidates: [HoraryChoiceCandidate],
        mode: HoraryChoiceSignificatorMode,
        calculator: SwissEphemerisCalculator
    ) async throws -> [HoraryChoiceResult] {
        let assigned = analyzeChoices(snapshot: snapshot, candidates: candidates, mode: mode)
        var judged: [HoraryChoiceResult] = []
        for result in assigned {
            let analysis = try await judgedAnalysis(
                snapshot: snapshot,
                targetHouse: result.house,
                targetRuler: result.ruler,
                relatedHouses: result.relatedHouses,
                calculator: calculator
            )
            judged.append(
                HoraryChoiceResult(
                    id: result.id,
                    label: result.label,
                    house: result.house,
                    relatedHouses: result.relatedHouses,
                    ruler: result.ruler,
                    supportScore: analysis.score,
                    analysis: analysis,
                    originalIndex: result.originalIndex
                )
            )
        }
        let sorted = judged.sorted(by: choicePrecedes)
        guard sorted.count > 1 else { return sorted }
        let leader = sorted[0]
        return sorted.map { result in
            let tiedWithLeader = result.id != leader.id
                && !choicePrecedes(leader, result)
                && !choicePrecedes(result, leader)
            return HoraryChoiceResult(
                id: result.id,
                label: result.label,
                house: result.house,
                relatedHouses: result.relatedHouses,
                ruler: result.ruler,
                supportScore: result.supportScore,
                analysis: result.analysis,
                originalIndex: result.originalIndex,
                isTiedForLead: tiedWithLeader
                    || (result.id == leader.id && sorted.dropFirst().contains {
                        !choicePrecedes(leader, $0) && !choicePrecedes($0, leader)
                    })
            )
        }
    }

    private static func choicePrecedes(_ lhs: HoraryChoiceResult, _ rhs: HoraryChoiceResult) -> Bool {
        let lhsJudgment = lhs.analysis.judgment
        let rhsJudgment = rhs.analysis.judgment
        let lhsRank = judgmentRank(lhsJudgment?.verdict)
        let rhsRank = judgmentRank(rhsJudgment?.verdict)
        if lhsRank != rhsRank { return lhsRank > rhsRank }

        let lhsPath = lhsJudgment?.perfection.primaryPath
        let rhsPath = rhsJudgment?.perfection.primaryPath
        if let lhsPath, let rhsPath {
            let lhsConjunction = lhsPath.aspectKind == .conjunction
            let rhsConjunction = rhsPath.aspectKind == .conjunction
            if lhsConjunction != rhsConjunction { return lhsConjunction }
            if abs(lhsPath.exactDate.timeIntervalSince(rhsPath.exactDate)) > 60 {
                return lhsPath.exactDate < rhsPath.exactDate
            }
        } else if lhsPath != nil || rhsPath != nil {
            return lhsPath != nil
        }

        let lhsReception = receptionRank(lhs.analysis)
        let rhsReception = receptionRank(rhs.analysis)
        if lhsReception != rhsReception { return lhsReception > rhsReception }
        if abs(lhs.analysis.target.score - rhs.analysis.target.score) > 0.001 {
            return lhs.analysis.target.score > rhs.analysis.target.score
        }
        let lhsMoon = moonTestimonyRank(lhs.analysis)
        let rhsMoon = moonTestimonyRank(rhs.analysis)
        if lhsMoon != rhsMoon { return lhsMoon > rhsMoon }
        return false
    }

    private static func judgmentRank(_ verdict: HoraryJudgmentVerdict?) -> Int {
        switch verdict {
        case .yes: 2
        case .noClearJudgment: 1
        case .no: 0
        case nil: -1
        }
    }

    private static func receptionRank(_ analysis: HoraryAnalysis) -> Int {
        if analysis.receptionFromQuerent.isPresent, analysis.receptionFromTarget.isPresent { return 2 }
        return analysis.receptionFromQuerent.isPresent || analysis.receptionFromTarget.isPresent ? 1 : 0
    }

    private static func moonTestimonyRank(_ analysis: HoraryAnalysis) -> Int {
        guard !analysis.moon.isVoidOfCourse else { return 0 }
        guard let next = analysis.moon.nextAspect else { return 1 }
        let ids = [next.firstID, next.secondID]
        return ids.contains(analysis.targetRuler.id) ? 3 : 2
    }

    public static func timingAnalysis(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        relatedHouses: [Int] = []
    ) -> HoraryAnalysis {
        let base = analyze(
            snapshot: snapshot,
            targetHouse: targetHouse,
            relatedHouses: relatedHouses
        )
        let ascendantRuler = ruler(ofHouse: 1, in: snapshot)
        let ascendant = assess(ascendantRuler, in: snapshot)
        let target = base.target
        let moon = base.moon
        let aspects = validTraditionalAspects(in: snapshot)
        let beneficSupport = aspects.filter { aspect in
            guard aspect.phase != .separating else { return false }
            let ids = Set([aspect.firstID, aspect.secondID])
            return ids.contains(base.targetRuler.id)
                && (ids.contains(CelestialBody.jupiter.id) || ids.contains(CelestialBody.venus.id))
                && (aspect.kind.supportive || aspect.kind == .conjunction)
        }
        let applyingConnection = base.relationship?.phase != .separating ? base.relationship : nil

        var components = [
            HoraryScoreComponent(
                id: "target-strength",
                value: scale(target.score, from: -30 ... 37, to: 0 ... 30)
            ),
            HoraryScoreComponent(
                id: "moon-condition",
                value: moon.isVoidOfCourse ? 3 : (moon.nextAspect == nil ? 10 : 25)
            ),
            HoraryScoreComponent(
                id: "ascendant-strength",
                value: scale(ascendant.score, from: -30 ... 37, to: 0 ... 15)
            ),
            HoraryScoreComponent(
                id: "benefic-support",
                value: min(15, Double(beneficSupport.count) * 7.5)
            ),
            HoraryScoreComponent(
                id: "applying-connection",
                value: applyingConnection == nil ? 0 : 15
            ),
        ]
        var risk = 0.0
        if target.conditions.contains(.retrograde) { risk -= 8 }
        if target.conditions.contains(.combust) { risk -= 12 }
        if moon.isVoidOfCourse { risk -= 10 }
        if base.relationship?.kind.challenging == true { risk -= 8 }
        risk = max(-30, risk)
        components.append(.init(id: "risk", value: risk))
        let total = clamp(components.reduce(0) { $0 + $1.value }, lower: 0, upper: 100)

        return HoraryAnalysis(
            querentHouse: base.querentHouse,
            targetHouse: base.targetHouse,
            querentRuler: base.querentRuler,
            targetRuler: base.targetRuler,
            querent: base.querent,
            target: base.target,
            relationship: base.relationship,
            receptionFromQuerent: base.receptionFromQuerent,
            receptionFromTarget: base.receptionFromTarget,
            moon: base.moon,
            score: total,
            components: components
        )
    }

    /// Traditional Dorothean triplicity rulers, ordered for the chart sect.
    /// The third value is the participating ruler used for a third same-area option.
    public static func triplicityRulers(
        ofSign signIndex: Int,
        isDayChart: Bool
    ) -> [CelestialBody] {
        let rulers: (day: CelestialBody, night: CelestialBody, participating: CelestialBody)
        switch normalizedSign(signIndex) % 4 {
        case 0: rulers = (.sun, .jupiter, .saturn)       // Fire
        case 1: rulers = (.venus, .moon, .mars)          // Earth
        case 2: rulers = (.saturn, .mercury, .jupiter)   // Air
        default: rulers = (.venus, .mars, .moon)         // Water
        }
        return isDayChart
            ? [rulers.day, rulers.night, rulers.participating]
            : [rulers.night, rulers.day, rulers.participating]
    }

    public static func isDayChart(_ snapshot: ChartSnapshot) -> Bool {
        guard let sun = snapshot.point(.sun) else { return true }
        return (7 ... 12).contains(snapshot.house(containing: sun.longitudeDegrees))
    }

    public static func validTraditionalAspects(in snapshot: ChartSnapshot) -> [ChartAspect] {
        snapshot.aspects.filter { aspect in
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID),
                  traditionalPlanets.contains(first),
                  traditionalPlanets.contains(second)
            else {
                return false
            }
            return aspect.orbDegrees <= (traditionalOrb(first) + traditionalOrb(second)) / 2
        }
    }

    public static func moonCondition(in snapshot: ChartSnapshot) -> HoraryMoonCondition {
        guard let moon = snapshot.point(.moon) else {
            return HoraryMoonCondition(
                isVoidOfCourse: true,
                nextAspect: nil,
                hoursUntilNextAspect: nil
            )
        }
        let speed = max(0.01, moon.position.longitudeSpeedDegreesPerDay)
        let degreesRemaining = 30 - moon.degreeInSign
        let daysUntilSignExit = degreesRemaining / speed
        var candidates: [(ChartAspect, Double)] = []

        for body in traditionalPlanets where body != .moon {
            guard let other = snapshot.point(body) else { continue }
            let start = signedSeparation(
                moon.longitudeDegrees,
                other.longitudeDegrees
            )
            let end = signedSeparation(
                moon.longitudeDegrees + moon.position.longitudeSpeedDegreesPerDay * daysUntilSignExit,
                other.longitudeDegrees + other.position.longitudeSpeedDegreesPerDay * daysUntilSignExit
            )
            for kind in AspectKind.allCases {
                guard let fraction = AspectEventInterpolation.exactCrossingFraction(
                    from: start,
                    to: end,
                    aspectAngleDegrees: kind.angleDegrees
                ) else {
                    continue
                }
                let hours = fraction * daysUntilSignExit * 24
                guard hours > 0.001 else { continue }
                let firstLongitude = normalizeDegrees(
                    moon.longitudeDegrees + moon.position.longitudeSpeedDegreesPerDay * daysUntilSignExit * fraction
                )
                let secondLongitude = normalizeDegrees(
                    other.longitudeDegrees + other.position.longitudeSpeedDegreesPerDay * daysUntilSignExit * fraction
                )
                candidates.append(
                    (
                        ChartAspect(
                            firstID: CelestialBody.moon.id,
                            secondID: body.id,
                            kind: kind,
                            orbDegrees: 0,
                            phase: .applying,
                            strength: 1,
                            firstLongitude: firstLongitude,
                            secondLongitude: secondLongitude
                        ),
                        hours
                    )
                )
            }
        }

        let next = candidates.min { $0.1 < $1.1 }
        return HoraryMoonCondition(
            isVoidOfCourse: next == nil,
            nextAspect: next?.0,
            hoursUntilNextAspect: next?.1
        )
    }

    private static func scoreRelationship(_ aspect: ChartAspect?) -> Double {
        guard let aspect else { return 0 }
        guard aspect.phase != .separating else { return 0 }
        let base: Double
        switch aspect.kind {
        case .conjunction: base = 20
        case .trine: base = 15
        case .sextile: base = 12
        case .square: base = 6
        case .opposition: base = 2
        }
        return base
    }

    private static func exaltationRuler(ofSign signIndex: Int) -> CelestialBody? {
        switch normalizedSign(signIndex) {
        case 0: .sun
        case 1: .moon
        case 3: .jupiter
        case 5: .mercury
        case 6: .saturn
        case 9: .mars
        case 11: .venus
        default: nil
        }
    }

    private static func oppositeSign(_ sign: Int) -> Int {
        normalizedSign(sign + 6)
    }

    private static func normalizedSign(_ sign: Int) -> Int {
        ((sign % 12) + 12) % 12
    }

    private static func traditionalOrb(_ body: CelestialBody) -> Double {
        switch body {
        case .sun: 15
        case .moon: 12
        case .mercury, .venus: 7
        case .mars: 8
        case .jupiter, .saturn: 9
        default: 0
        }
    }

    private static func angularDistance(_ first: Double, _ second: Double) -> Double {
        abs(signedSeparation(first, second))
    }

    private static func signedSeparation(_ first: Double, _ second: Double) -> Double {
        var value = normalizeDegrees(second) - normalizeDegrees(first)
        while value > 180 { value -= 360 }
        while value < -180 { value += 360 }
        return value
    }

    private static func normalizeDegrees(_ value: Double) -> Double {
        let result = value.truncatingRemainder(dividingBy: 360)
        return result >= 0 ? result : result + 360
    }

    private static func clamp(_ value: Double, lower: Double, upper: Double) -> Double {
        min(upper, max(lower, value))
    }

    private static func scale(
        _ value: Double,
        from source: ClosedRange<Double>,
        to destination: ClosedRange<Double>
    ) -> Double {
        let progress = clamp(
            (value - source.lowerBound) / (source.upperBound - source.lowerBound),
            lower: 0,
            upper: 1
        )
        return destination.lowerBound
            + progress * (destination.upperBound - destination.lowerBound)
    }
}

extension SwissEphemerisCalculator {
    public func resolveHoraryPerfection(
        snapshot: ChartSnapshot,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody
    ) throws -> HoraryPerfectionAssessment {
        let effectiveQuerent = querentRuler == targetRuler ? CelestialBody.moon : querentRuler
        if effectiveQuerent == targetRuler {
            return HoraryPerfectionAssessment(
                status: .ambiguous,
                primaryPath: nil,
                interruptions: []
            )
        }

        let aspects = HoraryEngine.validTraditionalAspects(in: snapshot)
        let direct = aspects.first {
            Set([$0.firstID, $0.secondID]) == Set([effectiveQuerent.id, targetRuler.id])
                && ($0.phase == .applying || $0.phase == .exact)
        }
        var directInterruptions: [HoraryPerfectionInterruption] = []
        if let direct,
           let path = try perfectionPath(
               kind: .direct,
               aspect: direct,
               moving: effectiveQuerent,
               reference: targetRuler,
               mediator: nil,
               after: snapshot.utcDate
           )
        {
            directInterruptions = try interruptions(
                before: path.exactDate,
                bodies: [effectiveQuerent, targetRuler],
                after: snapshot.utcDate
            )
            if directInterruptions.isEmpty,
               let prohibition = try prohibition(
                   of: targetRuler,
                   before: path.exactDate,
                   excluding: [effectiveQuerent, targetRuler],
                   aspects: aspects,
                   after: snapshot.utcDate
               )
            {
                directInterruptions.append(prohibition)
            }
            if directInterruptions.isEmpty {
                return HoraryPerfectionAssessment(
                    status: .completes,
                    primaryPath: path,
                    interruptions: []
                )
            }
        }

        let alternatives = try alternativePerfections(
            snapshot: snapshot,
            querentRuler: effectiveQuerent,
            targetRuler: targetRuler,
            aspects: aspects
        )
        if let alternative = alternatives.min(by: { $0.exactDate < $1.exactDate }) {
            return HoraryPerfectionAssessment(
                status: .completes,
                primaryPath: alternative,
                interruptions: directInterruptions
            )
        }
        if let direct {
            let delayed = directInterruptions.contains { $0.kind == .prohibition }
            return HoraryPerfectionAssessment(
                status: delayed ? .delayed : .prevented,
                primaryPath: try perfectionPath(
                    kind: .direct,
                    aspect: direct,
                    moving: effectiveQuerent,
                    reference: targetRuler,
                    mediator: nil,
                    after: snapshot.utcDate
                ),
                interruptions: directInterruptions
            )
        }
        return .none
    }

    private func alternativePerfections(
        snapshot: ChartSnapshot,
        querentRuler: CelestialBody,
        targetRuler: CelestialBody,
        aspects: [ChartAspect]
    ) throws -> [HoraryPerfectionPath] {
        var paths: [HoraryPerfectionPath] = []
        for mediator in HoraryEngine.traditionalPlanets
            where mediator != querentRuler && mediator != targetRuler
        {
            let withQuerent = aspect(between: mediator, and: querentRuler, in: aspects)
            let withTarget = aspect(between: mediator, and: targetRuler, in: aspects)
            guard let first = withQuerent, let second = withTarget else { continue }
            let mediatorSpeed = abs(snapshot.point(mediator)?.position.longitudeSpeedDegreesPerDay ?? 0)
            let querentSpeed = abs(snapshot.point(querentRuler)?.position.longitudeSpeedDegreesPerDay ?? 0)
            let targetSpeed = abs(snapshot.point(targetRuler)?.position.longitudeSpeedDegreesPerDay ?? 0)

            let translationApplying: (ChartAspect, CelestialBody)?
            if first.phase == .separating, second.phase == .applying {
                translationApplying = (second, targetRuler)
            } else if second.phase == .separating, first.phase == .applying {
                translationApplying = (first, querentRuler)
            } else {
                translationApplying = nil
            }
            if let (applying, reference) = translationApplying,
               mediatorSpeed > min(querentSpeed, targetSpeed),
               let path = try perfectionPath(
                   kind: .translation,
                   aspect: applying,
                   moving: mediator,
                   reference: reference,
                   mediator: mediator,
                   after: snapshot.utcDate
               ),
               try interruptions(
                   before: path.exactDate,
                   bodies: [mediator, reference],
                   after: snapshot.utcDate
               ).isEmpty
            {
                paths.append(path)
            }

            if first.phase == .applying, second.phase == .applying,
               mediatorSpeed < querentSpeed, mediatorSpeed < targetSpeed,
               let firstPath = try perfectionPath(
                   kind: .collection,
                   aspect: first,
                   moving: querentRuler,
                   reference: mediator,
                   mediator: mediator,
                   after: snapshot.utcDate
               ),
               let secondPath = try perfectionPath(
                   kind: .collection,
                   aspect: second,
                   moving: targetRuler,
                   reference: mediator,
                   mediator: mediator,
                   after: snapshot.utcDate
               )
            {
                let completion = firstPath.exactDate > secondPath.exactDate ? firstPath : secondPath
                if try interruptions(
                    before: completion.exactDate,
                    bodies: [querentRuler, targetRuler, mediator],
                    after: snapshot.utcDate
                ).isEmpty {
                    paths.append(completion)
                }
            }
        }
        return paths
    }

    private func perfectionPath(
        kind: HoraryPerfectionKind,
        aspect: ChartAspect,
        moving: CelestialBody,
        reference: CelestialBody,
        mediator: CelestialBody?,
        after date: Date
    ) throws -> HoraryPerfectionPath? {
        guard aspect.phase == .applying || aspect.phase == .exact else { return nil }
        let exactDate = aspect.phase == .exact
            ? date
            : try nextExactAspectDate(moving: moving, reference: reference, kind: aspect.kind, after: date)
        return HoraryPerfectionPath(
            kind: kind,
            exactDate: exactDate,
            aspectKind: aspect.kind,
            distanceDegrees: aspect.orbDegrees,
            mediator: mediator
        )
    }

    private func interruptions(
        before deadline: Date,
        bodies: [CelestialBody],
        after start: Date
    ) throws -> [HoraryPerfectionInterruption] {
        var result: [HoraryPerfectionInterruption] = []
        for body in Set(bodies) {
            if let ingress = try nextSignIngress(for: body, after: start, before: deadline) {
                result.append(.init(kind: .signChange, date: ingress, body: body))
            }
            if let station = try nextStation(for: body, after: start, before: deadline) {
                result.append(.init(kind: .refranation, date: station.date, body: body))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    private func prohibition(
        of receiving: CelestialBody,
        before deadline: Date,
        excluding: Set<CelestialBody>,
        aspects: [ChartAspect],
        after start: Date
    ) throws -> HoraryPerfectionInterruption? {
        var candidates: [HoraryPerfectionInterruption] = []
        for body in HoraryEngine.traditionalPlanets where !excluding.contains(body) {
            guard let candidate = aspect(between: body, and: receiving, in: aspects),
                  candidate.phase == .applying
            else { continue }
            let exact = try nextExactAspectDate(
                moving: body,
                reference: receiving,
                kind: candidate.kind,
                after: start
            )
            if exact < deadline,
               try interruptions(before: exact, bodies: [body, receiving], after: start).isEmpty
            {
                candidates.append(.init(kind: .prohibition, date: exact, body: body))
            }
        }
        return candidates.min { $0.date < $1.date }
    }

    private func aspect(
        between first: CelestialBody,
        and second: CelestialBody,
        in aspects: [ChartAspect]
    ) -> ChartAspect? {
        aspects.first { Set([$0.firstID, $0.secondID]) == Set([first.id, second.id]) }
    }

}

public struct ElectionTimingEngine: Sendable {
    private let calculator: SwissEphemerisCalculator

    public init(calculator: SwissEphemerisCalculator) {
        self.calculator = calculator
    }

    public func search(
        _ request: ElectionTimingRequest,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> [ElectionTimingCandidate] {
        guard request.endDate > request.startDate else {
            throw ElectionTimingError.invalidRange
        }
        let maximum: TimeInterval = switch request.precision {
        case .day: 90 * 86_400
        case .week: 184 * 86_400
        case .month: 367 * 86_400
        }
        guard request.endDate.timeIntervalSince(request.startDate) <= maximum + 86_400 else {
            throw ElectionTimingError.rangeTooLong
        }

        var calendar = Calendar(identifier: request.calendarIdentifier)
        calendar.timeZone = request.timeZone
        var samples: [(Date, ChartSnapshot, HoraryAnalysis)] = []
        let step: TimeInterval = 6 * 3_600
        let count = max(
            1,
            Int(ceil(request.endDate.timeIntervalSince(request.startDate) / step))
        )
        samples.reserveCapacity(count)
        for index in 0 ... count {
            try Task.checkCancellation()
            let date = min(
                request.endDate,
                request.startDate.addingTimeInterval(Double(index) * step)
            )
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: request.location),
                configuration: .horary
            )
            let analysis = HoraryEngine.timingAnalysis(
                snapshot: snapshot,
                targetHouse: request.targetHouse,
                relatedHouses: request.relatedHouses
            )
            samples.append((date, snapshot, analysis))
            progress(Double(index + 1) / Double(count + 1) * 0.78)
            if date >= request.endDate { break }
        }
        guard !samples.isEmpty else { throw ElectionTimingError.noCandidates }

        let dailyBest = Dictionary(grouping: samples) {
            calendar.startOfDay(for: $0.0)
        }
        .compactMapValues { values in values.max { $0.2.score < $1.2.score } }

        let peakDays = dailyBest.values
            .sorted { $0.2.score > $1.2.score }
            .prefix(12)
        var refined = dailyBest
        for (index, value) in peakDays.enumerated() {
            try Task.checkCancellation()
            let start = max(request.startDate, value.0.addingTimeInterval(-6 * 3_600))
            let end = min(request.endDate, value.0.addingTimeInterval(6 * 3_600))
            var cursor = start
            while cursor <= end {
                let snapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: cursor, location: request.location),
                    configuration: .horary
                )
                let analysis = HoraryEngine.timingAnalysis(
                    snapshot: snapshot,
                    targetHouse: request.targetHouse,
                    relatedHouses: request.relatedHouses
                )
                let day = calendar.startOfDay(for: cursor)
                if refined[day] == nil || analysis.score > refined[day]!.2.score {
                    refined[day] = (cursor, snapshot, analysis)
                }
                cursor = calendar.date(byAdding: .hour, value: 1, to: cursor)
                    ?? cursor.addingTimeInterval(3_600)
            }
            progress(0.78 + Double(index + 1) / Double(max(1, peakDays.count)) * 0.2)
        }

        let grouped = groupedCandidates(
            dailyBest: refined,
            request: request,
            calendar: calendar
        )
        progress(1)
        return Array(grouped.sorted { $0.score > $1.score }.prefix(3))
    }

    private func groupedCandidates(
        dailyBest: [Date: (Date, ChartSnapshot, HoraryAnalysis)],
        request: ElectionTimingRequest,
        calendar: Calendar
    ) -> [ElectionTimingCandidate] {
        switch request.precision {
        case .day:
            return dailyBest.map { day, value in
                let end = calendar.date(byAdding: .day, value: 1, to: day)
                    ?? day.addingTimeInterval(86_400)
                return ElectionTimingCandidate(
                    id: "day-\(day.timeIntervalSince1970)",
                    interval: DateInterval(
                        start: max(day, request.startDate),
                        end: min(end, request.endDate)
                    ),
                    peakDate: value.0,
                    score: value.2.score,
                    snapshot: value.1,
                    analysis: value.2
                )
            }
        case .week, .month:
            let groups = Dictionary(grouping: dailyBest) { day, _ in
                periodStart(for: day, precision: request.precision, calendar: calendar)
            }
            return groups.compactMap { period, values in
                guard let best = values.max(by: { $0.value.2.score < $1.value.2.score }) else {
                    return nil
                }
                let component: Calendar.Component = request.precision == .week ? .weekOfYear : .month
                let rawEnd = calendar.date(byAdding: component, value: 1, to: period)
                    ?? period.addingTimeInterval(
                        request.precision == .week ? 7 * 86_400 : 31 * 86_400
                    )
                let sortedScores = values.map(\.value.2.score).sorted(by: >)
                let robustCount = min(3, sortedScores.count)
                let robustScore = sortedScores.prefix(robustCount).reduce(0, +)
                    / Double(max(1, robustCount))
                return ElectionTimingCandidate(
                    id: "\(request.precision.rawValue)-\(period.timeIntervalSince1970)",
                    interval: DateInterval(
                        start: max(period, request.startDate),
                        end: min(rawEnd, request.endDate)
                    ),
                    peakDate: best.value.0,
                    score: robustScore,
                    snapshot: best.value.1,
                    analysis: best.value.2
                )
            }
        }
    }

    private func periodStart(
        for date: Date,
        precision: TimingPrecision,
        calendar: Calendar
    ) -> Date {
        switch precision {
        case .day:
            calendar.startOfDay(for: date)
        case .week:
            calendar.dateInterval(of: .weekOfYear, for: date)?.start
                ?? calendar.startOfDay(for: date)
        case .month:
            calendar.dateInterval(of: .month, for: date)?.start
                ?? calendar.startOfDay(for: date)
        }
    }
}

// MARK: - Significators (assigning named elements of a question to houses)

/// A named element of the question bound to the house that represents it.
/// Example: "我" → house 1, "吃饭" → house 5, "家" → house 4, "单位" → house 6.
public struct HorarySignificator: Sendable, Equatable {
    public let label: String
    public let house: Int

    public init(label: String, house: Int) {
        self.label = label
        self.house = house
    }
}

/// Per-element assessment: the house ruler, its condition, and how it relates
/// to the querent's ruler at the question moment.
public struct HorarySignificatorAssessment: Sendable, Equatable, Identifiable, Codable {
    public let label: String
    public let house: Int
    public let ruler: CelestialBody
    public let planet: HoraryPlanetAssessment
    public let relationship: ChartAspect?
    public let score: Double

    public var id: String { "\(label)-\(house)" }

    public init(
        label: String,
        house: Int,
        ruler: CelestialBody,
        planet: HoraryPlanetAssessment,
        relationship: ChartAspect?,
        score: Double
    ) {
        self.label = label
        self.house = house
        self.ruler = ruler
        self.planet = planet
        self.relationship = relationship
        self.score = score
    }
}

extension HoraryEngine {
    /// Assesses each named element of the question. The querent's house
    /// defaults to the first house, matching the fixed significator of "me".
    public static func assessSignificators(
        _ significators: [HorarySignificator],
        snapshot: ChartSnapshot,
        querentHouse: Int = 1
    ) -> [HorarySignificatorAssessment] {
        let querentRuler = ruler(ofHouse: querentHouse, in: snapshot)
        return significators.map { element in
            let ruler = ruler(ofHouse: element.house, in: snapshot)
            let planet = assess(ruler, in: snapshot)
            let relationship = snapshot.aspects.first { aspect in
                Set([aspect.firstID, aspect.secondID]) == Set([querentRuler.id, ruler.id])
            }
            var score = planet.score
            if let relationship {
                score += relationship.kind.supportive ? 6 : relationship.kind.challenging ? -6 : 0
                score += relationship.strength * 4
            }
            return HorarySignificatorAssessment(
                label: element.label,
                house: element.house,
                ruler: ruler,
                planet: planet,
                relationship: relationship,
                score: score
            )
        }
    }
}
