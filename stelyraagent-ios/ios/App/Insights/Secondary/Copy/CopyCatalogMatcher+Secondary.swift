import AstroCore

extension CopyCatalogMatcher {
    func secondaryCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        switch cardID {
        case "developmental-chapter":
            return pair("shared.secondary.progressedPhase.\(progressedPhaseKey(context.snapshot))", sourceFactIDs: ["progressed.phase"])
        case "progressed-moon":
            return pair("shared.natal.moonNeeds.\(context.moonSign)", sourceFactIDs: ["progressed.moon.sign"])
        case "identity-development":
            return pair("modern.secondary.progressedSun.\(context.sunSign)", sourceFactIDs: ["progressed.sun.sign"])
        case "areas-maturing":
            return pair("shared.maturingArea.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        case "turning-points":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: context.aspectSignalIDs)
        case "timeline":
            return pair("shared.secondary.progressedPhase.\(progressedPhaseKey(context.snapshot))", sourceFactIDs: ["progressed.phase"])
        default:
            return nil
        }
    }
}

extension CopyCatalogMatcher {
    func secondaryPlannedCopySelection(
        plan: PlannedCardEvidence,
        context: StandardCopySelectionContext
    ) -> CopySelection? {
        switch plan.copySlot {
        case "progressed-phase":
            return pair("shared.secondary.progressedPhase.\(progressedPhaseKey(context.snapshot))", sourceFactIDs: plan.evidenceFactIDs)
        case "progressed-moon-needs":
            return pair("shared.natal.moonNeeds.\(context.moonSign)", sourceFactIDs: plan.evidenceFactIDs)
        case "progressed-sun":
            return pair("modern.secondary.progressedSun.\(context.sunSign)", sourceFactIDs: plan.evidenceFactIDs)
        case "maturing-area":
            return pair("shared.maturingArea.\(context.leadingHouse)", sourceFactIDs: plan.evidenceFactIDs)
        case "progressed-aspect":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: plan.evidenceFactIDs)
        default:
            return nil
        }
    }
}
