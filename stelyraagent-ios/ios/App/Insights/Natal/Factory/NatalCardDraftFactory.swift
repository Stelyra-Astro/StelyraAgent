import AstroCore
import Foundation

enum NatalCardDraftFactory {
    static func make(_ context: ChartCardFactoryContext) -> [InsightCardModel] {
        InsightFactory.natalCards(context.snapshot, language: context.language)
    }
}

extension InsightFactory {
    static func natalCards(
        _ snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> [InsightCardModel] {
        let sun = snapshot.point(.sun)
        let moon = snapshot.point(.moon)
        let venus = snapshot.point(.venus)
        let ascSignIndex = Int(snapshot.angles.ascendantDegrees / 30) % 12
        let ascSign = Zodiac.name(index: ascSignIndex, language: language)
        let ascRuler = ruler(ofSign: ascSignIndex)
        let mcSignIndex = Int(snapshot.angles.midheavenDegrees / 30) % 12
        let mcRuler = ruler(ofSign: mcSignIndex)
        let mcRulerPoint = snapshot.point(mcRuler)
        let mcRulerHouse = mcRulerPoint.map { snapshot.house(containing: $0.longitudeDegrees) }
        let top = Array(snapshot.aspects.prefix(4))
        let strongestSupport = snapshot.aspects.first { $0.kind.supportive } ?? snapshot.aspects.first
        let strongestChallenge = snapshot.aspects.first { $0.kind.challenging } ?? snapshot.aspects.first
        let elementScores = elementBalance(snapshot)
        let modalityScores = modalityBalance(snapshot)
        let houseScores = houseValues(snapshot, natal: nil, aspects: snapshot.aspects)
        let activeHouses = activeHouseFacts(houseScores, language: language)
        let dominant = dominantBodies(snapshot.aspects, language: language)
        let orientation = "\(elementOrientation(elementScores, language: language)) · \(modalityOrientation(modalityScores, language: language))"
        let coreFacts: [InsightFact] = [
            sun.map { fact(localized("insight.natal.sun", language: language), Zodiac.position($0, language: language), .supportive, symbol: "☉") },
            moon.map { fact(localized("insight.natal.moon", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
            fact(localized("chart.rising", language: language), ascSign, .transition, symbol: "ASC"),
        ].compactMap { $0 }
        let loveFacts: [InsightFact] = [
            venus.map { fact(localized("insight.natal.you-give", language: language), Zodiac.position($0, language: language), .supportive, symbol: "♀") },
            moon.map { fact(localized("insight.natal.you-need", language: language), Zodiac.position($0, language: language), .neutral, symbol: "☽") },
        ].compactMap { $0 }
        let edgeFacts: [InsightFact] = [
            strongestSupport.map { fact(localized("insight.natal.core-strength", language: language), aspectTitle($0, language: language), .supportive) },
            strongestChallenge.map { fact(localized("insight.natal.growth-edge", language: language), aspectTitle($0, language: language), .challenging) },
        ].compactMap { $0 }
        let signatureFacts: [InsightFact] = [
            fact(localized("insight.natal.chart-ruler", language: language), bodyName(ascRuler, language: language), .supportive, symbol: ascRuler.symbol),
            dominant.map { fact(localized("insight.natal.dominant", language: language), $0, .transition) },
            fact(localized("insight.natal.orientation", language: language), orientation, .neutral),
        ].compactMap { $0 }

        return [
            card( id: "natal-interpretation",
                title: localized("insight.natal.natal-interpretation", language: language),
                icon: "✦", visual: .natalCore,
                facts: coreFacts,
                language: language
            ),
            card( id: "emotional-needs",
                title: localized("insight.natal.emotional-needs", language: language),
                icon: "☽", visual: .needsCard,
                facts: emotionalNeedsFacts(snapshot, language: language),
                language: language
            ),
            card( id: "love-connection",
                title: localized("insight.natal.love-connection", language: language),
                icon: "♡", visual: .dualInsight(
                    opening: venus.map { Zodiac.position($0, language: language) } ?? "",
                    demand: moon.map { Zodiac.position($0, language: language) } ?? "",
                    openingLabel: localized("insight.natal.you-give.f5b2fe5", language: language),
                    demandLabel: localized("insight.natal.you-need.b0c8f29", language: language)
                ),
                facts: loveFacts,
                language: language
            ),
            card( id: "career-direction",
                title: localized("insight.natal.career-direction", language: language),
                icon: "↗", visual: .growthPath,
                facts: careerDirectionFacts(
                    snapshot: snapshot,
                    mcSignIndex: mcSignIndex,
                    ruler: mcRuler,
                    rulerPoint: mcRulerPoint,
                    rulerHouse: mcRulerHouse,
                    language: language
                ),
                language: language
            ),
            card( id: "strengths-growth",
                title: localized("insight.natal.strengths-growth-edges", language: language),
                icon: "✚", visual: .edgeDual(
                    opening: strongestSupport.map { aspectTitle($0, language: language) } ?? "",
                    demand: strongestChallenge.map { aspectTitle($0, language: language) } ?? ""
                ),
                facts: edgeFacts,
                language: language
            ),
            card( id: "element-balance",
                title: localized("insight.natal.element-mode-balance", language: language),
                icon: "◪", visual: .elementRows,
                facts: elementFacts(elementScores, modalityScores: modalityScores, language: language),
                language: language
            ),
            card( id: "house-emphasis",
                title: localized("insight.natal.house-emphasis", language: language),
                icon: "⌂", visual: .areaRows,
                facts: Array(activeHouses.prefix(4)),
                language: language
            ),
            card( id: "chart-signature",
                title: localized("insight.natal.chart-signature", language: language),
                icon: "✶", visual: .signatureTrio(
                    ruler: ascRuler.symbol,
                    dominant: dominant ?? "",
                    orientation: orientation
                ),
                facts: signatureFacts,
                language: language
            ),
            card( id: "planet-placements",
                title: localized("insight.natal.planet-placements", language: language),
                icon: "⊛", visual: .placementList,
                facts: snapshot.points.map { point in
                    let house = snapshot.house(containing: point.longitudeDegrees)
                    let houseLabel = house > 0
                        ? AstroTerms.house(house, language: language)
                        : ""
                    return fact(
                        bodyName(point.body, language: language),
                        Zodiac.position(point, language: language),
                        point.retrograde ? .challenging : .neutral,
                        note: houseLabel.isEmpty
                            ? ConsumerCopy.lifeArea(house, language: language)
                            : "\(houseLabel) · \(ConsumerCopy.lifeArea(house, language: language))",
                        symbol: point.body.symbol,
                        category: semanticCategory(point.body, language: language)
                    )
                },
                language: language
            ),
            card( id: "key-aspects",
                title: localized("insight.natal.key-aspects", language: language),
                icon: "⌗", visual: .aspectList,
                facts: top.map {
                    fact(
                        aspectTitle($0, language: language),
                        "\(phaseLabel($0.phase, language: language)) · \(ConsumerCopy.intensity($0.strength, language: language))",
                        tone($0.kind),
                        note: ConsumerCopy.lifeArea(snapshot.house(containing: $0.firstLongitude), language: language),
                        progress: $0.strength,
                        symbol: $0.kind.supportive ? "△" : $0.kind.challenging ? "□" : "○"
                    )
                },
                language: language
            ),
        ]
    }

    // MARK: - Current Sky (7)

    static func emotionalNeedsFacts(_ snapshot: ChartSnapshot, language: AppLanguage) -> [InsightFact] {
        guard let moon = snapshot.point(.moon) else { return [] }
        let house = snapshot.house(containing: moon.longitudeDegrees)
        guard house > 0 else { return [] }
        let technical = localizedTemplate("dynamic.259fa5e386", substitutions: ["value1": String(describing: Zodiac.name(index: moon.signIndex, language: language)), "value2": String(describing: house), "value3": String(describing: ConsumerCopy.lifeArea(house, language: language))], language: language)
        return [
            fact(
                localized("insight.natal.calculated-pattern", language: language),
                technical,
                .neutral,
                stableID: "natal.emotional-needs.moon",
                interpretationKey: "natal.emotional-needs.moon-sign-\(moon.signIndex).house-\(house)",
                sourceFactIDs: ["point.moon"],
                symbol: "☽"
            ),
        ]
    }

    static func careerDirectionFacts(
        snapshot: ChartSnapshot,
        mcSignIndex: Int,
        ruler: CelestialBody,
        rulerPoint: ChartPoint?,
        rulerHouse: Int?,
        language: AppLanguage
    ) -> [InsightFact] {
        var facts = [
            fact(
                localized("insight.natal.public-style", language: language),
                Zodiac.name(index: mcSignIndex, language: language),
                .neutral,
                stableID: "natal.career-direction.midheaven",
                interpretationKey: "natal.career-direction.midheaven-sign-\(mcSignIndex)",
                sourceFactIDs: ["angle.midheaven"],
                symbol: "MC"
            ),
        ]
        if let rulerPoint, let rulerHouse, rulerHouse > 0 {
            facts.append(
                fact(
                    localized("insight.natal.direction-ruler", language: language),
                    "\(bodyName(ruler, language: language)) · \(Zodiac.position(rulerPoint, language: language))",
                    .transition,
                    stableID: "natal.career-direction.ruler",
                    interpretationKey: "natal.career-direction.ruler-\(ruler.rawValue).house-\(rulerHouse)",
                    sourceFactIDs: ["point.\(ruler.rawValue)"],
                    symbol: ruler.symbol
                )
            )
            facts.append(
                fact(
                    localized("insight.natal.contribution-arena", language: language),
                    ConsumerCopy.lifeArea(rulerHouse, language: language),
                    .supportive,
                    stableID: "natal.career-direction.ruler-house",
                    interpretationKey: "natal.career-direction.house-\(rulerHouse)",
                    sourceFactIDs: ["point.\(ruler.rawValue)"],
                    symbol: "\(rulerHouse)"
                )
            )
        }
        return facts
    }

    // MARK: - Solar return anchors (prototype .connection-grid / .compare-strip)

    static func semanticCategory(_ body: CelestialBody, language: AppLanguage) -> String {
        switch body {
        case .sun, .moon: localized("insight.natal.category.core-self", language: language)
        case .mercury: localized("insight.natal.category.mind-voice", language: language)
        case .venus: localized("insight.natal.category.heart-values", language: language)
        case .mars: localized("insight.natal.category.drive-action", language: language)
        case .jupiter: localized("insight.natal.category.growth-belief", language: language)
        case .saturn: localized("insight.natal.category.structure-limits", language: language)
        case .uranus: localized("insight.natal.category.change-innovation", language: language)
        case .neptune: localized("insight.natal.category.vision-intuition", language: language)
        case .pluto: localized("insight.natal.category.transformation-power", language: language)
        case .trueNode: localized("insight.natal.category.direction-fate", language: language)
        case .lilith, .partOfFortune, .juno: localized("insight.natal.category.direction-fate", language: language)
        }
    }

    // MARK: - Transit timeline helpers (TR-02/TR-04)
}
