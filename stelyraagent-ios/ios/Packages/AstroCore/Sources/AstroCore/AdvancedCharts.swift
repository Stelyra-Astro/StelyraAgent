import CSwissEphemeris
import Foundation

public struct LunarReturnCalculation: Sendable, Equatable, Codable {
    public let snapshot: ChartSnapshot
    public let returnMoment: Date
    public let natalMoonLongitude: Double

    public init(snapshot: ChartSnapshot, returnMoment: Date, natalMoonLongitude: Double) {
        self.snapshot = snapshot
        self.returnMoment = returnMoment
        self.natalMoonLongitude = natalMoonLongitude
    }
}

public struct SolarArcCalculation: Sendable, Equatable, Codable {
    public let snapshot: ChartSnapshot
    public let natal: ChartSnapshot
    public let progressedDate: Date
    public let arcDegrees: Double

    public init(snapshot: ChartSnapshot, natal: ChartSnapshot, progressedDate: Date, arcDegrees: Double) {
        self.snapshot = snapshot
        self.natal = natal
        self.progressedDate = progressedDate
        self.arcDegrees = arcDegrees
    }
}

extension SwissEphemerisCalculator {
    /// Tertiary-I key used by the supplied chart documentation: one ephemeris
    /// day corresponds to one sidereal lunar month in real time.
    public nonisolated static let tertiaryMonthDays = 27.321_582_18

    public nonisolated static func tertiaryProgressedDate(birthDate: Date, targetDate: Date) -> Date {
        let elapsedDays = max(0, targetDate.timeIntervalSince(birthDate) / 86_400)
        return birthDate.addingTimeInterval((elapsedDays / tertiaryMonthDays) * 86_400)
    }

    public nonisolated static func tertiaryTargetDate(birthDate: Date, progressedDate: Date) -> Date {
        let progressedDays = max(0, progressedDate.timeIntervalSince(birthDate) / 86_400)
        return birthDate.addingTimeInterval(progressedDays * tertiaryMonthDays * 86_400)
    }

