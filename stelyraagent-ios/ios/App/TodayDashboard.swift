import AstroCore
import Foundation

enum TodayLifeDomain: String, CaseIterable, Identifiable {
    case love
    case work
    case money
    case energy

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .love: localized("today.love-relationships", language: language)
        case .work: localized("today.work-direction", language: language)
        case .money: localized("today.money-resources", language: language)
        case .energy: localized("today.energy-wellbeing", language: language)
        }
    }

    var icon: String {
        switch self {
        case .love: "heart"
        case .work: "briefcase"
        case .money: "wallet.bifold"
        case .energy: "waveform.path.ecg"
        }
    }

}

struct TodayDashboardRules: Decodable {
    struct DomainRule: Decodable {
        let houses: [Int]
    }

    let version: String
    let transitWeight: Double
    let progressionWeight: Double
    let intensitySaturation: Double
    let toneDominanceRatio: Double
    let domains: [String: DomainRule]

    static func load(bundle: Bundle = .main) -> TodayDashboardRules {
        let urls = [
            bundle.url(forResource: "PrivateRules-Today", withExtension: "json"),
            bundle.resourceURL?.appendingPathComponent("PrivateRules/PrivateRules-Today.json"),
        ].compactMap { $0 }
        for url in urls where FileManager.default.fileExists(atPath: url.path) {
            if let data = try? Data(contentsOf: url),
               let rules = try? JSONDecoder().decode(TodayDashboardRules.self, from: data)
            {
                return rules
            }
        }
        return sample
    }

    func houses(for domain: TodayLifeDomain) -> Set<Int> {
        Set(domains[domain.rawValue]?.houses ?? [])
    }

    private static let sample = TodayDashboardRules(
        version: "public-sample-v1",
        transitWeight: 1,
        progressionWeight: 0.4,
        intensitySaturation: 2.5,
        toneDominanceRatio: 1.2,
        domains: [
            TodayLifeDomain.love.rawValue: DomainRule(houses: [5, 7]),
            TodayLifeDomain.work.rawValue: DomainRule(houses: [6, 10]),
            TodayLifeDomain.money.rawValue: DomainRule(houses: [2, 8]),
            TodayLifeDomain.energy.rawValue: DomainRule(houses: [1, 6, 12]),
        ]
    )
}

struct TodayDomainSummary: Identifiable {
    let domain: TodayLifeDomain
    let intensity: Double
    let tone: InsightTone
    let state: String
    let title: String
    let summary: String

    var id: TodayLifeDomain { domain }
}

struct TodayDashboardModel {
    let headline: String
    let summary: String
    let focusIntensity: Double
    let focusTone: InsightTone
    let rhythm: [Double]
    let rhythmLabels: [String]
    let peakLabel: String
    let domains: [TodayDomainSummary]
    let nextMoments: [TodayRhythmMoment]
}

struct TodayRhythmMoment: Identifiable {
    let id: String
    let stage: String
    let source: String
    let title: String
    let summary: String
    let tone: InsightTone
    let intensity: Double
}

enum TodayDashboardFactory {
    private struct DomainAccumulator {
        var total = 0.0
        var supportive = 0.0
        var challenging = 0.0
        var transition = 0.0

        mutating func add(_ contribution: WeeklySignalContribution) {
            let value = contribution.strength
            total += value
            switch contribution.tone {
            case .supportive:
                supportive += value
            case .challenging:
                challenging += value
            case .transition, .neutral:
                transition += value
            }
        }
    }

