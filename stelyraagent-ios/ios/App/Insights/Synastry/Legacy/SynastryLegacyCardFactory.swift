import AstroCore
import Foundation

enum SynastryPersonRole: String, Codable, Equatable, Sendable {
    case personA
    case personB
}

enum SynastryOverlayDirection: String, Codable, Equatable, Sendable {
    case personAToB
    case personBToA
}

enum SynastryThemeID: String, CaseIterable, Codable, Equatable, Sendable {
    case balanced
    case supportive
    case growthThroughFriction = "growth-through-friction"
    case intense
    case mutualFlow = "mutual-flow"
    case asymmetric
    case mixed
    case flow
    case friction
    case quiet
    case pressure
    case received
    case mutualReception = "mutual-reception"
    case oneWayReception = "one-way-reception"
    case fortifiedSupport = "fortified-support"
    case impairedPressure = "impaired-pressure"
    case mixedTestimony = "mixed-testimony"
    case neutral
    case mentalActivation = "mental-activation"
    case emotionalActivation = "emotional-activation"
    case relationalActivation = "relational-activation"
    case practicalActivation = "practical-activation"
    case mixedActivation = "mixed-activation"
}

struct SynastryPerspectivePlan: Equatable, Sendable {
    let person: SynastryPersonRole
    let otherPerson: SynastryPersonRole
    let themeID: SynastryThemeID
    let evidence: [SynastryFact]
}

struct SynastryAspectFact: Equatable, Sendable {
    let factID: String
    let firstBody: CelestialBody
    let secondBody: CelestialBody
    let kind: AspectKind
    let orbDegrees: Double
    let phase: AspectPhase
    let strength: Double
    let firstLongitude: Double
    let secondLongitude: Double
    let firstBodyInSecondHouse: Int
    let secondBodyInFirstHouse: Int
    let classicalReception: CrossChartReceptionAssessment?
}

struct SynastryOverlayFact: Equatable, Sendable {
    let factID: String
    let direction: SynastryOverlayDirection
    let body: CelestialBody
    let longitude: Double
    let signIndex: Int
    let degreeInSign: Double
    let receivingHouse: Int
}

struct SynastryPlanetConditionFact: Equatable, Sendable {
    let factID: String
    let person: SynastryPersonRole
    let assessment: HoraryPlanetAssessment
}

struct SynastryFactBundle: Equatable, Sendable {
    let scopeID: String
    let preset: String
    let first: ChartSnapshot
    let second: ChartSnapshot
    let aspects: [SynastryAspectFact]
    let overlays: [SynastryOverlayFact]
    let planetConditions: [SynastryPlanetConditionFact]
}

enum SynastryFact: Equatable, Sendable {
    case aspect(SynastryAspectFact)
    case overlay(SynastryOverlayFact)
    case planetCondition(SynastryPlanetConditionFact)

    var factID: String {
        switch self {
        case let .aspect(value): value.factID
        case let .overlay(value): value.factID
        case let .planetCondition(value): value.factID
        }
    }
}

struct SynastryCardEvidencePlan: Equatable, Sendable {
    let cardID: String
    let preset: String
    let scopeID: String
    let themeID: SynastryThemeID
    let evidence: [SynastryFact]
    let overviewDimensions: [SynastryOverviewDimension]
    let evidenceRoles: [String: String]
    let perspectives: [SynastryPerspectivePlan]

    var sourceFactIDs: [String] { evidence.map(\.factID) }
    var copyKey: String { "\(preset).synastry.\(cardID).\(themeID.rawValue)" }
}

struct SynastryContentPlan: Equatable, Sendable {
    let scopeID: String
    let preset: String
    let firstName: String
    let secondName: String
    let bundle: SynastryFactBundle
    let cards: [SynastryCardEvidencePlan]

    func card(_ id: String) -> SynastryCardEvidencePlan? {
        cards.first { $0.cardID == id }
    }
}

