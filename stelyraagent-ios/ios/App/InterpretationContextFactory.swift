import AstroCore
import ContentKit
import Foundation

enum InterpretationContextFactory {
    private static let signIDs = [
        "aries", "taurus", "gemini", "cancer", "leo", "virgo",
        "libra", "scorpio", "sagittarius", "capricorn", "aquarius", "pisces",
    ]

    static func make(
        chart: ChartKind,
        cardID: String,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage,
        transitCalendar: [Int],
        preset: String? = nil,
        aspectsAreCross: Bool = false,
        events: ChartEventData = .empty
    ) -> InterpretationContext {
        let normalizedAspects = aspects.sorted(by: aspectOrder)
        let aspectSignals = makeAspectSignals(
            chart: chart,
            snapshot: snapshot,
            natal: natal,
            aspects: normalizedAspects,
            language: language,
            aspectsAreCross: aspectsAreCross
        )
        let pointSignals = makePointSignals(
            chart: chart,
            snapshot: snapshot,
            natal: natal,
            aspects: normalizedAspects,
            language: language
        )
        let houseSignals = makeHouseSignals(
            chart: chart,
            snapshot: snapshot,
            natal: natal,
            aspects: normalizedAspects,
            language: language
        )
        let phaseSignal = makeLunarPhaseSignal(snapshot: snapshot, language: language)
        let calendarSignals = makeCalendarSignals(
            calendar: transitCalendar,
            language: language
        )
        let eventSignals = makeEventSignals(
            chart: chart,
            events: events,
            language: language
        )
        let supportive = normalizedAspects.filter(\.kind.supportive).count
        let challenging = normalizedAspects.filter(\.kind.challenging).count
        let neutral = max(0, normalizedAspects.count - supportive - challenging)
        let activity = activityScore(normalizedAspects)
        let retrogradeCount = snapshot.points.filter(\.retrograde).count
        let topHouse = houseSignals.first?.house
        let peakDay = strongestCalendarDay(transitCalendar)
        let quietDay = weakestCalendarDay(transitCalendar)

        let allSignals = aspectSignals
            + pointSignals
            + houseSignals
            + [phaseSignal]
            + calendarSignals
            + eventSignals
        let contextValues: [String: String] = [
            "chartID": chart.rawValue,
            "supportiveCount": String(supportive),
            "challengingCount": String(challenging),
            "neutralCount": String(neutral),
            "aspectCount": String(normalizedAspects.count),
            "activityScore": String(activity),
            "activityLabel": activityLabel(activity, language: language),
            "retrogradeCount": String(retrogradeCount),
            "lunarPhaseAngle": formatNumber(lunarPhaseAngle(snapshot)),
            "lunarPhaseName": lunarPhaseName(lunarPhaseAngle(snapshot), language: language),
            "topHouse": topHouse.map(String.init) ?? "",
            "topHouseName": topHouse.map { houseName($0, language: language) } ?? "",
            "calendarPeakDay": peakDay.map(String.init) ?? "",
            "calendarQuietDay": quietDay.map(String.init) ?? "",
        ]
        return InterpretationContext(
            technique: technique(for: chart),
            cardID: cardID,
            locale: language.rawValue,
            signals: allSignals,
            preset: preset,
            values: contextValues
        )
    }

