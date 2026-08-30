import AstroCore
import Foundation

/// Upcoming astronomical events derived from the bundled ephemeris and used by
/// timeline, gantt and season cards. Every date is calculated, never invented.
struct ChartEventData: Equatable, Codable {
    var skyIngresses: [SkyIngress] = []
    var skyExactEvents: [SkyExactEvent] = []
    var skyStations: [SkyStation] = []
    var transitWindows: [TransitWindow] = []
    var transitPlanetEvents: [TransitPlanetEvent] = []
    var progressedMoon: ProgressedMoonWindow?
    var progressedTurningPoints: [ProgressedTurningPoint] = []
    var secondaryTargetDate: Date?
    var solarSeasons: [SolarSeason] = []
    var solarYearStart: Date?

    static let empty = ChartEventData()

    struct SkyIngress: Equatable, Codable {
        let body: CelestialBody
        let signIndex: Int
        let date: Date
        let nextDate: Date?
    }

    struct SkyExactEvent: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let date: Date
    }

    struct SkyStation: Equatable, Codable {
        let body: CelestialBody
        let date: Date
        let retrogradeAfter: Bool
    }

    struct TransitWindow: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let firstLongitude: Double
        let start: Date
        let exact: Date
        let end: Date
        let repeatExact: Date?
        let nextExact: Date?
        let passIndex: Int
        let passCount: Int
        let returning: Bool
    }

    struct TransitPlanetEvent: Equatable, Codable {
        enum Kind: String, Equatable, Codable {
            case signIngress
            case houseIngress
            case stationRetrograde
            case stationDirect
        }

        let body: CelestialBody
        let kind: Kind
        let date: Date
        let timeZoneIdentifier: String
        let fromIndex: Int?
        let toIndex: Int?
    }

    struct ProgressedMoonWindow: Equatable, Codable {
        let signIndex: Int
        let daysInSign: Int
        let nextIngress: Date
    }

    struct ProgressedTurningPoint: Equatable, Codable {
        let first: CelestialBody
        let second: CelestialBody
        let kind: AspectKind
        let exactDate: Date?
        let separationDegrees: Double
        let phase: AspectPhase
    }

    struct SolarSeason: Equatable, Codable {
        let index: Int
        let start: Date
        let end: Date
    }
}

struct TransitEphemerisSample: Equatable, Sendable {
    let date: Date
    let snapshot: ChartSnapshot
}

struct TransitExactOccurrence: Equatable {
    let date: Date
    let isReturn: Bool
}

extension ChartEventData.TransitWindow {
    /// The first exact contact that has not happened yet. Repeated contacts are
    /// kept distinct so the UI does not label the initial peak as a return.
    func upcomingExactOccurrence(after referenceDate: Date) -> TransitExactOccurrence? {
        [
            TransitExactOccurrence(date: exact, isReturn: false),
            repeatExact.map { TransitExactOccurrence(date: $0, isReturn: true) },
            nextExact.map { TransitExactOccurrence(date: $0, isReturn: true) },
        ]
        .compactMap { $0 }
        .filter { $0.date > referenceDate }
        .min { $0.date < $1.date }
    }
}

/// Builds `ChartEventData` from the already-computed snapshots. This runs on the
/// main refresh path so the cards are ready the moment the chart is shown.
enum ChartEventBuilder {
    static let transitAspectOrbDegrees = 3.0

