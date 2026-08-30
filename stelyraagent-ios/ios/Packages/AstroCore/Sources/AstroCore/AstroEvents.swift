import CSwissEphemeris
import Foundation

/// Event search over the ephemeris: sign ingresses, exact aspects, and
/// progression windows. All results are derived deterministically from the
/// bundled Swiss Ephemeris data — nothing is invented.
public struct AstroEvent: Sendable, Equatable {
    public let body: CelestialBody
    public let date: Date
    public let kind: Kind

    public enum Kind: String, Sendable, Equatable {
        case signIngress
        case exactAspect
    }
}

public struct AstroStation: Sendable, Equatable {
    public let body: CelestialBody
    public let date: Date
    public let retrogradeAfter: Bool

    public init(body: CelestialBody, date: Date, retrogradeAfter: Bool) {
        self.body = body
        self.date = date
        self.retrogradeAfter = retrogradeAfter
    }
}

extension SwissEphemerisCalculator {

    // MARK: - Stations

    /// Finds the next true longitude-speed zero crossing. This is used for
    /// retrograde/direct deadlines; callers must not estimate a station from a
    /// fixed average speed.
    public func nextStation(for body: CelestialBody, after date: Date) throws -> AstroStation {
        let start = julianDay(for: date)
        var lower = start
        var lowerSpeed = try bodyPosition(body, julianDayUT: lower).speed
        let step = 1.0
        var upper = lower + step
        let searchEnd = start + 365.25 * 2

        while upper <= searchEnd {
            let upperSpeed = try bodyPosition(body, julianDayUT: upper).speed
            if lowerSpeed == 0 || upperSpeed == 0 || (lowerSpeed < 0) != (upperSpeed < 0) {
                var lo = lower
                var hi = upper
                var loSpeed = lowerSpeed
                for _ in 0 ..< 30 {
                    let mid = (lo + hi) / 2
                    let midSpeed = try bodyPosition(body, julianDayUT: mid).speed
                    if midSpeed == 0 {
                        lo = mid
                        hi = mid
                        break
                    }
                    if (loSpeed < 0) == (midSpeed < 0) {
                        lo = mid
                        loSpeed = midSpeed
                    } else {
                        hi = mid
                    }
                }
                let stationJD = (lo + hi) / 2
                let afterSpeed = try bodyPosition(body, julianDayUT: stationJD + 0.01).speed
                return AstroStation(
                    body: body,
                    date: dateFromJulianDay(stationJD),
                    retrogradeAfter: afterSpeed < 0
                )
            }
            lower = upper
            lowerSpeed = upperSpeed
            upper += step
        }
        throw AstroCoreError.eventNotFound("No station for \(body.displayName) within two years.")
    }

    /// Returns a station only when it occurs inside the supplied Horary event window.
    public func nextStation(
        for body: CelestialBody,
        after date: Date,
        before deadline: Date
    ) throws -> AstroStation? {
        guard deadline > date else { return nil }
        let start = julianDay(for: date)
        let end = julianDay(for: deadline)
        var lower = start
        var lowerSpeed = try bodyPosition(body, julianDayUT: lower).speed
        var upper = min(end, lower + 1)
        while upper <= end, upper > lower {
            let upperSpeed = try bodyPosition(body, julianDayUT: upper).speed
            if lowerSpeed == 0 || upperSpeed == 0 || (lowerSpeed < 0) != (upperSpeed < 0) {
                var lo = lower
                var hi = upper
                var loSpeed = lowerSpeed
                for _ in 0 ..< 30 {
                    let mid = (lo + hi) / 2
                    let midSpeed = try bodyPosition(body, julianDayUT: mid).speed
                    if (loSpeed < 0) == (midSpeed < 0) {
                        lo = mid
                        loSpeed = midSpeed
                    } else {
                        hi = mid
                    }
                }
                let stationJD = (lo + hi) / 2
                return AstroStation(
                    body: body,
                    date: dateFromJulianDay(stationJD),
                    retrogradeAfter: try bodyPosition(body, julianDayUT: stationJD + 0.01).speed < 0
                )
            }
            lower = upper
            lowerSpeed = upperSpeed
            upper = min(end, upper + 1)
        }
        return nil
    }

    // MARK: - Sign ingress

