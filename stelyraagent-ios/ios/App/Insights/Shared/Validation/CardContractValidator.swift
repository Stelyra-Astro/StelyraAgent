import Foundation

enum CardContractValidator {
    static func validate(_ cards: [InsightCardModel], for chart: ChartKind) throws {
        #if DEBUG
        let expectedIDs = chart.definition.localCardIDs
        guard cards.map(\.id) == expectedIDs else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) card set is incomplete")
        }
        guard cards.allSatisfy({ card in
            guard !card.title.isEmpty else { return false }
            return chart == .transit && card.id == "transit-timeline"
                ? card.text == nil && card.summary.isEmpty
                : !card.summary.isEmpty
        }) else {
            throw InsightFactoryError.invalidCardContract("\(chart.rawValue) contains empty card copy")
        }
        #endif
    }
}
