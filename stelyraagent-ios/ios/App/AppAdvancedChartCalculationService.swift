import AstroCore
import Foundation

enum AppAdvancedChartCalculationError: Error, LocalizedError {
    case unsupportedChart(ChartKind)
    case invalidTarget(ChartKind)

    var errorDescription: String? {
        switch self {
        case let .unsupportedChart(chart):
            "Unsupported advanced chart: \(chart.rawValue)"
        case let .invalidTarget(chart):
            "Invalid target for advanced chart: \(chart.rawValue)"
        }
    }
}
@MainActor
final class AppAdvancedChartCalculationService {
    func calculate(
        chart: ChartKind,
        context: ChartContext,
        profile: UserProfile,
        calculator: SwissEphemerisCalculator
    ) async throws -> ChartDisplayResult {
        guard chart.isAdvancedChart else {
            throw AppAdvancedChartCalculationError.unsupportedChart(chart)
        }

        let preset = context.preset
        let natalInput = NatalInput(
            utcDate: profile.birthDateUTC,
            location: profile.location
        )

        switch (chart, context.target) {
        case let (.tertiary, .tertiary(targetDate, _)):
            let reference = try await calculator.calculateSnapshot(natalInput, preset: preset)
            let progressedDate = SwissEphemerisCalculator.tertiaryProgressedDate(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate
            )
            let snapshot = try await calculator.calculateTertiaryProgression(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate,
                location: profile.location,
                preset: preset
            )
            return ChartDisplayResult(
                snapshot: snapshot,
                reference: reference,
                comparisonAspects: SwissEphemerisCalculator.advancedComparisonAspects(
                    moving: snapshot,
                    reference: reference,
                    preset: preset
                ),
                techniqueMetadata: .tertiary(
                    targetDate: targetDate,
                    progressedDate: progressedDate,
                    monthDays: SwissEphemerisCalculator.tertiaryMonthDays
                )
            )

        case let (.lunarReturn, .lunarReturn(targetDate, location, _)):
            let reference = try await calculator.calculateSnapshot(natalInput, preset: preset)
            let calculation = try await calculator.calculateLunarReturn(
                birthDate: profile.birthDateUTC,
                onOrBefore: targetDate,
                location: location.geographicLocation,
                preset: preset
            )
            let returnMoonLongitude = calculation.snapshot.point(.moon)?.longitudeDegrees
                ?? calculation.natalMoonLongitude
            return ChartDisplayResult(
                snapshot: calculation.snapshot,
                reference: reference,
                comparisonAspects: SwissEphemerisCalculator.advancedComparisonAspects(
                    moving: calculation.snapshot,
                    reference: reference,
                    preset: preset
                ),
                techniqueMetadata: .lunarReturn(
                    targetDate: targetDate,
                    returnMoment: calculation.returnMoment,
                    natalMoonLongitude: calculation.natalMoonLongitude,
                    returnMoonLongitude: returnMoonLongitude
                )
            )

        case let (.solarArc, .solarArc(targetDate, _)):
            let calculation = try await calculator.calculateSolarArc(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate,
                location: profile.location,
                preset: preset
            )
            return ChartDisplayResult(
                snapshot: calculation.snapshot,
                reference: calculation.natal,
                comparisonAspects: SwissEphemerisCalculator.advancedComparisonAspects(
                    moving: calculation.snapshot,
                    reference: calculation.natal,
                    preset: preset
                ),
                techniqueMetadata: .solarArc(
                    targetDate: targetDate,
                    progressedDate: calculation.progressedDate,
                    arcDegrees: calculation.arcDegrees
                )
            )

        case let (.relocation, .relocation(location)):
            let snapshot = try await calculator.calculateRelocation(
                birthDate: profile.birthDateUTC,
                location: location.geographicLocation,
                preset: preset
            )
            return ChartDisplayResult(
                snapshot: snapshot,
                reference: nil,
                comparisonAspects: snapshot.aspects,
                techniqueMetadata: .relocation
            )

        case (.twelfthHarmonic, .twelfthHarmonic):
            let reference = try await calculator.calculateSnapshot(natalInput, preset: preset)
            let snapshot = SwissEphemerisCalculator.harmonicSnapshot(
                from: reference,
                harmonic: 12,
                preset: preset
            )
            return ChartDisplayResult(
                snapshot: snapshot,
                reference: reference,
                comparisonAspects: SwissEphemerisCalculator.advancedComparisonAspects(
                    moving: snapshot,
                    reference: reference,
                    preset: preset
                ),
                techniqueMetadata: .harmonic(number: 12)
            )

        case (.thirteenthHarmonic, .thirteenthHarmonic):
            let reference = try await calculator.calculateSnapshot(natalInput, preset: preset)
            let snapshot = SwissEphemerisCalculator.harmonicSnapshot(
                from: reference,
                harmonic: 13,
                preset: preset
            )
            return ChartDisplayResult(
                snapshot: snapshot,
                reference: reference,
                comparisonAspects: SwissEphemerisCalculator.advancedComparisonAspects(
                    moving: snapshot,
                    reference: reference,
                    preset: preset
                ),
                techniqueMetadata: .harmonic(number: 13)
            )

        default:
            throw AppAdvancedChartCalculationError.invalidTarget(chart)
        }
    }
}
