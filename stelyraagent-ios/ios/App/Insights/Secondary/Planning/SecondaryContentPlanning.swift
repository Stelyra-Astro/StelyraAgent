import AstroCore
import Foundation

struct SecondaryFactBundle {
    let scopeID: String
    let preset: String
    let snapshot: ChartSnapshot
    let natal: ChartSnapshot?
    let aspects: [ChartAspect]
}

struct SecondaryContentPlan: StandardChartContentPlanProtocol {
    static let cardIDs = [
        "developmental-chapter", "progressed-moon", "identity-development",
        "turning-points", "areas-maturing", "timeline",
    ]
    let scopeID: String
    let cards: [PlannedCardEvidence]
}

enum SecondaryFactBundleBuilder {
    static func build(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        preset: String
    ) -> SecondaryFactBundle {
        SecondaryFactBundle(
            scopeID: ChartContentScopeID.make(
                technique: ChartKind.secondary.contentPrefix,
                preset: preset,
                snapshot: snapshot,
                reference: natal
            ),
            preset: preset,
            snapshot: snapshot,
            natal: natal,
            aspects: aspects.sorted { $0.strength > $1.strength }
        )
    }
}

enum SecondaryContentPlanner {
    static func plan(_ bundle: SecondaryFactBundle) -> SecondaryContentPlan {
        let aspectIDs = bundle.aspects.prefix(6).map { ChartContentScopeID.aspect($0, role: "progressed-to-natal") }
        let aspectEvidence = aspectIDs.isEmpty
            ? [ChartContentScopeID.point(.sun, role: "progressed"), ChartContentScopeID.point(.moon, role: "progressed")]
            : aspectIDs
        let placementIDs = bundle.snapshot.points.map { ChartContentScopeID.point($0.body, role: "progressed") }
        let houseIDs = bundle.snapshot.points.map { point in
            let house = bundle.natal?.house(containing: point.longitudeDegrees)
                ?? bundle.snapshot.house(containing: point.longitudeDegrees)
            return ChartContentScopeID.house(house, role: "progressed")
        }
        let cards = [
            PlannedCardEvidence(
                cardID: "developmental-chapter", copySlot: "progressed-phase",
                evidenceFactIDs: [ChartContentScopeID.point(.sun, role: "progressed"), ChartContentScopeID.point(.moon, role: "progressed")]
            ),
            PlannedCardEvidence(
                cardID: "progressed-moon", copySlot: "progressed-moon-needs",
                evidenceFactIDs: [ChartContentScopeID.point(.moon, role: "progressed")]
            ),
            PlannedCardEvidence(
                cardID: "identity-development", copySlot: "progressed-sun",
                evidenceFactIDs: [ChartContentScopeID.point(.sun, role: "progressed")]
            ),
            PlannedCardEvidence(
                cardID: "turning-points", copySlot: "progressed-aspect",
                evidenceFactIDs: aspectEvidence
            ),
            PlannedCardEvidence(
                cardID: "areas-maturing", copySlot: "maturing-area",
                evidenceFactIDs: houseIDs + Array(placementIDs.prefix(3))
            ),
            PlannedCardEvidence(
                cardID: "timeline", copySlot: "progressed-phase",
                evidenceFactIDs: Array(aspectIDs.prefix(4)) + [ChartContentScopeID.point(.moon, role: "progressed")]
            ),
        ]
        return SecondaryContentPlan(scopeID: bundle.scopeID, cards: cards)
    }
}
