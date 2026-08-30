import CSwissEphemeris
import Foundation

public struct GeographicLocation: Sendable, Equatable, Codable {
    public let latitudeDegrees: Double
    public let longitudeDegrees: Double

    public init(latitudeDegrees: Double, longitudeDegrees: Double) {
        self.latitudeDegrees = latitudeDegrees
        self.longitudeDegrees = longitudeDegrees
    }
}

public struct NatalInput: Sendable, Equatable {
    public let utcDate: Date
    public let location: GeographicLocation

    public init(utcDate: Date, location: GeographicLocation) {
        self.utcDate = utcDate
        self.location = location
    }
}

public enum LocalCalendarDay {
    public static func interval(containing date: Date, timeZone: TimeZone) -> DateInterval {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let start = calendar.startOfDay(for: date)
        let end = calendar.date(byAdding: .day, value: 1, to: start)
            ?? start.addingTimeInterval(86_400)
        return DateInterval(start: start, end: end)
    }
}

public enum CalculationPreset: String, CaseIterable, Sendable, Codable, Identifiable {
    case modern
    case classical
    case special

    public var id: String { rawValue }

    public var houseSystemCode: Character {
        switch self {
        case .modern: "P"
        case .classical: "B"
        case .special: "W"
        }
    }

    public var pointIDs: [CelestialBody] {
        switch self {
        case .modern:
            [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto, .trueNode]
        case .classical, .special:
            [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .trueNode]
        }
    }

    public var defaultOrbDegrees: Double {
        switch self {
        case .modern: 6
        case .classical: 7
        case .special: 5
        }
    }
}

public struct ChartCalculationConfiguration: Sendable, Equatable {
    public let pointIDs: [CelestialBody]
    public let houseSystemCode: Character
    public let aspectOrbDegrees: Double
    /// Optional per-aspect-kind orb profile (e.g. solar-return A/B families).
    public let orbsByKind: [AspectKind: Double]?
    /// Optional per-body starlight orbs (classical technique); the smaller of
    /// the two bodies' orbs becomes the effective orb.
    public let orbsByBody: [CelestialBody: Double]?

    public init(
        pointIDs: [CelestialBody],
        houseSystemCode: Character,
        aspectOrbDegrees: Double,
        orbsByKind: [AspectKind: Double]? = nil,
        orbsByBody: [CelestialBody: Double]? = nil
    ) {
        self.pointIDs = pointIDs
        self.houseSystemCode = houseSystemCode
        self.aspectOrbDegrees = aspectOrbDegrees
        self.orbsByKind = orbsByKind
        self.orbsByBody = orbsByBody
    }

    public static let horary = ChartCalculationConfiguration(
        pointIDs: [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn],
        houseSystemCode: "R",
        aspectOrbDegrees: 13.5
    )
}

public enum CelestialBody: String, CaseIterable, Sendable, Codable, Identifiable {
    case sun
    case moon
    case mercury
    case venus
    case mars
    case jupiter
    case saturn
    case uranus
    case neptune
    case pluto
    case trueNode
    case lilith
    case partOfFortune
    case juno

    public var id: String { rawValue }

    public var swissID: Int32? {
        switch self {
        case .sun: Int32(SE_SUN)
        case .moon: Int32(SE_MOON)
        case .mercury: Int32(SE_MERCURY)
        case .venus: Int32(SE_VENUS)
        case .mars: Int32(SE_MARS)
        case .jupiter: Int32(SE_JUPITER)
        case .saturn: Int32(SE_SATURN)
        case .uranus: Int32(SE_URANUS)
        case .neptune: Int32(SE_NEPTUNE)
        case .pluto: Int32(SE_PLUTO)
        case .trueNode: Int32(SE_TRUE_NODE)
        case .lilith: Int32(SE_MEAN_APOG)
        case .partOfFortune: nil
        case .juno: Int32(SE_JUNO)
        }
    }

    public var symbol: String {
        switch self {
        case .sun: "☉"
        case .moon: "☽"
        case .mercury: "☿"
        case .venus: "♀"
        case .mars: "♂"
        case .jupiter: "♃"
        case .saturn: "♄"
        case .uranus: "♅"
        case .neptune: "♆"
        case .pluto: "♇"
        case .trueNode: "☊"
        case .lilith: "⚸"
        case .partOfFortune: "⊗"
        case .juno: "⚵"
        }
    }