enum SynastryFactBundleBuilder {
    static func build(comparison: SynastryComparison, preset: String) -> SynastryFactBundle {
        let scopeID = makeScopeID(comparison: comparison, preset: preset)
        let receptions = Dictionary(
            uniqueKeysWithValues: (comparison.classicalAssessment?.crossChartReceptions ?? []).map {
                (receptionKey($0.firstBody, kind: $0.aspectKind, $0.secondBody), $0)
            }
        )
        let aspects = comparison.crossAspects.map { aspect in
            let firstBody = CelestialBody(rawValue: aspect.firstID)!
            let secondBody = CelestialBody(rawValue: aspect.secondID)!
            return SynastryAspectFact(
                factID: "synastry.\(scopeID).aspect.personA.\(aspect.firstID).\(aspect.kind.rawValue).personB.\(aspect.secondID)",
                firstBody: firstBody,
                secondBody: secondBody,
                kind: aspect.kind,
                orbDegrees: aspect.orbDegrees,
                phase: aspect.phase,
                strength: aspect.strength,
                firstLongitude: aspect.firstLongitude,
                secondLongitude: aspect.secondLongitude,
                firstBodyInSecondHouse: comparison.second.house(containing: aspect.firstLongitude),
                secondBodyInFirstHouse: comparison.first.house(containing: aspect.secondLongitude),
                classicalReception: receptions[receptionKey(firstBody, kind: aspect.kind, secondBody)]
            )
        }.sorted(by: aspectOrder)

        let overlays = overlayFacts(
            scopeID: scopeID,
            source: comparison.first,
            receiving: comparison.second,
            direction: .personAToB
        ) + overlayFacts(
            scopeID: scopeID,
            source: comparison.second,
            receiving: comparison.first,
            direction: .personBToA
        )

        var conditions: [SynastryPlanetConditionFact] = []
        if let classical = comparison.classicalAssessment {
            conditions += conditionFacts(scopeID: scopeID, assessments: classical.firstPlanets, person: .personA)
            conditions += conditionFacts(scopeID: scopeID, assessments: classical.secondPlanets, person: .personB)
        }
        return SynastryFactBundle(
            scopeID: scopeID,
            preset: preset,
            first: comparison.first,
            second: comparison.second,
            aspects: aspects,
            overlays: overlays.sorted { $0.factID < $1.factID },
            planetConditions: conditions.sorted { $0.factID < $1.factID }
        )
    }

    private static func makeScopeID(comparison: SynastryComparison, preset: String) -> String {
        let raw = [
            "synastry-v2", preset,
            String(format: "%.8f", comparison.first.julianDayUT),
            String(format: "%.5f", comparison.first.location.latitudeDegrees),
            String(format: "%.5f", comparison.first.location.longitudeDegrees),
            String(format: "%.8f", comparison.second.julianDayUT),
            String(format: "%.5f", comparison.second.location.latitudeDegrees),
            String(format: "%.5f", comparison.second.location.longitudeDegrees),
        ].joined(separator: "|")
        return String(SHA256Digest.hash(Data(raw.utf8)).hex.prefix(20))
    }

    private static func receptionKey(_ first: CelestialBody, kind: AspectKind, _ second: CelestialBody) -> String {
        "\(first.rawValue)|\(kind.rawValue)|\(second.rawValue)"
    }

    private static func aspectOrder(_ lhs: SynastryAspectFact, _ rhs: SynastryAspectFact) -> Bool {
        if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
        return lhs.factID < rhs.factID
    }

    private static func overlayFacts(
        scopeID: String,
        source: ChartSnapshot,
        receiving: ChartSnapshot,
        direction: SynastryOverlayDirection
    ) -> [SynastryOverlayFact] {
        source.points.map { point in
            SynastryOverlayFact(
                factID: "synastry.\(scopeID).overlay.\(direction.rawValue).\(point.body.rawValue)",
                direction: direction,
                body: point.body,
                longitude: point.longitudeDegrees,
                signIndex: point.signIndex,
                degreeInSign: point.degreeInSign,
                receivingHouse: receiving.house(containing: point.longitudeDegrees)
            )
        }
    }

    private static func conditionFacts(
        scopeID: String,
        assessments: [HoraryPlanetAssessment],
        person: SynastryPersonRole
    ) -> [SynastryPlanetConditionFact] {
        assessments.map {
            SynastryPlanetConditionFact(
                factID: "synastry.\(scopeID).condition.\(person.rawValue).\($0.body.rawValue)",
                person: person,
                assessment: $0
            )
        }
    }
}

enum SynastryContentPlanner {
    static let cardIDs = [
        "relationship-overview", "perspectives", "emotional-connection", "communication",
        "chemistry", "commitment", "house-overlays", "key-inter-aspects",
    ]

