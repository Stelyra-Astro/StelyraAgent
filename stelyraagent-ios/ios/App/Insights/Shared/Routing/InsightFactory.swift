import AstroCore
import Foundation

enum InsightFactory {
    static func make(
        chart: ChartKind,
        snapshot: ChartSnapshot?,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        content: CorpusContentProvider?,
        copyCatalog: CopyCatalogProvider?,
        language: AppLanguage,
        transitCalendar: [TransitCalendarDay],
        transitRangeDays: Int = 7,
        transitContentPlan: TransitContentPlan? = nil,
        synastryComparison: SynastryComparison? = nil,
        synastryContentPlan: SynastryContentPlan? = nil,
        synastryFirstName: String? = nil,
        synastrySecondName: String? = nil,
        preset: String? = nil,
        events: ChartEventData = .empty,
        timeZone: TimeZone = .current
    ) throws -> [InsightCardModel] {
        guard let snapshot else { return [] }
        guard chart.definition.insightMode == .plannedLocalCards else { return [] }
        let context = ChartCardFactoryContext(
            chart: chart,
            snapshot: snapshot,
            natal: natal,
            aspects: aspects,
            content: content,
            copyCatalog: copyCatalog,
            language: language,
            transitCalendar: transitCalendar,
            transitRangeDays: transitRangeDays,
            transitContentPlan: transitContentPlan,
            synastryComparison: synastryComparison,
            synastryContentPlan: synastryContentPlan,
            synastryFirstName: synastryFirstName,
            synastrySecondName: synastrySecondName,
            preset: preset,
            events: events,
            timeZone: timeZone
        )
        switch chart {
        case .natal:
            return try NatalChartCardFactory.make(context)
        case .currentSky:
            return try CurrentSkyChartCardFactory.make(context)
        case .transit:
            return try TransitChartCardFactory.make(context)
        case .secondary:
            return try SecondaryChartCardFactory.make(context)
        case .solarReturn:
            return try SolarReturnChartCardFactory.make(context)
        case .synastry:
            return try SynastryChartCardFactory.make(context)
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            return []
        }
    }
}
