import AstroCore
import Foundation

extension CopyCatalogMatcher {
    func plannedCardText(
        plan: PlannedCardEvidence,
        scopeID: String,
        chart: ChartKind,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        preset: String?
    ) -> CardTextModel? {
        let _ = preset
        let context = standardCopySelectionContext(snapshot: snapshot, natal: natal, aspects: aspects)
        let selection: CopySelection?
        switch chart {
        case .natal:
            selection = natalPlannedCopySelection(plan: plan, context: context)
        case .currentSky:
            selection = currentSkyPlannedCopySelection(plan: plan, context: context)
        case .secondary:
            selection = secondaryPlannedCopySelection(plan: plan, context: context)
        case .solarReturn:
            selection = solarReturnPlannedCopySelection(plan: plan, context: context)
        case .transit, .synastry:
            // Transit and Synastry own richer plan-aware copy renderers.
            selection = nil
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            selection = nil
        }
        return textModel(from: selection, cardID: plan.cardID, scopeID: scopeID)
    }
}