    /// The next moment at or after `after` when `body` crosses a sign boundary
    /// (longitude a multiple of 30°).
    public func nextSignIngress(
        for body: CelestialBody,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let position = try bodyPosition(body, julianDayUT: start)
        let startSign = Int(position.longitude / 30)
        // Keep each sample below roughly five degrees so a fast Moon and a
        // retrograde re-entry cannot jump across an entire sign unnoticed.
        let step = min(5.0, max(0.02, 5.0 / max(abs(position.speed), 0.05)))
        var lower = start
        var upper = start + step
        let searchEnd = start + 365.25 * 12
        while upper <= searchEnd {
            let upperSign = Int(try bodyPosition(body, julianDayUT: upper).longitude / 30)
            if upperSign != startSign {
                for _ in 0 ..< 28 {
                    let mid = (lower + upper) / 2
                    let midSign = Int(try bodyPosition(body, julianDayUT: mid).longitude / 30)
                    if midSign == startSign {
                        lower = mid
                    } else {
                        upper = mid
                    }
                }
                return dateFromJulianDay(upper)
            }
            lower = upper
            upper += step
        }
        throw AstroCoreError.eventNotFound("No sign ingress for \(body.displayName) within twelve years.")
    }

    /// Returns a sign change only when it occurs before the supplied Horary deadline.
    public func nextSignIngress(
        for body: CelestialBody,
        after date: Date,
        before deadline: Date
    ) throws -> Date? {
        guard deadline > date else { return nil }
        let start = julianDay(for: date)
        let end = julianDay(for: deadline)
        let position = try bodyPosition(body, julianDayUT: start)
        let startSign = Int(position.longitude / 30)
        let step = min(5.0, max(0.02, 5.0 / max(abs(position.speed), 0.05)))
        var lower = start
        var upper = min(end, start + step)
        while upper <= end, upper > lower {
            let upperSign = Int(try bodyPosition(body, julianDayUT: upper).longitude / 30)
            if upperSign != startSign {
                for _ in 0 ..< 28 {
                    let mid = (lower + upper) / 2
                    let midSign = Int(try bodyPosition(body, julianDayUT: mid).longitude / 30)
                    if midSign == startSign { lower = mid } else { upper = mid }
                }
                return dateFromJulianDay(upper)
            }
            lower = upper
            upper = min(end, upper + step)
        }
        return nil
    }

    // MARK: - Exact aspect

    /// The next moment at or after `after` when the separation between the two
    /// bodies equals the exact aspect angle.
    public func nextExactAspectDate(
        moving: CelestialBody,
        reference: CelestialBody,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let targets = exactAspectTargets(kind)
        let step = 0.25
        let maxDays = 365.25 * 3

        func relativeAngle(at jd: Double) throws -> Double {
            let m = try bodyPosition(moving, julianDayUT: jd).longitude
            let r = try bodyPosition(reference, julianDayUT: jd).longitude
            return norm360(m - r)
        }

        var lower = start
        var lowerAngle = try relativeAngle(at: lower)
        var upper = lower + step
        while upper < start + maxDays {
            let upperAngle = try relativeAngle(at: upper)
            for target in targets where crossesTarget(lowerAngle, upperAngle, target) {
                var lo = lower
                var hi = upper
                var loAngle = lowerAngle
                for _ in 0 ..< 24 {
                    let mid = (lo + hi) / 2
                    let midAngle = try relativeAngle(at: mid)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                return Date(timeIntervalSince1970: ((lo + hi) / 2 - 2_440_587.5) * 86_400)
            }
            lower = upper
            lowerAngle = upperAngle
            upper += step
        }
        throw AstroCoreError.eventNotFound(
            "No exact \(kind.rawValue) between \(moving.displayName) and \(reference.displayName) within the search window."
        )
    }

    // MARK: - Progression windows

    /// The current sign of a progressed point and the window until its next
    /// sign change, in days.
    public func progressionWindow(
        moving body: CelestialBody,
        at progressedDate: Date,
        signLabel: String
    ) throws -> (ingressDate: Date, daysInSign: Double) {
        let ingress = try nextSignIngress(for: body, after: progressedDate)
        // Days since the body entered the current sign.
        let previousIngress = try nextSignIngressBackward(for: body, before: progressedDate)
        let daysIn = progressedDate.timeIntervalSince(previousIngress) / 86_400
        return (ingress, daysIn)
    }

    // MARK: - Internal helpers

    private func bodyPosition(
        _ body: CelestialBody,
        julianDayUT: Double
    ) throws -> (longitude: Double, speed: Double) {
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
                    julianDayUT,
                    swissID,
                    Self.swissFlags,
                    valuesBuffer.baseAddress,
                    errorBufferPointer.baseAddress
                )
            }
        }
        guard returnedFlags >= 0 else {
            throw AstroCoreError.calculationFailed(body: body.displayName, message: String(decoding: errorBuffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self))
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: body.displayName, flags: returnedFlags)
        }
        return (norm360(values[0]), values[3])
    }

    private func nextSignIngressBackward(
        for body: CelestialBody,
        before date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let position = try bodyPosition(body, julianDayUT: start)
        let currentSign = Int(position.longitude / 30)
        let step = min(5.0, max(0.02, 5.0 / max(abs(position.speed), 0.05)))
        var upper = start
        var lower = start - step
        let searchEnd = start - 365.25 * 12
        while lower >= searchEnd {
            let lowerSign = Int(try bodyPosition(body, julianDayUT: lower).longitude / 30)
            if lowerSign != currentSign {
                for _ in 0 ..< 28 {
                    let mid = (lower + upper) / 2
                    let midSign = Int(try bodyPosition(body, julianDayUT: mid).longitude / 30)
                    if midSign == currentSign {
                        upper = mid
                    } else {
                        lower = mid
                    }
                }
                return dateFromJulianDay(upper)
            }
            upper = lower
            lower -= step
        }
        throw AstroCoreError.eventNotFound("No previous sign ingress for \(body.displayName) within twelve years.")
    }

    private func signedDelta(_ target: Double, _ value: Double) -> Double {
        var d = (value - target).truncatingRemainder(dividingBy: 360)
        if d > 180 { d -= 360 }
        if d < -180 { d += 360 }
        return d
    }

    /// The target relative angles (in degrees) for an aspect kind. Conjunctions
    /// and oppositions have a single target; the other aspects occur at both the
    /// forward and the complementary angle.
    private func exactAspectTargets(_ kind: AspectKind) -> [Double] {
        let target = kind.angleDegrees
        return target == 180 ? [180] : [target, 360 - target]
    }

    /// True when the circular relative angle crosses `target` between `from` and
    /// `to` (valid while the swept arc is smaller than 180°).
    private func crossesTarget(_ from: Double, _ to: Double, _ target: Double) -> Bool {
        let sweep = signedDelta(from, to)
        guard sweep != 0 else { return false }
        let toTarget = signedDelta(from, target)
        return toTarget != 0
            && (toTarget > 0) == (sweep > 0)
            && abs(toTarget) <= abs(sweep)
    }

    private func shortestSeparation(_ first: Double, _ second: Double) -> Double {
        let s = abs(norm360(first) - norm360(second))
        return min(s, 360 - s)
    }

    private func julianDay(for date: Date) -> Double {
        date.timeIntervalSince1970 / 86_400 + 2_440_587.5
    }

    private func dateFromJulianDay(_ value: Double) -> Date {
        Date(timeIntervalSince1970: (value - 2_440_587.5) * 86_400)
    }

    private func norm360(_ degrees: Double) -> Double {
        let v = degrees.truncatingRemainder(dividingBy: 360)
        return v >= 0 ? v : v + 360
    }
}

