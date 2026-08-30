import AstroCore
import Foundation

struct NatalFactBundle {
    let scopeID: String
    let preset: String
    let snapshot: ChartSnapshot
    let aspects: [ChartAspect]
}

struct NatalContentPlan: StandardChartContentPlanProtocol {
    static let cardIDs = [
        "natal-interpretation", "emotional-needs", "love-connection", "career-direction",
        "strengths-growth", "element-balance", "house-emphasis", "chart-signature",
        "planet-placements", "key-aspects",
    ]
    let scopeID: String
    let cards: [PlannedCardEvidence]
}

enum NatalFactBundleBuilder {
    static func build(snapshot: ChartSnapshot, preset: String) -> NatalFactBundle {
        NatalFactBundle(
            scopeID: ChartContentScopeID.make(
                technique: ChartKind.natal.contentPrefix,
                preset: preset,
                snapshot: snapshot
            ),
            preset: preset,
            snapshot: snapshot,
            aspects: snapshot.aspects.sorted { $0.strength > $1.strength }
        )
    }
}

enum NatalContentPlanner {
    static func plan(_ bundle: NatalFactBundle) -> NatalContentPlan {
        let snapshot = bundle.snapshot
        let topAspects = Array(bundle.aspects.prefix(4))
        let supportive = bundle.aspects.first(where: { $0.kind.supportive }) ?? bundle.aspects.first
        let challenging = bundle.aspects.first(where: { $0.kind.challenging }) ?? bundle.aspects.first
        let placementIDs = snapshot.points.map { ChartContentScopeID.point($0.body) }
        let houseIDs = snapshot.points.map { point in
            ChartContentScopeID.house(snapshot.house(containing: point.longitudeDegrees))
        }
        let aspectIDs = topAspects.map { ChartContentScopeID.aspect($0) }
        let aspectEvidence = aspectIDs.isEmpty
            ? [ChartContentScopeID.point(.sun), ChartContentScopeID.point(.moon)]
            : aspectIDs
        let strengthIDs = [supportive, challenging].compactMap { $0 }.map { ChartContentScopeID.aspect($0) }
        let strengthEvidence = strengthIDs.isEmpty
            ? [ChartContentScopeID.point(.sun), ChartContentScopeID.point(.moon)]
            : strengthIDs
        let cards = [
            PlannedCardEvidence(
                cardID: "natal-interpretation", copySlot: "big-three-signature",
                evidenceFactIDs: [ChartContentScopeID.point(.sun), ChartContentScopeID.point(.moon), ChartContentScopeID.angle("asc")]
            ),
            PlannedCardEvidence(
                cardID: "emotional-needs", copySlot: "moon-needs",
                evidenceFactIDs: [ChartContentScopeID.point(.moon)]
            ),
            PlannedCardEvidence(
                cardID: "love-connection", copySlot: "venus-moon-needs",
                evidenceFactIDs: [ChartContentScopeID.point(.venus), ChartContentScopeID.point(.moon)]
            ),
            PlannedCardEvidence(
                cardID: "career-direction", copySlot: "mc-direction",
                evidenceFactIDs: [ChartContentScopeID.angle("mc"), ChartContentScopeID.angle("asc")]
            ),
            PlannedCardEvidence(
                cardID: "strengths-growth", copySlot: "aspect-strength-growth",
                evidenceFactIDs: strengthEvidence
            ),
            PlannedCardEvidence(
                cardID: "element-balance", copySlot: "element-modality-balance",
                evidenceFactIDs: placementIDs
            ),
            PlannedCardEvidence(
                cardID: "house-emphasis", copySlot: "house-emphasis",
                evidenceFactIDs: houseIDs
            ),
            PlannedCardEvidence(
                cardID: "chart-signature", copySlot: "chart-ruler-signature",
                evidenceFactIDs: [ChartContentScopeID.angle("asc")] + aspectEvidence
            ),
            PlannedCardEvidence(
                cardID: "planet-placements", copySlot: "placement-pair",
                evidenceFactIDs: placementIDs
            ),
            PlannedCardEvidence(
                cardID: "key-aspects", copySlot: "key-aspect",
                evidenceFactIDs: aspectEvidence
            ),
        ]
        return NatalContentPlan(scopeID: bundle.scopeID, cards: cards)
    }
}
