import AstroCore
import Foundation

struct TodayEngine {
    private struct Sample {
        let date: Date
        let sky: ChartSnapshot
        let transit: ChartSnapshot
        let transits: [ChartAspect]
    }

    private struct Candidate {
        enum Kind {
            case exact(ChartAspect)
            case enteredOrb(ChartAspect)
            case leftOrb(ChartAspect)
            case signIngress(CelestialBody, Int, boundary: Double)
            case houseIngress(CelestialBody, Int, boundary: Double)
            case station(CelestialBody, retrograde: Bool)
        }

        let id: String
        let source: DailySignal.Source
        let kind: Kind
        let date: Date
        let tone: InsightTone
        let priority: Int
        let bracket: DateInterval
    }

    let calculator: SwissEphemerisCalculator
    let profile: UserProfile
    let natal: ChartSnapshot
    let skyPreset: CalculationPreset
    let transitPreset: CalculationPreset
    let language: AppLanguage
    let content: ContentProvider

    func scan(
        containing date: Date,
        skyLimit: Int = 3,
        transitLimit: Int = 3
    ) async throws -> [DailySignal] {
        let interval = localDay(containing: date)
        let samples = try await hourlySamples(interval)
        guard samples.count >= 2 else { return [] }

        var candidates: [Candidate] = []
        for index in 0 ..< samples.count - 1 {
            let first = samples[index]
            let second = samples[index + 1]
            candidates.append(contentsOf: aspectCandidates(first, second, source: .sky))
            candidates.append(contentsOf: aspectCandidates(first, second, source: .transit))
            candidates.append(contentsOf: pointCandidates(first, second))
        }

        var seen = Set<String>()
        let unique = candidates
            .sorted {
                if $0.priority != $1.priority { return $0.priority > $1.priority }
                return $0.date < $1.date
            }
            .filter { seen.insert($0.id).inserted }
        // Keep public-sky and personal-transit candidates independent. Mixing
        // them before the priority cut allowed a personal exact transit to
        // evict every sky row; Today Timeline then (correctly) filtered to sky
        // and rendered an incorrect empty state.
        let selected = selectCandidates(
            unique.filter { $0.source == .sky },
            limit: skyLimit
        ) + selectCandidates(
            unique.filter { $0.source == .transit },
            limit: transitLimit
        )
        let chronological = selected
            .sorted { $0.date < $1.date }
        var signals: [DailySignal] = []
        for candidate in chronological {
            let refinedCandidate = try await refined(candidate)
            signals.append(
                makeSignal(
                    refinedCandidate,
                    peakDate: try await peakDate(for: refinedCandidate)
                )
            )
        }
        return signals
    }

    private func selectCandidates(_ candidates: [Candidate], limit: Int) -> [Candidate] {
        guard limit > 0 else { return [] }
        let major = candidates.filter { $0.priority >= 90 }
        return Array((major.isEmpty ? candidates : major).prefix(limit))
    }

    private func localDay(containing date: Date) -> DateInterval {
        LocalCalendarDay.interval(
            containing: date,
            timeZone: TimeZone(identifier: profile.timezoneID) ?? .current
        )
    }

    private func hourlySamples(_ interval: DateInterval) async throws -> [Sample] {
        var result: [Sample] = []
        var date = interval.start
        while date <= interval.end {
            let input = NatalInput(utcDate: date, location: profile.location)
            let sky = try await calculator.calculateSnapshot(input, preset: skyPreset)
            let transitMoving = skyPreset == transitPreset
                ? sky
                : try await calculator.calculateSnapshot(input, preset: transitPreset)
            result.append(
                Sample(
                    date: date,
                    sky: sky,
                    transit: transitMoving,
                    transits: SwissEphemerisCalculator.compare(
                        moving: transitMoving,
                        reference: natal,
                        orbDegrees: 3
                    )
                )
            )
            date = min(interval.end, date.addingTimeInterval(3_600))
            if date == result.last?.date { break }
        }
        return result
    }

