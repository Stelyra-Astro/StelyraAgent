import AstroCore

enum NatalChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        let bundle = NatalFactBundleBuilder.build(
            snapshot: context.snapshot,
            preset: context.preset ?? CalculationPreset.modern.rawValue
        )
        let plan = NatalContentPlanner.plan(bundle)
        return try InsightCardAssembler.assemble(
            NatalCardDraftFactory.make(context),
            context: context,
            contentPlan: plan,
            standardPlan: plan
        )
    }
}
