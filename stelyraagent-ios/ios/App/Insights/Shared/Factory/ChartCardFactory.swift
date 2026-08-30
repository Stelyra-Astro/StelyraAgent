import AstroCore
import Foundation

enum InsightFactoryError: LocalizedError {
    case invalidCardContract(String)

    var errorDescription: String? {
        switch self {
        case let .invalidCardContract(message):
            "Insight card contract failed: \(message)"
        }
    }
}

protocol ChartCardFactory {
    static func make(_ context: ChartCardFactoryContext) throws -> [InsightCardModel]
}
