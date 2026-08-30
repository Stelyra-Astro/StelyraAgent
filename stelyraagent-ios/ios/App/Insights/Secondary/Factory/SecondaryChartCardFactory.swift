import AstroCore

enum SecondaryChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        let bundle = SecondaryFactBundleBuilder.build(
            snapshot: context.snapshot,
            natal: context.natal,
            aspects: context.aspects,
            preset: context.preset ?? CalculationPreset.modern.rawValue
        )
        let plan = SecondaryContentPlanner.plan(bundle)
        return try InsightCardAssembler.assemble(
            SecondaryCardDraftFactory.make(context),
            context: context,
            contentPlan: plan,
            standardPlan: plan
        )
    }
}
