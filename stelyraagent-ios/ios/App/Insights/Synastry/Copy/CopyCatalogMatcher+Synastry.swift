import AstroCore

struct SynastryCopyRequest: Codable, Equatable, Sendable {
    let key: String
    let cardID: String
    let preset: String
    let themeID: String
    let sourceFactIDs: [String]
}

extension CopyCatalogMatcher {
    func synastryFactInterpretation(
        fact: SynastryFact,
        plan: SynastryCardEvidencePlan
    ) throws -> String {
        let role = plan.evidenceRoles[fact.factID] ?? "general"
        let suffix: String
        switch fact {
        case let .aspect(value):
            suffix = "aspect.\(value.firstBody.rawValue).\(value.kind.rawValue).\(value.secondBody.rawValue)"
        case let .overlay(value):
            suffix = "overlay.\(value.direction.rawValue).\(value.body.rawValue).house-\(value.receivingHouse)"
        case let .planetCondition(value):
            let polarity = value.assessment.score >= 0 ? "supportive" : "challenging"
            suffix = "planet-condition.\(value.person.rawValue).\(value.assessment.body.rawValue).\(polarity)"
        }
        let exactPath = "\(plan.preset).synastry.fact.\(plan.cardID).\(role).\(suffix).interpretation"
        if let exact = valueIfPresent(at: exactPath) {
            return exact
        }

        // The reviewed v4 layer contains exact interpretations for observed
        // patterns. Real charts can produce additional valid combinations, so
        // every supported fact type has an explicit reviewed base selector.
        // This keeps missing exact variants from blanking the entire chart
        // without synthesizing consumer copy in Swift.
        return try value(at: synastryBaseInterpretationPath(for: fact, cardID: plan.cardID, role: role))
    }

    private func synastryBaseInterpretationPath(
        for fact: SynastryFact,
        cardID: String,
        role: String
    ) -> String {
        switch fact {
        case let .overlay(value):
            return "shared.synastry.houseOverlay.\(value.receivingHouse)"
        case let .planetCondition(value):
            return "shared.synastryRoles.\(value.assessment.body.rawValue)"
        case let .aspect(value):
            let focalBody: CelestialBody
            switch (cardID, role) {
            case ("emotional-connection", _):
                focalBody = .moon
            case ("communication", _):
                focalBody = .mercury
            case ("chemistry", "attraction"):
                focalBody = [value.firstBody, value.secondBody].contains(.venus) ? .venus : .mars
            case ("chemistry", "intensity"):
                focalBody = [value.firstBody, value.secondBody].contains(.pluto) ? .pluto : .mars
            case ("commitment", "stability"):
                focalBody = .saturn
            case ("commitment", "growth"):
                focalBody = .jupiter
            default:
                focalBody = value.firstBody
            }
            return "shared.synastryRoles.\(focalBody.rawValue)"
        }
    }

    func synastryCardText(
        plan: SynastryCardEvidencePlan,
        firstName: String,
        secondName: String
    ) throws -> CardTextModel {
        if plan.cardID == "perspectives" {
            let names: [SynastryPersonRole: String] = [.personA: firstName, .personB: secondName]
            let roleTexts = try plan.perspectives.flatMap { perspective -> [CardRoleText] in
                let base = "\(plan.preset).synastry.perspectives.\(perspective.themeID.rawValue)"
                let variables = ["otherName": names[perspective.otherPerson] ?? ""]
                let role = perspective.person.rawValue
                return [
                    CardRoleText(
                        roleID: "\(role).headline",
                        text: try value(at: "\(base).headline", variables: variables),
                        sourceFactIDs: perspective.evidence.map(\.factID)
                    ),
                    CardRoleText(
                        roleID: "\(role).body",
                        text: try value(at: "\(base).body", variables: variables),
                        sourceFactIDs: perspective.evidence.map(\.factID)
                    ),
                ]
            }
            return CardTextModel(
                sectionLabel: nil,
                cardLabel: plan.cardID,
                headline: nil,
                body: nil,
                secondaryBody: nil,
                areaLabel: nil,
                statusLabel: nil,
                technicalLabel: nil,
                startLabel: nil,
                endLabel: nil,
                themeID: plan.themeID.rawValue,
                sourceFactIDs: plan.sourceFactIDs,
                copyPackID: "\(pack.contentVersion):\(plan.preset).synastry.perspectives",
                scopeID: plan.scopeID,
                roleTexts: roleTexts,
                cycleTexts: nil
            )
        }
        let request = SynastryCopyRequest(
            key: plan.copyKey,
            cardID: plan.cardID,
            preset: plan.preset,
            themeID: plan.themeID.rawValue,
            sourceFactIDs: plan.sourceFactIDs
        )
        let selection = CopySelection(
            basePath: request.key,
            secondaryPath: nil,
            themeID: request.themeID,
            sourceFactIDs: request.sourceFactIDs
        )
        let roleFields: [String]
        switch plan.cardID {
        case "emotional-connection": roleFields = ["flow.body", "difference.body"]
        case "communication": roleFields = ["step1", "step2", "step3"]
        case "commitment": roleFields = ["stability.body", "growth.body"]
        default: roleFields = []
        }
        let roleTexts = roleFields.compactMap { field -> CardRoleText? in
            guard let value = valueIfPresent(at: "\(request.key).\(field)") else { return nil }
            let roleID = field.hasSuffix(".body") ? String(field.dropLast(5)) + ".body" : field
            let sourceIDs: [String]
            if field.hasSuffix(".body") {
                let role = String(field.dropLast(5))
                sourceIDs = plan.evidenceRoles.compactMap { $0.value == role ? $0.key : nil }.sorted()
            } else {
                sourceIDs = plan.sourceFactIDs
            }
            return CardRoleText(roleID: roleID, text: value, sourceFactIDs: sourceIDs)
        }
        guard let model = textModel(
            from: selection,
            cardID: plan.cardID,
            scopeID: plan.scopeID,
            roleTexts: roleTexts
        ) else {
            throw CopyCatalogError.missingCopy(request.key)
        }
        return model
    }

    /// Retained only for decoding old packs while the Synastry v2 corpus is
    /// generated. Runtime v2 cards never call this selector.
    func synastryCopySelection(cardID: String, context: StandardCopySelectionContext) -> CopySelection? {
        let overview = synastryOverview(context.aspects)
        switch cardID {
        case "relationship-overview":
            return pair("shared.synastry.overview.\(overview)", sourceFactIDs: context.aspects.prefix(3).map(\.id))
        case "perspectives":
            return CopySelection(
                basePath: "shared.synastryRoles.sun",
                secondaryPath: "shared.synastryRoles.moon",
                themeID: nil,
                sourceFactIDs: context.aspects.prefix(3).map(\.id)
            )
        case "emotional-connection", "communication", "chemistry", "commitment", "key-inter-aspects":
            guard let aspectPath = context.aspectPath else { return nil }
            return CopySelection(basePath: aspectPath, secondaryPath: nil, themeID: nil, sourceFactIDs: context.aspectSignalIDs)
        case "house-overlays":
            return pair("shared.synastry.houseOverlay.\(context.leadingHouse)", sourceFactIDs: ["house.\(context.leadingHouse)"])
        default:
            return nil
        }
    }
}
