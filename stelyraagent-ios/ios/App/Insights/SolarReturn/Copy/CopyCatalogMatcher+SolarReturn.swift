import AstroCore

extension CopyCatalogMatcher {
    func solarReturnCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        let ascSign = signKey(Int(context.snapshot.angles.ascendantDegrees / 30) % 12)
        switch cardID {
        case "year-theme":
            return pair("shared.solarReturn.solarAsc.\(ascSign)", sourceFactIDs: ["solar.ascendant.sign"])
        case "year-dynamics", "year-aspects":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: context.aspectSignalIDs)
        case "year-anchors", "year-timeline":
            let quarter = currentQuarter(from: context.snapshot.utcDate)
            return pair("shared.solarReturn.solarQuarters.\(quarter)", sourceFactIDs: ["solar.quarter.\(quarter)"])
        case "priority-areas":
            return pair("shared.lifeAreas.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        case "natal-overlay":
            let angle = closestNatalOverlayAngle(solar: context.snapshot, natal: context.natal)
            return pair("shared.overlayAngles.\(angle)", sourceFactIDs: ["natal.angle.\(angle)"])
        default:
            return nil
        }
    }
}

extension CopyCatalogMatcher {
    func solarReturnPlannedCopySelection(
        plan: PlannedCardEvidence,
        context: StandardCopySelectionContext
    ) -> CopySelection? {
        let ascSign = signKey(Int(context.snapshot.angles.ascendantDegrees / 30) % 12)
        switch plan.copySlot {
        case "return-ascendant":
            return pair("shared.solarReturn.solarAsc.\(ascSign)", sourceFactIDs: plan.evidenceFactIDs)
        case "return-aspect":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: plan.evidenceFactIDs)
        case "return-quarter":
            let quarter = currentQuarter(from: context.snapshot.utcDate)
            return pair("shared.solarReturn.solarQuarters.\(quarter)", sourceFactIDs: plan.evidenceFactIDs)
        case "life-area":
            return pair("shared.lifeAreas.\(context.leadingHouse)", sourceFactIDs: plan.evidenceFactIDs)
        case "natal-angle-overlay":
            let angle = closestNatalOverlayAngle(solar: context.snapshot, natal: context.natal)
            return pair("shared.overlayAngles.\(angle)", sourceFactIDs: plan.evidenceFactIDs)
        default:
            return nil
        }
    }
}