    private func aspectCandidates(
        _ first: Sample,
        _ second: Sample,
        source: DailySignal.Source
    ) -> [Candidate] {
        let firstAspects = Dictionary(uniqueKeysWithValues: aspects(first, source: source).map { ($0.id, $0) })
        let secondAspects = Dictionary(uniqueKeysWithValues: aspects(second, source: source).map { ($0.id, $0) })
        let ids = Set(firstAspects.keys).union(secondAspects.keys)
        var result: [Candidate] = []

        for id in ids {
            guard let aspect = firstAspects[id] ?? secondAspects[id] else { continue }
            let firstError = signedError(aspect, sample: first, source: source)
            let secondError = signedError(aspect, sample: second, source: source)
            let prefix = source == .sky ? "sky" : "transit"
            let orb = source == .sky ? skyPreset.defaultOrbDegrees : 3

            if let fraction = exactCrossingFraction(
                aspect,
                first: first,
                second: second,
                source: source
            ) {
                let eventDate = first.date.addingTimeInterval(
                    second.date.timeIntervalSince(first.date) * fraction
                )
                result.append(
                    Candidate(
                        id: "\(prefix)-exact-\(id)-\(eventKey(eventDate))",
                        source: source,
                        kind: .exact(aspect),
                        date: eventDate,
                        tone: tone(aspect.kind),
                        priority: 100,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            } else if let firstError, let secondError,
                      abs(firstError) > orb, abs(secondError) <= orb
            {
                let eventDate = interpolatedDate(
                    first.date,
                    second.date,
                    firstValue: abs(firstError) - orb,
                    secondValue: abs(secondError) - orb
                )
                result.append(
                    Candidate(
                        id: "\(prefix)-enter-orb-\(id)-\(eventKey(eventDate))",
                        source: source,
                        kind: .enteredOrb(aspect),
                        date: eventDate,
                        tone: tone(aspect.kind),
                        priority: 55,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            } else if let firstError, let secondError,
                      abs(firstError) <= orb, abs(secondError) > orb
            {
                let eventDate = interpolatedDate(
                    first.date,
                    second.date,
                    firstValue: abs(firstError) - orb,
                    secondValue: abs(secondError) - orb
                )
                result.append(
                    Candidate(
                        id: "\(prefix)-leave-orb-\(id)-\(eventKey(eventDate))",
                        source: source,
                        kind: .leftOrb(aspect),
                        date: eventDate,
                        tone: tone(aspect.kind),
                        priority: 50,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            }
        }
        return result
    }

    private func pointCandidates(_ first: Sample, _ second: Sample) -> [Candidate] {
        var result: [Candidate] = []
        for firstPoint in first.sky.points {
            guard let secondPoint = second.sky.point(firstPoint.body) else { continue }
            if firstPoint.signIndex != secondPoint.signIndex {
                let boundary = signBoundary(start: firstPoint, end: secondPoint)
                let eventDate = longitudeCrossingDate(
                    start: firstPoint.longitudeDegrees,
                    end: secondPoint.longitudeDegrees,
                    boundary: boundary,
                    startDate: first.date,
                    endDate: second.date
                )
                result.append(
                    Candidate(
                        id: "sky-ingress-\(firstPoint.id)-\(secondPoint.signIndex)-\(eventKey(eventDate))",
                        source: .sky,
                        kind: .signIngress(firstPoint.body, secondPoint.signIndex, boundary: boundary),
                        date: eventDate,
                        tone: .transition,
                        priority: 90,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            }
            let firstSpeed = firstPoint.position.longitudeSpeedDegreesPerDay
            let secondSpeed = secondPoint.position.longitudeSpeedDegreesPerDay
            if firstSpeed == 0 || secondSpeed == 0 || firstSpeed.sign != secondSpeed.sign {
                let eventDate = interpolatedDate(
                    first.date,
                    second.date,
                    firstValue: firstSpeed,
                    secondValue: secondSpeed
                )
                result.append(
                    Candidate(
                        id: "sky-station-\(firstPoint.id)-\(secondSpeed < 0 ? "retrograde" : "direct")-\(eventKey(eventDate))",
                        source: .sky,
                        kind: .station(firstPoint.body, retrograde: secondSpeed < 0),
                        date: eventDate,
                        tone: .transition,
                        priority: 95,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            }

        }

        for firstPoint in first.transit.points {
            guard let secondPoint = second.transit.point(firstPoint.body) else { continue }
            let firstHouse = natal.house(containing: firstPoint.longitudeDegrees)
            let secondHouse = natal.house(containing: secondPoint.longitudeDegrees)
            if firstHouse != secondHouse {
                let delta = signedTravel(
                    from: firstPoint.longitudeDegrees,
                    to: secondPoint.longitudeDegrees
                )
                let boundaryHouse = delta >= 0 ? secondHouse : firstHouse
                let boundary = natal.houses.first { $0.number == boundaryHouse }?.cuspDegrees
                    ?? secondPoint.longitudeDegrees
                let eventDate = longitudeCrossingDate(
                    start: firstPoint.longitudeDegrees,
                    end: secondPoint.longitudeDegrees,
                    boundary: boundary,
                    startDate: first.date,
                    endDate: second.date
                )
                result.append(
                    Candidate(
                        id: "transit-house-\(firstPoint.id)-\(secondHouse)-\(eventKey(eventDate))",
                        source: .transit,
                        kind: .houseIngress(firstPoint.body, secondHouse, boundary: boundary),
                        date: eventDate,
                        tone: .transition,
                        priority: 80,
                        bracket: DateInterval(start: first.date, end: second.date)
                    )
                )
            }
        }
        return result
    }

    private func aspects(_ sample: Sample, source: DailySignal.Source) -> [ChartAspect] {
        source == .sky ? sample.sky.aspects : sample.transits
    }

    private func signedError(
        _ aspect: ChartAspect,
        sample: Sample,
        source: DailySignal.Source
    ) -> Double? {
        let firstLongitude: Double?
        let secondLongitude: Double?
        if source == .sky {
            firstLongitude = sample.sky.points.first { $0.id == aspect.firstID }?.longitudeDegrees
            secondLongitude = sample.sky.points.first { $0.id == aspect.secondID }?.longitudeDegrees
        } else {
            firstLongitude = sample.transit.points.first { $0.id == aspect.firstID }?.longitudeDegrees
            secondLongitude = natal.points.first { $0.id == aspect.secondID }?.longitudeDegrees
        }
        guard let firstLongitude, let secondLongitude else { return nil }
        let raw = abs(firstLongitude - secondLongitude).truncatingRemainder(dividingBy: 360)
        let separation = min(raw, 360 - raw)
        return separation - aspect.kind.angleDegrees
    }

    private func exactCrossingFraction(
        _ aspect: ChartAspect,
        first: Sample,
        second: Sample,
        source: DailySignal.Source
    ) -> Double? {
        guard let firstSeparation = directedSeparation(aspect, sample: first, source: source),
              let secondSeparation = directedSeparation(aspect, sample: second, source: source)
        else {
            return nil
        }
        return AspectEventInterpolation.exactCrossingFraction(
            from: firstSeparation,
            to: secondSeparation,
            aspectAngleDegrees: aspect.kind.angleDegrees
        )
    }

    private func directedSeparation(
        _ aspect: ChartAspect,
        sample: Sample,
        source: DailySignal.Source
    ) -> Double? {
        directedSeparation(
            aspect,
            moving: source == .sky ? sample.sky : sample.transit,
            source: source
        )
    }

    private func directedSeparation(
        _ aspect: ChartAspect,
        moving: ChartSnapshot,
        source: DailySignal.Source
    ) -> Double? {
        let firstLongitude: Double?
        let secondLongitude: Double?
        if source == .sky {
            firstLongitude = moving.points.first { $0.id == aspect.firstID }?.longitudeDegrees
            secondLongitude = moving.points.first { $0.id == aspect.secondID }?.longitudeDegrees
        } else {
            firstLongitude = moving.points.first { $0.id == aspect.firstID }?.longitudeDegrees
            secondLongitude = natal.points.first { $0.id == aspect.secondID }?.longitudeDegrees
        }
        guard let firstLongitude, let secondLongitude else { return nil }
        return signedTravel(from: secondLongitude, to: firstLongitude)
    }

    private func refined(_ candidate: Candidate) async throws -> Candidate {
        let date: Date
        switch candidate.kind {
        case let .exact(aspect):
            date = try await refineExact(aspect, source: candidate.source, in: candidate.bracket)
                ?? candidate.date
        case let .enteredOrb(aspect), let .leftOrb(aspect):
            let orb = candidate.source == .sky ? skyPreset.defaultOrbDegrees : 3
            date = try await bisectedDate(in: candidate.bracket) { date in
                guard let error = try await aspectError(
                    aspect,
                    at: date,
                    source: candidate.source
                ) else {
                    return nil
                }
                return abs(error) - orb
            } ?? candidate.date
        case let .station(body, _):
            date = try await bisectedDate(in: candidate.bracket) { date in
                try await movingSnapshot(at: date, source: .sky)
                    .point(body)?
                    .position.longitudeSpeedDegreesPerDay
            } ?? candidate.date
        case let .signIngress(body, _, boundary):
            let startSnapshot = try await movingSnapshot(at: candidate.bracket.start, source: .sky)
            let startLongitude = startSnapshot.point(body)?.longitudeDegrees
            date = try await bisectedDate(in: candidate.bracket) { date in
                guard let startLongitude,
                      let longitude = try await movingSnapshot(at: date, source: .sky)
                        .point(body)?
                        .longitudeDegrees
                else {
                    return nil
                }
                var unwrapped = longitude
                while unwrapped - startLongitude > 180 { unwrapped -= 360 }
                while unwrapped - startLongitude < -180 { unwrapped += 360 }
                var target = boundary
                while target - startLongitude > 180 { target -= 360 }
                while target - startLongitude < -180 { target += 360 }
                return unwrapped - target
            } ?? candidate.date
        case let .houseIngress(body, _, boundary):
            let startSnapshot = try await movingSnapshot(at: candidate.bracket.start, source: .transit)
            let startLongitude = startSnapshot.point(body)?.longitudeDegrees
            date = try await bisectedDate(in: candidate.bracket) { date in
                guard let startLongitude,
                      let longitude = try await movingSnapshot(at: date, source: .transit)
                        .point(body)?
                        .longitudeDegrees
                else {
                    return nil
                }
                var unwrapped = longitude
                while unwrapped - startLongitude > 180 { unwrapped -= 360 }
                while unwrapped - startLongitude < -180 { unwrapped += 360 }
                var target = boundary
                while target - startLongitude > 180 { target -= 360 }
                while target - startLongitude < -180 { target += 360 }
                return unwrapped - target
            } ?? candidate.date
        }
        return Candidate(
            id: candidate.id,
            source: candidate.source,
            kind: candidate.kind,
            date: date,
            tone: candidate.tone,
            priority: candidate.priority,
            bracket: candidate.bracket
        )
    }

    private func refineExact(
        _ aspect: ChartAspect,
        source: DailySignal.Source,
        in interval: DateInterval
    ) async throws -> Date? {
        let firstSnapshot = try await movingSnapshot(at: interval.start, source: source)
        let secondSnapshot = try await movingSnapshot(at: interval.end, source: source)
        guard let first = directedSeparation(aspect, moving: firstSnapshot, source: source),
              var second = directedSeparation(aspect, moving: secondSnapshot, source: source),
              let fraction = AspectEventInterpolation.exactCrossingFraction(
                  from: first,
                  to: second,
                  aspectAngleDegrees: aspect.kind.angleDegrees
              )
        else {
            return nil
        }
        while second - first > 180 { second -= 360 }
        while second - first < -180 { second += 360 }
        let target = first + (second - first) * fraction

        return try await bisectedDate(in: interval) { date in
            guard var separation = try await directedSeparation(
                aspect,
                moving: movingSnapshot(at: date, source: source),
                source: source
            ) else {
                return nil
            }
            while separation - first > 180 { separation -= 360 }
            while separation - first < -180 { separation += 360 }
            return separation - target
        }
    }

    private func aspectError(
        _ aspect: ChartAspect,
        at date: Date,
        source: DailySignal.Source
    ) async throws -> Double? {
        guard let separation = try await directedSeparation(
            aspect,
            moving: movingSnapshot(at: date, source: source),
            source: source
        ) else {
            return nil
        }
        return abs(separation) - aspect.kind.angleDegrees
    }

    private func movingSnapshot(
        at date: Date,
        source: DailySignal.Source
    ) async throws -> ChartSnapshot {
        try await calculator.calculateSnapshot(
            NatalInput(utcDate: date, location: profile.location),
            preset: source == .sky ? skyPreset : transitPreset
        )
    }

    private func bisectedDate(
        in interval: DateInterval,
        value: (Date) async throws -> Double?
    ) async throws -> Date? {
        var lowerDate = interval.start
        var upperDate = interval.end
        guard var lowerValue = try await value(lowerDate),
              let initialUpperValue = try await value(upperDate)
        else {
            return nil
        }
        if lowerValue == 0 { return lowerDate }
        if initialUpperValue == 0 { return upperDate }
        guard lowerValue.sign != initialUpperValue.sign else { return nil }

        for _ in 0 ..< 7 {
            let middleDate = midpoint(lowerDate, upperDate)
            guard let middleValue = try await value(middleDate) else { return nil }
            if middleValue == 0 { return middleDate }
            if lowerValue.sign == middleValue.sign {
                lowerDate = middleDate
                lowerValue = middleValue
            } else {
                upperDate = middleDate
            }
        }
        return midpoint(lowerDate, upperDate)
    }

    private func interpolatedDate(
        _ start: Date,
        _ end: Date,
        firstValue: Double,
        secondValue: Double
    ) -> Date {
        let denominator = abs(firstValue) + abs(secondValue)
        let fraction = denominator > 0 ? abs(firstValue) / denominator : 0.5
        return start.addingTimeInterval(end.timeIntervalSince(start) * fraction)
    }

    private func midpoint(_ start: Date, _ end: Date) -> Date {
        start.addingTimeInterval(end.timeIntervalSince(start) / 2)
    }

    private func eventKey(_ date: Date) -> Int {
        Int(date.timeIntervalSince1970 / 60)
    }

    private func signBoundary(start: ChartPoint, end: ChartPoint) -> Double {
        let delta = signedTravel(from: start.longitudeDegrees, to: end.longitudeDegrees)
        return delta >= 0
            ? Double(end.signIndex * 30)
            : Double(start.signIndex * 30)
    }

    private func longitudeCrossingDate(
        start: Double,
        end: Double,
        boundary: Double,
        startDate: Date,
        endDate: Date
    ) -> Date {
        let delta = signedTravel(from: start, to: end)
        guard abs(delta) > 0.000_000_1 else { return midpoint(startDate, endDate) }
        var target = boundary
        if delta > 0, target < start { target += 360 }
        if delta < 0, target > start { target -= 360 }
        let fraction = max(0, min(1, (target - start) / delta))
        return startDate.addingTimeInterval(endDate.timeIntervalSince(startDate) * fraction)
    }

    private func signedTravel(from start: Double, to end: Double) -> Double {
        var value = (end - start).truncatingRemainder(dividingBy: 360)
        if value > 180 { value -= 360 }
        if value < -180 { value += 360 }
        return value
    }

    private func peakDate(for candidate: Candidate) async throws -> Date? {
        switch candidate.kind {
        case .exact:
            return candidate.date
        case let .enteredOrb(aspect) where candidate.source == .transit:
            guard let body = CelestialBody(rawValue: aspect.firstID) else { return nil }
            return try? await calculator.nextTransitNatalExactDate(
                moving: body,
                natalReferenceLongitude: aspect.secondLongitude,
                kind: aspect.kind,
                after: candidate.date
            )
        default:
            return nil
        }
    }

    private func makeSignal(_ candidate: Candidate, peakDate: Date?) -> DailySignal {
        let copy: (summary: String, detail: String)?
        let factTitle: String
        switch candidate.kind {
        case let .exact(aspect):
            copy = content.copyIfPresent(
                key: "today.event.connection.peak",
                variables: connectionVariables(aspect)
            )
            factTitle = aspectFactTitle(aspect, source: candidate.source)
        case let .enteredOrb(aspect):
            copy = content.copyIfPresent(
                key: "today.event.connection.building",
                variables: connectionVariables(aspect)
            )
            factTitle = aspectFactTitle(aspect, source: candidate.source)
        case let .leftOrb(aspect):
            copy = content.copyIfPresent(
                key: "today.event.connection.easing",
                variables: connectionVariables(aspect)
            )
            factTitle = aspectFactTitle(aspect, source: candidate.source)
        case let .signIngress(body, sign, _):
            copy = content.copyIfPresent(
                key: "today.event.style.change",
                variables: [
                    "theme": ConsumerCopy.bodyTheme(body, language: language),
                    "style": ConsumerCopy.style(signIndex: sign, language: language),
                ]
            )
            factTitle = localizedTemplate(
                "today.event-fact.sign-ingress",
                substitutions: [
                    "body": bodyName(body, language: language),
                    "sign": Zodiac.name(index: sign, language: language),
                ],
                language: language
            )
        case let .houseIngress(body, house, _):
            copy = content.copyIfPresent(
                key: "today.event.area.change",
                variables: [
                    "theme": ConsumerCopy.bodyTheme(body, language: language),
                    "area": ConsumerCopy.lifeArea(house, language: language),
                ]
            )
            factTitle = localizedTemplate(
                "today.event-fact.house-ingress",
                substitutions: [
                    "body": bodyName(body, language: language),
                    "house": ConsumerCopy.lifeArea(house, language: language),
                ],
                language: language
            )
        case let .station(body, retrograde):
            copy = content.copyIfPresent(
                key: retrograde
                    ? "today.event.motion.review"
                    : "today.event.motion.forward",
                variables: [
                    "theme": ConsumerCopy.bodyTheme(body, language: language),
                ]
            )
            factTitle = localizedTemplate(
                retrograde
                    ? "today.event-fact.stations-retrograde"
                    : "today.event-fact.stations-direct",
                substitutions: ["body": bodyName(body, language: language)],
                language: language
            )
        }

        return DailySignal(
            id: candidate.id,
            category: .happeningToday,
            source: candidate.source,
            title: factTitle,
            subtitle: copy?.detail ?? "",
            tone: candidate.tone,
            strength: candidate.priority,
            eventDate: candidate.date,
            peakDate: peakDate
        )
    }

    private func connectionVariables(_ aspect: ChartAspect) -> [String: String] {
        [
            "first": bodyName(
                CelestialBody(rawValue: aspect.firstID) ?? .sun,
                language: language
            ),
            "second": bodyName(
                CelestialBody(rawValue: aspect.secondID) ?? .moon,
                language: language
            ),
        ]
    }

    private func aspectFactTitle(_ aspect: ChartAspect, source: DailySignal.Source) -> String {
        let first = bodyName(
            CelestialBody(rawValue: aspect.firstID) ?? .sun,
            language: language
        )
        let second = bodyName(
            CelestialBody(rawValue: aspect.secondID) ?? .moon,
            language: language
        )
        return localizedTemplate(
            source == .transit
                ? "today.event-fact.transit-aspect"
                : "today.event-fact.sky-aspect",
            substitutions: [
                "first": first,
                "aspect": aspectKindName(aspect.kind, language: language),
                "second": second,
            ],
            language: language
        )
    }
}
