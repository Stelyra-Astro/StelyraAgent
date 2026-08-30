import AstroCore

extension CopyCatalogMatcher {
    func currentSkyCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        let snapshot = context.snapshot
        switch cardID {
        case "moon-now":
            return pair("shared.lunarPhase.\(lunarPhaseKey(snapshot))", sourceFactIDs: ["moon.phase", "moon.sign"])
        case "planetary-motion":
            let point = snapshot.points.first(where: \.retrograde) ?? snapshot.points.first
            guard let point else { return nil }
            let state = point.retrograde ? "retrograde" : "direct"
            return pair("shared.bodyMotion.\(point.body.rawValue).\(state)", sourceFactIDs: [point.id])
        case "sign-changes":
            return pair("shared.signStyle.\(context.moonSign)", sourceFactIDs: ["moon.sign"])
        case "sky-overview", "aspect-pattern", "element-climate", "upcoming-7-days":
            return pair("shared.currentSky.skyAtmosphere.\(context.atmosphere)", sourceFactIDs: snapshot.aspects.prefix(3).map(\.id))
        default:
            return nil
        }
    }
}

extension CopyCatalogMatcher {
    func currentSkyPlannedCopySelection(
        plan: PlannedCardEvidence,
        context: StandardCopySelectionContext
    ) -> CopySelection? {
        switch plan.copySlot {
        case "lunar-phase":
            return pair("shared.lunarPhase.\(lunarPhaseKey(context.snapshot))", sourceFactIDs: plan.evidenceFactIDs)
        case "body-motion":
            let point = context.snapshot.points.first(where: \.retrograde) ?? context.snapshot.points.first
            guard let point else { return nil }
            let state = point.retrograde ? "retrograde" : "direct"
            return pair("shared.bodyMotion.\(point.body.rawValue).\(state)", sourceFactIDs: plan.evidenceFactIDs)
        case "sign-style":
            return pair("shared.signStyle.\(context.moonSign)", sourceFactIDs: plan.evidenceFactIDs)
        case "sky-atmosphere", "aspect-pattern":
            return pair("shared.currentSky.skyAtmosphere.\(context.atmosphere)", sourceFactIDs: plan.evidenceFactIDs)
        default:
            return nil
        }
    }
}
