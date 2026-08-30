import Foundation

/// The sixteen relationship-chart capabilities defined by the supplied
/// relationship-chart specification. These are internal calculation
/// techniques for orchestration (for example Themes); they intentionally do
/// not extend the app-level `ChartKind` discovery surface.
public enum RelationshipChartKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case synastryA = "synastry-a"
    case synastryB = "synastry-b"
    case composite = "composite"
    case compositeTransit = "composite-transit"
    case compositeSecondary = "composite-secondary"
    case compositeTertiary = "composite-tertiary"
    case compositeSecondaryCompare = "composite-secondary-compare"
    case compositeTertiaryCompare = "composite-tertiary-compare"
    case davison = "davison"
    case davisonTransit = "davison-transit"
    case davisonSecondary = "davison-secondary"
    case davisonTertiary = "davison-tertiary"
    case marksA = "marks-a"
    case marksB = "marks-b"
    case marksSecondary = "marks-secondary"
    case marksTertiary = "marks-tertiary"

    public var id: String { rawValue }

    public var orbFamily: RelationshipOrbFamily {
        switch self {
        case .composite, .davison, .marksA, .marksB:
            .a
        default:
            .b
        }
    }

    public var defaultMidpointAlgorithm: RelationshipMidpointAlgorithm? {
        switch self {
        case .davison:
            .shortestDistance
        case .davisonTransit, .davisonSecondary, .davisonTertiary:
            .average
        case .marksA, .marksB, .marksSecondary, .marksTertiary:
            .shortestDistance
        default:
            nil
        }
    }
}

public enum RelationshipPreset: String, CaseIterable, Codable, Sendable, Identifiable {
    case modern
    case classical

    public var id: String { rawValue }

    public var calculationPreset: CalculationPreset {
        switch self {
        case .modern: .modern
        case .classical: .classical
        }
    }
}

public enum RelationshipOrbFamily: String, Codable, Sendable {
    case a
    case b
}

public enum RelationshipMidpointAlgorithm: String, Codable, Sendable {
    case average
    case shortestDistance
}

public enum RelationshipPerspective: String, Codable, Sendable {
    case first
    case second
}

/// Modern/Classical relationship settings transcribed from the supplied
/// parameter sheets. The relationship-only point sets include exactly the
/// documented Lilith / Part of Fortune / Juno defaults while the public chart
/// presets retain their pre-existing point lists.
public struct RelationshipPresetConfiguration: Sendable, Equatable {
    public let preset: RelationshipPreset
    public let orbFamily: RelationshipOrbFamily

    public init(preset: RelationshipPreset, orbFamily: RelationshipOrbFamily) {
        self.preset = preset
        self.orbFamily = orbFamily
    }

    public var houseSystemCode: Character {
        preset.calculationPreset.houseSystemCode
    }

    public var pointIDs: [CelestialBody] {
        switch (preset, orbFamily) {
        case (.modern, .a):
            CalculationPreset.modern.pointIDs + [.lilith, .partOfFortune, .juno]
        case (.modern, .b):
            CalculationPreset.modern.pointIDs
        case (.classical, _):
            CalculationPreset.classical.pointIDs + [.partOfFortune]
        }
    }

    public var orbsByKind: [AspectKind: Double]? {
        guard preset == .modern else { return nil }
        switch orbFamily {
        case .a: return ChartOrbProfile.singleA
        case .b: return ChartOrbProfile.comparisonB
        }
    }

    public var orbsByBody: [CelestialBody: Double]? {
        preset == .classical ? ChartOrbProfile.classicalStarlight : nil
    }

    public var documentedSupplementalPoints: [String] {
        switch (preset, orbFamily) {
        case (.modern, .a): ["lilith", "fortune", "juno"]
        case (.modern, .b): []
        case (.classical, _): ["fortune"]
        }
    }