    public var displayName: String {
        switch self {
        case .trueNode: "North Node"
        case .partOfFortune: "Part of Fortune"
        case .lilith: "Lilith"
        case .juno: "Juno"
        default: rawValue.prefix(1).uppercased() + rawValue.dropFirst()
        }
    }
}

public struct CelestialPosition: Sendable, Equatable, Codable {
    public let longitudeDegrees: Double
    public let latitudeDegrees: Double
    public let distanceAU: Double
    public let longitudeSpeedDegreesPerDay: Double
}

public struct ChartPoint: Sendable, Equatable, Identifiable, Codable {
    public let body: CelestialBody
    public let position: CelestialPosition

    public var id: String { body.id }
    public var longitudeDegrees: Double { position.longitudeDegrees }
    public var signIndex: Int { Int(normalize(longitudeDegrees) / 30) }
    public var degreeInSign: Double { normalize(longitudeDegrees).truncatingRemainder(dividingBy: 30) }
    public var retrograde: Bool { position.longitudeSpeedDegreesPerDay < 0 }
}

public struct NatalAngles: Sendable, Equatable, Codable {
    public let ascendantDegrees: Double
    public let midheavenDegrees: Double
}

public struct ChartHouse: Sendable, Equatable, Identifiable, Codable {
    public let number: Int
    public let cuspDegrees: Double
    public var id: Int { number }
}

public enum AspectKind: String, CaseIterable, Sendable, Codable {
    case conjunction
    case sextile
    case square
    case trine
    case opposition

    public var angleDegrees: Double {
        switch self {
        case .conjunction: 0
        case .sextile: 60
        case .square: 90
        case .trine: 120
        case .opposition: 180
        }
    }

    public var symbol: String {
        switch self {
        case .conjunction: "☌"
        case .sextile: "⚹"
        case .square: "□"
        case .trine: "△"
        case .opposition: "☍"
        }
    }

    public var supportive: Bool { self == .sextile || self == .trine }
    public var challenging: Bool { self == .square || self == .opposition }
}

public enum AspectPhase: String, Sendable, Codable {
    case applying
    case exact
    case separating
}

public enum AspectEventInterpolation {
    public static func exactCrossingFraction(
        from firstSeparation: Double,
        to rawSecondSeparation: Double,
        aspectAngleDegrees: Double
    ) -> Double? {
        var secondSeparation = rawSecondSeparation
        while secondSeparation - firstSeparation > 180 { secondSeparation -= 360 }
        while secondSeparation - firstSeparation < -180 { secondSeparation += 360 }

        let denominator = secondSeparation - firstSeparation
        guard abs(denominator) > 0.000_000_1 else { return nil }
        let targets = aspectAngleDegrees == 0
            ? [0.0]
            : [aspectAngleDegrees, -aspectAngleDegrees]
        let lower = min(firstSeparation, secondSeparation)
        let upper = max(firstSeparation, secondSeparation)
        let fractions = targets.flatMap { target in
            (-1 ... 1).compactMap { turn -> Double? in
                let unwrappedTarget = target + Double(turn) * 360
                guard unwrappedTarget >= lower, unwrappedTarget <= upper else { return nil }
                return (unwrappedTarget - firstSeparation) / denominator
            }
        }
        return fractions
            .filter { (0 ... 1).contains($0) }
            .min(by: { abs($0 - 0.5) < abs($1 - 0.5) })
    }
}

public struct ChartAspect: Sendable, Equatable, Identifiable, Codable {
    public let firstID: String
    public let secondID: String
    public let kind: AspectKind
    public let orbDegrees: Double
    public let phase: AspectPhase
    public let strength: Double
    public let firstLongitude: Double
    public let secondLongitude: Double

    public var id: String { "\(firstID)-\(kind.rawValue)-\(secondID)" }
}

public struct ChartSnapshot: Sendable, Equatable, Codable {
    public let utcDate: Date
    public let location: GeographicLocation
    public let julianDayUT: Double
    public let points: [ChartPoint]
    public let houses: [ChartHouse]
    public let angles: NatalAngles
    public let aspects: [ChartAspect]

