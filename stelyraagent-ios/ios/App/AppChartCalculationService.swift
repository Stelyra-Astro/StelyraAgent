import AstroCore
import Foundation

struct AppChartCalculationRequest {
    let subjectProfile: UserProfile
    let ownerProfile: UserProfile
    let synastryPartnerProfile: UserProfile?
    let presets: [ChartKind: CalculationPreset]
    let now: Date
    let currentSkyTargetDate: Date
    let transitTargetDate: Date
    let secondaryTargetDate: Date
    let solarReturnYear: Int
    let currentSkyUsesLiveDefault: Bool
    let transitUsesLiveDefault: Bool
    let secondaryUsesLiveDefault: Bool
    let currentSkyLocationOverride: ChartLocationSelection?
    let transitLocationOverride: ChartLocationSelection?
    let solarReturnLocationOverride: ChartLocationSelection?
    let chartsUseOwner: Bool

    func preset(for chart: ChartKind) -> CalculationPreset {
        presets[chart] ?? .modern
    }
}

struct AppChartCalculationResult {
    let now: Date
    let subjectProfile: UserProfile
    let skyLocation: ChartLocationSelection
    let transitLocation: ChartLocationSelection
    let skyDate: Date
    let transitDate: Date
    let secondaryDate: Date
    let natal: ChartSnapshot
    let transitReference: ChartSnapshot
    let progressedReference: ChartSnapshot
    let currentSky: ChartSnapshot
    let transit: ChartSnapshot
    let progressed: ChartSnapshot
    let solarReturn: ChartSnapshot
    let solarReturnReference: ChartSnapshot
    let solarReturnAspects: [ChartAspect]
    let synastry: SynastryComparison?
    let transitAspects: [ChartAspect]
    let progressedAspects: [ChartAspect]
    let todayNatal: ChartSnapshot
    let todayTransitReference: ChartSnapshot
    let todayProgressedReference: ChartSnapshot
    let todaySky: ChartSnapshot
    let todayTransit: ChartSnapshot
    let todayProgressed: ChartSnapshot
    let todayTransitAspects: [ChartAspect]
    let todayProgressedAspects: [ChartAspect]
}

@MainActor
final class AppChartCalculationService {
    func calculate(
        request: AppChartCalculationRequest,
        calculator: SwissEphemerisCalculator
    ) async throws -> AppChartCalculationResult {
        let natalInput = NatalInput(
            utcDate: request.subjectProfile.birthDateUTC,
            location: request.subjectProfile.location
        )
        let defaultLocation = ChartLocationSelection(
            placeName: request.subjectProfile.placeName,
            timezoneID: request.subjectProfile.timezoneID,
            latitude: request.subjectProfile.latitude,
            longitude: request.subjectProfile.longitude
        )
        let skyLocation = request.currentSkyLocationOverride ?? defaultLocation
        let transitLocation = request.transitLocationOverride ?? defaultLocation
        let returnLocation = request.solarReturnLocationOverride ?? defaultLocation
        let skyDate = request.currentSkyUsesLiveDefault ? request.now : request.currentSkyTargetDate
        let transitDate = request.transitUsesLiveDefault ? request.now : request.transitTargetDate
        let secondaryDate = request.secondaryUsesLiveDefault ? request.now : request.secondaryTargetDate
        let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: request.subjectProfile.birthDateUTC,
            targetDate: secondaryDate
        )

