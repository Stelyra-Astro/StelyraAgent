import CSwissEphemeris
import Foundation

/// Frozen capability boundary for the first Classical Synastry release.
///
/// Lunar nodes are deliberately outside this MVP, rather than declared
/// permanently unsupported by classical astrology. Expanding this boundary
/// requires a separate product and calculation contract.
public enum ClassicalSynastryMVPCapability {
    public static let traditionalBodies: [CelestialBody] = [
        .sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn,
    ]
    public static let aspectKinds: [AspectKind] = [
        .conjunction, .sextile, .square, .trine, .opposition,
    ]
    public static let includesLunarNodes = false
}

/// Directional traditional reception for one actual cross-chart aspect.
/// `first` and `second` always retain the caller's person ordering.
public struct CrossChartReceptionAssessment: Sendable, Equatable, Identifiable, Codable {
    public let firstBody: CelestialBody
    public let secondBody: CelestialBody
    public let aspectKind: AspectKind
    public let receptionFromFirst: HoraryReception
    public let receptionFromSecond: HoraryReception

    public var id: String {
        "first.\(firstBody.rawValue).\(aspectKind.rawValue).second.\(secondBody.rawValue)"
    }

    public init(
        firstBody: CelestialBody,
        secondBody: CelestialBody,
        aspectKind: AspectKind,
        receptionFromFirst: HoraryReception,
        receptionFromSecond: HoraryReception
    ) {
        self.firstBody = firstBody
        self.secondBody = secondBody
        self.aspectKind = aspectKind
        self.receptionFromFirst = receptionFromFirst
        self.receptionFromSecond = receptionFromSecond
    }
}

/// Classical conditions for both ordered natal charts and the traditional,
/// bidirectional reception attached to every actual cross-chart aspect.
public struct ClassicalSynastryAssessment: Sendable, Equatable, Codable {
    public let firstPlanets: [HoraryPlanetAssessment]
    public let secondPlanets: [HoraryPlanetAssessment]
    public let crossChartReceptions: [CrossChartReceptionAssessment]

    public init(
        firstPlanets: [HoraryPlanetAssessment],
        secondPlanets: [HoraryPlanetAssessment],
        crossChartReceptions: [CrossChartReceptionAssessment]
    ) {
        self.firstPlanets = firstPlanets
        self.secondPlanets = secondPlanets
        self.crossChartReceptions = crossChartReceptions
    }
}

/// Result of a two-person (synastry) comparison: both natal snapshots plus the
/// cross-chart aspects between them, all produced from one immutable pass.
public struct SynastryComparison: Sendable, Equatable, Codable {
    public let first: ChartSnapshot
    public let second: ChartSnapshot
    public let crossAspects: [ChartAspect]
    public let classicalAssessment: ClassicalSynastryAssessment?

    public init(
        first: ChartSnapshot,
        second: ChartSnapshot,
        crossAspects: [ChartAspect],
        classicalAssessment: ClassicalSynastryAssessment? = nil
    ) {
        self.first = first
        self.second = second
        self.crossAspects = crossAspects
        self.classicalAssessment = classicalAssessment
    }
}

/// Orb families from the Obsidian parameter research for the return and
/// comparison charts. Existing natal / sky / transit / secondary charts keep
/// their current uniform orbs and are unaffected.
public enum ChartOrbProfile {
    /// A-family single-chart profile from the documented presets: conjunction 7°, other major aspects 6°.
    public static let singleA: [AspectKind: Double] = [
        .conjunction: 7,
        .sextile: 6,
        .square: 6,
        .trine: 6,
        .opposition: 6,
    ]

    /// Backward-compatible name used by the existing solar-return implementation.
    public static let solarReturnSingle = singleA

    /// Dual-chart comparisons (solar return vs natal, synastry), B family:
    /// conjunction 2°, other majors 1°.
    public static let comparisonB: [AspectKind: Double] = [
        .conjunction: 2,
        .sextile: 1,
        .square: 1,
        .trine: 1,
        .opposition: 1,
    ]

    /// Classical starlight orbs: the effective orb for a pair is the smaller
    /// of the two bodies' orbs.
    public static let classicalStarlight: [CelestialBody: Double] = [
        .sun: 15,
        .moon: 12,
        .mercury: 7,
        .venus: 7,
        .mars: 8,
        .jupiter: 9,
        .saturn: 9,
        .uranus: 5,
        .neptune: 5,
        .pluto: 5,
        .trueNode: 5,
        .lilith: 5,
        .partOfFortune: 5,
        .juno: 5,
    ]
}