    private static func makeEventSignals(
        chart: ChartKind,
        events: ChartEventData,
        language: AppLanguage
    ) -> [InterpretationSignal] {
        var signals: [InterpretationSignal] = []
        signals += events.skyIngresses.enumerated().map { index, event in
            InterpretationSignal(
                id: "event.ingress.\(event.body.rawValue).\(Int(event.date.timeIntervalSince1970))",
                rank: index + 1,
                strength: 1,
                pointID: event.body.rawValue,
                signID: signIDs[event.signIndex],
                tone: .transition,
                tags: ["event", "ingress", "sky-event"],
                values: [
                    "bodyLabel": bodyName(event.body, language: language),
                    "signLabel": Zodiac.name(index: event.signIndex, language: language),
                    "eventDate": event.date.ISO8601Format(),
                ]
            )
        }
        signals += events.skyExactEvents.enumerated().map { index, event in
            InterpretationSignal(
                id: "event.sky-exact.\(event.first.rawValue).\(event.second.rawValue).\(Int(event.date.timeIntervalSince1970))",
                rank: index + 1,
                strength: 1,
                pointID: event.first.rawValue,
                referencePointID: event.second.rawValue,
                aspectID: event.kind.rawValue,
                phaseID: "exact",
                tone: interpretationTone(event.kind),
                tags: ["event", "exact", "aspect", "sky-event"],
                values: [
                    "bodyLabel": bodyName(event.first, language: language),
                    "referenceBodyLabel": bodyName(event.second, language: language),
                    "consumerLink": ConsumerCopy.connectionLabel(event.kind, language: language),
                    "aspectName": aspectKindName(event.kind, language: language),
                    "eventDate": event.date.ISO8601Format(),
                ]
            )
        }
        signals += events.skyStations.enumerated().map { index, event in
            InterpretationSignal(
                id: "event.station.\(event.body.rawValue).\(Int(event.date.timeIntervalSince1970))",
                rank: index + 1,
                strength: 1,
                pointID: event.body.rawValue,
                tone: .transition,
                tags: ["event", "station", "sky-event", event.retrogradeAfter ? "retrograde" : "direct"],
                values: [
                    "bodyLabel": bodyName(event.body, language: language),
                    "consumerMotion": event.retrogradeAfter
                        ? localized("interpretation.stations-retrograde", language: language)
                        : localized("interpretation.stations-direct", language: language),
                    "eventDate": event.date.ISO8601Format(),
                ]
            )
        }
        signals += events.transitWindows.enumerated().map { index, event in
            InterpretationSignal(
                id: "event.transit-window.\(event.first.rawValue).\(event.second.rawValue).\(Int(event.exact.timeIntervalSince1970))",
                rank: index + 1,
                strength: 1,
                pointID: event.first.rawValue,
                referencePointID: event.second.rawValue,
                aspectID: event.kind.rawValue,
                tone: interpretationTone(event.kind),
                tags: ["event", "transit-window", "cross-chart", "moving-transit"],
                values: [
                    "bodyLabel": bodyName(event.first, language: language),
                    "referenceBodyLabel": bodyName(event.second, language: language),
                    "consumerLink": ConsumerCopy.connectionLabel(event.kind, language: language),
                    "eventDate": event.exact.ISO8601Format(),
                ]
            )
        }
        signals += events.progressedTurningPoints.enumerated().map { index, event in
            InterpretationSignal(
                id: "event.progressed-turning.\(event.first.rawValue).\(event.second.rawValue).\(index)",
                rank: index + 1,
                strength: 1,
                pointID: event.first.rawValue,
                referencePointID: event.second.rawValue,
                aspectID: event.kind.rawValue,
                tone: interpretationTone(event.kind),
                tags: ["event", "turning-point", "cross-chart", "moving-progressed"],
                values: [
                    "bodyLabel": bodyName(event.first, language: language),
                    "referenceBodyLabel": bodyName(event.second, language: language),
                    "consumerLink": ConsumerCopy.connectionLabel(event.kind, language: language),
                    "eventDate": event.exactDate?.ISO8601Format() ?? "",
                ]
            )
        }
        if let event = events.progressedMoon {
            signals.append(
                InterpretationSignal(
                    id: "event.progressed-moon.\(event.signIndex)",
                    rank: 1,
                    strength: 1,
                    pointID: CelestialBody.moon.rawValue,
                    signID: signIDs[event.signIndex],
                    tone: .transition,
                    tags: ["event", "progressed-moon", "moving-progressed"],
                    values: [
                        "bodyLabel": bodyName(.moon, language: language),
                        "signLabel": Zodiac.name(index: event.signIndex, language: language),
                        "eventDate": event.nextIngress.ISO8601Format(),
                    ]
                )
            )
        }
        signals += events.solarSeasons.map { event in
            InterpretationSignal(
                id: "event.solar-season.\(event.index)",
                rank: event.index + 1,
                strength: 1,
                tone: .transition,
                tags: ["event", "solar-season"],
                values: [
                    "seasonIndex": String(event.index + 1),
                    "eventDate": event.start.ISO8601Format(),
                ]
            )
        }
        return signals
    }