        let natal = try await calculator.calculateSnapshot(
            natalInput,
            preset: request.preset(for: .natal)
        )
        let transitReference = request.preset(for: .transit) == request.preset(for: .natal)
            ? natal
            : try await calculator.calculateSnapshot(natalInput, preset: request.preset(for: .transit))
        let progressedReference = request.preset(for: .secondary) == request.preset(for: .natal)
            ? natal
            : try await calculator.calculateSnapshot(natalInput, preset: request.preset(for: .secondary))
        let solarReturnReference = request.preset(for: .solarReturn) == request.preset(for: .natal)
            ? natal
            : try await calculator.calculateSnapshot(natalInput, preset: request.preset(for: .solarReturn))
        let currentSky = try await calculator.calculateSnapshot(
            NatalInput(utcDate: skyDate, location: skyLocation.geographicLocation),
            preset: request.preset(for: .currentSky)
        )
        let transit = try await calculator.calculateSnapshot(
            NatalInput(utcDate: transitDate, location: transitLocation.geographicLocation),
            preset: request.preset(for: .transit)
        )
        let progressed = try await calculator.calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: request.subjectProfile.location),
            preset: request.preset(for: .secondary),
            aspectOrbDegrees: 3
        )

        var returnCalendar = Calendar(identifier: .gregorian)
        returnCalendar.timeZone = TimeZone(identifier: returnLocation.timezoneID) ?? .current
        let returnYearAnchor = returnCalendar.date(
            from: DateComponents(year: request.solarReturnYear, month: 1, day: 1)
        ) ?? request.now
        let solarReturn = try await calculator.calculateSolarReturn(
            birthDate: request.subjectProfile.birthDateUTC,
            after: returnYearAnchor.addingTimeInterval(-1),
            location: returnLocation.geographicLocation,
            preset: request.preset(for: .solarReturn)
        )
        let solarReturnAspects = SwissEphemerisCalculator.solarReturnNatalAspects(
            solarReturn: solarReturn,
            natal: solarReturnReference
        )
        let synastry: SynastryComparison?
        if let partner = request.synastryPartnerProfile {
            synastry = try await calculator.calculateSynastry(
                first: NatalInput(
                    utcDate: request.ownerProfile.birthDateUTC,
                    location: request.ownerProfile.location
                ),
                second: NatalInput(utcDate: partner.birthDateUTC, location: partner.location),
                preset: request.preset(for: .synastry)
            )
        } else {
            synastry = nil
        }
        let transitAspects = SwissEphemerisCalculator.compare(
            moving: transit,
            reference: transitReference,
            orbDegrees: ChartEventBuilder.transitAspectOrbDegrees
        )
        let progressedAspects = SwissEphemerisCalculator.compare(
            moving: progressed,
            reference: progressedReference,
            orbDegrees: 2
        )

        // Today is deliberately calculated from the owner and actual current moment.
        let ownerInput = NatalInput(
            utcDate: request.ownerProfile.birthDateUTC,
            location: request.ownerProfile.location
        )
        let todayNatal = request.chartsUseOwner
            ? natal
            : try await calculator.calculateSnapshot(ownerInput, preset: request.preset(for: .natal))
        let todayTransitReference = request.chartsUseOwner
            ? transitReference
            : try await calculator.calculateSnapshot(ownerInput, preset: request.preset(for: .transit))
        let todayProgressedReference = request.chartsUseOwner
            ? progressedReference
            : try await calculator.calculateSnapshot(ownerInput, preset: request.preset(for: .secondary))
        let todaySky = request.chartsUseOwner
            && request.currentSkyUsesLiveDefault
            && request.currentSkyLocationOverride == nil
            ? currentSky
            : try await calculator.calculateSnapshot(
                NatalInput(utcDate: request.now, location: request.ownerProfile.location),
                preset: request.preset(for: .currentSky)
            )
        let todayTransit = request.chartsUseOwner
            && request.transitUsesLiveDefault
            && request.transitLocationOverride == nil
            ? transit
            : try await calculator.calculateSnapshot(
                NatalInput(utcDate: request.now, location: request.ownerProfile.location),
                preset: request.preset(for: .transit)
            )
        let todayProgressed: ChartSnapshot
        if request.chartsUseOwner && request.secondaryUsesLiveDefault {
            todayProgressed = progressed
        } else {
            let date = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: request.ownerProfile.birthDateUTC,
                targetDate: request.now
            )
            todayProgressed = try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: request.ownerProfile.location),
                preset: request.preset(for: .secondary),
                aspectOrbDegrees: 3
            )
        }
        let todayTransitAspects = SwissEphemerisCalculator.compare(
            moving: todayTransit,
            reference: todayTransitReference,
            orbDegrees: ChartEventBuilder.transitAspectOrbDegrees
        )
        let todayProgressedAspects = SwissEphemerisCalculator.compare(
            moving: todayProgressed,
            reference: todayProgressedReference,
            orbDegrees: 2
        )

        return AppChartCalculationResult(
            now: request.now,
            subjectProfile: request.subjectProfile,
            skyLocation: skyLocation,
            transitLocation: transitLocation,
            skyDate: skyDate,
            transitDate: transitDate,
            secondaryDate: secondaryDate,
            natal: natal,
            transitReference: transitReference,
            progressedReference: progressedReference,
            currentSky: currentSky,
            transit: transit,
            progressed: progressed,
            solarReturn: solarReturn,
            solarReturnReference: solarReturnReference,
            solarReturnAspects: solarReturnAspects,
            synastry: synastry,
            transitAspects: transitAspects,
            progressedAspects: progressedAspects,
            todayNatal: todayNatal,
            todayTransitReference: todayTransitReference,
            todayProgressedReference: todayProgressedReference,
            todaySky: todaySky,
            todayTransit: todayTransit,
            todayProgressed: todayProgressed,
            todayTransitAspects: todayTransitAspects,
            todayProgressedAspects: todayProgressedAspects
        )
    }
}