    static func plan(
        _ bundle: SynastryFactBundle,
        firstName: String = "Person A",
        secondName: String = "Person B"
    ) -> SynastryContentPlan {
        let modern = bundle.preset != CalculationPreset.classical.rawValue
        let moon = involving([.moon], bundle.aspects)
        let communication = involving([.mercury], bundle.aspects)
        let chemistry = involving([.venus, .mars, .pluto], bundle.aspects)
        let commitment = involving([.saturn, .jupiter], bundle.aspects)
        let emotionalSelection = emotionalEvidence(moon, bundle: bundle)
        let communicationSelection = communicationEvidence(communication, bundle: bundle)
        let chemistrySelection = chemistryEvidence(chemistry, modern: modern, bundle: bundle)
        let commitmentSelection = commitmentEvidence(commitment, bundle: bundle)
        let perspectiveSelection = perspectiveEvidence(bundle)
        let overlaySelection = importantOverlays(bundle)
        let domainFactIDs = Set(
                emotionalSelection.map(\.fact.factID)
                + communicationSelection.map(\.factID)
                + chemistrySelection.map(\.fact.factID)
                + commitmentSelection.map(\.fact.factID)
        )
        let cards = [
            make(
                "relationship-overview",
                bundle,
                modern ? modernOverview(bundle.aspects) : classicalOverview(bundle),
                aspects(bundle.aspects, count: 5) + conditionEvidence(bundle, count: 2),
                overviewDimensions: overviewDimensions(bundle)
            ),
            make(
                "perspectives", bundle, perspectiveTheme(bundle),
                unique(perspectiveSelection.flatMap(\.evidence)),
                perspectives: perspectiveSelection
            ),
            make(
                "emotional-connection", bundle, domainTheme(moon, quiet: .quiet),
                emotionalSelection.map(\.fact),
                evidenceRoles: Dictionary(uniqueKeysWithValues: emotionalSelection.map { ($0.fact.factID, $0.role) })
            ),
            make(
                "communication", bundle, domainTheme(communication, quiet: .quiet),
                communicationSelection
            ),
            make(
                "chemistry", bundle, domainTheme(chemistry, quiet: .quiet),
                chemistrySelection.map(\.fact),
                evidenceRoles: Dictionary(uniqueKeysWithValues: chemistrySelection.map { ($0.fact.factID, $0.role) })
            ),
            make(
                "commitment", bundle, classicalCommitmentTheme(bundle, aspects: commitment),
                commitmentSelection.map(\.fact) + conditionEvidence(bundle, count: 2),
                evidenceRoles: Dictionary(uniqueKeysWithValues: commitmentSelection.map { ($0.fact.factID, $0.role) })
            ),
            make("house-overlays", bundle, .mixed, overlaySelection.map(SynastryFact.overlay)),
            make(
                "key-inter-aspects",
                bundle,
                domainTheme(Array(bundle.aspects.prefix(6)), quiet: .quiet),
                keyInterAspectEvidence(bundle.aspects, excluding: domainFactIDs)
            ),
        ]
        return SynastryContentPlan(
            scopeID: bundle.scopeID,
            preset: bundle.preset,
            firstName: firstName,
            secondName: secondName,
            bundle: bundle,
            cards: cards
        )
    }

    private static func make(
        _ id: String,
        _ bundle: SynastryFactBundle,
        _ theme: SynastryThemeID,
        _ evidence: [SynastryFact],
        overviewDimensions: [SynastryOverviewDimension] = [],
        evidenceRoles: [String: String] = [:],
        perspectives: [SynastryPerspectivePlan] = []
    ) -> SynastryCardEvidencePlan {
        SynastryCardEvidencePlan(
            cardID: id,
            preset: bundle.preset,
            scopeID: bundle.scopeID,
            themeID: theme,
            evidence: evidence,
            overviewDimensions: overviewDimensions,
            evidenceRoles: evidenceRoles,
            perspectives: perspectives
        )
    }

    private struct RoleFact {
        let role: String
        let fact: SynastryFact
    }

    private static func emotionalEvidence(
        _ values: [SynastryAspectFact],
        bundle: SynastryFactBundle
    ) -> [RoleFact] {
        var result: [RoleFact] = []
        if let flow = values.first(where: { $0.kind.supportive }) {
            result.append(RoleFact(role: "flow", fact: .aspect(flow)))
        }
        if let difference = values.first(where: { $0.kind.challenging }) {
            result.append(RoleFact(role: "difference", fact: .aspect(difference)))
        }
        let usedFactIDs = { Set(result.map(\.fact.factID)) }
        let moonOverlays = rankedOverlays(bundle.overlays.filter { $0.body == .moon }, count: 2)

        if !result.contains(where: { $0.role == "flow" }),
           let flowOverlay = moonOverlays.first(where: {
               [1, 4, 5, 7, 11].contains($0.receivingHouse) && !usedFactIDs().contains($0.factID)
           }) ?? moonOverlays.first(where: { !usedFactIDs().contains($0.factID) })
        {
            result.append(RoleFact(role: "flow", fact: .overlay(flowOverlay)))
        }
        if !result.contains(where: { $0.role == "difference" }),
           let differenceOverlay = moonOverlays.first(where: {
               [2, 3, 6, 8, 9, 10, 12].contains($0.receivingHouse) && !usedFactIDs().contains($0.factID)
           }) ?? moonOverlays.first(where: { !usedFactIDs().contains($0.factID) })
        {
            result.append(RoleFact(role: "difference", fact: .overlay(differenceOverlay)))
        }
        return result
    }

