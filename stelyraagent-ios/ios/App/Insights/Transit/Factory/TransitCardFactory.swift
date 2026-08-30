import AstroCore
import Foundation

enum TransitCardFactory {
    static func make(
        plan: TransitContentPlan,
        language: AppLanguage,
        initialRangeDays: Int
    ) -> [InsightCardModel] {
        InsightFactory.transitCards(
            plan: plan,
            language: language,
            initialRangeDays: initialRangeDays
        )
    }
}

extension InsightFactory {
    static func transitCards(
        plan: TransitContentPlan,
        language: AppLanguage,
        initialRangeDays: Int
    ) -> [InsightCardModel] {
        let timeZone = TimeZone(identifier: plan.timeZoneIdentifier) ?? .current
        let storyPlan = plan.card("current-story")!
        let cyclePlan = plan.card("current-cycles")!
        let timelinePlan = plan.card("transit-timeline")!
        let pathPlan = plan.card("planet-paths")!
        let areaPlan = plan.card("life-areas")!
        let activePlan = plan.card("active-transits")!

        let storyAspects = storyPlan.evidence.compactMap { evidence -> TransitAspectFact? in
            guard case let .aspect(fact) = evidence.fact else { return nil }
            return fact
        }
        let expanding = storyAspects.first(where: { $0.kind.supportive })
            .map { transitAspectTitle($0, language: language) } ?? ""
        let structuring = storyAspects.first(where: { $0.kind.challenging })
            .map { transitAspectTitle($0, language: language) } ?? ""

        let longCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .longCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let currentCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .currentCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let dailyCycle = cycleDisplay(
            cyclePlan.evidence.first { $0.role == .dailyCycle },
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let timelineCalendar = timelinePlan.evidence.compactMap { evidence -> TransitCalendarFact? in
            guard case let .calendar(fact) = evidence.fact else { return nil }
            return fact
        }
        let pathRows = transitPlanetPathRows(
            pathPlan,
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )
        let lifeAreaRows = transitLifeAreaRows(areaPlan, language: language)
        let activeRows = transitActiveRows(
            activePlan,
            anchorDate: plan.anchorDate,
            language: language,
            timeZone: timeZone
        )

        return [
            card(
                id: "current-story",
                title: localized("insight.transit.current-story", language: language),
                icon: "◎",
                visual: .storyWeave(
                    expanding: expanding,
                    structuring: structuring,
                    result: localizedTemplate("dynamic.ee6f12f5bb", substitutions: ["value1": String(describing: storyAspects.count)], language: language)
                ),
                facts: plannedAspectFacts(storyPlan, language: language, timeZone: timeZone),
                language: language
            ),
            card(
                id: "current-cycles",
                title: localized("insight.transit.current-cycles", language: language),
                icon: "◔",
                visual: .cycleTabs(
                    long: longCycle,
                    current: currentCycle,
                    daily: dailyCycle
                ),
                facts: cyclePlan.evidence
                    .filter { $0.role != .cycleCalendar }
                    .compactMap {
                        transitInsightFact(
                            $0,
                            anchorDate: plan.anchorDate,
                            language: language,
                            timeZone: timeZone
                        )
                    },
                language: language
            ),
            card(
                id: "transit-timeline",
                title: localized("insight.transit.transit-timeline", language: language),
                icon: "⇢",
                visual: .transitTimeline(
                    entries: TransitTimelineProjection.entries(from: timelinePlan.evidence),
                    calendar: timelineCalendar,
                    anchorDate: plan.anchorDate,
                    initialRangeDays: initialRangeDays,
                    timeZoneIdentifier: plan.timeZoneIdentifier
                ),
                facts: timelinePlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "planet-paths",
                title: localized("insight.transit.planet-paths", language: language),
                icon: "⊛",
                visual: .transitPlanetPaths(pathRows),
                facts: pathPlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "life-areas",
                title: localized("insight.transit.life-areas", language: language),
                icon: "⌂",
                visual: .transitLifeAreas(lifeAreaRows),
                facts: areaPlan.evidence.compactMap {
                    transitInsightFact(
                        $0,
                        anchorDate: plan.anchorDate,
                        language: language,
                        timeZone: timeZone
                    )
                },
                language: language
            ),
            card(
                id: "active-transits",
                title: localized("insight.transit.active-transits", language: language),
                icon: "⌗",
                visual: .transitActiveRows(activeRows),
                facts: plannedActiveFacts(
                    activePlan,
                    anchorDate: plan.anchorDate,
                    language: language,
                    timeZone: timeZone
                ),
                language: language
            ),
        ]
    }

    static func transitInsightFact(
        _ evidence: TransitPlannedEvidence,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> InsightFact? {
        switch evidence.fact {
        case let .aspect(aspect):
            return fact(
                transitAspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                stableID: aspect.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: ConsumerCopy.lifeArea(aspect.natalHouse, language: language),
                progress: aspect.strength,
                symbol: aspect.kind.symbol,
                category: cycleCategory(aspect.cycleBand)
            )
        case let .window(window):
            let total = max(1, window.end.timeIntervalSince(window.start))
            let progress = min(1, max(0, anchorDate.timeIntervalSince(window.start) / total))
            let exactDates = window.exactDates.map {
                $0.shortEventDate(language: language, timeZone: timeZone)
            }
            return fact(
                transitWindowTitle(window, language: language),
                exactDates.joined(separator: " · "),
                tone(window.kind),
                stableID: window.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: window.start.shortEventRange(to: window.end, language: language, timeZone: timeZone),
                progress: progress,
                symbol: window.kind.symbol,
                category: cycleCategory(window.cycleBand)
            )
        case let .planetEvent(event):
            return fact(
                bodyName(event.body, language: language),
                planetEventValue(event, language: language),
                event.kind == .stationRetrograde ? .challenging : .transition,
                stableID: event.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: event.timestamp.shortEventDate(language: language, timeZone: timeZone),
                symbol: event.body.symbol,
                category: evidence.role.rawValue
            )
        case let .placement(placement):
            let position = [
                "\(Zodiac.name(index: placement.signIndex, language: language)) \(Zodiac.formatDegree(placement.degreeInSign))",
                (1 ... 12).contains(placement.natalHouse)
                    ? ConsumerCopy.lifeArea(placement.natalHouse, language: language)
                    : nil,
            ].compactMap { $0 }.joined(separator: " · ")
            return fact(
                bodyName(placement.body, language: language),
                position,
                placement.retrograde ? .challenging : .neutral,
                stableID: placement.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                note: "\(motionLabel(retrograde: placement.retrograde, language: language)) · \(String(format: "%+.4f°/d", placement.longitudeSpeedDegreesPerDay))",
                symbol: placement.body.symbol
            )
        case let .lifeArea(area):
            let percent = Int((area.normalizedScore * 100).rounded())
            return fact(
                ConsumerCopy.lifeArea(area.house, language: language),
                activityLabel(percent, language: language),
                percent > 66 ? .challenging : percent > 35 ? .transition : .neutral,
                stableID: area.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                progress: area.normalizedScore,
                symbol: "\(area.house)"
            )
        case .calendar:
            return nil
        }
    }

    static func plannedActiveFacts(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let aspectFacts = plannedAspectFacts(plan, language: language, timeZone: timeZone)
        let eventFacts = plan.evidence.compactMap { evidence -> InsightFact? in
            guard case .planetEvent = evidence.fact else { return nil }
            return transitInsightFact(
                evidence,
                anchorDate: anchorDate,
                language: language,
                timeZone: timeZone
            )
        }
        return aspectFacts + eventFacts
    }

    static func transitPlanetPathRows(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [TransitPlanetPathRow] {
        let events = plan.evidence.compactMap { evidence -> TransitPlanetEventFact? in
            guard evidence.role == .pathEvent, case let .planetEvent(event) = evidence.fact else { return nil }
            return event
        }
        return plan.evidence.compactMap { evidence -> TransitPlanetPathRow? in
            guard evidence.role == .path, case let .placement(placement) = evidence.fact else { return nil }
            let bodyEvents = events
                .filter { $0.body == placement.body && $0.timestamp >= anchorDate }
                .sorted { $0.timestamp == $1.timestamp ? $0.factID < $1.factID : $0.timestamp < $1.timestamp }
            let nextHouseIngress = bodyEvents.first { $0.kind == .houseIngress }
            let nextDirectStation = bodyEvents.first { $0.kind == .stationDirect }
            let imminentHouseIngress = nextHouseIngress.flatMap { event in
                event.timestamp.timeIntervalSince(anchorDate) <= 30 * 86_400 ? event : nil
            }
            let title: String
            let detail: String
            let state: TransitPathState
            let timing: String
            let linkedEvent: TransitPlanetEventFact?
            let displayHouse: Int

            if let ingress = imminentHouseIngress, let house = ingress.toIndex, (1 ... 12).contains(house) {
                title = transitEnteringHouseTitle(placement.body, house: house, language: language)
                detail = localizedTemplate("dynamic.873dc1682a", substitutions: ["value1": String(describing: ConsumerCopy.lifeArea(house, language: language)), "value2": String(describing: ingress.timestamp.shortEventDate(language: language, timeZone: timeZone))], language: language)
                state = .next
                timing = relativeTransitTime(from: anchorDate, to: ingress.timestamp, language: language, includesPrefix: true)
                linkedEvent = ingress
                displayHouse = house
            } else {
                title = transitInHouseTitle(placement.body, house: placement.natalHouse, language: language)
                detail = localizedTemplate("dynamic.fd4ae99568", substitutions: ["value1": String(describing: ConsumerCopy.lifeArea(placement.natalHouse, language: language)), "value2": String(describing: Zodiac.name(index: placement.signIndex, language: language)), "value3": String(describing: Zodiac.formatDegree(placement.degreeInSign))], language: language)
                state = placement.retrograde ? .retrograde : .direct
                if placement.retrograde, let station = nextDirectStation {
                    timing = transitUntilMonth(station.timestamp, language: language, timeZone: timeZone)
                    linkedEvent = station
                } else if let nextEvent = bodyEvents.first {
                    timing = relativeTransitTime(from: anchorDate, to: nextEvent.timestamp, language: language, includesPrefix: false)
                    linkedEvent = nextEvent
                } else {
                    timing = localized("insight.transit.long-term", language: language)
                    linkedEvent = nil
                }
                displayHouse = placement.natalHouse
            }
            return TransitPlanetPathRow(
                id: placement.factID,
                sourceFactIDs: Array(Set(evidence.fact.sourceFactIDs + [linkedEvent?.factID].compactMap { $0 })).sorted(),
                body: placement.body,
                house: displayHouse,
                symbol: placement.body.symbol,
                title: title,
                detail: detail,
                state: state,
                timing: timing
            )
        }
    }

    static func transitLifeAreaRows(
        _ plan: CardEvidencePlan,
        language: AppLanguage
    ) -> [TransitLifeAreaRow] {
        plan.evidence.compactMap { evidence in
            guard case let .lifeArea(area) = evidence.fact else { return nil }
            let percent = Int((area.normalizedScore * 100).rounded())
            return TransitLifeAreaRow(
                id: area.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                title: area.house == 1
                    ? localized("insight.transit.personal-focus", language: language)
                    : ConsumerCopy.lifeArea(area.house, language: language),
                activity: activityLabel(percent, language: language),
                triggerCount: Set(area.contributingFactIDs).count,
                progress: area.normalizedScore
            )
        }
    }

    static func transitActiveRows(
        _ plan: CardEvidencePlan,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [TransitActiveRow] {
        let windows = plan.evidence.compactMap { evidence -> TransitWindowFact? in
            guard case let .window(window) = evidence.fact else { return nil }
            return window
        }
        let aspectRows = plan.evidence.compactMap { evidence -> TransitActiveRow? in
            guard case let .aspect(aspect) = evidence.fact else { return nil }
            let linkedWindows = windows.filter { $0.sourceAspectFactID == aspect.factID }
            let primaryWindow = linkedWindows.min {
                abs($0.exact.timeIntervalSince(anchorDate)) < abs($1.exact.timeIntervalSince(anchorDate))
            }
            let status: TransitActiveStatus
            if primaryWindow?.returning == true {
                status = .returning
            } else {
                status = switch aspect.phase {
                case .applying: .applying
                case .exact: .exact
                case .separating: .separating
                }
            }
            let sourceFactIDs = Array(Set(
                evidence.fact.sourceFactIDs + linkedWindows.flatMap { TransitFact.window($0).sourceFactIDs }
            )).sorted()
            let detailParts = [
                (1 ... 12).contains(aspect.natalHouse)
                    ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                    : nil,
                activeAspectTiming(status: status, window: primaryWindow, anchorDate: anchorDate, language: language, timeZone: timeZone),
            ].compactMap { $0 }
            var fields = [
                TransitTechnicalField(id: "stage", label: localized("insight.secondary.stage", language: language), value: activeStatusLabel(status, language: language)),
                TransitTechnicalField(id: "orb", label: localized("chart.orb", language: language), value: formatOrb(aspect.orbDegrees)),
                TransitTechnicalField(id: "house", label: localized("insight.transit.house", language: language), value: transitHouseLabel(aspect.natalHouse, language: language)),
            ]
            if let primaryWindow {
                fields.append(
                    TransitTechnicalField(
                        id: "window",
                        label: localized("insight.transit.active-window", language: language),
                        value: primaryWindow.start.shortEventRange(to: primaryWindow.end, language: language, timeZone: timeZone)
                    )
                )
            }
            return TransitActiveRow(
                id: aspect.factID,
                sourceFactIDs: sourceFactIDs,
                symbol: CelestialBody(rawValue: aspect.movingID)?.symbol ?? aspect.kind.symbol,
                title: transitActiveAspectTitle(aspect, language: language),
                detail: detailParts.joined(separator: " · "),
                category: cycleCategory(aspect.cycleBand),
                status: status,
                technicalValue: formatOrb(aspect.orbDegrees),
                fields: fields
            )
        }
        let eventRows = plan.evidence.compactMap { evidence -> TransitActiveRow? in
            guard case let .planetEvent(event) = evidence.fact else { return nil }
            let status: TransitActiveStatus = switch event.kind {
            case .signIngress, .houseIngress: .ingress
            case .stationRetrograde: .retrograde
            case .stationDirect: .direct
            }
            let detailParts = [
                event.kind == .houseIngress
                    ? ConsumerCopy.lifeArea(event.toIndex, language: language)
                    : nil,
                event.timestamp.shortEventDate(language: language, timeZone: timeZone),
            ].compactMap { $0 }
            let fields = [
                TransitTechnicalField(id: "event", label: localized("insight.transit.event", language: language), value: activeStatusLabel(status, language: language)),
                TransitTechnicalField(id: "time", label: localized("insight.transit.time", language: language), value: transitTimestamp(event.timestamp, language: language, timeZone: timeZone)),
                TransitTechnicalField(id: "target", label: localized("insight.transit.target", language: language), value: planetEventValue(event, language: language)),
            ]
            return TransitActiveRow(
                id: event.factID,
                sourceFactIDs: evidence.fact.sourceFactIDs,
                symbol: event.body.symbol,
                title: transitActiveEventTitle(event, language: language),
                detail: detailParts.joined(separator: " · "),
                category: cycleCategory(TransitCycleBand(movingID: event.body.rawValue)),
                status: status,
                technicalValue: relativeTransitTime(from: anchorDate, to: event.timestamp, language: language, includesPrefix: false),
                fields: fields
            )
        }
        return aspectRows + eventRows
    }

    static func transitInHouseTitle(_ body: CelestialBody, house: Int, language: AppLanguage) -> String {
        localizedTemplate("dynamic.5b39501d54", substitutions: ["value1": bodyName(body, language: language), "value2": AstroTerms.house(house, language: language)], language: language)
    }

    static func transitEnteringHouseTitle(_ body: CelestialBody, house: Int, language: AppLanguage) -> String {
        localizedTemplate("dynamic.da283ac4d3", substitutions: ["value1": bodyName(body, language: language), "value2": AstroTerms.house(house, language: language)], language: language)
    }

    static func transitActiveAspectTitle(_ aspect: TransitAspectFact, language: AppLanguage) -> String {
        let moving = CelestialBody(rawValue: aspect.movingID).map { bodyName($0, language: language) } ?? aspect.movingID
        let reference = CelestialBody(rawValue: aspect.referenceID).map { bodyName($0, language: language) } ?? aspect.referenceID
        return localizedTemplate("dynamic.0782a0ed98", substitutions: ["value1": String(describing: moving), "value2": String(describing: aspect.kind.symbol), "value3": String(describing: reference)], language: language)
    }

    static func transitActiveEventTitle(_ event: TransitPlanetEventFact, language: AppLanguage) -> String {
        let body = bodyName(event.body, language: language)
        switch event.kind {
        case .signIngress:
            guard let sign = event.toIndex else { return body }
            return localizedTemplate("dynamic.359e37f1d5", substitutions: ["value1": String(describing: body), "value2": String(describing: Zodiac.name(index: sign, language: language))], language: language)
        case .houseIngress:
            guard let house = event.toIndex else { return body }
            return transitEnteringHouseTitle(event.body, house: house, language: language)
        case .stationRetrograde:
            return localizedTemplate("dynamic.8d7de7deab", substitutions: ["value1": String(describing: body)], language: language)
        case .stationDirect:
            return localizedTemplate("dynamic.b40cc6b6fc", substitutions: ["value1": String(describing: body)], language: language)
        }
    }

    static func activeAspectTiming(
        status: TransitActiveStatus,
        window: TransitWindowFact?,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String? {
        guard let window else { return nil }
        switch status {
        case .returning:
            let next = window.exactDates.first { $0 >= anchorDate } ?? window.exact
            return localizedTemplate("dynamic.49908102ba", substitutions: ["value1": String(describing: next.shortEventDate(language: language, timeZone: timeZone))], language: language)
        case .separating:
            return localizedTemplate("dynamic.fe7c54d6dc", substitutions: ["value1": String(describing: relativeTransitTime(from: anchorDate, to: window.end, language: language, includesPrefix: true))], language: language)
        case .applying, .exact:
            return localizedTemplate("dynamic.e59f8c38f4", substitutions: ["value1": String(describing: transitTimestamp(window.exact, language: language, timeZone: timeZone))], language: language)
        case .ingress, .retrograde, .direct:
            return nil
        }
    }

    static func activeStatusLabel(_ status: TransitActiveStatus, language: AppLanguage) -> String {
        switch status {
        case .applying: localized("insight.transit.applying", language: language)
        case .returning: localized("insight.transit.returning", language: language)
        case .ingress: localized("insight.transit.ingress", language: language)
        case .separating: localized("insight.transit.separating", language: language)
        case .exact: localized("insight.secondary.exact", language: language)
        case .retrograde: localized("insight.transit.retrograde", language: language)
        case .direct: localized("insight.transit.direct", language: language)
        }
    }

    static func transitHouseLabel(_ house: Int, language: AppLanguage) -> String {
        guard (1 ... 12).contains(house) else { return localized("insight.transit.unknown", language: language) }
        return localizedTemplate("dynamic.bade3ca07d", substitutions: ["value1": AstroTerms.house(house, language: language)], language: language)
    }

    static func transitTimestamp(_ date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func transitUntilMonth(_ date: Date, language: AppLanguage, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: language.rawValue)
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMM")
        let month = formatter.string(from: date)
        return localizedTemplate("dynamic.b54a646b70", substitutions: ["value1": String(describing: month)], language: language)
    }

    static func relativeTransitTime(
        from start: Date,
        to end: Date,
        language: AppLanguage,
        includesPrefix: Bool
    ) -> String {
        let seconds = max(0, end.timeIntervalSince(start))
        let hours = max(1, Int(ceil(seconds / 3_600)))
        let value: String
        if hours < 24 {
            value = localizedTemplate("dynamic.14eb9f09f8", substitutions: ["value1": String(describing: hours)], language: language)
        } else {
            let days = max(1, Int(ceil(seconds / 86_400)))
            if days < 60 {
                value = localizedTemplate("dynamic.fa9464bed5", substitutions: ["value1": String(describing: days)], language: language)
            } else {
                let months = max(1, Int((Double(days) / 30).rounded()))
                value = localizedTemplate("dynamic.a99aafc649", substitutions: ["value1": String(describing: months)], language: language)
            }
        }
        guard includesPrefix else { return value }
        return localizedTemplate("dynamic.5f0315225b", substitutions: ["value1": String(describing: value)], language: language)
    }

    static func planetEventValue(
        _ event: TransitPlanetEventFact,
        language: AppLanguage
    ) -> String {
        switch event.kind {
        case .signIngress:
            guard let from = event.fromIndex, let to = event.toIndex else { return event.kind.rawValue }
            return "\(Zodiac.name(index: from, language: language)) → \(Zodiac.name(index: to, language: language))"
        case .houseIngress:
            guard let to = event.toIndex else { return event.kind.rawValue }
            return ConsumerCopy.lifeArea(to, language: language)
        case .stationRetrograde:
            return motionLabel(retrograde: true, language: language)
        case .stationDirect:
            return motionLabel(retrograde: false, language: language)
        }
    }

    static func plannedAspectFacts(
        _ plan: CardEvidencePlan,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let windows = plan.evidence.compactMap { evidence -> TransitWindowFact? in
            guard case let .window(window) = evidence.fact else { return nil }
            return window
        }
        return plan.evidence.compactMap { evidence -> InsightFact? in
            guard case let .aspect(aspect) = evidence.fact else { return nil }
            let linkedWindows = windows.filter { $0.sourceAspectFactID == aspect.factID }
            let sourceFactIDs = Array(Set(
                evidence.fact.sourceFactIDs + linkedWindows.flatMap {
                    [$0.factID] + [$0.sourceAspectFactID].compactMap { $0 }
                }
            )).sorted()
            let exactDates = linkedWindows
                .flatMap(\.exactDates)
                .sorted()
                .map { $0.shortEventDate(language: language, timeZone: timeZone) }
            let notes = [
                (1 ... 12).contains(aspect.natalHouse)
                    ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                    : nil,
                exactDates.isEmpty ? nil : exactDates.joined(separator: " · "),
            ].compactMap { $0 }
            return fact(
                transitAspectTitle(aspect, language: language),
                "\(phaseLabel(aspect.phase, language: language)) · \(ConsumerCopy.intensity(aspect.strength, language: language))",
                tone(aspect.kind),
                stableID: aspect.factID,
                sourceFactIDs: sourceFactIDs,
                note: notes.isEmpty ? nil : notes.joined(separator: " · "),
                progress: aspect.strength,
                symbol: aspect.kind.symbol,
                category: cycleCategory(aspect.cycleBand)
            )
        }
    }

    static func transitAspectTitle(
        _ aspect: TransitAspectFact,
        language: AppLanguage
    ) -> String {
        let moving = CelestialBody(rawValue: aspect.movingID)
            .map { bodyName($0, language: language) } ?? aspect.movingID
        let reference = CelestialBody(rawValue: aspect.referenceID)
            .map { bodyName($0, language: language) } ?? aspect.referenceID
        return "\(moving) \(aspect.kind.symbol) \(reference)"
    }

    static func transitWindowTitle(
        _ window: TransitWindowFact,
        language: AppLanguage
    ) -> String {
        let moving = CelestialBody(rawValue: window.movingID)
            .map { bodyName($0, language: language) } ?? window.movingID
        let reference = CelestialBody(rawValue: window.referenceID)
            .map { bodyName($0, language: language) } ?? window.referenceID
        return "\(moving) \(window.kind.symbol) \(reference)"
    }

    static func cycleDisplay(
        _ evidence: TransitPlannedEvidence?,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> TransitCyclePresentation? {
        guard let evidence else { return nil }
        switch evidence.fact {
        case let .window(window):
            return TransitCyclePresentation(
                roleID: evidence.role.rawValue,
                fallbackTitle: transitWindowTitle(window, language: language),
                tags: cycleWindowTags(
                    window,
                    role: evidence.role,
                    anchorDate: anchorDate,
                    language: language,
                    timeZone: timeZone
                ),
                sourceFactIDs: evidence.fact.sourceFactIDs
            )
        case let .aspect(aspect):
            return TransitCyclePresentation(
                roleID: evidence.role.rawValue,
                fallbackTitle: transitAspectTitle(aspect, language: language),
                tags: [
                    phaseLabel(aspect.phase, language: language),
                    (1 ... 12).contains(aspect.natalHouse)
                        ? ConsumerCopy.lifeArea(aspect.natalHouse, language: language)
                        : nil,
                ].compactMap { $0 },
                sourceFactIDs: evidence.fact.sourceFactIDs
            )
        default:
            return nil
        }
    }

    static func cycleWindowTags(
        _ window: TransitWindowFact,
        role: TransitEvidenceRole,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [String] {
        let area = (1 ... 12).contains(window.natalHouse)
            ? ConsumerCopy.lifeArea(window.natalHouse, language: language)
            : nil
        switch role {
        case .longCycle:
            let futureExact = window.exactDates.first { $0 >= anchorDate }
            let exactLabel = futureExact.map { date in
                if window.returning || window.passIndex > 1 {
                    return localizedTemplate("dynamic.58e31d7654", substitutions: ["value1": String(describing: date.shortEventDate(language: language, timeZone: timeZone))], language: language)
                }
                return localizedTemplate("dynamic.ccf2313c4f", substitutions: ["value1": String(describing: date.shortEventDate(language: language, timeZone: timeZone))], language: language)
            }
            return [
                cycleDateRange(window.start, window.end, anchorDate: anchorDate, language: language, timeZone: timeZone),
                exactLabel,
                area,
            ].compactMap { $0 }
        case .currentCycle:
            return [
                cycleDuration(window.start, window.end, language: language),
                phaseLabel(cyclePhase(window, anchorDate: anchorDate), language: language),
                area,
            ].compactMap { $0 }
        case .dailyCycle:
            return [
                cyclePeak(window, anchorDate: anchorDate, language: language, timeZone: timeZone),
                cycleEnd(window.end, anchorDate: anchorDate, language: language, timeZone: timeZone),
                area,
            ].compactMap { $0 }
        default:
            return [area].compactMap { $0 }
        }
    }

    static func cyclePhase(_ window: TransitWindowFact, anchorDate: Date) -> AspectPhase {
        let closestExact = window.exactDates.min {
            abs($0.timeIntervalSince(anchorDate)) < abs($1.timeIntervalSince(anchorDate))
        } ?? window.exact
        if abs(closestExact.timeIntervalSince(anchorDate)) < 3_600 { return .exact }
        return closestExact > anchorDate ? .applying : .separating
    }

    static func cycleDuration(_ start: Date, _ end: Date, language: AppLanguage) -> String {
        let days = max(1, Int(ceil(end.timeIntervalSince(start) / 86_400)))
        if days < 14 {
            return localizedTemplate("dynamic.fa9464bed5", substitutions: ["value1": String(describing: days)], language: language)
        }
        if days < 60 {
            let weeks = max(1, Int((Double(days) / 7).rounded()))
            return localizedTemplate("dynamic.65a2a86bf4", substitutions: ["value1": String(describing: weeks)], language: language)
        }
        let months = max(2, Int((Double(days) / 30).rounded()))
        return localizedTemplate("dynamic.a99aafc649", substitutions: ["value1": String(describing: months)], language: language)
    }

    static func cyclePeak(
        _ window: TransitWindowFact,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        let peak = window.exactDates.min {
            abs($0.timeIntervalSince(anchorDate)) < abs($1.timeIntervalSince(anchorDate))
        } ?? window.exact
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: peak)
        return localizedTemplate("dynamic.5f03886cd2", substitutions: ["value1": String(describing: time)], language: language)
    }

    static func cycleEnd(
        _ end: Date,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let anchorDay = calendar.startOfDay(for: anchorDate)
        let endDay = calendar.startOfDay(for: end)
        let dayDistance = calendar.dateComponents([.day], from: anchorDay, to: endDay).day ?? 0
        if dayDistance == 0 {
            return localized("insight.transit.ends-today", language: language)
        }
        if dayDistance == 1 {
            return localized("insight.transit.ends-tomorrow", language: language)
        }
        return localizedTemplate("dynamic.7f1e2d8a22", substitutions: ["value1": String(describing: end.shortEventDate(language: language, timeZone: timeZone))], language: language)
    }

    static func cycleDateRange(
        _ start: Date,
        _ end: Date,
        anchorDate: Date,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let anchorYear = calendar.component(.year, from: anchorDate)
        let includesOtherYear = calendar.component(.year, from: start) != anchorYear
            || calendar.component(.year, from: end) != anchorYear
        guard includesOtherYear else {
            return start.shortEventRange(to: end, language: language, timeZone: timeZone)
        }
        let formatter = DateFormatter()
        formatter.locale = language.locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: start))–\(formatter.string(from: end))"
    }

    static func cycleCategory(_ band: TransitCycleBand) -> String {
        switch band {
        case .longTerm: "long-term"
        case .current: "current"
        case .daily: "daily"
        }
    }

    // MARK: - Secondary (6)
}
