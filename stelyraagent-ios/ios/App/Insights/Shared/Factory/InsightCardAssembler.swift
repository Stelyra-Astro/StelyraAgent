import AstroCore
import Foundation

enum InsightCardAssembler {
    static func assemble(
        _ cards: [InsightCardModel],
        context: ChartCardFactoryContext,
        contentPlan: (any ChartContentPlanProtocol)? = nil,
        standardPlan: (any StandardChartContentPlanProtocol)? = nil,
        transitPlan: TransitContentPlan? = nil,
        synastryPlan: SynastryContentPlan? = nil
    ) throws -> [InsightCardModel] {
        let renderedCards = try cards.map { draft in
            let cardAspects: [ChartAspect]
            let aspectsAreCross: Bool
            switch context.chart {
            case .solarReturn:
                aspectsAreCross = draft.id == "natal-overlay"
                cardAspects = aspectsAreCross ? context.aspects : context.snapshot.aspects
            case .transit, .secondary, .synastry:
                aspectsAreCross = true
                cardAspects = context.aspects
            case .natal, .currentSky, .relocation:
                aspectsAreCross = false
                cardAspects = context.snapshot.aspects
            case .tertiary, .lunarReturn, .solarArc, .twelfthHarmonic, .thirteenthHarmonic:
                aspectsAreCross = true
                cardAspects = context.aspects
            }
            let interpretationContext = InterpretationContextFactory.make(
                chart: context.chart,
                cardID: draft.id,
                snapshot: context.snapshot,
                natal: context.natal,
                aspects: cardAspects,
                language: context.language,
                transitCalendar: context.transitCalendar.map(\.score),
                preset: context.preset,
                aspectsAreCross: aspectsAreCross,
                events: context.events
            )
            let interpretation = try? context.content?.interpret(interpretationContext)
            let cardText: CardTextModel?
            if let plan = transitPlan?.card(draft.id) {
                cardText = plan.evidence.isEmpty || plan.copySlot == nil
                    ? nil
                    : try context.copyCatalog?.transitCardText(plan: plan)
            } else if let plan = synastryPlan?.card(draft.id) {
                cardText = plan.evidence.isEmpty
                    ? nil
                    : try context.copyCatalog?.synastryCardText(
                        plan: plan,
                        firstName: synastryPlan?.firstName ?? "Person A",
                        secondName: synastryPlan?.secondName ?? "Person B"
                    )
            } else if let plan = standardPlan?.cards.first(where: { $0.cardID == draft.id }) {
                cardText = plan.evidenceFactIDs.isEmpty
                    ? nil
                    : context.copyCatalog?.plannedCardText(
                        plan: plan,
                        scopeID: standardPlan?.scopeID ?? "",
                        chart: context.chart,
                        snapshot: context.snapshot,
                        natal: context.natal,
                        aspects: cardAspects,
                        preset: context.preset
                    )
            } else {
                cardText = context.copyCatalog?.cardText(
                    chart: context.chart,
                    cardID: draft.id,
                    snapshot: context.snapshot,
                    natal: context.natal,
                    aspects: cardAspects,
                    preset: context.preset
                )
            }
            let plannedEvidenceAvailable = transitPlan?.card(draft.id).map { !$0.evidence.isEmpty }
                ?? synastryPlan?.card(draft.id).map { !$0.evidence.isEmpty }
                ?? standardPlan?.cards.first(where: { $0.cardID == draft.id }).map { !$0.evidenceFactIDs.isEmpty }
                ?? true
            if context.copyCatalog != nil, cardText == nil, plannedEvidenceAvailable,
               context.copyCatalog?.copyRequired(chart: context.chart, cardID: draft.id) == true {
                throw InsightFactoryError.invalidCardContract(
                    "\(context.chart.rawValue).\(draft.id) has no valid approved copy selection"
                )
            }
            let conclusion: String
            if let transitCardPlan = transitPlan?.card(draft.id), transitCardPlan.copySlot == nil {
                conclusion = ""
            } else {
                conclusion = cardText?.headline ?? cardText?.body ?? interpretation?.summary ?? localized("insight.shared.reviewed-interpretation-unavailable", language: context.language)
            }
            return InsightCardModel(
                id: draft.id,
                title: draft.title,
                icon: draft.icon,
                visual: draft.visual,
                facts: try draft.facts.map { fact in
                    if let synastryCardPlan = synastryPlan?.card(draft.id),
                       let plannedFact = synastryCardPlan.evidence.first(where: { $0.factID == fact.id }),
                       let copyCatalog = context.copyCatalog
                    {
                        return copying(
                            fact,
                            interpretation: try copyCatalog.synastryFactInterpretation(
                                fact: plannedFact,
                                plan: synastryCardPlan
                            )
                        )
                    }
                    guard draft.id == "emotional-needs", fact.interpretation == nil else { return fact }
                    return copying(fact, interpretation: conclusion)
                },
                conclusionKey: "\(context.chart.contentPrefix).\(draft.id)",
                conclusion: conclusion,
                text: cardText,
                scopeID: transitPlan?.scopeID ?? synastryPlan?.scopeID ?? contentPlan?.scopeID
            )
        }
        if let standardPlan {
            try PlannedCardContractValidator.validate(
                cards: renderedCards,
                standardPlan: standardPlan,
                chart: context.chart
            )
        } else if let contentPlan {
            try PlannedCardContractValidator.validate(cards: renderedCards, plan: contentPlan)
        }
        if let transitPlan {
            try TransitCardContractValidator.validate(cards: renderedCards, plan: transitPlan)
        }
        if let synastryPlan {
            try SynastryCardContractValidator.validate(cards: renderedCards, plan: synastryPlan)
        }
        try CardContractValidator.validate(renderedCards, for: context.chart)
        return renderedCards
    }

    private static func copying(_ fact: InsightFact, interpretation: String) -> InsightFact {
        InsightFact(
            id: fact.id,
            metricLabel: fact.metricLabel,
            calculatedValue: fact.calculatedValue,
            interpretationKey: fact.interpretationKey,
            interpretationVariables: fact.interpretationVariables,
            sourceFactIDs: fact.sourceFactIDs,
            visualRole: fact.visualRole,
            technicalDetail: fact.technicalDetail,
            interpretation: interpretation,
            emphasis: fact.emphasis,
            progress: fact.progress,
            symbol: fact.symbol,
            category: fact.category,
            markers: fact.markers
        )
    }
}