    public var chartConfiguration: ChartCalculationConfiguration {
        let calculationPreset = preset.calculationPreset
        return ChartCalculationConfiguration(
            pointIDs: pointIDs,
            houseSystemCode: houseSystemCode,
            aspectOrbDegrees: calculationPreset.defaultOrbDegrees,
            orbsByKind: orbsByKind,
            orbsByBody: orbsByBody
        )
    }
}

public enum RelationshipMidpoint {
    public static func normalizedDegrees(_ value: Double) -> Double {
        var result = value.truncatingRemainder(dividingBy: 360)
        if result < 0 { result += 360 }
        return result
    }

    /// Circular midpoint along the shortest arc, avoiding the 0°/360° seam.
    public static func shortestArcDegrees(_ first: Double, _ second: Double) -> Double {
        let a = normalizedDegrees(first)
        let b = normalizedDegrees(second)
        var delta = b - a
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return normalizedDegrees(a + delta / 2)
    }

    /// Arithmetic longitude midpoint, normalized only after averaging.
    public static func averageDegrees(_ first: Double, _ second: Double) -> Double {
        normalizedDegrees((first + second) / 2)
    }

    public static func longitudeDegrees(
        _ first: Double,
        _ second: Double,
        algorithm: RelationshipMidpointAlgorithm
    ) -> Double {
        switch algorithm {
        case .average:
            averageDegrees(first, second)
        case .shortestDistance:
            shortestArcDegrees(first, second)
        }
    }
}

public struct RelationshipPersonInput: Sendable, Equatable, Codable, Identifiable {
    public let id: String
    public let birthDate: Date
    public let location: GeographicLocation

    public init(id: String, birthDate: Date, location: GeographicLocation) {
        self.id = id
        self.birthDate = birthDate
        self.location = location
    }

    public var natalInput: NatalInput {
        NatalInput(utcDate: birthDate, location: location)
    }
}

public struct RelationshipChartRequest: Sendable, Equatable, Codable {
    public let kind: RelationshipChartKind
    public let first: RelationshipPersonInput
    public let second: RelationshipPersonInput
    public let preset: RelationshipPreset
    public let targetDate: Date?
    public let transitLocation: GeographicLocation?
    public let perspective: RelationshipPerspective?
    public let midpointAlgorithm: RelationshipMidpointAlgorithm?

    public init(
        kind: RelationshipChartKind,
        first: RelationshipPersonInput,
        second: RelationshipPersonInput,
        preset: RelationshipPreset,
        targetDate: Date? = nil,
        transitLocation: GeographicLocation? = nil,
        perspective: RelationshipPerspective? = nil,
        midpointAlgorithm: RelationshipMidpointAlgorithm? = nil
    ) {
        self.kind = kind
        self.first = first
        self.second = second
        self.preset = preset
        self.targetDate = targetDate
        self.transitLocation = transitLocation
        self.perspective = perspective
        self.midpointAlgorithm = midpointAlgorithm
    }
}

public enum RelationshipTechniqueBasis: String, Sendable, Equatable, Codable {
    case synastry
    case mathematicalMidpoint
    case timeSpaceMidpoint
    case marks
    case transit
    case progression
}

public struct RelationshipTechniqueMetadata: Sendable, Equatable, Codable {
    public let basis: RelationshipTechniqueBasis
    public let preset: RelationshipPreset
    public let perspective: RelationshipPerspective?
    public let midpointAlgorithm: RelationshipMidpointAlgorithm?
    public let targetDate: Date?

    public init(
        basis: RelationshipTechniqueBasis,
        preset: RelationshipPreset,
        perspective: RelationshipPerspective? = nil,
        midpointAlgorithm: RelationshipMidpointAlgorithm? = nil,
        targetDate: Date? = nil
    ) {
        self.basis = basis
        self.preset = preset
        self.perspective = perspective
        self.midpointAlgorithm = midpointAlgorithm
        self.targetDate = targetDate
    }
}