    public func point(_ body: CelestialBody) -> ChartPoint? {
        points.first { $0.body == body }
    }

    public func house(containing longitude: Double) -> Int {
        guard houses.count == 12 else { return 0 }
        let value = normalize(longitude)
        for index in houses.indices {
            let start = normalize(houses[index].cuspDegrees)
            let end = normalize(houses[(index + 1) % houses.count].cuspDegrees)
            let span = normalize(end - start)
            let offset = normalize(value - start)
            if offset < span || abs(offset - span) < 0.000_000_1 {
                return houses[index].number
            }
        }
        return 0
    }
}

public struct NatalCalculation: Sendable, Equatable {
    public let julianDayUT: Double
    public let sun: CelestialPosition
    public let moon: CelestialPosition
    public let angles: NatalAngles
}

public enum AstroCoreError: Error, Sendable, Equatable, LocalizedError {
    case ephemerisDirectoryMissing(String)
    case invalidLatitude(Double)
    case invalidLongitude(Double)
    case calculationFailed(body: String, message: String)
    case swissEphemerisFallback(body: String, flags: Int32)
    case housesFailed
    case eventNotFound(String)

    public var errorDescription: String? {
        switch self {
        case let .ephemerisDirectoryMissing(path):
            "Swiss Ephemeris data was not found at \(path)."
        case let .invalidLatitude(value):
            "Latitude \(value) is outside -90...90."
        case let .invalidLongitude(value):
            "Longitude \(value) is outside -180...180."
        case let .calculationFailed(body, message):
            "\(body) calculation failed: \(message)"
        case let .swissEphemerisFallback(body, flags):
            "\(body) did not use the bundled Swiss ephemeris files (flags: \(flags))."
        case .housesFailed:
            "Swiss Ephemeris could not calculate the requested houses."
        case let .eventNotFound(detail):
            "No upcoming astronomical event was found: \(detail)"
        }
    }
}

