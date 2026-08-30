import AstroCore
import Foundation

enum SolarReturnCardDraftFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.solarCards(
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
    static func solarCards(
        _ snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        events: ChartEventData,
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let ascSign = Zodiac.name(index: Int(snapshot.angles.ascendantDegrees / 30) % 12, language: language)
        let ruler = ruler(ofSign: Int(snapshot.angles.ascendantDegrees / 30) % 12)
        let top = Array(snapshot.aspects.prefix(4))
        var seenAspectIDs = Set<String>()
        let yearAspects = (aspects + snapshot.aspects)
            .filter { seenAspectIDs.insert($0.id).inserted }
            .sorted { $0.strength > $1.strength }
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let overlayAnchors = natalOverlayAnchors(snapshot: snapshot, natal: natal, language: language)
        let yearThemeFacts: [InsightFact] = [
            fact(localized("insight.solar-return.return-ascendant", language: language), ascSign, .transition, symbol: "ASC"),
            fact(localized("insight.natal.chart-ruler", language: language), bodyName(ruler, language: language), .supportive, symbol: ruler.symbol),
            sunHouseLabel(sun, snapshot: snapshot, language: language).map {
                fact(localized("insight.solar-return.sun-house", language: language), $0, .neutral, symbol: "☉")
            },
        ].compactMap { $0 }
        let dynamicFacts: [InsightFact] = [
            strongestSupport.map { fact(localized("insight.solar-return.supportive-aspect", language: language), aspectTitle($0, language: language), .supportive) },
            strongestChallenge.map { fact(localized("insight.solar-return.challenging-aspect", language: language), aspectTitle($0, language: language), .challenging) },
        ].compactMap { $0 }
        let firstOverlay = overlayAnchors.first
        let secondOverlay = overlayAnchors.dropFirst().first

        return [
            card( id: "year-theme",
                title: localized("insight.solar-return.your-birthday-year", language: language),
                icon: "☉", visual: .yearOrbit,
                facts: yearThemeFacts,
                language: language
            ),
            card( id: "year-anchors",
                title: localized("insight.solar-return.year-anchors", language: language),
                icon: "⚓", visual: .connectionGrid,
                facts: yearAnchorFacts(snapshot: snapshot, sun: sun, ruler: ruler, language: language),
                language: language
            ),
            card( id: "priority-areas",
                title: localized("insight.solar-return.priority-areas", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "year-dynamics",
                title: localized("insight.solar-return.year-dynamics", language: language),
                icon: "◈", visual: .dualInsight(
                    opening: strongestSupport.map { aspectTitle($0, language: language) } ?? "",
                    demand: strongestChallenge.map { aspectTitle($0, language: language) } ?? "",
                    openingLabel: localized("insight.solar-return.opening", language: language),
                    demandLabel: localized("insight.solar-return.demand", language: language)
                ),
                facts: dynamicFacts,
                language: language
            ),
            card( id: "year-timeline",
                title: localized("insight.solar-return.year-timeline", language: language),
                icon: "⇢", visual: .quarterTabs,
                facts: solarSeasonFacts(events, fallback: top, language: language, timeZone: timeZone),
                language: language
            ),
            card( id: "natal-overlay",
                title: localized("insight.solar-return.natal-overlay", language: language),
                icon: "∞", visual: .natalOverlay(
                    firstLabel: firstOverlay?.label ?? "",
                    firstValue: firstOverlay?.value ?? "",
                    secondLabel: secondOverlay?.label ?? "",
                    secondValue: secondOverlay?.value ?? ""
                ),
                facts: overlayAnchors,
                language: language
            ),
            card( id: "year-aspects",
                title: localized("insight.solar-return.year-aspects", language: language),
                icon: "⌗", visual: .aspectList,
                facts: yearAspects.prefix(5).map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
        ]
    }

    // MARK: - Synastry (8)

    static func sunHouseLabel(_ sun: ChartPoint?, snapshot: ChartSnapshot, language: AppLanguage) -> String? {
        guard let sun else { return nil }
        let house = snapshot.house(containing: sun.longitudeDegrees)
        guard house > 0 else { return nil }
        return AstroTerms.house(house, language: language)
    }

    static func yearAnchorFacts(
        snapshot: ChartSnapshot,
        sun: ChartPoint?,
        ruler: CelestialBody,
        language: AppLanguage
    ) -> [InsightFact] {
        let ascIndex = Int(snapshot.angles.ascendantDegrees / 30) % 12
        let ascValue = localizedTemplate("dynamic.161a609089", substitutions: ["value1": String(describing: Zodiac.name(index: ascIndex, language: language))], language: language)
        let rulerPoint = snapshot.point(ruler)
        let rulerHouse = rulerPoint.map { snapshot.house(containing: $0.longitudeDegrees) }
        let sunHouse = sun.map { snapshot.house(containing: $0.longitudeDegrees) }
        var facts: [InsightFact] = [
            fact(
                localized("insight.solar-return.return-ascendant", language: language),
                ascValue,
                .transition
            ),
        ]
        if let rulerPoint, let rulerHouse, rulerHouse > 0 {
            facts.append(
                fact(
                    localized("insight.natal.chart-ruler", language: language),
                    localizedTemplate("dynamic.cbb6cc5a06", substitutions: ["value1": bodyName(ruler, language: language), "value2": Zodiac.position(rulerPoint, language: language), "value3": AstroTerms.house(rulerHouse, language: language)], language: language),
                    .supportive
                )
            )
        }
        if let sun, let sunHouse, sunHouse > 0 {
            facts.append(
                fact(
                    localized("insight.solar-return.solar-return-sun", language: language),
                    localizedTemplate("dynamic.f8a781fce8", substitutions: ["value1": Zodiac.position(sun, language: language), "value2": AstroTerms.house(sunHouse, language: language)], language: language),
                    .neutral
                )
            )
        }
        if let angular = angularPlanetInfo(snapshot), angular.distance <= 5 {
            facts.append(
                fact(
                    localized("insight.solar-return.angular-planet", language: language),
                    localizedTemplate("dynamic.c8a2ff4904", substitutions: ["value1": String(describing: bodyName(angular.body, language: language)), "value2": String(describing: angular.axis), "value3": String(describing: Zodiac.formatDegree(angular.distance))], language: language),
                    .transition
                )
            )
        }
        return facts
    }

    static func natalOverlayAnchors(
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        language: AppLanguage
    ) -> [InsightFact] {
        guard let natal else { return [] }
        let asc = natal.angles.ascendantDegrees
        let mc = natal.angles.midheavenDegrees
        let axes: [(axis: String, longitude: Double)] = [
            ("MC", mc),
            ("IC", (mc + 180).truncatingRemainder(dividingBy: 360)),
            ("ASC", asc),
            ("DSC", (asc + 180).truncatingRemainder(dividingBy: 360)),
        ]
        var candidates: [(body: CelestialBody, axis: String, distance: Double)] = []
        for point in snapshot.points {
            for axis in axes {
                candidates.append((point.body, axis.axis, angularDistance(point.longitudeDegrees, axis.longitude)))
            }
        }
        candidates.sort { $0.distance < $1.distance }
        var usedBodies = Set<String>()
        var chosen: [(body: CelestialBody, axis: String, distance: Double)] = []
        for item in candidates where item.distance <= 5 && !usedBodies.contains(item.body.rawValue) {
            usedBodies.insert(item.body.rawValue)
            chosen.append(item)
            if chosen.count == 2 { break }
        }
        return chosen.map { overlayAnchorFact($0, language: language) }
    }

    static func overlayAnchorFact(
        _ item: (body: CelestialBody, axis: String, distance: Double),
        language: AppLanguage
    ) -> InsightFact {
        let value: String
        switch item.axis {
        case "MC":
            value = localized("insight.solar-return.near-natal-mc", language: language)
        case "IC":
            value = localized("insight.solar-return.at-natal-ic", language: language)
        case "ASC":
            value = localized("insight.solar-return.near-natal-asc", language: language)
        default:
            value = localized("insight.solar-return.near-natal-dsc", language: language)
        }
        let label = localizedTemplate("dynamic.a8b71d51e5", substitutions: ["value1": String(describing: bodyName(item.body, language: language))], language: language)
        return fact(
            label,
            "\(value) · \(Zodiac.formatDegree(item.distance))",
            item.axis == "MC" || item.axis == "ASC" ? .supportive : .challenging
        )
    }

    static func angularPlanetInfo(_ snapshot: ChartSnapshot) -> (body: CelestialBody, axis: String, distance: Double)? {
        let asc = snapshot.angles.ascendantDegrees
        let mc = snapshot.angles.midheavenDegrees
        let axes: [(axis: String, longitude: Double)] = [
            ("MC", mc),
            ("IC", (mc + 180).truncatingRemainder(dividingBy: 360)),
            ("ASC", asc),
            ("DSC", (asc + 180).truncatingRemainder(dividingBy: 360)),
        ]
        var best: (body: CelestialBody, axis: String, distance: Double)?
        for point in snapshot.points {
            for axis in axes {
                let distance = angularDistance(point.longitudeDegrees, axis.longitude)
                if distance < (best?.distance ?? .infinity) {
                    best = (point.body, axis.axis, distance)
                }
            }
        }
        return best
    }

    static func angularDistance(_ first: Double, _ second: Double) -> Double {
        let diff = abs(first - second).truncatingRemainder(dividingBy: 360)
        return min(diff, 360 - diff)
    }

    static func ordinal(_ value: Int) -> String {
        guard value > 0 else { return "1st" }
        let ones = value % 10
        let tens = value % 100
        if tens >= 11, tens <= 13 {
            return "\(value)th"
        }
        switch ones {
        case 1: return "\(value)st"
        case 2: return "\(value)nd"
        case 3: return "\(value)rd"
        default: return "\(value)th"
        }
    }

    static func solarSeasonFacts(
        _ events: ChartEventData,
        fallback: [ChartAspect],
        language: AppLanguage,
        timeZone: TimeZone
    ) -> [InsightFact] {
        let seasons = events.solarSeasons.prefix(4)
        guard !seasons.isEmpty else {
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
        return seasons.map { season in
            return fact(
                LocalizedFormatters.quarter(season.index + 1, language: language),
                season.start.shortEventRange(to: season.end, language: language, timeZone: timeZone),
                season.index == 0 ? .transition : .neutral,
                note: nil
            )
        }
    }
}