    private static func communicationEvidence(
        _ values: [SynastryAspectFact],
        bundle: SynastryFactBundle
    ) -> [SynastryFact] {
        let contacts = aspects(values, count: 3)
        if !contacts.isEmpty { return contacts }
        return rankedOverlays(bundle.overlays.filter { $0.body == .mercury }, count: 3)
            .map(SynastryFact.overlay)
    }

    private static func chemistryEvidence(
        _ values: [SynastryAspectFact],
        modern: Bool,
        bundle: SynastryFactBundle
    ) -> [RoleFact] {
        guard !values.isEmpty else {
            let allowedBodies: Set<CelestialBody> = modern ? [.venus, .mars, .pluto] : [.venus, .mars]
            let overlays = rankedOverlays(bundle.overlays.filter { allowedBodies.contains($0.body) }, count: 2)
            return overlays.enumerated().map { index, overlay in
                RoleFact(role: index == 0 ? "attraction" : "intensity", fact: .overlay(overlay))
            }
        }
        let attraction = values.first(where: {
            $0.kind.supportive && ([.venus, .mars].contains($0.firstBody) || [.venus, .mars].contains($0.secondBody))
        }) ?? values[0]
        let intensityBodies: Set<CelestialBody> = modern ? [.pluto, .mars] : [.mars]
        let intensity = values.first(where: {
            $0.factID != attraction.factID
                && (intensityBodies.contains($0.firstBody) || intensityBodies.contains($0.secondBody))
                && ($0.kind.challenging || $0.kind == .conjunction)
        }) ?? values.first(where: { $0.factID != attraction.factID })
        return [
            RoleFact(role: "attraction", fact: .aspect(attraction)),
            intensity.map { RoleFact(role: "intensity", fact: .aspect($0)) },
        ].compactMap { $0 }
    }

    private static func commitmentEvidence(
        _ values: [SynastryAspectFact],
        bundle: SynastryFactBundle
    ) -> [RoleFact] {
        let stability = values.first(where: {
            ($0.firstBody == .saturn || $0.secondBody == .saturn)
                && ($0.kind.supportive || $0.kind == .conjunction || $0.classicalReception != nil)
        }) ?? values.first(where: { $0.firstBody == .saturn || $0.secondBody == .saturn })
        let growth = values.first(where: {
            $0.factID != stability?.factID
                && ($0.firstBody == .jupiter || $0.secondBody == .jupiter)
                && ($0.kind.supportive || $0.kind == .conjunction)
        }) ?? values.first(where: {
            $0.factID != stability?.factID && ($0.firstBody == .jupiter || $0.secondBody == .jupiter)
        })
        let stabilityFact = stability.map(SynastryFact.aspect)
            ?? rankedOverlays(bundle.overlays.filter { $0.body == .saturn }, count: 1)
                .first.map(SynastryFact.overlay)
        let growthFact = growth.map(SynastryFact.aspect)
            ?? rankedOverlays(bundle.overlays.filter { $0.body == .jupiter }, count: 1)
                .first.map(SynastryFact.overlay)
        return [
            stabilityFact.map { RoleFact(role: "stability", fact: $0) },
            growthFact.map { RoleFact(role: "growth", fact: $0) },
        ].compactMap { $0 }
    }

    private static func perspectiveEvidence(_ bundle: SynastryFactBundle) -> [SynastryPerspectivePlan] {
        let first = rankedOverlays(bundle.overlays.filter { $0.direction == .personBToA }, count: 4)
        let second = rankedOverlays(bundle.overlays.filter { $0.direction == .personAToB }, count: 4)
        return [
            SynastryPerspectivePlan(
                person: .personA,
                otherPerson: .personB,
                themeID: perspectiveDirectionTheme(first),
                evidence: first.map(SynastryFact.overlay)
            ),
            SynastryPerspectivePlan(
                person: .personB,
                otherPerson: .personA,
                themeID: perspectiveDirectionTheme(second),
                evidence: second.map(SynastryFact.overlay)
            ),
        ]
    }

