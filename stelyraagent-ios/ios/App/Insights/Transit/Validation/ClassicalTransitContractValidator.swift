import AstroCore

enum ClassicalTransitContractValidator {
    static func validate(cards: [InsightCardModel], plan: TransitContentPlan) throws {
        guard plan.preset == CalculationPreset.classical.rawValue else {
            throw InsightFactoryError.invalidCardContract("classical transit plan has the wrong preset")
        }
        guard plan.cards.map(\.cardID) == TransitContentPlan.cardIDs else {
            throw InsightFactoryError.invalidCardContract("classical transit card order changed")
        }
        guard plan.cards.allSatisfy({ $0.preset == CalculationPreset.classical.rawValue }) else {
            throw InsightFactoryError.invalidCardContract("classical transit card used a non-classical strategy")
        }
        guard plan.cards.allSatisfy({ $0.integratedThemeID == nil && $0.signalRoles.isEmpty }) else {
            throw InsightFactoryError.invalidCardContract("classical transit reused modern semantic output")
        }
        guard plan.cards.flatMap(\.themeInputs).allSatisfy({ $0.classicalThemeID != nil }) else {
            throw InsightFactoryError.invalidCardContract("classical transit has an unmapped theme input")
        }
        let fullClaims = plan.cards.flatMap(\.evidence).filter { $0.claimMode == .full }
        guard fullClaims.count <= 1, fullClaims.first?.role == .primary || fullClaims.isEmpty else {
            throw InsightFactoryError.invalidCardContract("classical transit has duplicate full claims")
        }
        for cardPlan in plan.cards {
            guard cardPlan.scopeID == plan.scopeID,
                  cardPlan.sourceFactIDs.allSatisfy({ $0.hasPrefix("transit.\(plan.scopeID).") })
            else {
                throw InsightFactoryError.invalidCardContract("classical transit source facts escaped their scope")
            }
        }
        guard plan.card("transit-timeline")?.evidence.allSatisfy({ evidence in
            guard evidence.claimMode == .technical else { return false }
            switch evidence.fact {
            case .window, .planetEvent, .calendar: return true
            default: return false
            }
        }) == true else {
            throw InsightFactoryError.invalidCardContract("classical transit timeline contains non-technical evidence")
        }
        guard plan.card("current-cycles")?.evidence.allSatisfy({ $0.claimMode == .aggregate }) == true else {
            throw InsightFactoryError.invalidCardContract("classical transit cycles contain non-aggregate evidence")
        }
        guard plan.card("life-areas")?.evidence.allSatisfy({ $0.claimMode == .aggregate }) == true else {
            throw InsightFactoryError.invalidCardContract("classical transit life areas contain non-aggregate evidence")
        }
        guard plan.card("active-transits")?.evidence.allSatisfy({ $0.claimMode != .full }) == true else {
            throw InsightFactoryError.invalidCardContract("classical active transits repeated a full claim")
        }
        for card in cards {
            guard let cardPlan = plan.card(card.id), card.scopeID == plan.scopeID else {
                throw InsightFactoryError.invalidCardContract("classical transit UI bypassed its evidence plan")
            }
            let plannedIDs = Set(cardPlan.sourceFactIDs)
            guard Set(card.facts.flatMap(\.sourceFactIDs)).isSubset(of: plannedIDs),
                  Set(card.text?.sourceFactIDs ?? []).isSubset(of: plannedIDs)
            else {
                throw InsightFactoryError.invalidCardContract("classical transit output contains invalid source facts")
            }
        }
    }
}
