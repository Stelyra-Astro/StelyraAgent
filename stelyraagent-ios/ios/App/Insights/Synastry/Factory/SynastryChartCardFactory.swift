import AstroCore
import Foundation

enum SynastryChartCardFactory: ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel] {
        guard let comparison = context.synastryComparison else { return [] }
        guard let firstName = context.synastryFirstName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !firstName.isEmpty,
              let secondName = context.synastrySecondName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !secondName.isEmpty
        else {
            throw InsightFactoryError.invalidCardContract("synastry requires both real person names")
        }
        let plan = context.synastryContentPlan ?? SynastryContentPlanner.plan(
            SynastryFactBundleBuilder.build(
                comparison: comparison,
                preset: context.preset ?? CalculationPreset.modern.rawValue
            ),
            firstName: firstName,
            secondName: secondName
        )
        let cards = InsightFactory.synastryCards(plan: plan, language: context.language)
        return try InsightCardAssembler.assemble(cards, context: context, contentPlan: plan, synastryPlan: plan)
    }
}