    private static func makeAspectSignals(
        chart: ChartKind,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage,
        aspectsAreCross: Bool
    ) -> [InterpretationSignal] {
        aspects.enumerated().map { index, aspect in
            let point = body(for: aspect.firstID)
            let reference = body(for: aspect.secondID)
            let movingHouse = aspectsAreCross
                ? natal?.house(containing: aspect.firstLongitude)
                : snapshot.house(containing: aspect.firstLongitude)
            let pointName = point.map { bodyName($0, language: language) } ?? aspect.firstID
            let referenceName = reference.map { bodyName($0, language: language) } ?? aspect.secondID
            let tone = interpretationTone(aspect.kind)
            var tags: Set<String> = [
                "aspect",
                aspect.kind.rawValue,
                aspect.phase.rawValue,
                tone.rawValue,
            ]
            if aspectsAreCross {
                tags.insert("cross-chart")
                switch chart {
                case .transit: tags.insert("moving-transit")
                case .secondary: tags.insert("moving-progressed")
                case .solarReturn: tags.insert("solar-return-overlay")
                case .synastry: tags.insert("synastry-cross")
                case .tertiary: tags.insert("moving-tertiary")
                case .lunarReturn: tags.insert("lunar-return-overlay")
                case .solarArc: tags.insert("solar-arc-directed")
                case .twelfthHarmonic: tags.insert("harmonic-12-overlay")
                case .thirteenthHarmonic: tags.insert("harmonic-13-overlay")
                case .natal, .currentSky, .relocation: break
                }
            } else {
                tags.insert("single-chart")
            }
            if isPersonal(point) || isPersonal(reference) {
                tags.insert("personal")
            }
            if isSocial(point) || isSocial(reference) {
                tags.insert("social")
            }
            if isOuter(point) || isOuter(reference) {
                tags.insert("outer")
            }
            if aspect.strength >= 0.8 {
                tags.insert("tight")
            } else if aspect.strength >= 0.5 {
                tags.insert("moderate")
            } else {
                tags.insert("wide")
            }

            return InterpretationSignal(
                id: "\(chart.rawValue).aspect.\(aspect.id).\(index + 1)",
                rank: index + 1,
                strength: aspect.strength,
                pointID: aspect.firstID,
                referencePointID: aspect.secondID,
                signID: signID(longitude: aspect.firstLongitude),
                house: movingHouse.flatMap { $0 > 0 ? $0 : nil },
                aspectID: aspect.kind.rawValue,
                phaseID: aspect.phase.rawValue,
                tone: tone,
                tags: tags,
                values: [
                    "pointName": pointName,
                    "bodyLabel": bodyName(point ?? .sun, language: language),
                    "referencePointName": referenceName,
                    "referenceBodyLabel": bodyName(reference ?? .moon, language: language),
                    "aspectName": aspectKindName(aspect.kind, language: language),
                    "phaseName": phaseName(aspect.phase, language: language),
                    "orb": formatOrb(aspect.orbDegrees),
                    "consumerTitle": ConsumerCopy.connectionTitle(aspect, language: language),
                    "consumerFirst": ConsumerCopy.bodyTheme(point, language: language),
                    "consumerSecond": ConsumerCopy.bodyTheme(reference, language: language),
                    "consumerLink": ConsumerCopy.connectionLabel(aspect.kind, language: language),
                    "consumerTiming": ConsumerCopy.timing(aspect.phase, language: language),
                    "consumerIntensity": ConsumerCopy.intensity(aspect.strength, language: language),
                    "consumerArea": ConsumerCopy.lifeArea(movingHouse, language: language),
                    "strengthPercent": String(Int((aspect.strength * 100).rounded())),
                    "movingHouse": movingHouse.flatMap { $0 > 0 ? String($0) : nil } ?? "",
                    "movingHouseName": movingHouse.flatMap { $0 > 0 ? houseName($0, language: language) : nil } ?? "",
                    "title": "\(pointName) \(aspectKindName(aspect.kind, language: language)) \(referenceName)",
                ]
            )
        }
    }