    public func calculateTertiaryProgression(
        birthDate: Date,
        targetDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern
    ) throws -> ChartSnapshot {
        let progressedDate = Self.tertiaryProgressedDate(birthDate: birthDate, targetDate: targetDate)
        return try calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: location),
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: preset.defaultOrbDegrees,
                orbsByKind: preset == .classical ? nil : ChartOrbProfile.comparisonB,
                orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
            )
        )
    }

    public func calculateRelocation(
        birthDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern
    ) throws -> ChartSnapshot {
        try calculateSnapshot(
            NatalInput(utcDate: birthDate, location: location),
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: preset.defaultOrbDegrees,
                orbsByKind: preset == .classical ? nil : ChartOrbProfile.singleA,
                orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
            )
        )
    }

    public nonisolated static func harmonicSnapshot(
        from natal: ChartSnapshot,
        harmonic: Int,
        preset: CalculationPreset
    ) -> ChartSnapshot {
        precondition(harmonic > 0, "Harmonic number must be positive")
        let multiplier = Double(harmonic)
        let points = natal.points.map { point in
            ChartPoint(
                body: point.body,
                position: CelestialPosition(
                    longitudeDegrees: advancedNormalize(point.longitudeDegrees * multiplier),
                    latitudeDegrees: point.position.latitudeDegrees,
                    distanceAU: point.position.distanceAU,
                    longitudeSpeedDegreesPerDay: point.position.longitudeSpeedDegreesPerDay * multiplier
                )
            )
        }
        let aspects = Self.calculateAspects(
            for: points,
            orbDegrees: preset.defaultOrbDegrees,
            orbsByKind: preset == .classical ? nil : ChartOrbProfile.singleA,
            orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
        )
        return ChartSnapshot(
            utcDate: natal.utcDate,
            location: natal.location,
            julianDayUT: natal.julianDayUT,
            points: points,
            houses: natal.houses,
            angles: NatalAngles(
                ascendantDegrees: advancedNormalize(natal.angles.ascendantDegrees * multiplier),
                midheavenDegrees: advancedNormalize(natal.angles.midheavenDegrees * multiplier)
            ),
            aspects: aspects
        )
    }

    public func calculateSolarArc(
        birthDate: Date,
        targetDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern
    ) throws -> SolarArcCalculation {
        let natal = try calculateSnapshot(
            NatalInput(utcDate: birthDate, location: location),
            preset: preset
        )
        let progressedDate = Self.secondaryProgressedDate(birthDate: birthDate, targetDate: targetDate)
        let progressed = try calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: location),
            preset: preset
        )
        let natalSun = natal.point(.sun)?.longitudeDegrees ?? 0
        let progressedSun = progressed.point(.sun)?.longitudeDegrees ?? natalSun
        let arcDegrees = advancedNormalize(progressedSun - natalSun)
        let directedSpeed = (progressed.point(.sun)?.position.longitudeSpeedDegreesPerDay ?? 0) / 365.2425
        let points = natal.points.map { point in
            ChartPoint(
                body: point.body,
                position: CelestialPosition(
                    longitudeDegrees: advancedNormalize(point.longitudeDegrees + arcDegrees),
                    latitudeDegrees: point.position.latitudeDegrees,
                    distanceAU: point.position.distanceAU,
                    longitudeSpeedDegreesPerDay: directedSpeed
                )
            )
        }
        let aspects = Self.calculateAspects(
            for: points,
            orbDegrees: preset.defaultOrbDegrees,
            orbsByKind: preset == .classical ? nil : ChartOrbProfile.comparisonB,
            orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
        )
        let targetJD = targetDate.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let snapshot = ChartSnapshot(
            utcDate: targetDate,
            location: location,
            julianDayUT: targetJD,
            points: points,
            houses: natal.houses,
            angles: NatalAngles(
                ascendantDegrees: advancedNormalize(natal.angles.ascendantDegrees + arcDegrees),
                midheavenDegrees: advancedNormalize(natal.angles.midheavenDegrees + arcDegrees)
            ),
            aspects: aspects
        )
        return SolarArcCalculation(
            snapshot: snapshot,
            natal: natal,
            progressedDate: progressedDate,
            arcDegrees: arcDegrees
        )
    }

    public nonisolated static func advancedComparisonAspects(
        moving: ChartSnapshot,
        reference: ChartSnapshot,
        preset: CalculationPreset
    ) -> [ChartAspect] {
        if preset == .classical {
            return compare(
                moving: moving,
                reference: reference,
                orbsByBody: ChartOrbProfile.classicalStarlight
            )
        }
        return compare(
            moving: moving,
            reference: reference,
            orbsByKind: ChartOrbProfile.comparisonB
        )
    }

    /// Returns the lunar return that opened the lunar-return cycle containing
    /// `targetDate` (the most recent exact return at or before the target).
    public func calculateLunarReturn(
        birthDate: Date,
        onOrBefore targetDate: Date,
        location: GeographicLocation,
        preset: CalculationPreset = .modern
    ) throws -> LunarReturnCalculation {
        let natalMoon = try advancedBodyPosition(body: .moon, at: birthDate).longitude
        // Search far enough back to guarantee at least one return, then walk
        // forward until the next exact return would lie after the target. A
        // fixed 32-day window can contain two returns when the first falls near
        // the window start, so taking only the first crossing is insufficient.
        let searchAnchor = targetDate.addingTimeInterval(-35 * 86_400)
        var returnMoment = try nextAdvancedReturnMoment(
            body: .moon,
            targetLongitude: natalMoon,
            after: searchAnchor,
            meanMotionDegreesPerDay: 13.176_358
        )
        for _ in 0 ..< 3 {
            let next = try nextAdvancedReturnMoment(
                body: .moon,
                targetLongitude: natalMoon,
                after: returnMoment.addingTimeInterval(60),
                meanMotionDegreesPerDay: 13.176_358
            )
            guard next <= targetDate else { break }
            returnMoment = next
        }
        let snapshot = try calculateSnapshot(
            NatalInput(utcDate: returnMoment, location: location),
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: preset.defaultOrbDegrees,
                orbsByKind: preset == .classical ? nil : ChartOrbProfile.singleA,
                orbsByBody: preset == .classical ? ChartOrbProfile.classicalStarlight : nil
            )
        )
        return LunarReturnCalculation(
            snapshot: snapshot,
            returnMoment: returnMoment,
            natalMoonLongitude: natalMoon
        )
    }

    private struct AdvancedBodyPosition {
        let longitude: Double
        let speedDegreesPerDay: Double
    }

    private func advancedBodyPosition(body: CelestialBody, at date: Date) throws -> AdvancedBodyPosition {
        let julianDay = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        swe_set_ephe_path(ephemerisPath)
        guard let swissID = body.swissID else {
            throw AstroCoreError.eventNotFound("Derived point \(body.displayName) has no ephemeris position for this calculation.")
        }
        var values = [Double](repeating: 0, count: 6)
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let returnedFlags = values.withUnsafeMutableBufferPointer { valuesBuffer in
            errorBuffer.withUnsafeMutableBufferPointer { errorBufferPointer in
                swe_calc_ut(
                    julianDay,
                    swissID,
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
            throw AstroCoreError.calculationFailed(body: body.displayName, message: message)
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: body.displayName, flags: returnedFlags)
        }
        return AdvancedBodyPosition(
            longitude: advancedNormalize(values[0]),
            speedDegreesPerDay: values[3]
        )
    }

    private func nextAdvancedReturnMoment(
        body: CelestialBody,
        targetLongitude: Double,
        after anchorDate: Date,
        meanMotionDegreesPerDay: Double
    ) throws -> Date {
        let startPosition = try advancedBodyPosition(body: body, at: anchorDate)
        var distance = advancedNormalize(targetLongitude - startPosition.longitude)
        if distance < 0.000_001 {
            return anchorDate
        }
        var guessDate = anchorDate.addingTimeInterval((distance / meanMotionDegreesPerDay) * 86_400)
        for _ in 0 ..< 12 {
            let position = try advancedBodyPosition(body: body, at: guessDate)
            var error = (position.longitude - targetLongitude).truncatingRemainder(dividingBy: 360)
            if error > 180 { error -= 360 }
            if error < -180 { error += 360 }
            if abs(error) < 0.000_000_1 { break }
            guard abs(position.speedDegreesPerDay) > 1e-9 else { break }
            let correctionDays = error / position.speedDegreesPerDay
            guard correctionDays.isFinite, abs(correctionDays) < 4 else { break }
            guessDate = guessDate.addingTimeInterval(-correctionDays * 86_400)
        }
        // Refinement should stay on or after the requested anchor.
        if guessDate < anchorDate.addingTimeInterval(-60) {
            distance += 360
            guessDate = anchorDate.addingTimeInterval((distance / meanMotionDegreesPerDay) * 86_400)
            for _ in 0 ..< 12 {
                let position = try advancedBodyPosition(body: body, at: guessDate)
                var error = (position.longitude - targetLongitude).truncatingRemainder(dividingBy: 360)
                if error > 180 { error -= 360 }
                if error < -180 { error += 360 }
                if abs(error) < 0.000_000_1 { break }
                guard abs(position.speedDegreesPerDay) > 1e-9 else { break }
                let correctionDays = error / position.speedDegreesPerDay
                guard correctionDays.isFinite, abs(correctionDays) < 4 else { break }
                guessDate = guessDate.addingTimeInterval(-correctionDays * 86_400)
            }
        }
        return guessDate
    }
}

private func advancedNormalize(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value >= 0 ? value : value + 360
}
