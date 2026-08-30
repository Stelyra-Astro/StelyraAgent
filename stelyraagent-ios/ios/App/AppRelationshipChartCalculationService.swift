import AstroCore
import Foundation

enum AppRelationshipChartCalculationError: Error, LocalizedError {
    case unsupportedPreset(CalculationPreset)

    var errorDescription: String? {
        switch self {
        case let .unsupportedPreset(preset):
            "Relationship techniques support Modern and Classical presets only: \(preset.rawValue)."
        }
    }
}

/// Immutable app-side input for one hidden relationship technique. Themes can
/// persist its own participant snapshots and later recreate this request
/// without binding the calculation to AppModel's current Charts selection.
struct AppRelationshipChartRequest {
    let kind: RelationshipChartKind
    let firstID: String
    let firstProfile: UserProfile
    let secondID: String
    let secondProfile: UserProfile
    let preset: CalculationPreset
    let targetDate: Date?
    let transitLocation: ChartLocationSelection?
    let perspective: RelationshipPerspective?
    let midpointAlgorithm: RelationshipMidpointAlgorithm?

    init(
        kind: RelationshipChartKind,
        firstID: String,
        firstProfile: UserProfile,
        secondID: String,
        secondProfile: UserProfile,
        preset: CalculationPreset,
        targetDate: Date? = nil,
        transitLocation: ChartLocationSelection? = nil,
        perspective: RelationshipPerspective? = nil,
        midpointAlgorithm: RelationshipMidpointAlgorithm? = nil
    ) {
        self.kind = kind
        self.firstID = firstID
        self.firstProfile = firstProfile
        self.secondID = secondID
        self.secondProfile = secondProfile
        self.preset = preset
        self.targetDate = targetDate
        self.transitLocation = transitLocation
        self.perspective = perspective
        self.midpointAlgorithm = midpointAlgorithm
    }
}

@MainActor
final class AppRelationshipChartCalculationService {
    func calculate(
        request: AppRelationshipChartRequest,
        calculator: SwissEphemerisCalculator
    ) async throws -> RelationshipChartArtifact {
        let relationshipPreset: RelationshipPreset
        switch request.preset {
        case .modern:
            relationshipPreset = .modern
        case .classical:
            relationshipPreset = .classical
        case .special:
            throw AppRelationshipChartCalculationError.unsupportedPreset(request.preset)
        }

        return try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: request.kind,
                first: RelationshipPersonInput(
                    id: request.firstID,
                    birthDate: request.firstProfile.birthDateUTC,
                    location: request.firstProfile.location
                ),
                second: RelationshipPersonInput(
                    id: request.secondID,
                    birthDate: request.secondProfile.birthDateUTC,
                    location: request.secondProfile.location
                ),
                preset: relationshipPreset,
                targetDate: request.targetDate,
                transitLocation: request.transitLocation?.geographicLocation,
                perspective: request.perspective,
                midpointAlgorithm: request.midpointAlgorithm
            )
        )
    }
}