    static func build(
        calculator: SwissEphemerisCalculator,
        skyAnchor: Date,
        transitAnchor: Date,
        secondaryTargetDate: Date,
        birthDate: Date,
        location: GeographicLocation,
        skySnapshot: ChartSnapshot,
        skyPreset: CalculationPreset,
        transitNatal: ChartSnapshot,
        transitPreset: CalculationPreset,
        transitRangeDays: Int,
        transitSamples: [TransitEphemerisSample],
        timeZone: TimeZone,
        transitAspects: [ChartAspect],
        progressedSnapshot: ChartSnapshot,
        progressedAspects: [ChartAspect],
        solarReturnMoment: Date?
    ) async throws -> ChartEventData {
        var data = ChartEventData()
        data.secondaryTargetDate = secondaryTargetDate

        // 1. Sky sign changes: next ingresses of the fast-moving bodies,
        //    keeping at most two Moon rows so the card stays varied.
        let ingressBodies: [CelestialBody] = [.moon, .mercury, .venus, .sun, .mars]
        var pending: [(body: CelestialBody, date: Date)] = []
        for body in ingressBodies {
            if let date = try? await calculator.nextSignIngress(for: body, after: skyAnchor) {
                pending.append((body, date))
            }
        }
        pending.sort { $0.date < $1.date }
        var moonRows = 0
        for item in pending {
            guard data.skyIngresses.count < 4 else { break }
            if item.body == .moon, moonRows >= 2 { continue }
            if item.body == .moon { moonRows += 1 }
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: item.date, location: location),
                preset: skyPreset
            )
            let signIndex = snapshot.point(item.body)?.signIndex ?? 0
            let nextDate = (try? await calculator.nextSignIngress(for: item.body, after: item.date))
            data.skyIngresses.append(
                ChartEventData.SkyIngress(body: item.body, signIndex: signIndex, date: item.date, nextDate: nextDate)
            )
        }

        // 2. Sky exact events within the next 7 days, from the aspects already
        //    within orb in the current sky.
        var exactEvents: [ChartEventData.SkyExactEvent] = []
        for aspect in skySnapshot.aspects.prefix(8) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID),
                  let date = try? await calculator.nextSkyExactDate(
                      moving: first,
                      reference: second,
                      kind: aspect.kind,
                      after: skyAnchor
                  ),
                  date.timeIntervalSince(skyAnchor) <= 7 * 86_400
            else { continue }
            exactEvents.append(
                ChartEventData.SkyExactEvent(first: first, second: second, kind: aspect.kind, date: date)
            )
        }
        exactEvents.sort { $0.date < $1.date }
        data.skyExactEvents = Array(exactEvents.prefix(3))

        // 2b. True station dates for the bodies that can visibly station.
        // These power both upcoming events and retrograde deadlines.
        let stationBodies: [CelestialBody] = [.mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto]
        var stations: [ChartEventData.SkyStation] = []
        for body in stationBodies {
            guard let station = try? await calculator.nextStation(for: body, after: skyAnchor) else { continue }
            stations.append(.init(body: body, date: station.date, retrogradeAfter: station.retrogradeAfter))
        }
        data.skyStations = stations.sorted { $0.date < $1.date }

        var transitCalendar = Calendar(identifier: .gregorian)
        transitCalendar.timeZone = timeZone
        let transitRangeEnd = transitCalendar
            .date(byAdding: .day, value: transitRangeDays, to: transitAnchor)
            ?? transitAnchor.addingTimeInterval(Double(transitRangeDays) * 86_400)

        // 3. Transit windows for the strongest active transits: the exact peak,
        //    repeated passes, and the in-orb start and end dates.
        for aspect in transitAspects {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID)
            else { continue }
            let exact: Date
            switch aspect.phase {
            case .applying:
                guard let calculated = try? await calculator.nextTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    after: transitAnchor
                ) else { continue }
                exact = calculated
            case .exact:
                exact = transitAnchor
            case .separating:
                guard let calculated = try? await calculator.previousTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    before: transitAnchor
                ) else { continue }
                exact = calculated
            }
            guard let window = try? await calculator.transitNatalAspectWindow(
                moving: first,
                natalReferenceLongitude: aspect.secondLongitude,
                kind: aspect.kind,
                exactDate: exact,
                orbDegrees: transitAspectOrbDegrees
            ) else { continue }
            var previousExactDates: [Date] = []
            var previousCursor = exact.addingTimeInterval(-0.1 * 86_400)
            while previousExactDates.count < 2,
                  let previous = try? await calculator.previousTransitNatalExactDate(
                      moving: first,
                      natalReferenceLongitude: aspect.secondLongitude,
                      kind: aspect.kind,
                      before: previousCursor
                  ),
                  previous >= window.start
            {
                previousExactDates.append(previous)
                previousCursor = previous.addingTimeInterval(-0.1 * 86_400)
            }

            var repeatedExactDates: [Date] = []
            var searchCursor = exact.addingTimeInterval(0.1 * 86_400)
            let repeatSearchEnd = window.end
            while repeatedExactDates.count < 2,
                  let repeated = try? await calculator.nextTransitNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    after: searchCursor
                  ),
                  repeated <= repeatSearchEnd
            {
                repeatedExactDates.append(repeated)
                searchCursor = repeated.addingTimeInterval(0.1 * 86_400)
            }
            let repeatExact = repeatedExactDates.first
            let nextExact = repeatedExactDates.dropFirst().first
            let passIndex = previousExactDates.count + 1
            let passCount = previousExactDates.count + 1 + repeatedExactDates.count
            data.transitWindows.append(
                ChartEventData.TransitWindow(
                    first: first,
                    second: second,
                    kind: aspect.kind,
                    firstLongitude: aspect.firstLongitude,
                    start: window.start,
                    exact: exact,
                    end: window.end,
                    repeatExact: repeatExact,
                    nextExact: nextExact,
                    passIndex: passIndex,
                    passCount: passCount,
                    returning: passCount > 1
                )
            )
        }

        data.transitPlanetEvents = try await buildTransitPlanetEvents(
            calculator: calculator,
            anchor: transitAnchor,
            rangeEnd: transitRangeEnd,
            location: location,
            preset: transitPreset,
            natal: transitNatal,
            samples: transitSamples,
            timeZone: timeZone
        )

        // 4. Progressed Moon: how long it has already been in the current sign
        //    and when it next changes sign.
        if let moon = progressedSnapshot.point(.moon),
           let window = try? await calculator.progressionWindow(
               moving: .moon,
               at: progressedSnapshot.utcDate,
               signLabel: ""
           )
        {
            let enteredProgressedDate = progressedSnapshot.utcDate.addingTimeInterval(
                -window.daysInSign * 86_400
            )
            let enteredTargetDate = SwissEphemerisCalculator.secondaryTargetDate(
                birthDate: birthDate,
                progressedDate: enteredProgressedDate
            )
            let nextIngressTargetDate = SwissEphemerisCalculator.secondaryTargetDate(
                birthDate: birthDate,
                progressedDate: window.ingressDate
            )
            data.progressedMoon = ChartEventData.ProgressedMoonWindow(
                signIndex: moon.signIndex,
                daysInSign: max(
                    0,
                    Int(secondaryTargetDate.timeIntervalSince(enteredTargetDate) / 86_400)
                ),
                nextIngress: nextIngressTargetDate
            )
        }

        // 5. Progressed turning points: upcoming exact contacts with real months.
        for aspect in progressedAspects.prefix(3) {
            guard let first = CelestialBody(rawValue: aspect.firstID),
                  let second = CelestialBody(rawValue: aspect.secondID)
            else { continue }
            let exactDate: Date?
            switch aspect.phase {
            case .applying:
                exactDate = try? await calculator.nextProgressedNatalExactDate(
                    moving: first,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    birthDate: birthDate,
                    after: secondaryTargetDate,
                    maxYears: 8
                )
            case .exact:
                exactDate = secondaryTargetDate
            case .separating:
                exactDate = nil
            }
            data.progressedTurningPoints.append(
                ChartEventData.ProgressedTurningPoint(
                    first: first,
                    second: second,
                    kind: aspect.kind,
                    exactDate: exactDate,
                    separationDegrees: aspect.orbDegrees,
                    phase: aspect.phase
                )
            )
        }

        // 6. Solar return seasons: four three-month phases from the return moment.
        if let moment = solarReturnMoment {
            data.solarYearStart = moment
            let calendar = Calendar(identifier: .gregorian)
            for index in 0 ..< 4 {
                let start = calendar.date(byAdding: .month, value: index * 3, to: moment) ?? moment
                let end = calendar.date(byAdding: .month, value: (index + 1) * 3, to: moment) ?? moment
                data.solarSeasons.append(ChartEventData.SolarSeason(index: index, start: start, end: end))
            }
        }

        return data
    }

    private static func buildTransitPlanetEvents(
        calculator: SwissEphemerisCalculator,
        anchor: Date,
        rangeEnd: Date,
        location: GeographicLocation,
        preset: CalculationPreset,
        natal: ChartSnapshot,
        samples: [TransitEphemerisSample],
        timeZone: TimeZone
    ) async throws -> [ChartEventData.TransitPlanetEvent] {
        guard anchor < rangeEnd, samples.count > 1 else { return [] }
        var events: [ChartEventData.TransitPlanetEvent] = []
        for (firstSample, secondSample) in zip(samples, samples.dropFirst()) {
            let firstDate = firstSample.date
            let secondDate = secondSample.date
            guard secondDate >= anchor, firstDate <= rangeEnd else { continue }
            let firstSnapshot = firstSample.snapshot
            let secondSnapshot = secondSample.snapshot
            for firstPoint in firstSnapshot.points {
                guard let secondPoint = secondSnapshot.point(firstPoint.body) else { continue }
                if firstPoint.signIndex != secondPoint.signIndex {
                    let boundary = crossingBoundary(
                        from: firstPoint.longitudeDegrees,
                        to: secondPoint.longitudeDegrees,
                        candidates: stride(from: 0.0, to: 360.0, by: 30.0).map { $0 }
                    )
                    let date = try await refinedLongitudeCrossing(
                        calculator: calculator,
                        body: firstPoint.body,
                        boundary: boundary,
                        startLongitude: firstPoint.longitudeDegrees,
                        interval: DateInterval(start: firstDate, end: secondDate),
                        location: location,
                        preset: preset
                    )
                    events.append(
                        .init(
                            body: firstPoint.body,
                            kind: .signIngress,
                            date: date,
                            timeZoneIdentifier: timeZone.identifier,
                            fromIndex: firstPoint.signIndex,
                            toIndex: secondPoint.signIndex
                        )
                    )
                }

                let firstHouse = natal.house(containing: firstPoint.longitudeDegrees)
                let secondHouse = natal.house(containing: secondPoint.longitudeDegrees)
                if firstHouse != secondHouse {
                    let boundaryHouse = signedTravel(
                        from: firstPoint.longitudeDegrees,
                        to: secondPoint.longitudeDegrees
                    ) >= 0 ? secondHouse : firstHouse
                    let boundary = natal.houses.first { $0.number == boundaryHouse }?.cuspDegrees
                        ?? secondPoint.longitudeDegrees
                    let date = try await refinedLongitudeCrossing(
                        calculator: calculator,
                        body: firstPoint.body,
                        boundary: boundary,
                        startLongitude: firstPoint.longitudeDegrees,
                        interval: DateInterval(start: firstDate, end: secondDate),
                        location: location,
                        preset: preset
                    )
                    events.append(
                        .init(
                            body: firstPoint.body,
                            kind: .houseIngress,
                            date: date,
                            timeZoneIdentifier: timeZone.identifier,
                            fromIndex: firstHouse,
                            toIndex: secondHouse
                        )
                    )
                }

                let firstSpeed = firstPoint.position.longitudeSpeedDegreesPerDay
                let secondSpeed = secondPoint.position.longitudeSpeedDegreesPerDay
                if firstSpeed == 0 || secondSpeed == 0 || firstSpeed.sign != secondSpeed.sign {
                    let date = try await refinedStation(
                        calculator: calculator,
                        body: firstPoint.body,
                        interval: DateInterval(start: firstDate, end: secondDate),
                        location: location,
                        preset: preset
                    )
                    events.append(
                        .init(
                            body: firstPoint.body,
                            kind: secondSpeed < 0 ? .stationRetrograde : .stationDirect,
                            date: date,
                            timeZoneIdentifier: timeZone.identifier,
                            fromIndex: nil,
                            toIndex: nil
                        )
                    )
                }
            }
        }

        var seen = Set<String>()
        return events.sorted {
            if $0.date != $1.date { return $0.date < $1.date }
            if $0.body.rawValue != $1.body.rawValue { return $0.body.rawValue < $1.body.rawValue }
            return $0.kind.rawValue < $1.kind.rawValue
        }.filter { event in
            guard event.date >= anchor, event.date <= rangeEnd else { return false }
            let key = [
                event.body.rawValue,
                event.kind.rawValue,
                String(Int(event.date.timeIntervalSince1970.rounded())),
            ].joined(separator: ".")
            return seen.insert(key).inserted
        }
    }

    private static func refinedLongitudeCrossing(
        calculator: SwissEphemerisCalculator,
        body: CelestialBody,
        boundary: Double,
        startLongitude: Double,
        interval: DateInterval,
        location: GeographicLocation,
        preset: CalculationPreset
    ) async throws -> Date {
        try await bisectedDate(in: interval) { date in
            guard let longitude = try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: location),
                preset: preset
            ).point(body)?.longitudeDegrees else { return nil }
            return unwrapped(longitude, relativeTo: startLongitude)
                - unwrapped(boundary, relativeTo: startLongitude)
        } ?? interval.start
    }

    private static func refinedStation(
        calculator: SwissEphemerisCalculator,
        body: CelestialBody,
        interval: DateInterval,
        location: GeographicLocation,
        preset: CalculationPreset
    ) async throws -> Date {
        try await bisectedDate(in: interval) { date in
            try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: location),
                preset: preset
            ).point(body)?.position.longitudeSpeedDegreesPerDay
        } ?? interval.start
    }

    private static func bisectedDate(
        in interval: DateInterval,
        value: (Date) async throws -> Double?
    ) async throws -> Date? {
        guard var lowerValue = try await value(interval.start),
              let upperValue = try await value(interval.end)
        else { return nil }
        var lower = interval.start
        var upper = interval.end
        guard lowerValue == 0 || upperValue == 0 || lowerValue.sign != upperValue.sign else { return nil }
        for _ in 0 ..< 24 {
            let midpoint = lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
            guard let midpointValue = try await value(midpoint) else { return nil }
            if midpointValue == 0 { return midpoint }
            if lowerValue.sign == midpointValue.sign {
                lower = midpoint
                lowerValue = midpointValue
            } else {
                upper = midpoint
            }
        }
        return lower.addingTimeInterval(upper.timeIntervalSince(lower) / 2)
    }

    private static func crossingBoundary(
        from start: Double,
        to end: Double,
        candidates: [Double]
    ) -> Double {
        let travel = signedTravel(from: start, to: end)
        return candidates.min { lhs, rhs in
            let lhsDistance = abs(unwrapped(lhs, relativeTo: start) - start)
            let rhsDistance = abs(unwrapped(rhs, relativeTo: start) - start)
            if travel >= 0 {
                return (unwrapped(lhs, relativeTo: start) - start >= 0 ? lhsDistance : .greatestFiniteMagnitude)
                    < (unwrapped(rhs, relativeTo: start) - start >= 0 ? rhsDistance : .greatestFiniteMagnitude)
            }
            return (unwrapped(lhs, relativeTo: start) - start <= 0 ? lhsDistance : .greatestFiniteMagnitude)
                < (unwrapped(rhs, relativeTo: start) - start <= 0 ? rhsDistance : .greatestFiniteMagnitude)
        } ?? end
    }

    private static func unwrapped(_ longitude: Double, relativeTo reference: Double) -> Double {
        var value = longitude
        while value - reference > 180 { value -= 360 }
        while value - reference < -180 { value += 360 }
        return value
    }

    private static func signedTravel(from start: Double, to end: Double) -> Double {
        unwrapped(end, relativeTo: start) - start
    }
}

// MARK: - Consumer date formatting

extension Date {
    /// Short event label such as "Aug 2" / "8月2日".
    func shortEventDate(language: AppLanguage, timeZone: TimeZone = .current) -> String {
        LocalizedFormatters.shortDate(self, language: language, timeZone: timeZone)
    }

    /// Month-year label such as "Sep 2026" / "2026年9月".
    func shortEventMonthYear(language: AppLanguage, timeZone: TimeZone = .current) -> String {
        LocalizedFormatters.monthYear(self, language: language, timeZone: timeZone)
    }

    /// Compact range such as "Jul 18–Nov 6" / "7月18日–11月6日".
    func shortEventRange(to end: Date, language: AppLanguage, timeZone: TimeZone = .current) -> String {
        "\(shortEventDate(language: language, timeZone: timeZone))–\(end.shortEventDate(language: language, timeZone: timeZone))"
    }
}
