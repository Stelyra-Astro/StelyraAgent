import AstroCore

enum SolarReturnChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        let bundle = SolarReturnFactBundleBuilder.build(
            snapshot: context.snapshot,
            natal: context.natal,
            aspects: context.aspects,
            events: context.events,
            preset: context.preset ?? CalculationPreset.modern.rawValue
        )
        let plan = SolarReturnContentPlanner.plan(bundle)
        return try InsightCardAssembler.assemble(
            SolarReturnCardDraftFactory.make(context),
            context: context,
            contentPlan: plan,
            standardPlan: plan
        )
    }
}