extension SwissEphemerisCalculator {
    /// The next moment at or after `anchorDate` when the Sun returns to its
    /// natal longitude — the solar return moment that opens the next solar year.
    public func solarReturnMoment(
        birthDate: Date,
        after anchorDate: Date
    ) throws -> Date {
        let natalSun = try sunPosition(julianDayUT: julianDay(for: birthDate)).longitude
        return try nextSolarReturnMoment(targetLongitude: natalSun, after: anchorDate)
    }

    /// Full solar return snapshot for the solar year that opens at the next
    /// return moment, using the selected consumer preset and its Obsidian orb
    /// family (modern: A family; classical: starlight per-body orbs).
    public func calculateSolarReturn(
        birthDate: Date,
        after anchorDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern,
        aspectOrbDegrees: Double? = nil
    ) throws -> ChartSnapshot {
        let moment = try solarReturnMoment(birthDate: birthDate, after: anchorDate)
        return try calculateSnapshot(
            NatalInput(utcDate: moment, location: location),
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: aspectOrbDegrees ?? preset.defaultOrbDegrees,
                orbsByKind: preset == .classical ? nil : ChartOrbProfile.solarReturnSingle,
                orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
            )
        )
    }

    /// Cross-chart aspects between a solar return chart and the natal chart,
    /// using the tight B-family orbs for the return dual wheel.
    public nonisolated static func solarReturnNatalAspects(
        solarReturn: ChartSnapshot,
        natal: ChartSnapshot
    ) -> [ChartAspect] {
        compare(
            moving: solarReturn,
            reference: natal,
            orbsByKind: ChartOrbProfile.comparisonB
        )
    }

    /// Synastry comparison between two natal charts under the same preset.
    /// Modern uses the tight B-family orbs; classical uses starlight per-body
    /// orbs, matching the Obsidian comparison-chart parameters.
    public func calculateSynastry(
        first: NatalInput,
        second: NatalInput,
        preset: CalculationPreset = .modern,
        aspectOrbDegrees: Double? = nil
    ) throws -> SynastryComparison {
        let firstSnapshot: ChartSnapshot
        let secondSnapshot: ChartSnapshot
        if preset == .classical {
            // Synastry has a narrower MVP boundary than the global Classical
            // preset: calculate only the seven traditional planets so Node
            // facts cannot leak into internal or cross-chart aspects.
            let configuration = ChartCalculationConfiguration(
                pointIDs: ClassicalSynastryMVPCapability.traditionalBodies,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: aspectOrbDegrees ?? preset.defaultOrbDegrees,
                orbsByBody: ChartOrbProfile.classicalStarlight
            )
            firstSnapshot = try calculateSnapshot(first, configuration: configuration)
            secondSnapshot = try calculateSnapshot(second, configuration: configuration)
        } else {
            firstSnapshot = try calculateSnapshot(
                first,
                preset: preset,
                aspectOrbDegrees: aspectOrbDegrees
            )
            secondSnapshot = try calculateSnapshot(
                second,
                preset: preset,
                aspectOrbDegrees: aspectOrbDegrees
            )
        }
        let crossAspects: [ChartAspect]
        if preset == .classical {
            crossAspects = Self.compare(
                moving: firstSnapshot,
                reference: secondSnapshot,
                orbsByBody: ChartOrbProfile.classicalStarlight
            )
        } else {
            crossAspects = Self.compare(
                moving: firstSnapshot,
                reference: secondSnapshot,
                orbsByKind: ChartOrbProfile.comparisonB
            )
        }
        let deterministicCrossAspects = Self.deterministicSynastryOrder(crossAspects)
        let classicalAssessment = preset == .classical
            ? Self.classicalSynastryAssessment(
                first: firstSnapshot,
                second: secondSnapshot,
                crossAspects: deterministicCrossAspects
            )
            : nil
        return SynastryComparison(
            first: firstSnapshot,
            second: secondSnapshot,
            crossAspects: deterministicCrossAspects,
            classicalAssessment: classicalAssessment
        )
    }

    private nonisolated static func classicalSynastryAssessment(
        first: ChartSnapshot,
        second: ChartSnapshot,
        crossAspects: [ChartAspect]
    ) -> ClassicalSynastryAssessment {
        let bodies = ClassicalSynastryMVPCapability.traditionalBodies
        let receptions = crossAspects.compactMap { aspect -> CrossChartReceptionAssessment? in
            guard let firstBody = CelestialBody(rawValue: aspect.firstID),
                  let secondBody = CelestialBody(rawValue: aspect.secondID),
                  bodies.contains(firstBody),
                  bodies.contains(secondBody)
            else {
                return nil
            }
            return CrossChartReceptionAssessment(
                firstBody: firstBody,
                secondBody: secondBody,
                aspectKind: aspect.kind,
                receptionFromFirst: HoraryEngine.reception(
                    from: firstBody,
                    to: secondBody,
                    in: first
                ),
                receptionFromSecond: HoraryEngine.reception(
                    from: secondBody,
                    to: firstBody,
                    in: second
                )
            )
        }
        return ClassicalSynastryAssessment(
            firstPlanets: bodies.map { HoraryEngine.assess($0, in: first) },
            secondPlanets: bodies.map { HoraryEngine.assess($0, in: second) },
            crossChartReceptions: receptions
        )
    }

    private nonisolated static func deterministicSynastryOrder(
        _ aspects: [ChartAspect]
    ) -> [ChartAspect] {
        aspects.sorted { lhs, rhs in
            if lhs.strength != rhs.strength { return lhs.strength > rhs.strength }
            if lhs.firstID != rhs.firstID { return lhs.firstID < rhs.firstID }
            if lhs.secondID != rhs.secondID { return lhs.secondID < rhs.secondID }
            if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
            if lhs.orbDegrees != rhs.orbDegrees { return lhs.orbDegrees < rhs.orbDegrees }
            return lhs.phase.rawValue < rhs.phase.rawValue
        }
    }

    // MARK: - Solar return moment search

    private struct SunPosition {
        let longitude: Double
        let speedDegreesPerDay: Double
    }

    private func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private func sunPosition(julianDayUT: Double) throws -> SunPosition {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        var values = [Double](repeating: 0, count: 6)
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let returnedFlags = values.withUnsafeMutableBufferPointer { valuesBuffer in
            errorBuffer.withUnsafeMutableBufferPointer { errorBufferPointer in
                swe_calc_ut(
                    julianDayUT,
                    Int32(SE_SUN),
                    Self.swissFlags,
                    valuesBuffer.baseAddress,
                    errorBufferPointer.baseAddress
                )
            }
        }
        guard returnedFlags >= 0 else {
            let message = String(
                decoding: errorBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) },
                as: UTF8.self
            )
            throw AstroCoreError.calculationFailed(body: "Sun", message: message)
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: "Sun", flags: returnedFlags)
        }
        return SunPosition(
            longitude: normalize360(values[0]),
            speedDegreesPerDay: values[3]
        )
    }

    private func nextSolarReturnMoment(
        targetLongitude: Double,
        after anchorDate: Date
    ) throws -> Date {
        let startJD = julianDay(for: anchorDate)
        let startPosition = try sunPosition(julianDayUT: startJD)

        // Angular distance the Sun must travel to reach the target, in [0, 360).
        var distance = (targetLongitude - startPosition.longitude)
            .truncatingRemainder(dividingBy: 360)
        if distance < 0 { distance += 360 }
        if distance < 0.000_001 {
            // Anchor sits exactly on a return moment; move to the next year.
            distance += 365.242_189 * 0.985_647_36
        }

        // Mean tropical motion of the Sun is about 0.98564736 degrees per day.
        let meanMotion = 0.985_647_36
        var guessJD = startJD + distance / meanMotion

        // Newton refinement using the instantaneous longitude and speed.
        for _ in 0 ..< 8 {
            let position = try sunPosition(julianDayUT: guessJD)
            var error = (position.longitude - targetLongitude)
                .truncatingRemainder(dividingBy: 360)
            if error > 180 { error -= 360 }
            if error < -180 { error += 360 }
            guard abs(position.speedDegreesPerDay) > 1e-9 else { break }
            let correction = error / position.speedDegreesPerDay
            guard correction.isFinite, abs(correction) < 30 else { break }
            guessJD -= correction
        }

        // Safety: the refined moment must not drift before the anchor date.
        while guessJD < startJD - 0.25 {
            guessJD += 365.242_189
        }
        return Date(timeIntervalSince1970: (guessJD - 2_440_587.5) * 86_400)
    }
}

private func normalize360(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value >= 0 ? value : value + 360
}