    private static func perspectiveDirectionTheme(_ overlays: [SynastryOverlayFact]) -> SynastryThemeID {
        var scores: [SynastryThemeID: Int] = [:]
        for overlay in overlays {
            let theme: SynastryThemeID
            switch overlay.receivingHouse {
            case 3, 9, 11: theme = .mentalActivation
            case 4, 8, 12: theme = .emotionalActivation
            case 1, 5, 7: theme = .relationalActivation
            case 2, 6, 10: theme = .practicalActivation
            default: theme = .mixedActivation
            }
            scores[theme, default: 0] += overlayRelevance(overlay)
        }
        let ordered = scores.sorted {
            if $0.value != $1.value { return $0.value > $1.value }
            return $0.key.rawValue < $1.key.rawValue
        }
        guard let first = ordered.first else { return .mixedActivation }
        if ordered.count > 1, first.value == ordered[1].value { return .mixedActivation }
        return first.key
    }

    private static func importantOverlays(_ bundle: SynastryFactBundle) -> [SynastryOverlayFact] {
        let first = rankedOverlays(bundle.overlays.filter { $0.direction == .personAToB }, count: 2)
        let second = rankedOverlays(bundle.overlays.filter { $0.direction == .personBToA }, count: 2)
        return (first + second).sorted {
            let left = overlayRelevance($0)
            let right = overlayRelevance($1)
            if left != right { return left > right }
            return $0.factID < $1.factID
        }
    }

    private static func rankedOverlays(_ values: [SynastryOverlayFact], count: Int) -> [SynastryOverlayFact] {
        values.sorted {
            let left = overlayRelevance($0)
            let right = overlayRelevance($1)
            if left != right { return left > right }
            return $0.factID < $1.factID
        }.prefix(count).map { $0 }
    }

    private static func overlayRelevance(_ value: SynastryOverlayFact) -> Int {
        let bodyScore: Int = switch value.body {
        case .sun, .moon: 9
        case .venus, .mars: 8
        case .mercury, .jupiter, .saturn: 7
        case .pluto: 6
        case .uranus, .neptune: 5
        case .trueNode, .lilith, .partOfFortune, .juno: 4
        }
        let houseScore = [1, 4, 7, 10].contains(value.receivingHouse) ? 6
            : ([3, 5, 8, 11].contains(value.receivingHouse) ? 4 : 2)
        return bodyScore + houseScore
    }

    static func overlayRelevanceForPresentation(_ value: SynastryOverlayFact) -> Int {
        overlayRelevance(value)
    }

    private static func unique(_ facts: [SynastryFact]) -> [SynastryFact] {
        var seen = Set<String>()
        return facts.filter { seen.insert($0.factID).inserted }
    }

    private static func overviewDimensions(_ bundle: SynastryFactBundle) -> [SynastryOverviewDimension] {
        let communication = involving([.mercury], bundle.aspects)
        let emotion = involving([.moon], bundle.aspects)
        let chemistry = involving([.venus, .mars, .pluto], bundle.aspects)
        return [
            SynastryOverviewDimension(
                id: .communication,
                state: dimensionState(domainTheme(communication, quiet: .quiet), dimension: .communication),
                sourceFactIDs: communication.prefix(3).map(\.factID)
            ),
            SynastryOverviewDimension(
                id: .emotionalPace,
                state: dimensionState(domainTheme(emotion, quiet: .quiet), dimension: .emotionalPace),
                sourceFactIDs: emotion.prefix(3).map(\.factID)
            ),
            SynastryOverviewDimension(
                id: .chemistry,
                state: dimensionState(domainTheme(chemistry, quiet: .quiet), dimension: .chemistry),
                sourceFactIDs: chemistry.prefix(3).map(\.factID)
            ),
        ]
    }

    private static func dimensionState(
        _ theme: SynastryThemeID,
        dimension: SynastryOverviewDimensionID
    ) -> SynastryOverviewDimensionState {
        switch (dimension, theme) {
        case (_, .quiet): .quiet
        case (.communication, .flow): .strong
        case (.communication, .friction): .active
        case (.emotionalPace, .flow): .steady
        case (.emotionalPace, .friction): .different
        case (.chemistry, .flow), (.chemistry, .friction): .active
        default: .mixed
        }
    }

    private static func involving(_ bodies: Set<CelestialBody>, _ values: [SynastryAspectFact]) -> [SynastryAspectFact] {
        values.filter { bodies.contains($0.firstBody) || bodies.contains($0.secondBody) }
    }

    private static func aspects(_ values: [SynastryAspectFact], count: Int) -> [SynastryFact] {
        values.prefix(count).map(SynastryFact.aspect)
    }