    private static func makePointSignals(
        chart: ChartKind,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InterpretationSignal] {
        let scored = snapshot.points.map { point -> (ChartPoint, Double) in
            let related = aspects.filter { $0.firstID == point.id || (!chart.isComparison && $0.secondID == point.id) }
            let strength = related.prefix(3).reduce(0.0) { $0 + $1.strength } / 3
            return (point, min(1, max(0.05, strength)))
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            return bodyOrder($0.0.body) < bodyOrder($1.0.body)
        }

        return scored.enumerated().map { index, item in
            let point = item.0
            let house = chart.isComparison
                ? natal?.house(containing: point.longitudeDegrees)
                : snapshot.house(containing: point.longitudeDegrees)
            let name = bodyName(point.body, language: language)
            var tags: Set<String> = [
                "point",
                point.retrograde ? "retrograde" : "direct",
                bodyGroup(point.body),
            ]
            if point.body == .sun || point.body == .moon {
                tags.insert("luminary")
            }
            if chart.isComparison {
                tags.insert("moving-point")
            }

            return InterpretationSignal(
                id: "\(chart.rawValue).point.\(point.id)",
                rank: index + 1,
                strength: item.1,
                pointID: point.id,
                signID: signIDs[point.signIndex],
                house: house.flatMap { $0 > 0 ? $0 : nil },
                tone: point.retrograde ? .transition : .neutral,
                tags: tags,
                values: [
                    "pointName": name,
                    "bodyLabel": bodyName(point.body, language: language),
                    "signName": Zodiac.name(index: point.signIndex, language: language),
                    "signLabel": Zodiac.name(index: point.signIndex, language: language),
                    "position": Zodiac.position(point, language: language),
                    "consumerTheme": ConsumerCopy.bodyTheme(point.body, language: language),
                    "consumerArea": ConsumerCopy.lifeArea(house, language: language),
                    "consumerStyle": ConsumerCopy.style(signIndex: point.signIndex, language: language),
                    "consumerMotion": ConsumerCopy.motion(isRetrograde: point.retrograde, language: language),
                    "degree": Zodiac.formatDegree(point.degreeInSign),
                    "house": house.flatMap { $0 > 0 ? String($0) : nil } ?? "",
                    "houseName": house.flatMap { $0 > 0 ? houseName($0, language: language) : nil } ?? "",
                    "motionName": point.retrograde
                        ? localized("interpretation.retrograde", language: language)
                        : localized("interpretation.direct", language: language),
                    "speed": formatNumber(point.position.longitudeSpeedDegreesPerDay),
                ]
            )
        }
    }