/// Renderer-ready output. `reference` is the inner wheel and `snapshot` is the
/// outer/main wheel, matching `ChartWheelView`'s existing contract.
public struct RelationshipChartArtifact: Sendable, Equatable, Codable {
    public let kind: RelationshipChartKind
    public let snapshot: ChartSnapshot
    public let reference: ChartSnapshot?
    public let comparisonAspects: [ChartAspect]
    public let metadata: RelationshipTechniqueMetadata

    public init(
        kind: RelationshipChartKind,
        snapshot: ChartSnapshot,
        reference: ChartSnapshot?,
        comparisonAspects: [ChartAspect],
        metadata: RelationshipTechniqueMetadata
    ) {
        self.kind = kind
        self.snapshot = snapshot
        self.reference = reference
        self.comparisonAspects = comparisonAspects
        self.metadata = metadata
    }
}

public enum RelationshipChartError: Error, Sendable, Equatable, LocalizedError {
    case targetDateRequired(RelationshipChartKind)
    case unsupportedTechnique(RelationshipChartKind)

    public var errorDescription: String? {
        switch self {
        case let .targetDateRequired(kind):
            "A target date is required for \(kind.rawValue)."
        case let .unsupportedTechnique(kind):
            "Relationship technique \(kind.rawValue) is not implemented."
        }
    }
}

extension RelationshipMidpoint {
    public static func date(_ first: Date, _ second: Date) -> Date {
        first.addingTimeInterval(second.timeIntervalSince(first) / 2)
    }

    public static func location(
        _ first: GeographicLocation,
        _ second: GeographicLocation,
        algorithm: RelationshipMidpointAlgorithm
    ) -> GeographicLocation {
        switch algorithm {
        case .average:
            let longitude = averageDegrees(
                first.longitudeDegrees,
                second.longitudeDegrees
            )
            return GeographicLocation(
                latitudeDegrees: (first.latitudeDegrees + second.latitudeDegrees) / 2,
                longitudeDegrees: longitude > 180 ? longitude - 360 : longitude
            )

        case .shortestDistance:
            // Midpoint of the shorter great-circle arc on a unit sphere.
            // Averaging latitude/longitude independently is not a geodesic
            // midpoint and becomes materially wrong for distant locations.
            let latitude1 = first.latitudeDegrees * .pi / 180
            let longitude1 = first.longitudeDegrees * .pi / 180
            let latitude2 = second.latitudeDegrees * .pi / 180
            let longitude2 = second.longitudeDegrees * .pi / 180

            let x = cos(latitude1) * cos(longitude1) + cos(latitude2) * cos(longitude2)
            let y = cos(latitude1) * sin(longitude1) + cos(latitude2) * sin(longitude2)
            let z = sin(latitude1) + sin(latitude2)
            let horizontal = hypot(x, y)

            // Antipodal points do not have a unique shortest-arc midpoint.
            // Fall back to the documented coordinate-average behavior rather
            // than returning NaN or an unstable direction.
            if horizontal < 1e-14 && abs(z) < 1e-14 {
                let longitude = shortestArcDegrees(
                    first.longitudeDegrees,
                    second.longitudeDegrees
                )
                return GeographicLocation(
                    latitudeDegrees: (first.latitudeDegrees + second.latitudeDegrees) / 2,
                    longitudeDegrees: longitude > 180 ? longitude - 360 : longitude
                )
            }

            let latitude = atan2(z, horizontal) * 180 / .pi
            let longitude = atan2(y, x) * 180 / .pi
            return GeographicLocation(
                latitudeDegrees: latitude,
                longitudeDegrees: longitude
            )
        }
    }

    public static func natalInput(
        _ first: NatalInput,
        _ second: NatalInput,
        algorithm: RelationshipMidpointAlgorithm
    ) -> NatalInput {
        NatalInput(
            utcDate: date(first.utcDate, second.utcDate),
            location: location(first.location, second.location, algorithm: algorithm)
        )
    }
}