    static func make(
        contributions: [WeeklySignalContribution],
        signals: [DailySignal],
        content: ContentProvider,
        rules: TodayDashboardRules,
        language: AppLanguage,
        timeZone: TimeZone
    ) throws -> TodayDashboardModel {
        var accumulators = Dictionary(
            uniqueKeysWithValues: TodayLifeDomain.allCases.map { ($0, DomainAccumulator()) }
        )

        for contribution in contributions {
            accumulators[contribution.domain]?.add(contribution)
        }

        let domains = try TodayLifeDomain.allCases.map { domain in
            let accumulator = accumulators[domain] ?? DomainAccumulator()
            let intensity = min(
                1,
                accumulator.total / max(0.01, rules.intensitySaturation)
            )
            let tone = domainTone(
                accumulator,
                dominanceRatio: rules.toneDominanceRatio
            )
            let state = stateLabel(intensity: intensity, tone: tone, language: language)
            let copyKey = "today.domain.\(domain.rawValue).\(tone.rawValue)"
            let copy = try content.requiredCopy(key: copyKey)
            return TodayDomainSummary(
                domain: domain,
                intensity: intensity,
                tone: tone,
                state: state,
                title: copy.summary,
                summary: copy.detail
            )
        }

        let dominant = domains.max {
            if abs($0.intensity - $1.intensity) > 0.000_001 {
                return $0.intensity < $1.intensity
            }
            return $0.domain.rawValue > $1.domain.rawValue
        } ?? domains[0]
        let rhythm = buildRhythm(signals: signals, timeZone: timeZone)
        let peakIndex = rhythm.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
        let rhythmLabels = [
            localized("today.morning", language: language),
            localized("today.afternoon", language: language),
            localized("today.evening", language: language),
        ]
        let nextMoments = try buildNextMoments(
            signals: signals,
            content: content,
            language: language,
            timeZone: timeZone
        )

        return TodayDashboardModel(
            headline: dominant.title,
            summary: dominant.summary,
            focusIntensity: dominant.intensity,
            focusTone: dominant.tone,
            rhythm: rhythm,
            rhythmLabels: rhythmLabels,
            peakLabel: rhythmLabels[min(2, peakIndex / 2)],
            domains: domains,
            nextMoments: nextMoments
        )
    }

    private static func buildNextMoments(
        signals: [DailySignal],
        content: ContentProvider,
        language: AppLanguage,
        timeZone: TimeZone
    ) throws -> [TodayRhythmMoment] {
        var seen = Set<String>()
        let selected = signals.filter { signal in
            seen.insert("\(signal.source.contentID).\(signal.tone.rawValue)").inserted
        }
        .prefix(3)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("j:mm")

        return try selected.map { signal in
            let copy = try content.requiredCopy(
                key: "today.rhythm.\(signal.source.contentID).\(signal.tone.rawValue)"
            )
            return TodayRhythmMoment(
                id: signal.id,
                stage: signal.eventDate.map(formatter.string(from:))
                    ?? localized("today.ongoing", language: language),
                source: signal.source.consumerTitle(language: language),
                title: copy.summary,
                summary: copy.detail,
                tone: signal.tone,
                intensity: max(0.08, min(1, Double(signal.strength) / 100))
            )
        }
    }

    private static func domainTone(
        _ value: DomainAccumulator,
        dominanceRatio: Double
    ) -> InsightTone {
        guard value.total > 0.000_001 else { return .neutral }
        let ratio = max(1, dominanceRatio)
        if value.challenging > value.supportive * ratio { return .challenging }
        if value.supportive > value.challenging * ratio { return .supportive }
        return .transition
    }

    private static func stateLabel(
        intensity: Double,
        tone: InsightTone,
        language: AppLanguage
    ) -> String {
        guard intensity >= 0.14 else {
            return localized("today.steady", language: language)
        }
        return switch tone {
        case .supportive: localized("today.flowing", language: language)
        case .challenging: localized("today.tone.tension", language: language)
        case .transition: localized("today.active", language: language)
        case .neutral: localized("today.steady", language: language)
        }
    }

    private static func buildRhythm(
        signals: [DailySignal],
        timeZone: TimeZone
    ) -> [Double] {
        var values = Array(repeating: 0.0, count: 7)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        for signal in signals {
            let strength = max(0.05, min(1, Double(signal.strength) / 100))
            guard let date = signal.eventDate else {
                for index in values.indices {
                    values[index] += strength * 0.22
                }
                continue
            }
            let hour = calendar.component(.hour, from: date)
            let minute = calendar.component(.minute, from: date)
            let dayFraction = (Double(hour) + Double(minute) / 60) / 24
            let center = Int((dayFraction * Double(values.count)).rounded())
                .clamped(to: values.indices)
            for index in values.indices {
                let distance = abs(index - center)
                guard distance <= 2 else { continue }
                values[index] += strength * (distance == 0 ? 1 : distance == 1 ? 0.48 : 0.18)
            }
        }

        guard let maximum = values.max(), maximum > 0 else { return values }
        return values.map { $0 / maximum }
    }

}

private extension DailySignal.Source {
    var contentID: String {
        switch self {
        case .sky: "sky"
        case .transit: "transit"
        case .secondary: "secondary"
        }
    }

    func consumerTitle(language: AppLanguage) -> String {
        switch self {
        case .sky:
            localized("today.shared-atmosphere", language: language)
        case .transit:
            localized("today.personal-timing", language: language)
        case .secondary:
            localized("today.long-term-shift", language: language)
        }
    }
}

private extension Int {
    func clamped(to range: Range<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound - 1)
    }
}
