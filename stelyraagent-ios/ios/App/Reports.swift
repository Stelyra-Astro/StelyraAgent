import AstroCore
import Foundation

struct SavedReport: Codable, Identifiable, Equatable {
    let id: String
    let scope: String // chart.<kind> or period.<type>
    let title: String
    let subtitle: String
    let generatedAt: Date
    let report: AIReport

    init(id: String, scope: String, title: String, subtitle: String, generatedAt: Date, report: AIReport) {
        self.id = id
        self.scope = scope
        self.title = title
        self.subtitle = subtitle
        self.generatedAt = generatedAt
        self.report = report
    }

    static func == (lhs: SavedReport, rhs: SavedReport) -> Bool { lhs.id == rhs.id }

    init(artifact: GeneratedChartArtifact) {
        id = artifact.semanticFingerprint
        scope = artifact.chartKind.hasPrefix("relationship.")
            ? artifact.chartKind
            : "chart.\(artifact.chartKind)"
        title = artifact.response.report.title
        subtitle = artifact.response.report.subtitle
        generatedAt = artifact.generatedAt
        report = AIReport(
            title: artifact.response.report.title,
            subtitle: artifact.response.report.subtitle,
            sections: artifact.response.report.sections
        )
    }
}

func savedReportScopeTitle(_ scope: String, language: AppLanguage) -> String {
    switch scope {
    case "chart.natal": return localized("reports.natal-report", language: language)
    case "chart.current-sky": return localized("reports.current-sky-report", language: language)
    case "chart.transit": return localized("reports.transit-report", language: language)
    case "chart.secondary": return localized("reports.progressed-report", language: language)
    case "chart.solar-return": return localized("reports.solar-return-report", language: language)
    case "chart.synastry": return localized("reports.synastry-report", language: language)
    case "chart.tertiary": return ChartKind.tertiary.title(language: language)
    case "chart.lunar-return": return ChartKind.lunarReturn.title(language: language)
    case "chart.solar-arc": return ChartKind.solarArc.title(language: language)
    case "chart.relocation": return ChartKind.relocation.title(language: language)
    case "chart.twelfth-harmonic": return ChartKind.twelfthHarmonic.title(language: language)
    case "chart.thirteenth-harmonic": return ChartKind.thirteenthHarmonic.title(language: language)
    default:
        if scope.hasPrefix("relationship."),
           let kind = RelationshipChartKind(rawValue: String(scope.dropFirst("relationship.".count)))
        {
            return kind.title(language: language)
        }
        return scope
    }
}

func savedReportScopeSymbol(_ scope: String) -> String {
    switch scope {
    case "chart.natal": return "✦"
    case "chart.current-sky": return "◉"
    case "chart.transit": return "◎"
    case "chart.secondary": return "◐"
    case "chart.solar-return": return "☉"
    case "chart.synastry": return "∞"
    case "chart.tertiary": return "◑"
    case "chart.lunar-return": return "☽"
    case "chart.solar-arc": return "↗"
    case "chart.relocation": return "⌖"
    case "chart.twelfth-harmonic": return "⑫"
    case "chart.thirteenth-harmonic": return "⑬"
    default:
        if scope.hasPrefix("relationship.") { return "∞" }
        return "◎"
    }
}