extension SwissEphemerisCalculator {
    /// Calculates one of the archive-defined relationship techniques. The
    /// public artifact is deliberately independent of app-level `ChartKind`
    /// so these capabilities can remain hidden from Charts discovery.
    public func calculateRelationshipChart(
        _ request: RelationshipChartRequest
    ) throws -> RelationshipChartArtifact {
        switch request.kind {
        case .synastryA:
            return try relationshipSynastryArtifact(request, perspective: .first)
        case .synastryB:
            return try relationshipSynastryArtifact(request, perspective: .second)
        case .composite:
            return try relationshipCompositeArtifact(request)
        case .davison:
            return try relationshipDavisonArtifact(request)
        case .marksA:
            return try relationshipMarksArtifact(request, perspective: .first)
        case .marksB:
            return try relationshipMarksArtifact(request, perspective: .second)
        case .compositeTransit:
            return try relationshipCompositeTransitArtifact(request)
        case .compositeSecondary:
            return try relationshipCompositeProgressionArtifact(request, progression: .secondary, compare: false)
        case .compositeTertiary:
            return try relationshipCompositeProgressionArtifact(request, progression: .tertiary, compare: false)
        case .compositeSecondaryCompare:
            return try relationshipCompositeProgressionArtifact(request, progression: .secondary, compare: true)
        case .compositeTertiaryCompare:
            return try relationshipCompositeProgressionArtifact(request, progression: .tertiary, compare: true)
        case .davisonTransit:
            return try relationshipDavisonTransitArtifact(request)
        case .davisonSecondary:
            return try relationshipDavisonProgressionArtifact(request, progression: .secondary)
        case .davisonTertiary:
            return try relationshipDavisonProgressionArtifact(request, progression: .tertiary)
        case .marksSecondary:
            return try relationshipMarksProgressionArtifact(request, progression: .secondary)
        case .marksTertiary:
            return try relationshipMarksProgressionArtifact(request, progression: .tertiary)
        }
    }

    private func relationshipSynastryArtifact(
        _ request: RelationshipChartRequest,
        perspective: RelationshipPerspective
    ) throws -> RelationshipChartArtifact {
        let configuration = RelationshipPresetConfiguration(
            preset: request.preset,
            orbFamily: .b
        )
        let firstSnapshot = try calculateSnapshot(
            request.first.natalInput,
            configuration: configuration.chartConfiguration
        )
        let secondSnapshot = try calculateSnapshot(
            request.second.natalInput,
            configuration: configuration.chartConfiguration
        )
        let reference: ChartSnapshot
        let moving: ChartSnapshot
        switch perspective {
        case .first:
            reference = firstSnapshot
            moving = secondSnapshot
        case .second:
            reference = secondSnapshot
            moving = firstSnapshot
        }
        let crossAspects = Self.compare(
            moving: moving,
            reference: reference,
            orbDegrees: request.preset.calculationPreset.defaultOrbDegrees,
            orbsByKind: configuration.orbsByKind,
            orbsByBody: configuration.orbsByBody
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: moving,
            reference: reference,
            comparisonAspects: crossAspects,
            metadata: RelationshipTechniqueMetadata(
                basis: .synastry,
                preset: request.preset,
                perspective: perspective
            )
        )
    }

    private func relationshipCompositeArtifact(
        _ request: RelationshipChartRequest
    ) throws -> RelationshipChartArtifact {
        let configuration = RelationshipPresetConfiguration(
            preset: request.preset,
            orbFamily: .a
        )
        let firstSnapshot = try calculateSnapshot(
            request.first.natalInput,
            configuration: configuration.chartConfiguration
        )
        let secondSnapshot = try calculateSnapshot(
            request.second.natalInput,
            configuration: configuration.chartConfiguration
        )
        let snapshot = Self.relationshipCompositeSnapshot(
            first: firstSnapshot,
            second: secondSnapshot,
            configuration: configuration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: snapshot,
            reference: nil,
            comparisonAspects: [],
            metadata: RelationshipTechniqueMetadata(
                basis: .mathematicalMidpoint,
                preset: request.preset
            )
        )
    }