    private static func keyInterAspectEvidence(
        _ values: [SynastryAspectFact],
        excluding usedFactIDs: Set<String>
    ) -> [SynastryFact] {
        var selected = values.filter { !usedFactIDs.contains($0.factID) }.prefix(6).map(SynastryFact.aspect)
        if selected.count < min(3, values.count) {
            let selectedIDs = Set(selected.map(\.factID))
            selected.append(contentsOf: values
                .filter { !selectedIDs.contains($0.factID) }
                .prefix(min(3, values.count) - selected.count)
                .map(SynastryFact.aspect))
        }
        return selected
    }

    private static func overlayEvidence(_ bundle: SynastryFactBundle, count: Int) -> [SynastryFact] {
        bundle.overlays.sorted {
            if $0.receivingHouse != $1.receivingHouse { return $0.receivingHouse < $1.receivingHouse }
            return $0.factID < $1.factID
        }.prefix(count).map(SynastryFact.overlay)
    }

    private static func conditionEvidence(_ bundle: SynastryFactBundle, count: Int) -> [SynastryFact] {
        bundle.planetConditions.sorted {
            if abs($0.assessment.score) != abs($1.assessment.score) { return abs($0.assessment.score) > abs($1.assessment.score) }
            return $0.factID < $1.factID
        }.prefix(count).map(SynastryFact.planetCondition)
    }

    private static func modernOverview(_ values: [SynastryAspectFact]) -> SynastryThemeID {
        guard !values.isEmpty else { return .balanced }
        let supportive = values.filter { $0.kind.supportive }.reduce(0) { $0 + $1.strength }
        let challenging = values.filter { $0.kind.challenging }.reduce(0) { $0 + $1.strength }
        let conjunction = values.filter { $0.kind == .conjunction }.reduce(0) { $0 + $1.strength }
        if conjunction > supportive + challenging { return .intense }
        if supportive > challenging * 1.35 { return .supportive }
        if challenging > supportive * 1.15 { return .growthThroughFriction }
        return .balanced
    }

    private static func classicalOverview(_ bundle: SynastryFactBundle) -> SynastryThemeID {
        let receptions = bundle.aspects.compactMap(\.classicalReception)
        let mutual = receptions.contains { $0.receptionFromFirst.isPresent && $0.receptionFromSecond.isPresent }
        if mutual { return .mutualReception }
        if receptions.contains(where: { $0.receptionFromFirst.isPresent || $0.receptionFromSecond.isPresent }) { return .oneWayReception }
        let score = bundle.planetConditions.reduce(0) { $0 + $1.assessment.score }
        if score >= 8 { return .fortifiedSupport }
        if score <= -8 { return .impairedPressure }
        return bundle.aspects.isEmpty ? .neutral : .mixedTestimony
    }

    private static func perspectiveTheme(_ bundle: SynastryFactBundle) -> SynastryThemeID {
        let a = bundle.overlays.filter { $0.direction == .personAToB && [1, 4, 7, 10].contains($0.receivingHouse) }.count
        let b = bundle.overlays.filter { $0.direction == .personBToA && [1, 4, 7, 10].contains($0.receivingHouse) }.count
        if abs(a - b) >= 2 { return .asymmetric }
        return a + b > 0 ? .mutualFlow : .mixed
    }

    private static func domainTheme(_ values: [SynastryAspectFact], quiet: SynastryThemeID) -> SynastryThemeID {
        guard !values.isEmpty else { return quiet }
        let supportive = values.filter { $0.kind.supportive }.reduce(0) { $0 + $1.strength }
        let challenging = values.filter { $0.kind.challenging }.reduce(0) { $0 + $1.strength }
        if supportive > challenging * 1.25 { return .flow }
        if challenging > supportive * 1.15 { return .friction }
        return .mixed
    }

    private static func classicalCommitmentTheme(_ bundle: SynastryFactBundle, aspects: [SynastryAspectFact]) -> SynastryThemeID {
        guard bundle.preset == CalculationPreset.classical.rawValue else { return domainTheme(aspects, quiet: .quiet) }
        let receptions = aspects.compactMap(\.classicalReception)
        if receptions.contains(where: { $0.receptionFromFirst.isPresent || $0.receptionFromSecond.isPresent }) { return .received }
        return domainTheme(aspects, quiet: .quiet)
    }
}