    private static func makeHouseSignals(
        chart: ChartKind,
        snapshot: ChartSnapshot,
        natal: ChartSnapshot?,
        aspects: [ChartAspect],
        language: AppLanguage
    ) -> [InterpretationSignal] {
        let houseSnapshot = chart.isComparison ? natal : snapshot
        guard let houseSnapshot else { return [] }

        var scores = Dictionary(uniqueKeysWithValues: (1 ... 12).map { ($0, 0.0) })
        for point in snapshot.points {
            let house = houseSnapshot.house(containing: point.longitudeDegrees)
            guard (1 ... 12).contains(house) else { continue }
            let related = aspects
                .filter { $0.firstID == point.id || (!chart.isComparison && $0.secondID == point.id) }
                .prefix(3)
                .reduce(0.0) { $0 + $1.strength }
            scores[house, default: 0] += max(0.1, related)
        }

        let ranked = scores
            .filter { $0.value > 0 }
            .sorted {
                if $0.value != $1.value { return $0.value > $1.value }
                return $0.key < $1.key
            }
        let maximum = max(ranked.first?.value ?? 1, 0.001)
        return ranked.enumerated().map { index, item in
            let normalized = min(1, item.value / maximum)
            return InterpretationSignal(
                id: "\(chart.rawValue).house.\(item.key)",
                rank: index + 1,
                strength: normalized,
                house: item.key,
                tone: .transition,
                tags: ["house", "active-domain", index < 3 ? "leading-domain" : "supporting-domain"],
                values: [
                    "house": String(item.key),
                    "houseName": houseName(item.key, language: language),
                    "consumerArea": ConsumerCopy.lifeArea(item.key, language: language),
                    "activityPercent": String(Int((normalized * 100).rounded())),
                ]
            )
        }
    }

    private static func makeLunarPhaseSignal(
        snapshot: ChartSnapshot,
        language: AppLanguage
    ) -> InterpretationSignal {
        let angle = lunarPhaseAngle(snapshot)
        let phaseID = lunarPhaseID(angle)
        return InterpretationSignal(
            id: "lunar-phase.\(phaseID)",
            rank: 1,
            strength: lunarPhaseStrength(angle),
            pointID: CelestialBody.moon.rawValue,
            referencePointID: CelestialBody.sun.rawValue,
            phaseID: phaseID,
            tone: .transition,
            tags: ["lunar-phase", "phase", phaseID],
            values: [
                "angle": formatNumber(angle),
                "phaseName": lunarPhaseName(angle, language: language),
                "consumerStage": ConsumerCopy.cycleStage(angle: angle, language: language),
            ]
        )
    }

    private static func makeCalendarSignals(
        calendar: [Int],
        language: AppLanguage
    ) -> [InterpretationSignal] {
        calendar.enumerated()
            .filter { $0.element > 0 }
            .sorted {
                if $0.element != $1.element { return $0.element > $1.element }
                return $0.offset < $1.offset
            }
            .prefix(7)
            .enumerated()
            .map { rank, item in
                let day = item.offset + 1
                let strength = min(1, Double(item.element) / 100)
                return InterpretationSignal(
                    id: "transit.calendar.day-\(day)",
                    rank: rank + 1,
                    strength: strength,
                    tone: .transition,
                    tags: ["calendar", rank == 0 ? "calendar-peak" : "calendar-active"],
                    values: [
                        "day": String(day),
                        "dayLabel": LocalizedFormatters.calendarDay(day, language: language),
                        "intensity": String(item.element),
                    ]
                )
            }
    }

    private static func technique(for chart: ChartKind) -> InterpretationTechnique {
        switch chart {
        case .natal: .natal
        case .currentSky: .currentSky
        case .transit: .transit
        case .secondary: .secondary
        case .solarReturn: .solarReturn
        case .synastry: .synastry
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            preconditionFailure("Advanced charts do not use local interpretation cards")
        }
    }

    private static func body(for id: String) -> CelestialBody? {
        CelestialBody(rawValue: id)
    }

    private static func signID(longitude: Double) -> String {
        let normalized = longitude.truncatingRemainder(dividingBy: 360)
        let positive = normalized >= 0 ? normalized : normalized + 360
        return signIDs[Int(positive / 30) % 12]
    }

    private static func interpretationTone(_ kind: AspectKind) -> InterpretationTone {
        if kind.supportive { return .supportive }
        if kind.challenging { return .challenging }
        return .neutral
    }

