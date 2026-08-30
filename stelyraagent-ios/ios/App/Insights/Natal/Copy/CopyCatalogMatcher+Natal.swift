import AstroCore

extension CopyCatalogMatcher {
    func natalCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        let snapshot = context.snapshot
        let signature = temperament(snapshot)
        switch cardID {
        case "natal-interpretation":
            return pair("modern.natal.bigThree.\(signature.element).\(signature.mode)", sourceFactIDs: snapshot.points.prefix(3).map(\.id))
        case "element-balance":
            return pair("modern.natal.bigThree.\(signature.element).\(signature.mode)", sourceFactIDs: snapshot.points.prefix(3).map(\.id))
        case "emotional-needs":
            return pair("shared.natal.moonNeeds.\(context.moonSign)", sourceFactIDs: ["moon.sign"])
        case "love-connection":
            let venusSign = snapshot.point(.venus).map { signKey($0.signIndex) } ?? "aries"
            let base = "shared.natal.loveElementMatrix.\(element(for: venusSign)).\(element(for: context.moonSign))"
            return CopySelection(basePath: base, secondaryPath: "shared.natal.venusGives.\(venusSign)", themeID: nil, sourceFactIDs: ["venus.sign", "moon.sign"])
        case "career-direction":
            return pair("shared.natal.mcDirection.\(signKey(Int(snapshot.angles.midheavenDegrees / 30) % 12))", sourceFactIDs: ["mc.sign"])
        case "strengths-growth", "key-aspects":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: context.aspectSignalIDs)
        case "house-emphasis":
            return pair("shared.lifeAreas.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        case "chart-signature":
            return pair("modern.rulership.chartRulerCopy.\(ruler(for: context.ascSign))", sourceFactIDs: ["ascendant.sign"])
        case "planet-placements":
            let sunPlacement = "modern.natal.placement.sun.\(context.sunSign)"
            let moonPlacement = "modern.natal.placement.moon.\(context.moonSign)"
            return CopySelection(basePath: sunPlacement, secondaryPath: moonPlacement, themeID: nil, sourceFactIDs: ["sun.sign", "moon.sign"])
        default:
            return nil
        }
    }
}

extension CopyCatalogMatcher {
    func natalPlannedCopySelection(
        plan: PlannedCardEvidence,
        context: StandardCopySelectionContext
    ) -> CopySelection? {
        let snapshot = context.snapshot
        let signature = temperament(snapshot)
        switch plan.copySlot {
        case "big-three-signature", "element-modality-balance":
            return pair("modern.natal.bigThree.\(signature.element).\(signature.mode)", sourceFactIDs: plan.evidenceFactIDs)
        case "moon-needs":
            return pair("shared.natal.moonNeeds.\(context.moonSign)", sourceFactIDs: plan.evidenceFactIDs)
        case "venus-moon-needs":
            let venusSign = snapshot.point(.venus).map { signKey($0.signIndex) } ?? "aries"
            let base = "shared.natal.loveElementMatrix.\(element(for: venusSign)).\(element(for: context.moonSign))"
            return CopySelection(
                basePath: base,
                secondaryPath: "shared.natal.venusGives.\(venusSign)",
                themeID: nil,
                sourceFactIDs: plan.evidenceFactIDs
            )
        case "mc-direction":
            return pair("shared.natal.mcDirection.\(signKey(Int(snapshot.angles.midheavenDegrees / 30) % 12))", sourceFactIDs: plan.evidenceFactIDs)
        case "aspect-strength-growth", "key-aspect":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: plan.evidenceFactIDs)
        case "house-emphasis":
            return pair("shared.lifeAreas.\(context.leadingHouse)", sourceFactIDs: plan.evidenceFactIDs)
        case "chart-ruler-signature":
            return pair("modern.rulership.chartRulerCopy.\(ruler(for: context.ascSign))", sourceFactIDs: plan.evidenceFactIDs)
        case "placement-pair":
            return CopySelection(
                basePath: "modern.natal.placement.sun.\(context.sunSign)",
                secondaryPath: "modern.natal.placement.moon.\(context.moonSign)",
                themeID: nil,
                sourceFactIDs: plan.evidenceFactIDs
            )
        default:
            return nil
        }
    }
}
