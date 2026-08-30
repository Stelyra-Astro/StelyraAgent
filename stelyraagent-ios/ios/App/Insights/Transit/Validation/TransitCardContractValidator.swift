import Foundation

enum TransitCardContractValidator {
    static func validate(
        cards: [InsightCardModel],
        plan: TransitContentPlan
    ) throws {
        if plan.preset == "classical" {
            return try ClassicalTransitContractValidator.validate(cards: cards, plan: plan)
        }
        guard plan.cards.map(\.cardID) == TransitContentPlan.cardIDs else {
            throw InsightFactoryError.invalidCardContract("transit content plan card set is incomplete")
        }
        var fullClaims: [String: Int] = [:]
        for cardPlan in plan.cards {
            for evidence in cardPlan.evidence where evidence.claimMode == .full {
                fullClaims[evidence.fact.factID, default: 0] += 1
            }
        }
        guard fullClaims.values.allSatisfy({ $0 == 1 }) else {
            throw InsightFactoryError.invalidCardContract("a transit fact has multiple full claims")
        }

        for card in cards {
            guard let cardPlan = plan.card(card.id) else {
                throw InsightFactoryError.invalidCardContract("transit card \(card.id) has no evidence plan")
            }
            guard card.scopeID == plan.scopeID,
                  card.text == nil || card.text?.scopeID == plan.scopeID
            else {
                throw InsightFactoryError.invalidCardContract("transit card \(card.id) scope does not match its content plan")
            }
            let plannedIDs = Set(cardPlan.sourceFactIDs)
            let uiIDs = Set(card.facts.flatMap(\.sourceFactIDs))
            guard uiIDs.isSubset(of: plannedIDs) else {
                throw InsightFactoryError.invalidCardContract("transit card \(card.id) UI bypassed its evidence plan")
            }
            let copyIDs = Set(card.text?.sourceFactIDs ?? [])
            guard copyIDs.isSubset(of: plannedIDs) else {
                throw InsightFactoryError.invalidCardContract("transit card \(card.id) copy bypassed its evidence plan")
            }
        }

        let timelineFacts = plan.card("transit-timeline")?.evidence.map(\.fact) ?? []
        guard timelineFacts.allSatisfy({ fact in
            switch fact {
            case .window, .planetEvent, .calendar: true
            default: false
            }
        }) else {
            throw InsightFactoryError.invalidCardContract("transit timeline contains unsupported technical evidence")
        }
        let pathFacts = plan.card("planet-paths")?.evidence.map(\.fact) ?? []
        guard pathFacts.allSatisfy({ fact in
            switch fact {
            case .placement, .planetEvent: true
            default: false
            }
        }) else {
            throw InsightFactoryError.invalidCardContract("planet paths contains unsupported path evidence")
        }
        let areaFacts = plan.card("life-areas")?.evidence.map(\.fact) ?? []
        guard areaFacts.allSatisfy({ if case .lifeArea = $0 { true } else { false } }) else {
            throw InsightFactoryError.invalidCardContract("life areas contains non-aggregate evidence")
        }
        guard areaFacts.count == 12 else {
            throw InsightFactoryError.invalidCardContract("life areas must preserve all twelve houses")
        }
        let story = plan.card("current-story")
        guard story?.copySlot == .integratedStory,
              story?.signalRoles.allSatisfy({ !$0.movingID.isEmpty && !$0.lifeAreas.isEmpty }) == true,
              story?.integratedThemeID != nil || story?.evidence.isEmpty == true
        else {
            throw InsightFactoryError.invalidCardContract("current story is missing its integrated signal contract")
        }
        let activeFacts = plan.card("active-transits")?.evidence.map(\.fact) ?? []
        guard activeFacts.allSatisfy({ fact in
            switch fact {
            case .aspect, .window, .planetEvent: true
            default: false
            }
        }) else {
            throw InsightFactoryError.invalidCardContract("active transits contains unsupported evidence")
        }
    }
}
