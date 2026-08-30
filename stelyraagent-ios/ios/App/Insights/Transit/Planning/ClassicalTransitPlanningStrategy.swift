import AstroCore
import Foundation

enum ClassicalTransitPlanningStrategy {
    static func plan(_ bundle: TransitFactBundle) -> TransitContentPlan {
        var ledger = EvidenceUsageLedger()
        let rangeEnd = bundle.anchorDate.addingTimeInterval(Double(bundle.rangeDays) * 86_400)
        let aspects = bundle.crossAspects
            .filter {
                $0.classicalContext != nil
                    && CelestialBody(rawValue: $0.movingID).map(HoraryEngine.traditionalPlanets.contains) == true
            }
            .sorted(by: aspectOrder)
        let windows = bundle.transitWindows
            .filter { $0.end >= bundle.anchorDate && $0.start <= rangeEnd }
            .sorted { $0.exact == $1.exact ? $0.factID < $1.factID : $0.exact < $1.exact }
        let events = bundle.planetEvents
            .filter { $0.timestamp >= bundle.anchorDate && $0.timestamp <= rangeEnd }
            .sorted { $0.timestamp == $1.timestamp ? $0.factID < $1.factID : $0.timestamp < $1.timestamp }
        let placements = bundle.planetPlacements
            .filter { HoraryEngine.traditionalPlanets.contains($0.body) && $0.classicalScore != nil }
            .sorted(by: placementOrder)
        let lifeAreas = bundle.lifeAreaScores.sorted {
            $0.normalizedScore == $1.normalizedScore ? $0.house < $1.house : $0.normalizedScore > $1.normalizedScore
        }

        let storyFacts = Array(aspects.prefix(3))
        let storyEvidence = storyFacts.enumerated().compactMap { index, fact in
            ledger.claim(.aspect(fact), mode: index == 0 ? .full : .short, role: index == 0 ? .primary : .supporting)
        }
        let storyFactIDs = Set(storyFacts.map(\.factID))
        let storyWindows = windows.compactMap { window -> TransitPlannedEvidence? in
            guard let sourceID = window.sourceAspectFactID, storyFactIDs.contains(sourceID) else { return nil }
            return ledger.claim(
                .window(window),
                mode: .technical,
                role: sourceID == storyFacts.first?.factID ? .primaryWindow : .supportingWindow
            )
        }
        let assignments = storyFacts.map {
            ClassicalTransitStorySignalAssignment(
                signalRole: ClassicalTransitThemeMapper.signalRole(for: $0),
                movingID: $0.movingID,
                sourceFactIDs: [$0.factID] + (bundle.aspectWindowFactIDs[$0.factID] ?? [])
            )
        }

        var cycleEvidence: [TransitPlannedEvidence] = []
        for (band, role) in [(TransitCycleBand.longTerm, TransitEvidenceRole.longCycle), (.current, .currentCycle), (.daily, .dailyCycle)] {
            if let window = windows.first(where: { $0.cycleBand == band && $0.start <= bundle.anchorDate && $0.end >= bundle.anchorDate }) {
                if let claim = ledger.claim(.window(window), mode: .aggregate, role: role) { cycleEvidence.append(claim) }
            } else if let aspect = aspects.first(where: { $0.cycleBand == band }),
                      let claim = ledger.claim(.aspect(aspect), mode: .aggregate, role: role)
            {
                cycleEvidence.append(claim)
            }
        }
        cycleEvidence += bundle.transitCalendar.prefix(TransitTimelineContract.defaultRangeDays).compactMap {
            ledger.claim(.calendar($0), mode: .aggregate, role: .cycleCalendar)
        }

        var timelineEvidence = windows.compactMap { ledger.claim(.window($0), mode: .technical, role: .timeline) }
        timelineEvidence += events.compactMap { ledger.claim(.planetEvent($0), mode: .technical, role: .timeline) }
        timelineEvidence += bundle.transitCalendar.compactMap { ledger.claim(.calendar($0), mode: .technical, role: .timeline) }

        var pathEvidence = placements.compactMap { ledger.claim(.placement($0), mode: .technical, role: .path) }
        pathEvidence += events.compactMap { ledger.claim(.planetEvent($0), mode: .technical, role: .pathEvent) }
        let areaEvidence = lifeAreas.compactMap { ledger.claim(.lifeArea($0), mode: .aggregate, role: .lifeArea) }
        var activeEvidence = aspects.compactMap { ledger.claim(.aspect($0), mode: .short, role: .active) }
        let activeAspectIDs = Set(activeEvidence.map(\.fact.factID))
        activeEvidence += windows.compactMap { window in
            guard let sourceID = window.sourceAspectFactID, activeAspectIDs.contains(sourceID) else { return nil }
            return ledger.claim(.window(window), mode: .technical, role: .activeWindow)
        }
        activeEvidence += events.compactMap {
            ledger.claim(.planetEvent($0), mode: .short, role: activeRole(for: $0.kind))
        }

        let cards = [
            makePlan(bundle, cardID: "current-story", evidence: storyEvidence + storyWindows, copySlot: .integratedStory, assignments: assignments),
            makePlan(bundle, cardID: "current-cycles", evidence: cycleEvidence, copySlot: .cycleChapter),
            makePlan(bundle, cardID: "transit-timeline", evidence: timelineEvidence, copySlot: nil),
            makePlan(bundle, cardID: "planet-paths", evidence: pathEvidence, copySlot: .planetPathShort),
            makePlan(bundle, cardID: "life-areas", evidence: areaEvidence, copySlot: .lifeAreaShort),
            makePlan(bundle, cardID: "active-transits", evidence: activeEvidence, copySlot: .activeTransitShort),
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

    private static func makePlan(
        _ bundle: TransitFactBundle,
        cardID: String,
        evidence: [TransitPlannedEvidence],
        copySlot: TransitCopySlot?,
        assignments: [ClassicalTransitStorySignalAssignment] = []
    ) -> CardEvidencePlan {
        CardEvidencePlan(
            scopeID: bundle.scopeID,
            preset: bundle.preset,
            cardID: cardID,
            evidence: evidence,
            primaryFactID: evidence.first { $0.role != .cycleCalendar }?.fact.factID,
            themeInputs: evidence.compactMap { themeInput($0, anchorDate: bundle.anchorDate) },
            signalRoles: [],
            integratedThemeID: nil,
            classicalSignalRoles: assignments,
            classicalIntegratedThemeID: ClassicalTransitThemeMapper.integratedThemeID(for: assignments),
            copySlot: copySlot,
            emptyState: .showInsufficientFacts
        )
    }

    private static func themeInput(_ evidence: TransitPlannedEvidence, anchorDate: Date) -> TransitThemeInput? {
        switch evidence.fact {
        case let .aspect(fact):
            return TransitThemeInput(
                signalID: "classical.transit.signal.aspect.\(fact.movingID).\(fact.kind.rawValue).\(fact.referenceID).\(fact.phase.rawValue)",
                sourceFactIDs: [fact.factID],
                movingID: fact.movingID,
                referenceID: fact.referenceID,
                aspectKind: fact.kind,
                tone: "classical",
                house: fact.natalHouse,
                roleID: evidence.role.rawValue,
                classicalThemeID: ClassicalTransitThemeMapper.themeID(for: fact)
            )
        case let .window(fact):
            return TransitThemeInput(
                signalID: "classical.transit.signal.window.\(fact.movingID).\(Int(fact.exact.timeIntervalSince1970))",
                sourceFactIDs: [fact.factID],
                movingID: fact.movingID,
                referenceID: fact.referenceID,
                aspectKind: fact.kind,
                tone: "classical",
                house: fact.natalHouse,
                roleID: evidence.role.rawValue,
                classicalThemeID: fact.returning ? .motionChange : phaseTheme(for: fact, anchorDate: anchorDate)
            )
        case let .placement(fact):
            return TransitThemeInput(
                signalID: "classical.transit.signal.placement.\(fact.body.rawValue)",
                sourceFactIDs: [fact.factID],
                movingID: fact.body.rawValue,
                referenceID: nil,
                aspectKind: nil,
                tone: "classical",
                house: fact.natalHouse,
                roleID: evidence.role.rawValue,
                classicalThemeID: ClassicalTransitThemeMapper.themeID(for: fact)
            )
        case let .lifeArea(fact):
            return TransitThemeInput(
                signalID: "classical.transit.signal.life-area.\(fact.house)",
                sourceFactIDs: [fact.factID] + fact.contributingFactIDs,
                movingID: nil,
                referenceID: nil,
                aspectKind: nil,
                tone: "classical",
                house: fact.house,
                roleID: evidence.role.rawValue,
                classicalThemeID: .houseActivation
            )
        case let .planetEvent(fact):
            return TransitThemeInput(
                signalID: "classical.transit.signal.event.\(fact.body.rawValue).\(fact.kind.rawValue)",
                sourceFactIDs: [fact.factID],
                movingID: fact.body.rawValue,
                referenceID: nil,
                aspectKind: nil,
                tone: "classical",
                house: fact.kind == .houseIngress ? fact.toIndex : nil,
                roleID: evidence.role.rawValue,
                classicalThemeID: .motionChange
            )
        case .calendar:
            return nil
        }
    }

    private static func phaseTheme(for window: TransitWindowFact, anchorDate: Date) -> ClassicalTransitThemeID {
        if window.exact == anchorDate { return .exactContact }
        return window.exact > anchorDate ? .applyingContact : .separatingContact
    }

    private static func aspectOrder(_ lhs: TransitAspectFact, _ rhs: TransitAspectFact) -> Bool {
        let lhsScore = testimonyScore(lhs)
        let rhsScore = testimonyScore(rhs)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
        return lhs.factID < rhs.factID
    }

    private static func testimonyScore(_ fact: TransitAspectFact) -> Double {
        let context = fact.classicalContext
        let reception = context?.receptionFromMoving == true || context?.receptionFromReference == true ? 30.0 : 0
        let phase = fact.phase == .applying ? 20.0 : fact.phase == .exact ? 25.0 : 0
        return abs(context?.movingScore ?? 0) + reception + phase + fact.strength * 10
    }

    private static func placementOrder(_ lhs: TransitPlanetPlacementFact, _ rhs: TransitPlanetPlacementFact) -> Bool {
        let lhsScore = abs(lhs.classicalScore ?? 0)
        let rhsScore = abs(rhs.classicalScore ?? 0)
        if lhsScore != rhsScore { return lhsScore > rhsScore }
        return lhs.factID < rhs.factID
    }

    private static func activeRole(for kind: TransitPlanetEventKind) -> TransitEvidenceRole {
        switch kind {
        case .signIngress: .activeSignIngress
        case .houseIngress: .activeHouseIngress
        case .stationRetrograde: .activeStationRetrograde
        case .stationDirect: .activeStationDirect
        }
    }

    private struct EvidenceUsageLedger {
        private var fullClaims = Set<String>()

        mutating func claim(_ fact: TransitFact, mode: TransitClaimMode, role: TransitEvidenceRole) -> TransitPlannedEvidence? {
            if mode == .full, !fullClaims.insert(fact.factID).inserted { return nil }
            return TransitPlannedEvidence(fact: fact, claimMode: mode, role: role)
        }
    }
}
