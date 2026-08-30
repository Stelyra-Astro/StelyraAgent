import AstroCore

enum CurrentSkyChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        let bundle = CurrentSkyFactBundleBuilder.build(
            snapshot: context.snapshot,
            events: context.events,
            preset: context.preset ?? CalculationPreset.modern.rawValue
        )
        let plan = CurrentSkyContentPlanner.plan(bundle)
        return try InsightCardAssembler.assemble(
            CurrentSkyCardDraftFactory.make(context),
            context: context,
            contentPlan: plan,
            standardPlan: plan
        )
    }
}
