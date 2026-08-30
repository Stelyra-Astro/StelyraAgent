import AstroCore
import Foundation
import Testing

@Suite("Advanced chart techniques")
struct AdvancedChartTests {
    @Test("Tertiary I maps one sidereal month to one ephemeris day")
    func tertiaryProgressionKey() {
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let target = birth.addingTimeInterval(SwissEphemerisCalculator.tertiaryMonthDays * 86_400)
        let progressed = SwissEphemerisCalculator.tertiaryProgressedDate(
            birthDate: birth,
            targetDate: target
        )
        #expect(abs(progressed.timeIntervalSince(birth) - 86_400) < 0.001)
        let roundTrip = SwissEphemerisCalculator.tertiaryTargetDate(
            birthDate: birth,
            progressedDate: progressed
        )
        #expect(abs(roundTrip.timeIntervalSince(target)) < 0.001)
    }

    @Test("Relocation preserves planetary longitudes and changes local angles")
    func relocationChart() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let birthLocation = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let relocatedLocation = GeographicLocation(latitudeDegrees: 48.8566, longitudeDegrees: 2.3522)
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: birth, location: birthLocation),
            preset: .modern
        )
        let relocated = try await calculator.calculateRelocation(
            birthDate: birth,
            location: relocatedLocation,
            preset: .modern
        )

        #expect(relocated.points.map(\.body) == natal.points.map(\.body))
        for body in natal.points.map(\.body) {
            let natalLongitude = try #require(natal.point(body)?.longitudeDegrees)
            let relocatedLongitude = try #require(relocated.point(body)?.longitudeDegrees)
            #expect(absAngularDifference(natalLongitude, relocatedLongitude) < 1e-8)
        }
        #expect(absAngularDifference(relocated.angles.ascendantDegrees, natal.angles.ascendantDegrees) > 0.1)
        #expect(absAngularDifference(relocated.angles.midheavenDegrees, natal.angles.midheavenDegrees) > 0.1)
    }

    @Test("12th and 13th harmonic multiply natal longitudes")
    func harmonicCharts() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )
        let natal = try await calculator.calculateSnapshot(input, preset: .modern)
        let harmonic12 = SwissEphemerisCalculator.harmonicSnapshot(from: natal, harmonic: 12, preset: .modern)
        let harmonic13 = SwissEphemerisCalculator.harmonicSnapshot(from: natal, harmonic: 13, preset: .modern)

        for body in natal.points.map(\.body) {
            let source = try #require(natal.point(body))
            let derived12 = try #require(harmonic12.point(body))
            let derived13 = try #require(harmonic13.point(body))
            #expect(absAngularDifference(derived12.longitudeDegrees, normalize(source.longitudeDegrees * 12)) < 1e-8)
            #expect(absAngularDifference(derived13.longitudeDegrees, normalize(source.longitudeDegrees * 13)) < 1e-8)
        }
        #expect(harmonic12.points.count == 11)
        #expect(harmonic13.points.count == 11)
    }

    @Test("Classical harmonic keeps the documented classical point set")
    func classicalHarmonicPointSet() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )
        let natal = try await calculator.calculateSnapshot(input, preset: .classical)
        let harmonic = SwissEphemerisCalculator.harmonicSnapshot(from: natal, harmonic: 12, preset: .classical)
        #expect(harmonic.points.map(\.body) == CalculationPreset.classical.pointIDs)
        #expect(harmonic.point(.uranus) == nil)
        #expect(harmonic.point(.trueNode) != nil)
    }

    @Test("Solar arc directs every point by the same secondary-Sun arc")
    func solarArcUniformDirection() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let target = birth.addingTimeInterval(30 * 365.2425 * 86_400)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let calculation = try await calculator.calculateSolarArc(
            birthDate: birth,
            targetDate: target,
            location: location,
            preset: .modern
        )
        let natal = calculation.natal
        let directed = calculation.snapshot
        #expect(calculation.arcDegrees > 20 && calculation.arcDegrees < 40)
        for body in natal.points.map(\.body) {
            let source = try #require(natal.point(body)).longitudeDegrees
            let result = try #require(directed.point(body)).longitudeDegrees
            #expect(absAngularDifference(result, normalize(source + calculation.arcDegrees)) < 1e-8)
        }
        #expect(absAngularDifference(
            directed.angles.ascendantDegrees,
            normalize(natal.angles.ascendantDegrees + calculation.arcDegrees)
        ) < 1e-8)
        #expect(absAngularDifference(
            directed.angles.midheavenDegrees,
            normalize(natal.angles.midheavenDegrees + calculation.arcDegrees)
        ) < 1e-8)
    }

    @Test("Lunar return on-or-before target exactly returns to natal Moon longitude")
    func lunarReturnExactness() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let target = birth.addingTimeInterval(30 * 365.2425 * 86_400)
        let location = GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: birth, location: location),
            preset: .modern
        )
        let natalMoon = try #require(natal.point(.moon)).longitudeDegrees
        let result = try await calculator.calculateLunarReturn(
            birthDate: birth,
            onOrBefore: target,
            location: location,
            preset: .modern
        )
        let returnMoon = try #require(result.snapshot.point(.moon)).longitudeDegrees

        #expect(result.returnMoment <= target)
        #expect(target.timeIntervalSince(result.returnMoment) < 28 * 86_400)
        #expect(absAngularDifference(returnMoon, natalMoon) < 0.00001)
    }

    @Test("Advanced chart orb profiles match documented A and B families")
    func advancedOrbProfiles() {
        #expect(ChartOrbProfile.singleA[.conjunction] == 7)
        #expect(ChartOrbProfile.singleA[.opposition] == 6)
        #expect(ChartOrbProfile.singleA[.trine] == 6)
        #expect(ChartOrbProfile.singleA[.square] == 6)
        #expect(ChartOrbProfile.singleA[.sextile] == 6)
        #expect(ChartOrbProfile.comparisonB[.conjunction] == 2)
        #expect(ChartOrbProfile.comparisonB[.opposition] == 1)
        #expect(ChartOrbProfile.comparisonB[.trine] == 1)
        #expect(ChartOrbProfile.comparisonB[.square] == 1)
        #expect(ChartOrbProfile.comparisonB[.sextile] == 1)
    }

    private func absAngularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        let raw = abs(normalize(lhs) - normalize(rhs))
        return min(raw, 360 - raw)
    }

    private func normalize(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }

    private var ephemerisDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }
}