    private func relationshipDavisonArtifact(
        _ request: RelationshipChartRequest
    ) throws -> RelationshipChartArtifact {
        let algorithm = request.midpointAlgorithm
            ?? request.kind.defaultMidpointAlgorithm
            ?? .shortestDistance
        let configuration = RelationshipPresetConfiguration(
            preset: request.preset,
            orbFamily: .a
        )
        let input = RelationshipMidpoint.natalInput(
            request.first.natalInput,
            request.second.natalInput,
            algorithm: algorithm
        )
        let snapshot = try calculateSnapshot(input, configuration: configuration.chartConfiguration)
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: snapshot,
            reference: nil,
            comparisonAspects: [],
            metadata: RelationshipTechniqueMetadata(
                basis: .timeSpaceMidpoint,
                preset: request.preset,
                midpointAlgorithm: algorithm
            )
        )
    }

    private func relationshipMarksArtifact(
        _ request: RelationshipChartRequest,
        perspective: RelationshipPerspective
    ) throws -> RelationshipChartArtifact {
        let algorithm = request.midpointAlgorithm
            ?? request.kind.defaultMidpointAlgorithm
            ?? .shortestDistance
        let configuration = RelationshipPresetConfiguration(
            preset: request.preset,
            orbFamily: .a
        )
        let relationshipInput = RelationshipMidpoint.natalInput(
            request.first.natalInput,
            request.second.natalInput,
            algorithm: algorithm
        )
        let personInput = perspective == .first
            ? request.first.natalInput
            : request.second.natalInput
        let marksInput = RelationshipMidpoint.natalInput(
            personInput,
            relationshipInput,
            algorithm: algorithm
        )
        let snapshot = try calculateSnapshot(
            marksInput,
            configuration: configuration.chartConfiguration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: snapshot,
            reference: nil,
            comparisonAspects: [],
            metadata: RelationshipTechniqueMetadata(
                basis: .marks,
                preset: request.preset,
                perspective: perspective,
                midpointAlgorithm: algorithm
            )
        )
    }


    private enum RelationshipProgressionMethod {
        case secondary
        case tertiary
    }

    private func requiredTargetDate(_ request: RelationshipChartRequest) throws -> Date {
        guard let targetDate = request.targetDate else {
            throw RelationshipChartError.targetDateRequired(request.kind)
        }
        return targetDate
    }

    private func relationshipCompositeTransitArtifact(
        _ request: RelationshipChartRequest
    ) throws -> RelationshipChartArtifact {
        let targetDate = try requiredTargetDate(request)
        let configuration = RelationshipPresetConfiguration(preset: request.preset, orbFamily: .b)
        let composite = try relationshipCompositeSnapshot(request, configuration: configuration)
        let transitLocation = request.transitLocation ?? composite.location
        let transit = try calculateSnapshot(
            NatalInput(utcDate: targetDate, location: transitLocation),
            configuration: configuration.chartConfiguration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: transit,
            reference: composite,
            comparisonAspects: relationshipComparisonAspects(
                moving: transit,
                reference: composite,
                configuration: configuration
            ),
            metadata: RelationshipTechniqueMetadata(
                basis: .transit,
                preset: request.preset,
                targetDate: targetDate
            )
        )
    }

    private func relationshipCompositeProgressionArtifact(
        _ request: RelationshipChartRequest,
        progression: RelationshipProgressionMethod,
        compare: Bool
    ) throws -> RelationshipChartArtifact {
        let targetDate = try requiredTargetDate(request)
        let configuration = RelationshipPresetConfiguration(preset: request.preset, orbFamily: .b)
        let firstProgressed = try relationshipProgressedSnapshot(
            person: request.first,
            targetDate: targetDate,
            progression: progression,
            configuration: configuration
        )
        let secondProgressed = try relationshipProgressedSnapshot(
            person: request.second,
            targetDate: targetDate,
            progression: progression,
            configuration: configuration
        )
        let progressedComposite = Self.relationshipCompositeSnapshot(
            first: firstProgressed,
            second: secondProgressed,
            configuration: configuration
        )
        let reference = compare
            ? try relationshipCompositeSnapshot(request, configuration: configuration)
            : nil
        let comparisonAspects = reference.map {
            relationshipComparisonAspects(
                moving: progressedComposite,
                reference: $0,
                configuration: configuration
            )
        } ?? []
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: progressedComposite,
            reference: reference,
            comparisonAspects: comparisonAspects,
            metadata: RelationshipTechniqueMetadata(
                basis: .progression,
                preset: request.preset,
                targetDate: targetDate
            )
        )
    }

    private func relationshipDavisonTransitArtifact(
        _ request: RelationshipChartRequest
    ) throws -> RelationshipChartArtifact {
        let targetDate = try requiredTargetDate(request)
        let algorithm = request.midpointAlgorithm
            ?? request.kind.defaultMidpointAlgorithm
            ?? .average
        let configuration = RelationshipPresetConfiguration(preset: request.preset, orbFamily: .b)
        let radixInput = relationshipDavisonInput(request, algorithm: algorithm)
        let radix = try calculateSnapshot(radixInput, configuration: configuration.chartConfiguration)
        let transit = try calculateSnapshot(
            NatalInput(
                utcDate: targetDate,
                location: request.transitLocation ?? radix.location
            ),
            configuration: configuration.chartConfiguration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: transit,
            reference: radix,
            comparisonAspects: relationshipComparisonAspects(
                moving: transit,
                reference: radix,
                configuration: configuration
            ),
            metadata: RelationshipTechniqueMetadata(
                basis: .transit,
                preset: request.preset,
                midpointAlgorithm: algorithm,
                targetDate: targetDate
            )
        )
    }

    private func relationshipDavisonProgressionArtifact(
        _ request: RelationshipChartRequest,
        progression: RelationshipProgressionMethod
    ) throws -> RelationshipChartArtifact {
        let targetDate = try requiredTargetDate(request)
        let algorithm = request.midpointAlgorithm
            ?? request.kind.defaultMidpointAlgorithm
            ?? .average
        let configuration = RelationshipPresetConfiguration(preset: request.preset, orbFamily: .b)
        let radixInput = relationshipDavisonInput(request, algorithm: algorithm)
        let progressedDate = relationshipProgressedDate(
            birthDate: radixInput.utcDate,
            targetDate: targetDate,
            progression: progression
        )
        let progressed = try calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: radixInput.location),
            configuration: configuration.chartConfiguration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: progressed,
            reference: nil,
            comparisonAspects: [],
            metadata: RelationshipTechniqueMetadata(
                basis: .progression,
                preset: request.preset,
                midpointAlgorithm: algorithm,
                targetDate: targetDate
            )
        )
    }

    private func relationshipMarksProgressionArtifact(
        _ request: RelationshipChartRequest,
        progression: RelationshipProgressionMethod
    ) throws -> RelationshipChartArtifact {
        let targetDate = try requiredTargetDate(request)
        let perspective = request.perspective ?? .first
        let algorithm = request.midpointAlgorithm
            ?? request.kind.defaultMidpointAlgorithm
            ?? .shortestDistance
        let configuration = RelationshipPresetConfiguration(preset: request.preset, orbFamily: .b)
        let radixInput = relationshipMarksInput(
            request,
            perspective: perspective,
            algorithm: algorithm
        )
        let progressedDate = relationshipProgressedDate(
            birthDate: radixInput.utcDate,
            targetDate: targetDate,
            progression: progression
        )
        let progressed = try calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: radixInput.location),
            configuration: configuration.chartConfiguration
        )
        return RelationshipChartArtifact(
            kind: request.kind,
            snapshot: progressed,
            reference: nil,
            comparisonAspects: [],
            metadata: RelationshipTechniqueMetadata(
                basis: .progression,
                preset: request.preset,
                perspective: perspective,
                midpointAlgorithm: algorithm,
                targetDate: targetDate
            )
        )
    }

    private func relationshipProgressedSnapshot(
        person: RelationshipPersonInput,
        targetDate: Date,
        progression: RelationshipProgressionMethod,
        configuration: RelationshipPresetConfiguration
    ) throws -> ChartSnapshot {
        let progressedDate = relationshipProgressedDate(
            birthDate: person.birthDate,
            targetDate: targetDate,
            progression: progression
        )
        return try calculateSnapshot(
            NatalInput(utcDate: progressedDate, location: person.location),
            configuration: configuration.chartConfiguration
        )
    }

    private nonisolated func relationshipProgressedDate(
        birthDate: Date,
        targetDate: Date,
        progression: RelationshipProgressionMethod
    ) -> Date {
        switch progression {
        case .secondary:
            Self.secondaryProgressedDate(birthDate: birthDate, targetDate: targetDate)
        case .tertiary:
            Self.tertiaryProgressedDate(birthDate: birthDate, targetDate: targetDate)
        }
    }

    private func relationshipCompositeSnapshot(
        _ request: RelationshipChartRequest,
        configuration: RelationshipPresetConfiguration
    ) throws -> ChartSnapshot {
        let first = try calculateSnapshot(
            request.first.natalInput,
            configuration: configuration.chartConfiguration
        )
        let second = try calculateSnapshot(
            request.second.natalInput,
            configuration: configuration.chartConfiguration
        )
        return Self.relationshipCompositeSnapshot(
            first: first,
            second: second,
            configuration: configuration
        )
    }

    private nonisolated func relationshipDavisonInput(
        _ request: RelationshipChartRequest,
        algorithm: RelationshipMidpointAlgorithm
    ) -> NatalInput {
        RelationshipMidpoint.natalInput(
            request.first.natalInput,
            request.second.natalInput,
            algorithm: algorithm
        )
    }

    private nonisolated func relationshipMarksInput(
        _ request: RelationshipChartRequest,
        perspective: RelationshipPerspective,
        algorithm: RelationshipMidpointAlgorithm
    ) -> NatalInput {
        let relationshipInput = relationshipDavisonInput(request, algorithm: algorithm)
        let personInput = perspective == .first
            ? request.first.natalInput
            : request.second.natalInput
        return RelationshipMidpoint.natalInput(
            personInput,
            relationshipInput,
            algorithm: algorithm
        )
    }

    private nonisolated func relationshipComparisonAspects(
        moving: ChartSnapshot,
        reference: ChartSnapshot,
        configuration: RelationshipPresetConfiguration
    ) -> [ChartAspect] {
        Self.compare(
            moving: moving,
            reference: reference,
            orbDegrees: configuration.preset.calculationPreset.defaultOrbDegrees,
            orbsByKind: configuration.orbsByKind,
            orbsByBody: configuration.orbsByBody
        )
    }

    private nonisolated static func relationshipCompositeSnapshot(
        first: ChartSnapshot,
        second: ChartSnapshot,
        configuration: RelationshipPresetConfiguration
    ) -> ChartSnapshot {
        let secondPoints = Dictionary(uniqueKeysWithValues: second.points.map { ($0.body, $0) })
        var points = first.points.compactMap { firstPoint -> ChartPoint? in
            guard let secondPoint = secondPoints[firstPoint.body] else { return nil }
            return ChartPoint(
                body: firstPoint.body,
                position: CelestialPosition(
                    longitudeDegrees: RelationshipMidpoint.shortestArcDegrees(
                        firstPoint.position.longitudeDegrees,
                        secondPoint.position.longitudeDegrees
                    ),
                    latitudeDegrees: (firstPoint.position.latitudeDegrees + secondPoint.position.latitudeDegrees) / 2,
                    distanceAU: (firstPoint.position.distanceAU + secondPoint.position.distanceAU) / 2,
                    longitudeSpeedDegreesPerDay: (
                        firstPoint.position.longitudeSpeedDegreesPerDay
                            + secondPoint.position.longitudeSpeedDegreesPerDay
                    ) / 2
                )
            )
        }
        let secondHouses = Dictionary(uniqueKeysWithValues: second.houses.map { ($0.number, $0) })
        let houses = first.houses.compactMap { firstHouse -> ChartHouse? in
            guard let secondHouse = secondHouses[firstHouse.number] else { return nil }
            return ChartHouse(
                number: firstHouse.number,
                cuspDegrees: RelationshipMidpoint.shortestArcDegrees(
                    firstHouse.cuspDegrees,
                    secondHouse.cuspDegrees
                )
            )
        }
        let angles = NatalAngles(
            ascendantDegrees: RelationshipMidpoint.shortestArcDegrees(
                first.angles.ascendantDegrees,
                second.angles.ascendantDegrees
            ),
            midheavenDegrees: RelationshipMidpoint.shortestArcDegrees(
                first.angles.midheavenDegrees,
                second.angles.midheavenDegrees
            )
        )

        // A composite Part of Fortune is a derived lot of the composite
        // chart itself, not the midpoint of the two natal lots. Recalculate
        // it from the already-derived composite Ascendant, Sun and Moon.
        // This also avoids carrying each natal chart's day/night branch into
        // a mathematical midpoint where that branch can differ by 180°.
        if let fortuneIndex = points.firstIndex(where: { $0.body == .partOfFortune }),
           let sun = points.first(where: { $0.body == .sun }),
           let moon = points.first(where: { $0.body == .moon }) {
            let sunHouse = relationshipHouseNumber(
                containing: sun.position.longitudeDegrees,
                houses: houses
            )
            let fortuneLongitude = RelationshipMidpoint.normalizedDegrees(
                (7 ... 12).contains(sunHouse)
                    ? angles.ascendantDegrees + moon.position.longitudeDegrees - sun.position.longitudeDegrees
                    : angles.ascendantDegrees + sun.position.longitudeDegrees - moon.position.longitudeDegrees
            )
            points[fortuneIndex] = ChartPoint(
                body: .partOfFortune,
                position: CelestialPosition(
                    longitudeDegrees: fortuneLongitude,
                    latitudeDegrees: 0,
                    distanceAU: 0,
                    longitudeSpeedDegreesPerDay: 0
                )
            )
        }

        let utcDate = RelationshipMidpoint.date(first.utcDate, second.utcDate)
        let location = RelationshipMidpoint.location(
            first.location,
            second.location,
            algorithm: .shortestDistance
        )
        let aspects = Self.calculateAspects(
            for: points,
            orbDegrees: configuration.preset.calculationPreset.defaultOrbDegrees,
            orbsByKind: configuration.orbsByKind,
            orbsByBody: configuration.orbsByBody
        )
        return ChartSnapshot(
            utcDate: utcDate,
            location: location,
            julianDayUT: (first.julianDayUT + second.julianDayUT) / 2,
            points: points,
            houses: houses,
            angles: angles,
            aspects: aspects
        )
    }

    private nonisolated static func relationshipHouseNumber(
        containing longitude: Double,
        houses: [ChartHouse]
    ) -> Int {
        guard houses.count == 12 else { return 0 }
        let value = RelationshipMidpoint.normalizedDegrees(longitude)
        for index in houses.indices {
            let start = RelationshipMidpoint.normalizedDegrees(houses[index].cuspDegrees)
            let end = RelationshipMidpoint.normalizedDegrees(houses[(index + 1) % houses.count].cuspDegrees)
            let span = RelationshipMidpoint.normalizedDegrees(end - start)
            let offset = RelationshipMidpoint.normalizedDegrees(value - start)
            if offset < span || abs(offset - span) < 0.000_000_1 {
                return houses[index].number
            }
        }
        return 0
    }
}