extension SwissEphemerisCalculator {
    /// Next exact aspect in the sky between two ephemeris bodies.
    public func nextSkyExactDate(
        moving: CelestialBody,
        reference: CelestialBody,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        try nextExactAspectDate(moving: moving, reference: reference, kind: kind, after: date)
    }

    /// Next exact aspect between a transit body (moving at the searched date)
    /// and a fixed natal longitude.
    public func nextTransitNatalExactDate(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        after date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let targets = exactAspectTargets(kind)

        func relativeAngle(at jd: Double) throws -> Double {
            let m = try bodyPosition(moving, julianDayUT: jd).longitude
            return norm360(m - natalReferenceLongitude)
        }

        // The step adapts to the transit body's current motion so the whole
        // circle is swept with a bounded number of samples (about 1 degree of
        // motion per sample; the Moon needs a fraction of a day, Saturn months).
        let position = try bodyPosition(moving, julianDayUT: start)
        let speed = max(abs(position.speed), 0.01)
        let step = max(0.05, 1.0 / speed)
        let maxDays = 365.25 * 8

        var lower = start
        var lowerAngle = try relativeAngle(at: lower)
        var upper = lower + step
        while upper < start + maxDays {
            let upperAngle = try relativeAngle(at: upper)
            for target in targets where crossesTarget(lowerAngle, upperAngle, target) {
                var lo = lower
                var hi = upper
                var loAngle = lowerAngle
                for _ in 0 ..< 24 {
                    let mid = (lo + hi) / 2
                    let midAngle = try relativeAngle(at: mid)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                return Date(timeIntervalSince1970: ((lo + hi) / 2 - 2_440_587.5) * 86_400)
            }
            lower = upper
            lowerAngle = upperAngle
            upper += step
        }
        throw AstroCoreError.eventNotFound(
            "No exact \(kind.rawValue) from transiting \(moving.displayName) to the natal longitude within the search window."
        )
    }

    /// Previous exact contact for an already-separating transit. This mirrors
    /// the forward search but walks backward through real ephemeris positions;
    /// it never infers a date from the current speed.
    public func previousTransitNatalExactDate(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        before date: Date
    ) throws -> Date {
        let start = julianDay(for: date)
        let targets = exactAspectTargets(kind)

        func relativeAngle(at jd: Double) throws -> Double {
            let longitude = try bodyPosition(moving, julianDayUT: jd).longitude
            return norm360(longitude - natalReferenceLongitude)
        }

        let position = try bodyPosition(moving, julianDayUT: start)
        let speed = max(abs(position.speed), 0.01)
        let step = max(0.05, 1.0 / speed)
        let searchEnd = start - 365.25 * 8
        var upper = start
        var upperAngle = try relativeAngle(at: upper)
        var lower = upper - step
        while lower > searchEnd {
            let lowerAngle = try relativeAngle(at: lower)
            for target in targets where crossesTarget(lowerAngle, upperAngle, target) {
                var lo = lower
                var hi = upper
                var loAngle = lowerAngle
                for _ in 0 ..< 28 {
                    let mid = (lo + hi) / 2
                    let midAngle = try relativeAngle(at: mid)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                return dateFromJulianDay((lo + hi) / 2)
            }
            upper = lower
            upperAngle = lowerAngle
            lower -= step
        }
        throw AstroCoreError.eventNotFound(
            "No previous exact \(kind.rawValue) from transiting \(moving.displayName) within the search window."
        )
    }

    /// Exact in-orb boundaries around a known transit hit. Boundaries are
    /// searched from ephemeris positions, not estimated from mean speed.
    public func transitNatalAspectWindow(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        exactDate: Date,
        orbDegrees: Double
    ) throws -> (start: Date, end: Date) {
        let exactJD = julianDay(for: exactDate)
        let targets = exactAspectTargets(kind)
        let orb = max(0.05, orbDegrees)

        func error(at jd: Double) throws -> Double {
            let longitude = try bodyPosition(moving, julianDayUT: jd).longitude
            let relative = norm360(longitude - natalReferenceLongitude)
            return targets.map { abs(signedDelta($0, relative)) }.min() ?? 180
        }

        func boundary(direction: Double) throws -> Double {
            var inside = exactJD
            var outside = exactJD + direction * 0.25
            let limit = exactJD + direction * 365.25 * 3
            while (direction > 0 ? outside <= limit : outside >= limit), try error(at: outside) < orb {
                inside = outside
                outside += direction * 0.25
            }
            guard try error(at: outside) >= orb else {
                throw AstroCoreError.eventNotFound("Transit orb boundary was not found.")
            }
            var lower = min(inside, outside)
            var upper = max(inside, outside)
            for _ in 0 ..< 28 {
                let mid = (lower + upper) / 2
                let midInside = try error(at: mid) < orb
                if direction > 0 {
                    if midInside { lower = mid } else { upper = mid }
                } else {
                    if midInside { upper = mid } else { lower = mid }
                }
            }
            return (lower + upper) / 2
        }

        let start = try boundary(direction: -1)
        let end = try boundary(direction: 1)
        return (dateFromJulianDay(start), dateFromJulianDay(end))
    }

    /// Next exact aspect between a progressed body (birth date + N days) and a
    /// fixed natal longitude, searching up to `maxYears` real years ahead.
    /// The returned date is a real calendar date.
    public func nextProgressedNatalExactDate(
        moving: CelestialBody,
        natalReferenceLongitude: Double,
        kind: AspectKind,
        birthDate: Date,
        after targetDate: Date,
        maxYears: Int = 10
    ) throws -> Date? {
        let targets = exactAspectTargets(kind)
        let startYear = max(0, Int(targetDate.timeIntervalSince(birthDate) / (365.2425 * 86_400)))
        for year in startYear ..< (startYear + maxYears) {
            let progressedDate = birthDate.addingTimeInterval(Double(year) * 86_400)
            let nextProgressed = birthDate.addingTimeInterval(Double(year + 1) * 86_400)
            let p1 = try bodyPosition(moving, julianDayUT: julianDay(for: progressedDate)).longitude
            let p2 = try bodyPosition(moving, julianDayUT: julianDay(for: nextProgressed)).longitude
            let r1 = norm360(p1 - natalReferenceLongitude)
            let r2 = norm360(p2 - natalReferenceLongitude)
            for target in targets where crossesTarget(r1, r2, target) {
                var lo = Double(year)
                var hi = Double(year + 1)
                var loAngle = r1
                for _ in 0 ..< 28 {
                    let mid = (lo + hi) / 2
                    let midProgressed = birthDate.addingTimeInterval(mid * 86_400)
                    let midLon = try bodyPosition(moving, julianDayUT: julianDay(for: midProgressed)).longitude
                    let midAngle = norm360(midLon - natalReferenceLongitude)
                    if crossesTarget(loAngle, midAngle, target) {
                        hi = mid
                    } else {
                        lo = mid
                        loAngle = midAngle
                    }
                }
                let exactRealDate = birthDate.addingTimeInterval(((lo + hi) / 2) * 365.2425 * 86_400)
                if exactRealDate >= targetDate {
                    return exactRealDate
                }
            }
        }
        return nil
    }
}
