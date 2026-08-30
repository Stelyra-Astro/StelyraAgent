import AstroCore
import Foundation

struct WeeklySignalFrame {
    let sourceID: String
    let aspects: [ChartAspect]
    let reference: ChartSnapshot?
}

struct WeeklyDayContext {
    let date: Date
    let natal: ChartSnapshot
    let frames: [String: WeeklySignalFrame]
}

struct WeeklySignalContribution {
    let domain: TodayLifeDomain
    let tone: InsightTone
    let strength: Double
    let sourceID: String
}

/// A chart technique participates in Today by translating its calculation
/// output into these neutral contributions. The weekly UI never switches on
/// chart types, so a future technique can register another provider here.
protocol WeeklySignalProviding {
    var sourceID: String { get }
    func contributions(for context: WeeklyDayContext) -> [WeeklySignalContribution]
}

struct AspectWeeklySignalProvider: WeeklySignalProviding {
    let sourceID: String
    let weight: Double
    let rules: TodayDashboardRules

    func contributions(for context: WeeklyDayContext) -> [WeeklySignalContribution] {
        let source = sourceID
        guard let frame = context.frames[sourceID] else { return [] }
        return frame.aspects.prefix(12).flatMap { aspect in
            let house = (frame.reference ?? context.natal)
                .house(containing: aspect.firstLongitude)
            let matchingDomains = TodayLifeDomain.allCases.filter {
                rules.houses(for: $0).contains(house)
            }
            let domains = matchingDomains.isEmpty ? [.energy] : matchingDomains
            return domains.map {
                WeeklySignalContribution(
                    domain: $0,
                    tone: tone(aspect.kind),
                    strength: max(0.04, aspect.strength * weight),
                    sourceID: source
                )
            }
        }
    }
}

enum WeeklySignalRegistry {
    static func standard(rules: TodayDashboardRules) -> [any WeeklySignalProviding] {
        [
            AspectWeeklySignalProvider(sourceID: "natal", weight: 0.12, rules: rules),
            AspectWeeklySignalProvider(sourceID: "current-sky", weight: 0.28, rules: rules),
            AspectWeeklySignalProvider(sourceID: "transit", weight: 1.0, rules: rules),
            AspectWeeklySignalProvider(sourceID: "secondary", weight: 0.42, rules: rules),
        ]
    }
}

struct WeeklyDayOverview: Identifiable {
    let date: Date
    let intensity: Double
    let tone: InsightTone
    let domain: TodayLifeDomain
    let title: String
    let situation: String
    let progress: String
    let next: String
    let peakStatus: String
    let peakIcon: String
    let nextFocusIcon: String
    let hasPersonalActivation: Bool

    var id: Date { date }
}

struct WeeklyDomainOverview: Identifiable {
    let domain: TodayLifeDomain
    let intensity: Double
    let tone: InsightTone

    var id: TodayLifeDomain { domain }
}

struct WeeklyForecastModel {
    let days: [WeeklyDayOverview]
    let domains: [WeeklyDomainOverview]

    static let empty = WeeklyForecastModel(days: [], domains: [])
}

enum WeeklyForecastFactory {
    private struct DayDraft {
        let date: Date
        let intensity: Double
        let tone: InsightTone
        let domain: TodayLifeDomain
        let hasPersonalActivation: Bool
    }

