import AstroCore
import Foundation

struct SolarReturnFactBundle {
    let scopeID: String
    let preset: String
    let snapshot: ChartSnapshot
    let natal: ChartSnapshot?
    let aspects: [ChartAspect]
    let events: ChartEventData
}

struct SolarReturnContentPlan: StandardChartContentPlanProtocol {
    static let cardIDs = [
        "year-theme", "year-anchors", "priority-areas", "year-dynamics",
        "year-timeline", "natal-overlay", "year-aspects",
    ]
    let scopeID: String
    let cards: [PlannedCardEvidence]
}

enum SolarReturnFactBundleBuilder {
    static func build(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        preset: String
    ) -> SolarReturnFactBundle {
        SolarReturnFactBundle(
            scopeID: ChartContentScopeID.make(
                technique: ChartKind.solarReturn.contentPrefix,
                preset: preset,
                snapshot: snapshot,
                reference: natal
            ),
            preset: preset,
            snapshot: snapshot,
            natal: natal,
            aspects: aspects.sorted { $0.strength > $1.strength },
            events: events
        )
    }
}

enum SolarReturnContentPlanner {
    static func plan(_ bundle: SolarReturnFactBundle) -> SolarReturnContentPlan {
        let internalAspects = bundle.snapshot.aspects.sorted { $0.strength > $1.strength }
        let internalAspectIDs = internalAspects.prefix(4).map { ChartContentScopeID.aspect($0, role: "return") }
        let internalAspectEvidence = internalAspectIDs.isEmpty
            ? [ChartContentScopeID.point(.sun, role: "return"), ChartContentScopeID.angle("asc", role: "return")]
            : internalAspectIDs
        let overlayAspectIDs = bundle.aspects.prefix(5).map { ChartContentScopeID.aspect($0, role: "return-to-natal") }
        let placementIDs = bundle.snapshot.points.map { ChartContentScopeID.point($0.body, role: "return") }
        let houseIDs = bundle.snapshot.points.map { point in
            ChartContentScopeID.house(bundle.snapshot.house(containing: point.longitudeDegrees), role: "return")
        }
        let cards = [
            PlannedCardEvidence(
                cardID: "year-theme", copySlot: "return-ascendant",
                evidenceFactIDs: [ChartContentScopeID.angle("asc", role: "return"), ChartContentScopeID.point(.sun, role: "return")]
            ),
            PlannedCardEvidence(
                cardID: "year-anchors", copySlot: "return-quarter",
                evidenceFactIDs: [ChartContentScopeID.angle("asc", role: "return"), ChartContentScopeID.angle("mc", role: "return")] + Array(placementIDs.prefix(3))
            ),
            PlannedCardEvidence(
                cardID: "priority-areas", copySlot: "life-area",
                evidenceFactIDs: houseIDs
            ),
            PlannedCardEvidence(
                cardID: "year-dynamics", copySlot: "return-aspect",
                evidenceFactIDs: internalAspectEvidence
            ),
            PlannedCardEvidence(
                cardID: "year-timeline", copySlot: "return-quarter",
                evidenceFactIDs: ["solar-return.events.quarters"] + Array(internalAspectIDs.prefix(2))
            ),
            PlannedCardEvidence(
                cardID: "natal-overlay", copySlot: "natal-angle-overlay",
                evidenceFactIDs: overlayAspectIDs.isEmpty ? ["solar-return.natal-angle-overlay"] : overlayAspectIDs
            ),
            PlannedCardEvidence(
                cardID: "year-aspects", copySlot: "return-aspect",
                evidenceFactIDs: overlayAspectIDs.isEmpty ? internalAspectEvidence : overlayAspectIDs
            ),
        ]
        return SolarReturnContentPlan(scopeID: bundle.scopeID, cards: cards)
    }
}
