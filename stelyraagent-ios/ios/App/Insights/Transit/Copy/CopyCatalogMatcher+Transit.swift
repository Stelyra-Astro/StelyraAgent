import AstroCore
import Foundation

extension CopyCatalogMatcher {
    func transitCardText(plan: CardEvidencePlan) throws -> CardTextModel {
        let requests = transitCopyRequests(plan: plan)
        let roleTexts = try requests
            .filter { $0.copySlot == TransitCopySlot.signalRole.rawValue }
            .map { request in
                CardRoleText(
                    roleID: request.roleID ?? "supporting",
                    text: try value(
                        at: request.key,
                        variables: renderedTransitVariables(request.variables)
                    ),
                    sourceFactIDs: request.sourceFactIDs
                )
            }
        let cycleTexts = try requests
            .filter { $0.copySlot == TransitCopySlot.cycleChapter.rawValue }
            .map { request in
                let headline = try value(at: "\(request.key).headline")
                let body = try value(at: "\(request.key).body")
                return TransitCycleText(
                    roleID: request.roleID ?? "",
                    headline: headline,
                    body: body,
                    sourceFactIDs: request.sourceFactIDs
                )
            }
        guard plan.copySlot != nil,
              let selection = transitCopySelection(plan: plan, requests: requests),
              let model = textModel(
                  from: selection,
                  cardID: plan.cardID,
                  scopeID: plan.scopeID,
                  roleTexts: roleTexts,
                  cycleTexts: cycleTexts
              )
        else {
            throw CopyCatalogError.missingCopy("\(plan.preset).transit.\(plan.copySlot?.rawValue ?? "technical")")
        }
        return model
    }

    func transitCopyRequests(plan: CardEvidencePlan) -> [TransitCopyRequest] {
        guard !plan.evidence.isEmpty, plan.cardID != "transit-timeline" else { return [] }
        if plan.preset == CalculationPreset.classical.rawValue {
            return classicalTransitCopyRequests(plan: plan)
        }
        guard plan.preset == CalculationPreset.modern.rawValue else { return [] }
        switch plan.copySlot {
        case .integratedStory:
            var requests: [TransitCopyRequest] = []
            if let integratedThemeID = plan.integratedThemeID {
                requests.append(
                    TransitCopyRequest(
                        key: "modern.transit.integratedStory.\(integratedThemeID.rawValue)",
                        cardID: plan.cardID,
                        copySlot: TransitCopySlot.integratedStory.rawValue,
                        themeID: nil,
                        integratedThemeID: integratedThemeID.rawValue,
                        roleID: nil,
                        variables: [:],
                        sourceFactIDs: plan.sourceFactIDs
                    )
                )
            }
            requests += plan.signalRoles.map { assignment in
                TransitCopyRequest(
                    key: "modern.transit.signalRole.\(assignment.signalRole.rawValue)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.signalRole.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: assignment.signalRole.rawValue,
                    variables: [
                        "transitPlanet": assignment.movingID,
                        "lifeAreas": assignment.lifeAreas.map(String.init).joined(separator: ","),
                    ],
                    sourceFactIDs: assignment.sourceFactIDs
                )
            }
            return requests
        case .cycleChapter:
            return plan.themeInputs.compactMap { input in
                transitThemeRequest(
                    input: input,
                    cardID: plan.cardID,
                    slot: .cycleChapter
                )
            }
        case .planetPathShort:
            guard let evidence = plan.evidence.first(where: {
                if case .placement = $0.fact { return true }
                return false
            }),
            case let .placement(placement) = evidence.fact
            else { return [] }
            let state = placement.retrograde ? "retrograde" : "direct"
            var requests = [
                TransitCopyRequest(
                    key: "shared.bodyMotion.\(placement.body.rawValue).\(state)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.planetPathShort.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: "path",
                    variables: [:],
                    sourceFactIDs: evidence.fact.sourceFactIDs
                ),
            ]
            if (1 ... 12).contains(placement.natalHouse) {
                requests.append(
                    TransitCopyRequest(
                        key: "shared.lifeAreas.\(placement.natalHouse)",
                        cardID: plan.cardID,
                        copySlot: TransitCopySlot.planetPathShort.rawValue,
                        themeID: nil,
                        integratedThemeID: nil,
                        roleID: "path",
                        variables: [:],
                        sourceFactIDs: evidence.fact.sourceFactIDs
                    )
                )
            }
            return requests
        case .lifeAreaShort:
            guard let evidence = plan.evidence.first(where: {
                if case .lifeArea = $0.fact { return true }
                return false
            }),
            case let .lifeArea(area) = evidence.fact
            else { return [] }
            return [
                TransitCopyRequest(
                    key: "shared.lifeAreas.\(area.house)",
                    cardID: plan.cardID,
                    copySlot: TransitCopySlot.lifeAreaShort.rawValue,
                    themeID: nil,
                    integratedThemeID: nil,
                    roleID: "lifeArea",
                    variables: [:],
                    sourceFactIDs: evidence.fact.sourceFactIDs
                ),
            ]
        case .activeTransitShort:
            return transitThemeRequest(plan: plan, slot: .activeTransitShort).map { [$0] } ?? []
        case .signalRole, nil:
            return []
        }
    }


