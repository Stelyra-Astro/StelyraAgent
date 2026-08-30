import AstroCore

enum TransitChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        let plan = context.transitContentPlan ?? TransitContentPlanner.plan(
            TransitFactBundleBuilder.build(
                snapshot: context.snapshot,
                natal: context.natal,
                crossAspects: context.aspects,
                transitWindows: context.events.transitWindows,
                planetEvents: context.events.transitPlanetEvents,
                transitCalendar: context.transitCalendar,
                rangeDays: context.transitRangeDays,
                preset: context.preset ?? CalculationPreset.modern.rawValue,
                timeZone: context.timeZone
            )
        )
        let cards = TransitCardFactory.make(
            plan: plan,
            language: context.language,
            initialRangeDays: context.transitRangeDays
        )
        return try InsightCardAssembler.assemble(cards, context: context, contentPlan: plan, transitPlan: plan)
    }
}
