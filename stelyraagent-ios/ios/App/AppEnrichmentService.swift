import AstroCore
import Foundation

@MainActor
final class AppEnrichmentService {
    func buildActiveSignals(
        sky: ChartSnapshot,
        transits: [ChartAspect],
        progressions: [ChartAspect],
        language: AppLanguage
    ) -> [DailySignal] {
        let transitSignals = transits.prefix(3).map {
            DailySignal(
                id: "transit-\($0.id)",
                category: .activeNow,
                source: .transit,
                title: aspectTitle(
                    $0,
                    prefix: localized("enrichment.transit", language: language),
                    language: language
                ),
                subtitle: "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        let skySignals = sky.aspects.prefix(2).map {
            DailySignal(
                id: "sky-\($0.id)",
                category: .activeNow,
                source: .sky,
                title: aspectTitle($0, language: language),
                subtitle: "\(localized("enrichment.active-now", language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        let progressedSignal = progressions.first.map {
            DailySignal(
                id: "secondary-\($0.id)",
                category: .activeNow,
                source: .secondary,
                title: aspectTitle(
                    $0,
                    prefix: localized("enrichment.progressed", language: language),
                    language: language
                ),
                subtitle: "\(localized("enrichment.long-term-background", language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                tone: tone($0.kind),
                strength: Int($0.strength * 100),
                eventDate: nil
            )
        }
        return (Array(transitSignals) + Array(skySignals) + [progressedSignal].compactMap { $0 })
            .sorted { $0.strength > $1.strength }
            .prefix(5)
            .map { $0 }
    }

    func buildWeeklyForecast(
        calculator: SwissEphemerisCalculator,
        profile: UserProfile,
        presets: [ChartKind: CalculationPreset],
        language: AppLanguage,
        natal: ChartSnapshot,
        transitReference: ChartSnapshot,
        progressedReference: ChartSnapshot,
        startingAt date: Date
    ) async throws -> WeeklyForecastModel {
        func preset(_ chart: ChartKind) -> CalculationPreset { presets[chart] ?? .modern }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        let start = calendar.startOfDay(for: date)
        var contexts: [WeeklyDayContext] = []
        contexts.reserveCapacity(7)

        for offset in 0 ..< 7 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let localNoon = calendar.date(byAdding: .hour, value: 12, to: day)
            else { continue }
            let input = NatalInput(utcDate: localNoon, location: profile.location)
            let sky = try await calculator.calculateSnapshot(input, preset: preset(.currentSky))
            let transitMoving = preset(.transit) == preset(.currentSky)
                ? sky
                : try await calculator.calculateSnapshot(input, preset: preset(.transit))
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: profile.birthDateUTC,
                targetDate: localNoon
            )
            let progressedMoving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: progressedDate, location: profile.location),
                preset: preset(.secondary),
                aspectOrbDegrees: 3
            )
            contexts.append(
                WeeklyDayContext(
                    date: localNoon,
                    natal: natal,
                    frames: [
                        "natal": WeeklySignalFrame(
                            sourceID: "natal",
                            aspects: natal.aspects,
                            reference: natal
                        ),
                        "current-sky": WeeklySignalFrame(
                            sourceID: "current-sky",
                            aspects: sky.aspects,
                            reference: natal
                        ),
                        "transit": WeeklySignalFrame(
                            sourceID: "transit",
                            aspects: SwissEphemerisCalculator.compare(
                                moving: transitMoving,
                                reference: transitReference,
                                orbDegrees: 3
                            ),
                            reference: transitReference
                        ),
                        "secondary": WeeklySignalFrame(
                            sourceID: "secondary",
                            aspects: SwissEphemerisCalculator.compare(
                                moving: progressedMoving,
                                reference: progressedReference,
                                orbDegrees: 2
                            ),
                            reference: progressedReference
                        ),
                    ]
                )
            )
        }

        let rules = TodayDashboardRules.load()
        return try WeeklyForecastFactory.make(
            contexts: contexts,
            providers: WeeklySignalRegistry.standard(rules: rules),
            content: ContentProvider(area: .today, language: language)
        )
    }

    func buildTransitEphemerisSamples(
        calculator: SwissEphemerisCalculator,
        startingAt date: Date,
        rangeDays: Int,
        timeZone: TimeZone,
        location: GeographicLocation,
        preset: CalculationPreset
    ) async throws -> [TransitEphemerisSample] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: rangeDays, to: start)
            ?? start.addingTimeInterval(Double(rangeDays) * 86_400)
        var values: [TransitEphemerisSample] = []
        values.reserveCapacity(rangeDays * 2 + 1)
        var sampleDate = start
        while sampleDate <= end {
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: sampleDate, location: location),
                preset: preset
            )
            values.append(TransitEphemerisSample(date: sampleDate, snapshot: snapshot))
            guard let nextDate = calendar.date(byAdding: .hour, value: 12, to: sampleDate),
                  nextDate > sampleDate
            else { break }
            sampleDate = nextDate
        }
        return values
    }

    func buildTransitCalendar(
        natal: ChartSnapshot,
        startingAt date: Date,
        rangeDays: Int,
        scopeID: String,
        timeZone: TimeZone,
        samples: [TransitEphemerisSample]
    ) -> [TransitCalendarDay] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let samplesByDay = Dictionary(grouping: samples) { calendar.startOfDay(for: $0.date) }
        var values: [TransitCalendarDay] = []
        values.reserveCapacity(rangeDays)

        for offset in 0 ..< rangeDays {
            guard let day = calendar.date(byAdding: .day, value: offset, to: start),
                  let daySamples = samplesByDay[day],
                  let moving = daySamples.min(by: {
                      abs(calendar.component(.hour, from: $0.date) - 12)
                          < abs(calendar.component(.hour, from: $1.date) - 12)
                  })?.snapshot
            else { continue }
            let aspects = SwissEphemerisCalculator.compare(moving: moving, reference: natal, orbDegrees: 3)
            let strongest = Array(aspects.prefix(8))
            let density = strongest.isEmpty ? 0 : strongest.reduce(0) { $0 + $1.strength } / 8
            values.append(
                TransitCalendarDay(
                    date: day,
                    score: Int(min(1, density) * 100),
                    sourceFactIDs: strongest.map {
                        TransitFactBundleBuilder.calendarSourceFactID(
                            scopeID: scopeID,
                            date: day,
                            aspect: $0,
                            timeZone: timeZone
                        )
                    }.sorted()
                )
            )
        }
        return values
    }

    func makeTransitContentPlan(
        snapshot: ChartSnapshot?,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        timeZone: TimeZone,
        calendarDays: [TransitCalendarDay],
        preset: CalculationPreset
    ) -> TransitContentPlan? {
        guard let bundle = makeTransitFactBundle(
            snapshot: snapshot,
            natal: natal,
            aspects: aspects,
            events: events,
            timeZone: timeZone,
            calendarDays: calendarDays,
            preset: preset
        ) else { return nil }
        return TransitContentPlanner.plan(bundle)
    }

    func makeTransitFactBundle(
        snapshot: ChartSnapshot?,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        timeZone: TimeZone,
        calendarDays: [TransitCalendarDay],
        rangeDays: Int = TransitTimelineContract.maximumRangeDays,
        preset: CalculationPreset
    ) -> TransitFactBundle? {
        guard let snapshot else { return nil }
        return TransitFactBundleBuilder.build(
            snapshot: snapshot,
            natal: natal,
            crossAspects: aspects,
            transitWindows: events.transitWindows,
            planetEvents: events.transitPlanetEvents,
            transitCalendar: calendarDays,
            rangeDays: rangeDays,
            preset: preset.rawValue,
            timeZone: timeZone
        )
    }
}