    func transitCopySelection(
        plan: CardEvidencePlan,
        requests: [TransitCopyRequest]
    ) -> CopySelection? {
        guard let copySlot = plan.copySlot else { return nil }
        switch copySlot {
        case .integratedStory:
            guard let request = requests.first(where: {
                $0.copySlot == TransitCopySlot.integratedStory.rawValue
            }) else { return nil }
            return CopySelection(
                basePath: request.key,
                secondaryPath: nil,
                themeID: request.integratedThemeID,
                sourceFactIDs: request.sourceFactIDs
            )
        case .cycleChapter:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: $0.themeID, sourceFactIDs: $0.sourceFactIDs)
            }
        case .signalRole:
            return nil
        case .planetPathShort:
            if plan.preset == CalculationPreset.classical.rawValue {
                return requests.first.map {
                    CopySelection(basePath: $0.key, secondaryPath: nil, themeID: $0.themeID, sourceFactIDs: $0.sourceFactIDs)
                }
            }
            guard let request = requests.first(where: { $0.key.hasPrefix("shared.bodyMotion.") }) else { return nil }
            return CopySelection(
                basePath: request.key,
                secondaryPath: requests.first(where: { $0.key.hasPrefix("shared.lifeAreas.") })?.key,
                themeID: nil,
                sourceFactIDs: request.sourceFactIDs
            )
        case .lifeAreaShort:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: nil, sourceFactIDs: $0.sourceFactIDs)
            }
        case .activeTransitShort:
            return requests.first.map {
                CopySelection(basePath: $0.key, secondaryPath: nil, themeID: $0.themeID, sourceFactIDs: $0.sourceFactIDs)
            }
        }
    }

    func transitThemeRequest(
        plan: CardEvidencePlan,
        slot: TransitCopySlot
    ) -> TransitCopyRequest? {
        guard let input = plan.themeInputs.first else { return nil }
        return transitThemeRequest(input: input, cardID: plan.cardID, slot: slot)
    }

    func transitThemeRequest(
        input: TransitThemeInput,
        cardID: String,
        slot: TransitCopySlot
    ) -> TransitCopyRequest? {
        let mappedThemeID = ThemeMapper.themeID(
            for: input,
            rules: pack.themeRulesByPreset["modern"] ?? [],
            houseFallback: { house, tone in
                valueIfPresent(at: "shared.transit.houseFallback.\(house).\(tone)")
            }
        )
        guard let themeID = TransitThemeID(rawValue: mappedThemeID) else { return nil }
        let basePath: String
        switch slot {
        case .cycleChapter:
            basePath = "modern.transit.cycleChapter.\(input.roleID).\(themeID.rawValue)"
        case .activeTransitShort:
            basePath = "modern.transit.activeTransitShort.\(input.roleID).\(themeID.rawValue)"
        default:
            return nil
        }
        return TransitCopyRequest(
            key: basePath,
            cardID: cardID,
            copySlot: slot.rawValue,
            themeID: themeID.rawValue,
            integratedThemeID: nil,
            roleID: input.roleID,
            variables: [:],
            sourceFactIDs: input.sourceFactIDs
        )
    }

    func renderedTransitVariables(_ variables: [String: String]) -> [String: String] {
        guard let language = AppLanguage(rawValue: pack.locale) else { return variables }
        var rendered = variables
        if let bodyID = variables["transitPlanet"] {
            rendered["transitPlanet"] = AstroTerms.value("bodies", bodyID, language: language)
        }
        if let houseIDs = variables["lifeAreas"] {
            let houses = houseIDs.split(separator: ",").compactMap { Int($0) }.map {
                AstroTerms.house($0, language: language)
            }
            let formatter = ListFormatter()
            formatter.locale = language.locale
            rendered["lifeAreas"] = formatter.string(from: houses) ?? houses.joined(separator: ", ")
        }
        return rendered
    }

    func transitLegacyCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        let themeID = ThemeMapper.themeID(
            for: context.primaryAspect,
            house: context.leadingHouse,
            rules: context.themeRules,
            houseFallback: { house, tone in valueIfPresent(at: "shared.transit.houseFallback.\(house).\(tone)") }
        )
        switch cardID {
        case "current-story", "current-cycles", "active-transits", "transit-timeline":
            let slot = cardID == "current-story" ? "chapter" : (cardID == "transit-timeline" ? "coming" : "active")
            return pair("shared.transit.themePacks.\(themeID).\(slot)", themeID: themeID, sourceFactIDs: context.aspectSignalIDs)
        case "planet-paths":
            guard let body = prominentMovingBody(in: context.snapshot) else { return nil }
            let state = body.retrograde ? "retrograde" : "direct"
            return CopySelection(
                basePath: "shared.bodyMotion.\(body.id).\(state)",
                secondaryPath: "shared.lifeAreas.\(context.leadingHouse)",
                themeID: nil,
                sourceFactIDs: [body.id]
            )
        case "life-areas":
            return pair("shared.lifeAreas.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        default:
            return nil
        }
    }
}