    static func make(
        contexts: [WeeklyDayContext],
        providers: [any WeeklySignalProviding],
        content: ContentProvider
    ) throws -> WeeklyForecastModel {
        let dayContributions = contexts.map { context in
            providers.flatMap { $0.contributions(for: context) }
        }
        let rawDrafts = zip(contexts, dayContributions).map { context, contributions in
            draft(date: context.date, contributions: contributions)
        }
        let minimum = rawDrafts.map(\.intensity).min() ?? 0
        let maximum = rawDrafts.map(\.intensity).max() ?? 0
        let spread = maximum - minimum
        let drafts = rawDrafts.map { item in
            DayDraft(
                date: item.date,
                intensity: spread < 0.000_001
                    ? 0.48
                    : 0.24 + 0.70 * ((item.intensity - minimum) / spread),
                tone: item.tone,
                domain: item.domain,
                hasPersonalActivation: item.hasPersonalActivation
            )
        }
        let peakIndex = drafts.enumerated()
            .max(by: { $0.element.intensity < $1.element.intensity })?.offset ?? 0
        let days = try drafts.enumerated().map { index, item in
            let currentCopy = try content.requiredCopy(
                key: "week.domain.\(item.domain.rawValue).\(item.tone.rawValue)"
            )
            let nextDraft = drafts[min(index + 1, drafts.count - 1)]
            let nextCopy = try content.requiredCopy(
                key: "week.domain.\(nextDraft.domain.rawValue).\(nextDraft.tone.rawValue)"
            )
            let peakPhase = index < peakIndex ? "ahead" : index == peakIndex ? "current" : "passed"
            let peakCopy = try content.requiredCopy(key: "week.peak.\(peakPhase)")
            return WeeklyDayOverview(
                date: item.date,
                intensity: item.intensity,
                tone: item.tone,
                domain: item.domain,
                title: currentCopy.summary,
                situation: currentCopy.detail,
                progress: peakCopy.detail,
                next: nextCopy.detail,
                peakStatus: peakCopy.summary,
                peakIcon: peakIcon(for: index, peakIndex: peakIndex),
                nextFocusIcon: nextFocusDomain(after: index, drafts: drafts).icon,
                hasPersonalActivation: item.hasPersonalActivation
            )
        }

        let domains = TodayLifeDomain.allCases.map { domain in
            let matching = dayContributions.flatMap { $0 }.filter { $0.domain == domain }
            let total = matching.reduce(0) { $0 + $1.strength }
            let maximum = TodayLifeDomain.allCases.map { candidate in
                dayContributions.flatMap { $0 }
                    .filter { $0.domain == candidate }
                    .reduce(0) { $0 + $1.strength }
            }.max() ?? 1
            return WeeklyDomainOverview(
                domain: domain,
                intensity: min(1, total / max(0.01, maximum)),
                tone: dominantTone(matching)
            )
        }

        return WeeklyForecastModel(days: days, domains: domains)
    }

    private static func draft(
        date: Date,
        contributions: [WeeklySignalContribution]
    ) -> DayDraft {
        let total = contributions.reduce(0) { $0 + $1.strength }
        let domain = TodayLifeDomain.allCases.max { first, second in
            domainTotal(first, contributions: contributions)
                < domainTotal(second, contributions: contributions)
        } ?? .energy
        return DayDraft(
            date: date,
            intensity: total,
            tone: dominantTone(contributions),
            domain: domain,
            hasPersonalActivation: contributions.contains { ["transit", "secondary"].contains($0.sourceID) }
        )
    }

    private static func domainTotal(
        _ domain: TodayLifeDomain,
        contributions: [WeeklySignalContribution]
    ) -> Double {
        contributions
            .filter { $0.domain == domain }
            .reduce(0) { $0 + $1.strength }
    }

    private static func dominantTone(
        _ contributions: [WeeklySignalContribution]
    ) -> InsightTone {
        let supportive = contributions
            .filter { $0.tone == .supportive }
            .reduce(0) { $0 + $1.strength }
        let challenging = contributions
            .filter { $0.tone == .challenging }
            .reduce(0) { $0 + $1.strength }
        if challenging > supportive * 1.15 { return .challenging }
        if supportive > challenging * 1.15 { return .supportive }
        return contributions.isEmpty ? .neutral : .transition
    }

    private static func peakIcon(for index: Int, peakIndex: Int) -> String {
        if index < peakIndex { return "arrow.up.right" }
        if index == peakIndex { return "exclamationmark.circle.fill" }
        return "checkmark.circle.fill"
    }

    private static func nextFocusDomain(
        after index: Int,
        drafts: [DayDraft]
    ) -> TodayLifeDomain {
        guard index + 1 < drafts.count else {
            return drafts[index].domain
        }
        return drafts[index + 1].domain
    }
}
