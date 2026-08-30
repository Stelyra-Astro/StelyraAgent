import AstroCore
import Foundation

struct CurrentSkyFactBundle {
    let scopeID: String
    let preset: String
    let snapshot: ChartSnapshot
    let events: ChartEventData
    let aspects: [ChartAspect]
}

struct CurrentSkyContentPlan: StandardChartContentPlanProtocol {
    static let cardIDs = [
        "sky-overview", "moon-now", "aspect-pattern", "planetary-motion",
        "sign-changes", "element-climate", "upcoming-7-days",
    ]
    let scopeID: String
    let cards: [PlannedCardEvidence]
}

enum CurrentSkyFactBundleBuilder {
    static func build(snapshot: ChartSnapshot, events: ChartEventData, preset: String) -> CurrentSkyFactBundle {
        CurrentSkyFactBundle(
            scopeID: ChartContentScopeID.make(
                technique: ChartKind.currentSky.contentPrefix,
                preset: preset,
                snapshot: snapshot
            ),
            preset: preset,
            snapshot: snapshot,
            events: events,
            aspects: snapshot.aspects.sorted { $0.strength > $1.strength }
        )
    }
}

enum CurrentSkyContentPlanner {
    static func plan(_ bundle: CurrentSkyFactBundle) -> CurrentSkyContentPlan {
        let pointIDs = bundle.snapshot.points.map { ChartContentScopeID.point($0.body, role: "sky") }
        let aspectIDs = bundle.aspects.prefix(5).map { ChartContentScopeID.aspect($0, role: "sky") }
        let aspectEvidence = aspectIDs.isEmpty
            ? [ChartContentScopeID.point(.sun, role: "sky"), ChartContentScopeID.point(.moon, role: "sky")]
            : aspectIDs
        let motionIDs = bundle.snapshot.points.filter(\.retrograde).map {
            ChartContentScopeID.point($0.body, role: "motion")
        }
        let cards = [
            PlannedCardEvidence(
                cardID: "sky-overview", copySlot: "sky-atmosphere",
                evidenceFactIDs: Array(aspectIDs.prefix(3)) + [ChartContentScopeID.point(.moon, role: "sky")]
            ),
            PlannedCardEvidence(
                cardID: "moon-now", copySlot: "lunar-phase",
                evidenceFactIDs: [ChartContentScopeID.point(.sun, role: "sky"), ChartContentScopeID.point(.moon, role: "sky")]
            ),
            PlannedCardEvidence(
                cardID: "aspect-pattern", copySlot: "aspect-pattern",
                evidenceFactIDs: aspectEvidence
            ),
            PlannedCardEvidence(
                cardID: "planetary-motion", copySlot: "body-motion",
                evidenceFactIDs: motionIDs.isEmpty ? Array(pointIDs.prefix(1)) : motionIDs
            ),
            PlannedCardEvidence(
                cardID: "sign-changes", copySlot: "sign-style",
                evidenceFactIDs: [ChartContentScopeID.point(.moon, role: "sky"), "sky.events.sign-changes"]
            ),
            PlannedCardEvidence(
                cardID: "element-climate", copySlot: "sky-atmosphere",
                evidenceFactIDs: pointIDs
            ),
            PlannedCardEvidence(
                cardID: "upcoming-7-days", copySlot: "sky-atmosphere",
                evidenceFactIDs: Array(aspectIDs.prefix(3)) + ["sky.events.upcoming-7-days"]
            ),
        ]
        return CurrentSkyContentPlan(scopeID: bundle.scopeID, cards: cards)
    }
}