enum SynastryCardContractValidator {
    static func validate(cards: [InsightCardModel], plan: SynastryContentPlan) throws {
        guard cards.map(\.id) == SynastryContentPlanner.cardIDs else {
            throw InsightFactoryError.invalidCardContract("synastry card order mismatch")
        }
        guard cards.allSatisfy({ $0.scopeID == plan.scopeID }) else {
            throw InsightFactoryError.invalidCardContract("synastry scope mismatch")
        }
        let allowed = Set(plan.bundle.aspects.map(\.factID) + plan.bundle.overlays.map(\.factID) + plan.bundle.planetConditions.map(\.factID))
        guard plan.cards.flatMap(\.sourceFactIDs).allSatisfy(allowed.contains) else {
            throw InsightFactoryError.invalidCardContract("synastry sourceFactID outside bundle")
        }
        guard let overviewPlan = plan.card("relationship-overview"),
              overviewPlan.overviewDimensions.map(\.id) == [.communication, .emotionalPace, .chemistry],
              overviewPlan.overviewDimensions.flatMap(\.sourceFactIDs).allSatisfy(allowed.contains),
              let overviewCard = cards.first(where: { $0.id == "relationship-overview" }),
              case let .bondOrbit(presentation) = overviewCard.visual,
              !presentation.firstName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !presentation.secondName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              presentation.dimensions == overviewPlan.overviewDimensions
        else {
            throw InsightFactoryError.invalidCardContract("synastry relationship overview presentation mismatch")
        }
        guard let perspectives = plan.card("perspectives"),
              perspectives.perspectives.map(\.person) == [.personA, .personB],
              perspectives.perspectives.allSatisfy({ !$0.evidence.isEmpty }),
              let perspectiveCard = cards.first(where: { $0.id == "perspectives" }),
              case let .perspectiveTabs(perspectivePresentation) = perspectiveCard.visual,
              perspectivePresentation.firstSourceFactIDs == perspectives.perspectives[0].evidence.map(\.factID),
              perspectivePresentation.secondSourceFactIDs == perspectives.perspectives[1].evidence.map(\.factID)
        else {
            throw InsightFactoryError.invalidCardContract("synastry directional perspectives mismatch")
        }
        let expectedRoles: [String: Set<String>] = [
            "emotional-connection": ["flow", "difference"],
            "chemistry": ["attraction", "intensity"],
            "commitment": ["stability", "growth"],
        ]
        for (cardID, roles) in expectedRoles {
            guard let cardPlan = plan.card(cardID),
                  Set(cardPlan.evidenceRoles.values).isSubset(of: roles),
                  Set(cardPlan.evidenceRoles.keys).isSubset(of: Set(cardPlan.sourceFactIDs))
            else {
                throw InsightFactoryError.invalidCardContract("synastry \(cardID) evidence role mismatch")
            }
        }
        if let overlays = plan.card("house-overlays") {
            let values = overlays.evidence.compactMap { fact -> SynastryOverlayFact? in
                guard case let .overlay(value) = fact else { return nil }
                return value
            }
            guard values.count <= 4,
                  Set(values.map(\.direction)) == Set([.personAToB, .personBToA])
            else {
                throw InsightFactoryError.invalidCardContract("synastry house overlays must preserve both directions")
            }
        }
        if plan.preset == CalculationPreset.classical.rawValue {
            let allowedBodies = Set(ClassicalSynastryMVPCapability.traditionalBodies)
            guard plan.bundle.first.points.allSatisfy({ allowedBodies.contains($0.body) }),
                  plan.bundle.second.points.allSatisfy({ allowedBodies.contains($0.body) }),
                  plan.bundle.aspects.allSatisfy({ allowedBodies.contains($0.firstBody) && allowedBodies.contains($0.secondBody) })
            else {
                throw InsightFactoryError.invalidCardContract("classical synastry exceeded seven-planet MVP boundary")
            }
        }
    }
}

extension InsightFactory {
    static func synastryCards(plan: SynastryContentPlan, language: AppLanguage) -> [InsightCardModel] {
        plan.cards.map { cardPlan in
            let facts = cardPlan.evidence.map {
                synastryFact(
                    $0,
                    cardID: cardPlan.cardID,
                    firstName: plan.firstName,
                    secondName: plan.secondName,
                    visualRole: cardPlan.evidenceRoles[$0.factID],
                    language: language
                )
            }
            let visual: InsightVisual
            switch cardPlan.cardID {
            case "relationship-overview":
                visual = .bondOrbit(
                    SynastryOverviewPresentation(
                        firstName: plan.firstName,
                        secondName: plan.secondName,
                        dimensions: cardPlan.overviewDimensions
                    )
                )
            case "perspectives":
                visual = .perspectiveTabs(
                    SynastryPerspectivePresentation(
                        pair: SynastryPairPresentation(firstName: plan.firstName, secondName: plan.secondName),
                        firstSourceFactIDs: cardPlan.perspectives.first?.evidence.map(\.factID) ?? [],
                        secondSourceFactIDs: cardPlan.perspectives.dropFirst().first?.evidence.map(\.factID) ?? []
                    )
                )
            case "emotional-connection": visual = .synastryConnectionGrid(.emotional)
            case "communication": visual = .synastryPathFlow
            case "chemistry": visual = .synastryChemistry
            case "commitment": visual = .synastryConnectionGrid(.commitment)
            case "house-overlays": visual = .synastryHouseOverlayRows(SynastryPairPresentation(firstName: plan.firstName, secondName: plan.secondName))
            default: visual = .synastryInterAspectRows(SynastryPairPresentation(firstName: plan.firstName, secondName: plan.secondName))
            }
            return InsightCardModel(
                id: cardPlan.cardID,
                title: synastryTitle(cardPlan.cardID, language: language),
                icon: synastryIcon(cardPlan.cardID),
                visual: visual,
                facts: facts,
                conclusion: "",
                scopeID: plan.scopeID
            )
        }
    }