/// Serializes access to Swiss Ephemeris, whose configuration is process-global.
public actor SwissEphemerisCalculator {
    static let swissFlags = Int32(SEFLG_SWIEPH | SEFLG_SPEED)
    static let processLock = NSLock()
    let ephemerisPath: String

    public init(ephemerisDirectory: URL) throws {
        let path = ephemerisDirectory.standardizedFileURL.path
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
              isDirectory.boolValue
        else {
            throw AstroCoreError.ephemerisDirectoryMissing(path)
        }
        ephemerisPath = path
    }

    public func calculateSnapshot(
        _ input: NatalInput,
        preset: CalculationPreset = .modern,
        aspectOrbDegrees: Double? = nil
    ) throws -> ChartSnapshot {
        try calculateSnapshot(
            input,
            configuration: ChartCalculationConfiguration(
                pointIDs: preset.pointIDs,
                houseSystemCode: preset.houseSystemCode,
                aspectOrbDegrees: aspectOrbDegrees ?? preset.defaultOrbDegrees
            )
        )
    }

    public func calculateSnapshot(
        _ input: NatalInput,
        configuration: ChartCalculationConfiguration
    ) throws -> ChartSnapshot {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        try validate(input.location)
        swe_set_ephe_path(ephemerisPath)
        let julianDay = input.utcDate.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let houseResult = try calculateHouses(
            julianDayUT: julianDay,
            location: input.location,
            houseSystem: configuration.houseSystemCode
        )
        let points = try configuration.pointIDs.map { body in
            let position: CelestialPosition
            if body == .partOfFortune {
                position = try calculatePartOfFortune(
                    julianDayUT: julianDay,
                    location: input.location,
                    houseSystem: configuration.houseSystemCode,
                    houseResult: houseResult
                )
            } else if let swissID = body.swissID {
                position = try calculateBody(id: swissID, name: body.displayName, julianDayUT: julianDay)
            } else {
                throw AstroCoreError.calculationFailed(
                    body: body.displayName,
                    message: "No local calculation implementation is available."
                )
            }
            return ChartPoint(body: body, position: position)
        }
        let aspects = Self.aspects(
            points.map {
                AspectPoint(
                    id: $0.id,
                    longitude: $0.longitudeDegrees,
                    speed: $0.position.longitudeSpeedDegreesPerDay,
                    body: $0.body
                )
            },
            orbDegrees: configuration.aspectOrbDegrees,
            orbsByKind: configuration.orbsByKind,
            orbsByBody: configuration.orbsByBody
        )
        return ChartSnapshot(
            utcDate: input.utcDate,
            location: input.location,
            julianDayUT: julianDay,
            points: points,
            houses: houseResult.houses,
            angles: houseResult.angles,
            aspects: aspects
        )
    }

    public func calculateNatal(
        _ input: NatalInput,
        houseSystem: Character = "P"
    ) throws -> NatalCalculation {
        Self.processLock.lock()
        defer { Self.processLock.unlock() }
        try validate(input.location)
        swe_set_ephe_path(ephemerisPath)
        let julianDay = input.utcDate.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let sun = try calculateBody(id: Int32(SE_SUN), name: "Sun", julianDayUT: julianDay)
        let moon = try calculateBody(id: Int32(SE_MOON), name: "Moon", julianDayUT: julianDay)
        let result = try calculateHouses(
            julianDayUT: julianDay,
            location: input.location,
            houseSystem: houseSystem
        )
        return NatalCalculation(julianDayUT: julianDay, sun: sun, moon: moon, angles: result.angles)
    }

    public nonisolated static func compare(
        moving: ChartSnapshot,
        reference: ChartSnapshot,
        orbDegrees: Double = 3,
        orbsByKind: [AspectKind: Double]? = nil,
        orbsByBody: [CelestialBody: Double]? = nil
    ) -> [ChartAspect] {
        var results: [ChartAspect] = []
        for movingPoint in moving.points {
            for referencePoint in reference.points {
                if let aspect = closestAspect(
                    first: AspectPoint(
                        id: movingPoint.id,
                        longitude: movingPoint.longitudeDegrees,
                        speed: movingPoint.position.longitudeSpeedDegreesPerDay,
                        body: movingPoint.body
                    ),
                    second: AspectPoint(
                        id: referencePoint.id,
                        longitude: referencePoint.longitudeDegrees,
                        speed: 0,
                        body: referencePoint.body
                    ),
                    orbDegrees: orbDegrees,
                    orbsByKind: orbsByKind,
                    orbsByBody: orbsByBody
                ) {
                    results.append(aspect)
                }
            }
        }
        return results.sorted { $0.strength > $1.strength }
    }

    public nonisolated static func secondaryProgressedDate(birthDate: Date, targetDate: Date) -> Date {
        let years = max(0, targetDate.timeIntervalSince(birthDate) / (365.2425 * 86_400))
        return birthDate.addingTimeInterval(years * 86_400)
    }

    /// Maps a date on the secondary-progression ephemeris axis back to the
    /// corresponding real-world target date (one ephemeris day per tropical
    /// year). UI and event models must use this inverse before presenting a
    /// progressed ingress date to the user.
    public nonisolated static func secondaryTargetDate(birthDate: Date, progressedDate: Date) -> Date {
        let progressedDays = max(0, progressedDate.timeIntervalSince(birthDate) / 86_400)
        return birthDate.addingTimeInterval(progressedDays * 365.2425 * 86_400)
    }

    private func validate(_ location: GeographicLocation) throws {
        guard (-90 ... 90).contains(location.latitudeDegrees) else {
            throw AstroCoreError.invalidLatitude(location.latitudeDegrees)
        }
        guard (-180 ... 180).contains(location.longitudeDegrees) else {
            throw AstroCoreError.invalidLongitude(location.longitudeDegrees)
        }
    }

    private func calculatePartOfFortune(
        julianDayUT: Double,
        location: GeographicLocation,
        houseSystem: Character,
        houseResult: (houses: [ChartHouse], angles: NatalAngles)
    ) throws -> CelestialPosition {
        let sun = try calculateBody(id: Int32(SE_SUN), name: "Sun", julianDayUT: julianDayUT)
        let moon = try calculateBody(id: Int32(SE_MOON), name: "Moon", julianDayUT: julianDayUT)
        let sunHouse = Self.houseNumber(containing: sun.longitudeDegrees, houses: houseResult.houses)
        let isDayChart = (7 ... 12).contains(sunHouse)

        func longitude(at julianDay: Double) throws -> Double {
            let localSun = try calculateBody(id: Int32(SE_SUN), name: "Sun", julianDayUT: julianDay)
            let localMoon = try calculateBody(id: Int32(SE_MOON), name: "Moon", julianDayUT: julianDay)
            let localHouses = try calculateHouses(
                julianDayUT: julianDay,
                location: location,
                houseSystem: houseSystem
            )
            let value = isDayChart
                ? localHouses.angles.ascendantDegrees + localMoon.longitudeDegrees - localSun.longitudeDegrees
                : localHouses.angles.ascendantDegrees + localSun.longitudeDegrees - localMoon.longitudeDegrees
            return normalize(value)
        }

        let center = isDayChart
            ? normalize(houseResult.angles.ascendantDegrees + moon.longitudeDegrees - sun.longitudeDegrees)
            : normalize(houseResult.angles.ascendantDegrees + sun.longitudeDegrees - moon.longitudeDegrees)
        let deltaDays = 1.0 / 1_440.0
        let before = try longitude(at: julianDayUT - deltaDays)
        let after = try longitude(at: julianDayUT + deltaDays)
        var delta = after - before
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return CelestialPosition(
            longitudeDegrees: center,
            latitudeDegrees: 0,
            distanceAU: 0,
            longitudeSpeedDegreesPerDay: delta / (2 * deltaDays)
        )
    }

    private nonisolated static func houseNumber(
        containing longitude: Double,
        houses: [ChartHouse]
    ) -> Int {
        guard houses.count == 12 else { return 0 }
        let value = normalize(longitude)
        for index in houses.indices {
            let start = normalize(houses[index].cuspDegrees)
            let end = normalize(houses[(index + 1) % houses.count].cuspDegrees)
            let span = normalize(end - start)
            let offset = normalize(value - start)
            if offset < span || abs(offset - span) < 0.000_000_1 {
                return houses[index].number
            }
        }
        return 0
    }

    private func calculateBody(id: Int32, name: String, julianDayUT: Double) throws -> CelestialPosition {
        var values = [Double](repeating: 0, count: 6)
        var errorBuffer = [CChar](repeating: 0, count: 256)
        let returnedFlags = values.withUnsafeMutableBufferPointer { valuesBuffer in
            errorBuffer.withUnsafeMutableBufferPointer { errorBufferPointer in
                swe_calc_ut(
                    julianDayUT,
                    id,
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
            throw AstroCoreError.calculationFailed(body: name, message: message)
        }
        guard returnedFlags & Int32(SEFLG_SWIEPH) != 0 else {
            throw AstroCoreError.swissEphemerisFallback(body: name, flags: returnedFlags)
        }
        return CelestialPosition(
            longitudeDegrees: normalize(values[0]),
            latitudeDegrees: values[1],
            distanceAU: values[2],
            longitudeSpeedDegreesPerDay: values[3]
        )
    }

    private func calculateHouses(
        julianDayUT: Double,
        location: GeographicLocation,
        houseSystem: Character
    ) throws -> (houses: [ChartHouse], angles: NatalAngles) {
        guard let scalar = houseSystem.asciiValue else { throw AstroCoreError.housesFailed }
        var cusps = [Double](repeating: 0, count: 13)
        var ascmc = [Double](repeating: 0, count: 10)
        let status = cusps.withUnsafeMutableBufferPointer { cuspBuffer in
            ascmc.withUnsafeMutableBufferPointer { angleBuffer in
                swe_houses_ex(
                    julianDayUT,
                    0,
                    location.latitudeDegrees,
                    location.longitudeDegrees,
                    Int32(scalar),
                    cuspBuffer.baseAddress,
                    angleBuffer.baseAddress
                )
            }
        }
        guard status == 0 else { throw AstroCoreError.housesFailed }
        return (
            (1 ... 12).map { ChartHouse(number: $0, cuspDegrees: normalize(cusps[$0])) },
            NatalAngles(
                ascendantDegrees: normalize(ascmc[0]),
                midheavenDegrees: normalize(ascmc[1])
            )
        )
    }

    private struct AspectPoint {
        let id: String
        let longitude: Double
        let speed: Double
        let body: CelestialBody?
    }

    public nonisolated static func calculateAspects(
        for points: [ChartPoint],
        orbDegrees: Double,
        orbsByKind: [AspectKind: Double]? = nil,
        orbsByBody: [CelestialBody: Double]? = nil
    ) -> [ChartAspect] {
        aspects(
            points.map {
                AspectPoint(
                    id: $0.id,
                    longitude: $0.longitudeDegrees,
                    speed: $0.position.longitudeSpeedDegreesPerDay,
                    body: $0.body
                )
            },
            orbDegrees: orbDegrees,
            orbsByKind: orbsByKind,
            orbsByBody: orbsByBody
        )
    }

    private nonisolated static func aspects(
        _ points: [AspectPoint],
        orbDegrees: Double,
        orbsByKind: [AspectKind: Double]? = nil,
        orbsByBody: [CelestialBody: Double]? = nil
    ) -> [ChartAspect] {
        var results: [ChartAspect] = []
        for firstIndex in points.indices {
            for secondIndex in points.indices where secondIndex > firstIndex {
                if let aspect = closestAspect(
                    first: points[firstIndex],
                    second: points[secondIndex],
                    orbDegrees: orbDegrees,
                    orbsByKind: orbsByKind,
                    orbsByBody: orbsByBody
                ) {
                    results.append(aspect)
                }
            }
        }
        return results.sorted { $0.strength > $1.strength }
    }

    private nonisolated static func effectiveOrb(
        kind: AspectKind,
        firstBody: CelestialBody?,
        secondBody: CelestialBody?,
        orbDegrees: Double,
        orbsByKind: [AspectKind: Double]?,
        orbsByBody: [CelestialBody: Double]?
    ) -> Double {
        if let orbsByBody {
            let firstOrb = firstBody.flatMap { orbsByBody[$0] } ?? orbDegrees
            let secondOrb = secondBody.flatMap { orbsByBody[$0] } ?? orbDegrees
            return min(firstOrb, secondOrb)
        }
        if let orbsByKind, let configured = orbsByKind[kind] {
            return configured
        }
        return orbDegrees
    }

    private nonisolated static func closestAspect(
        first: AspectPoint,
        second: AspectPoint,
        orbDegrees: Double,
        orbsByKind: [AspectKind: Double]? = nil,
        orbsByBody: [CelestialBody: Double]? = nil
    ) -> ChartAspect? {
        let separation = shortestSeparation(first.longitude, second.longitude)
        let candidates = AspectKind.allCases.map { ($0, abs(separation - $0.angleDegrees)) }
        guard let match = candidates.min(by: { $0.1 < $1.1 }) else {
            return nil
        }
        let effective = effectiveOrb(
            kind: match.0,
            firstBody: first.body,
            secondBody: second.body,
            orbDegrees: orbDegrees,
            orbsByKind: orbsByKind,
            orbsByBody: orbsByBody
        )
        guard match.1 <= effective else {
            return nil
        }
        let futureFirst = normalize(first.longitude + first.speed / 24)
        let futureSecond = normalize(second.longitude + second.speed / 24)
        let futureOrb = abs(shortestSeparation(futureFirst, futureSecond) - match.0.angleDegrees)
        let phase: AspectPhase
        if match.1 < 0.02 {
            phase = .exact
        } else {
            phase = futureOrb < match.1 ? .applying : .separating
        }
        return ChartAspect(
            firstID: first.id,
            secondID: second.id,
            kind: match.0,
            orbDegrees: match.1,
            phase: phase,
            strength: max(0, 1 - match.1 / max(effective, 0.001)),
            firstLongitude: first.longitude,
            secondLongitude: second.longitude
        )
    }
}

private func normalize(_ degrees: Double) -> Double {
    let value = degrees.truncatingRemainder(dividingBy: 360)
    return value >= 0 ? value : value + 360
}

private func shortestSeparation(_ first: Double, _ second: Double) -> Double {
    let separation = abs(normalize(first) - normalize(second))
    return min(separation, 360 - separation)
}
