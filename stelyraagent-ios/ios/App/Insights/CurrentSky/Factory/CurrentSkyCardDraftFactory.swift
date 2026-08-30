import AstroCore
import Foundation

enum CurrentSkyCardDraftFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.skyCards(
            context.snapshot,
            events: context.events,
            language: context.language,
            timeZone: context.timeZone
        )
    }
}

extension InsightFactory {
    static func skyCards(
        _ snapshot: ChartSnapshot,
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let top = Array(snapshot.aspects.prefix(3))
        let balance = counts(snapshot.aspects)
        let retrogrades = snapshot.points.filter(\.retrograde)
        let phase = phaseAngle(snapshot)
        let activity = signalDensity(snapshot.aspects, limit: 8)
        let cycleAspects = cycleLeaders(snapshot.aspects)
        let elementScores = elementBalance(snapshot)
        let modalityScores = modalityBalance(snapshot)
        let moon = snapshot.point(.moon)
        let moonHouse = snapshot.house(containing: moon?.longitudeDegrees ?? 0)
        let overviewFacts: [InsightFact] = [
            top.first.map { fact(localized("insight.current-sky.dominant-pattern", language: language), aspectTitle($0, language: language), tone($0.kind)) },
            fact(localized("insight.current-sky.review-cycles", language: language), "\(retrogrades.count)", .transition),
            fact(localized("insight.current-sky.atmosphere", language: language), activityLabel(activity, language: language)),
        ].compactMap { $0 }
        let moonFacts: [InsightFact] = [
            moon.map { fact(localized("insight.current-sky.moon-sign", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            moonHouse > 0 ? fact(localized("insight.current-sky.moon-area", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition) : nil,
            fact(localized("insight.current-sky.lunar-phase", language: language), progressedPhaseName(phase, language: language)),
        ].compactMap { $0 }
        let patternFacts: [InsightFact] = [
            fact(localized("insight.current-sky.support", language: language), "\(balance.supportive)", .supportive),
            fact(localized("insight.current-sky.pressure", language: language), "\(balance.challenging)", .challenging),
            dominantBodies(snapshot.aspects, language: language).map { fact(localized("insight.current-sky.focus", language: language), $0, .transition) },
        ].compactMap { $0 }

        return [
            card( id: "sky-overview",
                title: localized("insight.current-sky.sky-at-a-glance", language: language),
                icon: "◉", visual: .skyOverview(
                    phase: phase,
                    activity: activity,
                    cycles: cycleAspects.map { $0?.strength ?? 0 }
                ),
                facts: overviewFacts,
                language: language
            ),
            card( id: "moon-now",
                title: localized("insight.current-sky.moon-now", language: language),
                icon: "☽", visual: .phaseDial(phase: phase, illumination: moonIllumination(snapshot)),
                facts: moonFacts,
                language: language
            ),
            card( id: "aspect-pattern",
                title: localized("insight.current-sky.major-aspect-pattern", language: language),
                icon: "◇", visual: .structureMap(
                    supportive: balance.supportive,
                    challenging: balance.challenging,
                    neutral: balance.neutral
                ),
                facts: patternFacts,
                language: language
            ),
            card( id: "planetary-motion",
                title: localized("insight.current-sky.planetary-motion", language: language),
                icon: "↺", visual: .motionList,
                facts: motionFacts(snapshot, language: language),
                language: language
            ),
            card( id: "sign-changes",
                title: localized("insight.current-sky.sign-changes", language: language),
                icon: "⇢", visual: .eventTimeline,
                facts: skyIngressFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
            card( id: "element-climate",
                title: localized("insight.current-sky.element-mode-climate", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, modalityScores: modalityScores, language: language),
                language: language
            ),
            card( id: "upcoming-7-days",
                title: localized("insight.current-sky.upcoming-7-days", language: language),
                icon: "▦", visual: .dateEvents,
                facts: skyUpcomingFacts(
                    events,
                    anchor: snapshot.utcDate,
                    fallback: top,
                    language: language,
                    timeZone: timeZone
                ),
                language: language
            ),
        ]
    }

    // MARK: - Transits (6)

    static func counts(_ aspects: [ChartAspect]) -> (supportive: Int, challenging: Int, neutral: Int) {
        let supportive = aspects.filter { $0.kind.supportive }.count
        let challenging = aspects.filter { $0.kind.challenging }.count
        return (supportive, challenging, max(0, aspects.count - supportive - challenging))
    }

    static func activityLabel(_ value: Int, language: AppLanguage) -> String {
        switch value {
        case 0 ... 20: localized("insight.current-sky.low", language: language)
        case 21 ... 45: localized("insight.current-sky.moderate", language: language)
        case 46 ... 70: localized("insight.current-sky.high", language: language)
        default: localized("insight.current-sky.very-high", language: language)
        }
    }

    static func signalDensity(_ aspects: [ChartAspect], limit: Int) -> Int {
        guard limit > 0 else { return 0 }
        let total = aspects.prefix(limit).reduce(0) { $0 + $1.strength }
        return Int(min(1, total / Double(limit)) * 100)
    }

    static func motionFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
        snapshot.points.map { point in
            fact(
                bodyName(point.body, language: language),
                Zodiac.position(point, language: language),
                point.retrograde ? .challenging : .neutral,
                note: motionLabel(point, language: language),
                symbol: point.body.symbol
            )
        }
    }

    static func cycleLeaders(_ aspects: [ChartAspect]) -> [ChartAspect?] {
        let long = aspects.first { $0.firstID == CelestialBody.saturn.rawValue || $0.firstID == CelestialBody.uranus.rawValue || $0.firstID == CelestialBody.neptune.rawValue || $0.firstID == CelestialBody.pluto.rawValue }
        let current = aspects.first { $0.firstID == CelestialBody.jupiter.rawValue }
        let daily = aspects.first { $0.firstID == CelestialBody.moon.rawValue || $0.firstID == CelestialBody.mercury.rawValue }
        return [long ?? aspects.first, current, daily ?? aspects.first]
    }

    static func moonIllumination(_ snapshot: ChartSnapshot) -> Double {
        LunarPhaseGeometry.illuminationFraction(elongation: phaseAngle(snapshot))
    }

    static func skyIngressFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let rows = events.skyIngresses.prefix(4)
        guard !rows.isEmpty else {
            return timelineFacts(fallback, language: language)
        }
        return rows.map { ingress in
            let title = localizedTemplate("dynamic.e2ccdb4ffa", substitutions: ["value1": String(describing: bodyName(ingress.body, language: language)), "value2": String(describing: Zodiac.name(index: ingress.signIndex, language: language))], language: language)
            let note = ingress.nextDate.map {
                localizedTemplate("dynamic.3abdfb89d0", substitutions: ["value1": String(describing: $0.shortEventDate(language: language, timeZone: timeZone))], language: language)
            }
            return fact(
                ingress.date.shortEventDate(language: language, timeZone: timeZone),
                title,
                .transition,
                note: note
            )
        }
    }

    static func skyUpcomingFacts(
        _ events: ChartEventData,
        anchor: Date,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        var rows: [(date: Date, title: String, note: String?)] = []
        for ingress in events.skyIngresses {
            let interval = ingress.date.timeIntervalSince(anchor)
            guard interval >= 0, interval <= 7 * 86_400 else { continue }
            rows.append((
                ingress.date,
                localizedTemplate("dynamic.e2ccdb4ffa", substitutions: ["value1": String(describing: bodyName(ingress.body, language: language)), "value2": String(describing: Zodiac.name(index: ingress.signIndex, language: language))], language: language),
                nil
            ))
        }
        for exact in events.skyExactEvents {
            let interval = exact.date.timeIntervalSince(anchor)
            guard interval >= 0, interval <= 7 * 86_400 else { continue }
            rows.append((exact.date, skyExactEventTitle(exact, language: language), nil))
        }
        for station in events.skyStations {
            let interval = station.date.timeIntervalSince(anchor)
            guard interval >= 0, interval <= 7 * 86_400 else { continue }
            let status = localized(
                station.retrogradeAfter ? "today.stations-retrograde" : "today.stations-direct",
                language: language
            )
            rows.append((
                station.date,
                "\(bodyName(station.body, language: language)) · \(status)",
                nil
            ))
        }
        rows.sort { $0.date < $1.date }
        let topRows = rows.prefix(3)
        guard !topRows.isEmpty else {
            return timelineFacts(fallback, language: language)
        }
        return topRows.map { row in
            fact(
                row.date.shortEventDate(language: language, timeZone: timeZone),
                row.title,
                .transition,
                note: row.note
            )
        }
    }

    static func skyExactEventTitle(
        _ event: ChartEventData.SkyExactEvent,
        language: AppLanguage
    ) -> String {
        let sunMoonPair = (event.first == .sun && event.second == .moon)
            || (event.first == .moon && event.second == .sun)
        if sunMoonPair {
            if event.kind == .opposition {
                return localized("insight.current-sky.full-moon", language: language)
            }
            if event.kind == .conjunction {
                return localized("insight.current-sky.new-moon", language: language)
            }
        }
        return "\(bodyName(event.first, language: language)) \(event.kind.symbol) \(bodyName(event.second, language: language))"
    }
}