    private static func aspectOrder(_ lhs: ChartAspect, _ rhs: ChartAspect) -> Bool {
        if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
        if lhs.orbDegrees != rhs.orbDegrees { return lhs.orbDegrees < rhs.orbDegrees }
        return lhs.id < rhs.id
    }

    private static func isPersonal(_ body: CelestialBody?) -> Bool {
        guard let body else { return false }
        return [.sun, .moon, .mercury, .venus, .mars].contains(body)
    }

    private static func isSocial(_ body: CelestialBody?) -> Bool {
        guard let body else { return false }
        return [.jupiter, .saturn].contains(body)
    }

    private static func isOuter(_ body: CelestialBody?) -> Bool {
        guard let body else { return false }
        return [.uranus, .neptune, .pluto].contains(body)
    }

    private static func bodyGroup(_ body: CelestialBody) -> String {
        if isPersonal(body) { return "personal" }
        if isSocial(body) { return "social" }
        if isOuter(body) { return "outer" }
        return "node"
    }

    private static func bodyOrder(_ body: CelestialBody) -> Int {
        CelestialBody.allCases.firstIndex(of: body) ?? Int.max
    }

    private static func phaseName(_ phase: AspectPhase, language: AppLanguage) -> String {
        AstroTerms.value("aspectPhases", phase.rawValue, language: language)
    }

    private static func houseName(_ house: Int, language: AppLanguage) -> String {
        AstroTerms.house(house, language: language)
    }

    private static func formatOrb(_ value: Double) -> String {
        String(format: "%.2f°", value)
    }

    private static func formatNumber(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private static func activityScore(_ aspects: [ChartAspect]) -> Int {
        guard !aspects.isEmpty else { return 0 }
        let weighted = aspects.prefix(12).reduce(0.0) { $0 + $1.strength }
        return Int(min(1, weighted / Double(min(12, aspects.count))) * 100)
    }

    private static func activityLabel(_ value: Int, language: AppLanguage) -> String {
        switch value {
        case 0 ... 20: localized("interpretation.low", language: language)
        case 21 ... 45: localized("interpretation.moderate", language: language)
        case 46 ... 70: localized("interpretation.high", language: language)
        default: localized("interpretation.very-high", language: language)
        }
    }

    private static func lunarPhaseAngle(_ snapshot: ChartSnapshot) -> Double {
        guard let sun = snapshot.point(.sun), let moon = snapshot.point(.moon) else { return 0 }
        let raw = (moon.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        return raw >= 0 ? raw : raw + 360
    }

    private static func lunarPhaseID(_ angle: Double) -> String {
        switch angle {
        case 0 ..< 45: "new-moon"
        case 45 ..< 90: "waxing-crescent"
        case 90 ..< 135: "first-quarter"
        case 135 ..< 180: "waxing-gibbous"
        case 180 ..< 225: "full-moon"
        case 225 ..< 270: "waning-gibbous"
        case 270 ..< 315: "last-quarter"
        default: "waning-crescent"
        }
    }

    private static func lunarPhaseName(_ angle: Double, language: AppLanguage) -> String {
        AstroTerms.value("moonPhases", lunarPhaseID(angle), language: language)
    }

    private static func lunarPhaseStrength(_ angle: Double) -> Double {
        let nearestMajor = [0.0, 90.0, 180.0, 270.0, 360.0]
            .map { abs(angle - $0) }
            .min() ?? 45
        return max(0, 1 - nearestMajor / 45)
    }

    private static func strongestCalendarDay(_ calendar: [Int]) -> Int? {
        calendar.enumerated()
            .max { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset > rhs.offset : lhs.element < rhs.element
            }
            .flatMap { $0.element > 0 ? $0.offset + 1 : nil }
    }

    private static func weakestCalendarDay(_ calendar: [Int]) -> Int? {
        calendar.enumerated()
            .min { lhs, rhs in
                lhs.element == rhs.element ? lhs.offset < rhs.offset : lhs.element < rhs.element
            }
            .map { $0.offset + 1 }
    }
}