    private static func synastryFact(
        _ factValue: SynastryFact,
        cardID: String,
        firstName: String,
        secondName: String,
        visualRole: String?,
        language: AppLanguage
    ) -> InsightFact {
        switch factValue {
        case let .aspect(value):
            let first = bodyName(value.firstBody, language: language)
            let second = bodyName(value.secondBody, language: language)
            let label = cardID == "key-inter-aspects"
                ? "\(firstName) \(first) \(value.kind.symbol) \(secondName) \(second)"
                : "\(first) \(value.kind.symbol) \(second)"
            return fact(
                label,
                String(format: "%.2f° · %@", value.orbDegrees, phaseLabel(value.phase, language: language)),
                tone(value.kind),
                stableID: value.factID,
                sourceFactIDs: [value.factID],
                visualRole: visualRole,
                progress: value.strength,
                symbol: value.firstBody.symbol,
                category: "\(firstName) → \(secondName)"
            )
        case let .overlay(value):
            let sourceName = value.direction == .personAToB ? firstName : secondName
            let receiverName = value.direction == .personAToB ? secondName : firstName
            let body = bodyName(value.body, language: language)
            let label = localizedTemplate(
                "dynamic.e62646a1cc",
                substitutions: [
                    "value1": sourceName,
                    "value2": body,
                    "value3": receiverName,
                    "value4": AstroTerms.house(value.receivingHouse, language: language),
                ],
                language: language
            )
            return fact(label, ConsumerCopy.lifeArea(value.receivingHouse, language: language), .transition, stableID: value.factID, sourceFactIDs: [value.factID], visualRole: visualRole, technicalDetail: "\(Zodiac.name(index: value.signIndex, language: language)) \(Zodiac.formatDegree(value.degreeInSign))", progress: Double(SynastryContentPlanner.overlayRelevanceForPresentation(value)) / 15.0, symbol: value.body.symbol, category: value.direction.rawValue)
        case let .planetCondition(value):
            return fact(bodyName(value.assessment.body, language: language), String(format: "%+.0f", value.assessment.score), value.assessment.score >= 0 ? .supportive : .challenging, stableID: value.factID, sourceFactIDs: [value.factID], technicalDetail: value.assessment.conditions.map(\.rawValue).joined(separator: " · "), symbol: value.assessment.body.symbol, category: value.person.rawValue)
        }
    }

    private static func synastryTitle(_ id: String, language: AppLanguage) -> String {
        let keys: [String: String] = [
            "relationship-overview": "insight.synastry.title.relationship-overview",
            "perspectives": "insight.synastry.title.perspectives",
            "emotional-connection": "insight.synastry.title.emotional-connection",
            "communication": "insight.synastry.title.communication",
            "chemistry": "insight.synastry.title.chemistry",
            "commitment": "insight.synastry.title.commitment",
            "house-overlays": "insight.synastry.title.house-overlays",
            "key-inter-aspects": "insight.synastry.title.key-inter-aspects",
        ]
        guard let key = keys[id] else {
            assertionFailure("Unknown synastry card title: \(id)")
            return id
        }
        return localized(key, language: language)
    }

    private static func synastryIcon(_ id: String) -> String {
        ["relationship-overview": "∞", "perspectives": "◐", "emotional-connection": "☽", "communication": "☿", "chemistry": "♀", "commitment": "♄", "house-overlays": "⌂", "key-inter-aspects": "⌗"][id] ?? "•"
    }
}

extension SynastryContentPlan: ChartContentPlanProtocol {
    var orderedCardIDs: [String] { cards.map(\.cardID) }

    func evidenceFactIDs(for cardID: String) -> [String] {
        card(cardID)?.sourceFactIDs ?? []
    }
}
