import AstroCore
import Foundation

enum SecondaryCardDraftFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.secondaryCards(
            context.snapshot,
            natal: context.natal,
            aspects: context.aspects,
            events: context.events,
            language: context.language,
            timeZone: context.timeZone
        )
    }
}

extension InsightFactory {
    static func secondaryCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let moon = snapshot.point(.moon)
        let sun = snapshot.point(.sun)
        let natalSun = natal?.point(.sun)
        let top = Array(aspects.prefix(6))
        let houseScores = houseValues(snapshot, natal: natal, aspects: aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let phase = phaseAngle(snapshot)
        let moonHouse = natal?.house(containing: moon?.longitudeDegrees ?? 0) ?? 0
        let phaseSequence = progressedPhaseSequence(phase, language: language)
        let chapterFacts: [InsightFact] = [
            fact(localized("insight.secondary.stage", language: language), progressedPhaseName(phase, language: language), .transition),
            moon.map { fact(localized("insight.progressed-moon.fact", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            sun.map { fact(localized("insight.secondary.progressed-sun", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
        ].compactMap { $0 }
        let identityFacts: [InsightFact] = [
            natalSun.map { fact(localized("insight.secondary.natal-sun", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☉") },
            sun.map { fact(localized("insight.secondary.progressed-sun", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
        ].compactMap { $0 }

        return [
            card( id: "developmental-chapter",
                title: localized("insight.secondary.developmental-chapter", language: language),
                icon: "◐", visual: .stageFlow(
                    old: phaseSequence.previous,
                    transition: phaseSequence.current,
                    emerging: phaseSequence.next
                ),
                facts: chapterFacts,
                language: language
            ),
            card( id: "progressed-moon",
                title: localized("insight.progressed-moon.title", language: language),
                icon: "☽", visual: .moonProgress(progress: phase / 360),
                facts: progressedMoonFacts(
                    events,
                    moon: moon,
                    moonHouse: moonHouse,
                    phase: phase,
                    language: language,
                    timeZone: timeZone
                ),
                language: language
            ),
            card( id: "identity-development",
                title: localized("insight.secondary.identity-development", language: language),
                icon: "☉", visual: .identityCompare(
                    natal: natalSun.map { Zodiac.position($0, language: language) } ?? "",
                    progressed: sun.map { Zodiac.position($0, language: language) } ?? ""
                ),
                facts: identityFacts,
                language: language
            ),
            card( id: "turning-points",
                title: localized("insight.secondary.turning-points", language: language),
                icon: "⟐", visual: .turningRows,
                facts: turningPointFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
            card( id: "areas-maturing",
                title: localized("insight.secondary.areas-maturing", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "timeline",
                title: localized("insight.secondary.24-month-timeline", language: language),
                icon: "⇢", visual: .gantt,
                facts: secondaryTimelineFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
        ]
    }

    // MARK: - Solar return (7)

    static func progressedPhaseSequence(
        _ angle: Double,
        language: AppLanguage
    ) -> (previous: String, current: String, next: String) {
        let labels = [
            localized("insight.secondary.new-phase", language: language),
            localized("insight.secondary.building-phase", language: language),
            localized("insight.secondary.review-phase", language: language),
            localized("insight.secondary.integration-phase", language: language),
        ]
        let normalized = angle.truncatingRemainder(dividingBy: 360)
        let index = min(3, max(0, Int(normalized / 90)))
        return (
            labels[(index + labels.count - 1) % labels.count],
            labels[index],
            labels[(index + 1) % labels.count]
        )
    }

    static func progressedMoonFacts(
        _ events: ChartEventData,
        moon: ChartPoint?,
        moonHouse: Int,
        phase: Double,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        var facts: [InsightFact] = [
            moon.map { fact(localized("insight.current-sky.moon-sign", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            moonHouse > 0 ? fact(localized("insight.current-sky.moon-area", language: language), ConsumerCopy.lifeArea(moonHouse, language: language), .transition) : nil,
            fact(localized("insight.secondary.phase", language: language), progressedPhaseName(phase, language: language)),
        ].compactMap { $0 }
        if let window = events.progressedMoon {
            let months = max(0, Int((Double(window.daysInSign) / 30.44).rounded()))
            facts.append(
                fact(
                    localized("insight.secondary.in-sign", language: language),
                    localizedTemplate("dynamic.983c1afebb", substitutions: ["value1": String(describing: months)], language: language),
                    .supportive
                )
            )
            facts.append(
                fact(
                    localized("insight.secondary.ingress", language: language),
                    window.nextIngress.shortEventMonthYear(language: language, timeZone: timeZone),
                    .transition
                )
            )
        }
        return facts
    }

    static func turningPointFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let rows = events.progressedTurningPoints.prefix(3)
        guard !rows.isEmpty else {
            return fallback.prefix(3).map {
                fact(
                    aspectTitle($0, language: language),
                    "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                    tone($0.kind),
                    note: nil,
                    progress: $0.strength
                )
            }
        }
        return rows.map { point in
            let title = "\(bodyName(point.first, language: language)) \(point.kind.symbol) \(bodyName(point.second, language: language))"
            if let date = point.exactDate {
                return fact(
                    localized("insight.secondary.exact", language: language),
                    title,
                    tone(point.kind),
                    note: date.shortEventMonthYear(language: language, timeZone: timeZone),
                    symbol: point.first.symbol
                )
            }
            return fact(
                localized("insight.secondary.building", language: language),
                title,
                .transition,
                note: Zodiac.formatDegree(point.separationDegrees),
                symbol: point.first.symbol
            )
        }
    }

    static func secondaryTimelineFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        guard let moon = events.progressedMoon else {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        let now = events.secondaryTargetDate ?? Date()
        var rows: [InsightFact] = []
        let moonTitle = localizedTemplate("dynamic.ce5ddbd118", substitutions: ["value1": String(describing: Zodiac.name(index: moon.signIndex, language: language))], language: language)
        rows.append(
            fact(
                moonTitle,
                localized("insight.secondary.now", language: language),
                .transition,
                note: now.shortEventRange(to: moon.nextIngress, language: language, timeZone: timeZone),
                progress: 0
            )
        )
        for point in events.progressedTurningPoints.prefix(2) {
            guard let exactDate = point.exactDate else { continue }
            let start = exactDate.addingTimeInterval(-30 * 86_400)
            let end = exactDate.addingTimeInterval(30 * 86_400)
            let total = max(1, end.timeIntervalSince(start))
            let progress = min(1, max(0, now.timeIntervalSince(start) / total))
            rows.append(
                fact(
                    "\(bodyName(point.first, language: language)) \(point.kind.symbol) \(bodyName(point.second, language: language))",
                    exactDate.shortEventMonthYear(language: language, timeZone: timeZone),
                    tone(point.kind),
                    note: start.shortEventRange(to: end, language: language, timeZone: timeZone),
                    progress: progress,
                    markers: [progress]
                )
            )
        }
        if rows.isEmpty {
            return fallback.prefix(3).map {
                fact(
                    phaseLabel($0.phase, language: language),
                    aspectTitle($0, language: language),
                    tone($0.kind),
                    note: ConsumerCopy.intensity($0.strength, language: language),
                    progress: $0.strength
                )
            }
        }
        return rows
    }
}
