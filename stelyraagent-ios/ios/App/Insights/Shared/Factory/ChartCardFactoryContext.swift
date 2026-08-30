import AstroCore
import Foundation

struct ChartCardFactoryContext {
    let chart: ChartKind
    let snapshot: ChartSnapshot
    let natal: ChartSnapshot?
    let aspects: [ChartAspect]
    let content: CorpusContentProvider?
    let copyCatalog: CopyCatalogProvider?
    let language: AppLanguage
    let transitCalendar: [TransitCalendarDay]
    let transitRangeDays: Int
    let transitContentPlan: TransitContentPlan?
    let synastryComparison: SynastryComparison?
    let synastryContentPlan: SynastryContentPlan?
    let synastryFirstName: String?
    let synastrySecondName: String?
    let preset: String?
    let events: ChartEventData
    let timeZone: TimeZone
}
