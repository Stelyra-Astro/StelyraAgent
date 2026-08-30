import AstroCore
import Foundation
import Testing

@Suite("Relationship chart capabilities")
struct RelationshipChartTests {
    @Test("Registry matches the supplied 16 relationship subtypes")
    func registryMatchesArchive() {
        #expect(RelationshipChartKind.allCases.map(\.rawValue) == [
            "synastry-a",
            "synastry-b",
            "composite",
            "composite-transit",
            "composite-secondary",
            "composite-tertiary",
            "composite-secondary-compare",
            "composite-tertiary-compare",
            "davison",
            "davison-transit",
            "davison-secondary",
            "davison-tertiary",
            "marks-a",
            "marks-b",
            "marks-secondary",
            "marks-tertiary",
        ])
        #expect(RelationshipChartKind.allCases.count == 16)
    }

    @Test("Relationship presets match documented modern and classical families")
    func relationshipPresetConfiguration() {
        let modernA = RelationshipPresetConfiguration(preset: .modern, orbFamily: .a)
        let modernB = RelationshipPresetConfiguration(preset: .modern, orbFamily: .b)
        let classicalA = RelationshipPresetConfiguration(preset: .classical, orbFamily: .a)
        let classicalB = RelationshipPresetConfiguration(preset: .classical, orbFamily: .b)

        #expect(modernA.houseSystemCode == "P")
        #expect(classicalA.houseSystemCode == "B")
        #expect(modernA.pointIDs == CalculationPreset.modern.pointIDs + [.lilith, .partOfFortune, .juno])
        #expect(classicalA.pointIDs == CalculationPreset.classical.pointIDs + [.partOfFortune])

        #expect(modernA.orbsByKind?[.conjunction] == 7)
        #expect(modernA.orbsByKind?[.opposition] == 6)
        #expect(modernB.orbsByKind?[.conjunction] == 2)
        #expect(modernB.orbsByKind?[.opposition] == 1)
        #expect(classicalA.orbsByKind == nil)
        #expect(classicalB.orbsByKind == nil)
        #expect(classicalA.orbsByBody?[.sun] == 15)
        #expect(classicalB.orbsByBody?[.moon] == 12)

        #expect(modernA.documentedSupplementalPoints == ["lilith", "fortune", "juno"])
        #expect(modernB.documentedSupplementalPoints.isEmpty)
        #expect(classicalA.documentedSupplementalPoints == ["fortune"])
        #expect(classicalB.documentedSupplementalPoints == ["fortune"])
    }

    @Test("Archive maps base charts to A family and timing charts to B family")
    func orbFamilies() {
        let aFamily: Set<RelationshipChartKind> = [.composite, .davison, .marksA, .marksB]
        for kind in RelationshipChartKind.allCases {
            #expect(kind.orbFamily == (aFamily.contains(kind) ? .a : .b))
        }
    }

    @Test("Circular midpoint follows the shortest arc")
    func circularMidpoint() {
        #expect(abs(RelationshipMidpoint.shortestArcDegrees(350, 10) - 0) < 1e-10)
        #expect(abs(RelationshipMidpoint.shortestArcDegrees(10, 350) - 0) < 1e-10)
        #expect(abs(RelationshipMidpoint.shortestArcDegrees(30, 90) - 60) < 1e-10)
    }

    @Test("Circular midpoint is symmetric for exact oppositions")
    func circularMidpointOppositionIsSymmetric() {
        let forward = RelationshipMidpoint.shortestArcDegrees(0, 180)
        let reverse = RelationshipMidpoint.shortestArcDegrees(180, 0)
        #expect(absAngularDifference(forward, reverse) < 1e-12)
        #expect(absAngularDifference(forward, 90) < 1e-12)

        let seamForward = RelationshipMidpoint.shortestArcDegrees(350, 170)
        let seamReverse = RelationshipMidpoint.shortestArcDegrees(170, 350)
        #expect(absAngularDifference(seamForward, seamReverse) < 1e-12)
    }

    @Test("Shortest-distance geographic midpoint follows the great-circle path")
    func sphericalGeographicMidpoint() {
        let tokyo = GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)
        let newYork = GeographicLocation(latitudeDegrees: 40.7128, longitudeDegrees: -74.0060)
        let midpoint = RelationshipMidpoint.location(tokyo, newYork, algorithm: .shortestDistance)
        #expect(abs(midpoint.latitudeDegrees - 69.67715794568474) < 1e-9)
        #expect(abs(midpoint.longitudeDegrees - -153.70449409381928) < 1e-9)

        let arithmetic = RelationshipMidpoint.location(tokyo, newYork, algorithm: .average)
        #expect(abs(arithmetic.latitudeDegrees - 38.1945) < 1e-9)
        #expect(abs(arithmetic.longitudeDegrees - 32.82215) < 1e-9)
    }

    @Test("Technique-specific midpoint defaults match the supplied settings")
    func midpointDefaults() {
        #expect(RelationshipChartKind.davison.defaultMidpointAlgorithm == .shortestDistance)
        #expect(RelationshipChartKind.davisonTransit.defaultMidpointAlgorithm == .average)
        #expect(RelationshipChartKind.davisonSecondary.defaultMidpointAlgorithm == .average)
        #expect(RelationshipChartKind.davisonTertiary.defaultMidpointAlgorithm == .average)
        #expect(RelationshipChartKind.marksA.defaultMidpointAlgorithm == .shortestDistance)
        #expect(RelationshipChartKind.marksB.defaultMidpointAlgorithm == .shortestDistance)
        #expect(RelationshipChartKind.marksSecondary.defaultMidpointAlgorithm == .shortestDistance)
        #expect(RelationshipChartKind.marksTertiary.defaultMidpointAlgorithm == .shortestDistance)
    }

    @Test("Synastry A/B preserve the requested inner and outer orientation")
    func synastryOrientation() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let first = firstPerson
        let second = secondPerson

        let a = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .synastryA, first: first, second: second, preset: .modern)
        )
        let b = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .synastryB, first: first, second: second, preset: .modern)
        )

        #expect(a.reference?.utcDate == first.birthDate)
        #expect(a.snapshot.utcDate == second.birthDate)
        #expect(b.reference?.utcDate == second.birthDate)
        #expect(b.snapshot.utcDate == first.birthDate)
        #expect(a.metadata.basis == .synastry)
        #expect(b.metadata.basis == .synastry)
        #expect(!a.comparisonAspects.isEmpty)
        #expect(!b.comparisonAspects.isEmpty)
    }

    @Test("Composite uses circular midpoints for same-point positions and angles")
    func compositeMidpoints() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let firstNatal = try await calculator.calculateSnapshot(
            firstPerson.natalInput,
            configuration: RelationshipPresetConfiguration(preset: .modern, orbFamily: .a).chartConfiguration
        )
        let secondNatal = try await calculator.calculateSnapshot(
            secondPerson.natalInput,
            configuration: RelationshipPresetConfiguration(preset: .modern, orbFamily: .a).chartConfiguration
        )
        let composite = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: firstPerson, second: secondPerson, preset: .modern)
        )

        for body in RelationshipPresetConfiguration(preset: .modern, orbFamily: .a).pointIDs {
            let lhs = try #require(firstNatal.point(body)).longitudeDegrees
            let rhs = try #require(secondNatal.point(body)).longitudeDegrees
            let actual = try #require(composite.snapshot.point(body)).longitudeDegrees
            #expect(absAngularDifference(actual, RelationshipMidpoint.shortestArcDegrees(lhs, rhs)) < 1e-9)
        }
        #expect(absAngularDifference(
            composite.snapshot.angles.ascendantDegrees,
            RelationshipMidpoint.shortestArcDegrees(firstNatal.angles.ascendantDegrees, secondNatal.angles.ascendantDegrees)
        ) < 1e-9)
        #expect(composite.reference == nil)
        #expect(composite.metadata.basis == .mathematicalMidpoint)
    }

    @Test("Composite midpoint method includes every house cusp and is participant-order invariant")
    func compositeHouseMidpointsAndSymmetry() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let configuration = RelationshipPresetConfiguration(preset: .modern, orbFamily: .a)
        let firstNatal = try await calculator.calculateSnapshot(
            firstPerson.natalInput,
            configuration: configuration.chartConfiguration
        )
        let secondNatal = try await calculator.calculateSnapshot(
            secondPerson.natalInput,
            configuration: configuration.chartConfiguration
        )
        let forward = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: firstPerson, second: secondPerson, preset: .modern)
        )
        let reverse = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: secondPerson, second: firstPerson, preset: .modern)
        )

        for houseNumber in 1 ... 12 {
            let firstCusp = try #require(firstNatal.houses.first(where: { $0.number == houseNumber })).cuspDegrees
            let secondCusp = try #require(secondNatal.houses.first(where: { $0.number == houseNumber })).cuspDegrees
            let actual = try #require(forward.snapshot.houses.first(where: { $0.number == houseNumber })).cuspDegrees
            #expect(absAngularDifference(
                actual,
                RelationshipMidpoint.shortestArcDegrees(firstCusp, secondCusp)
            ) < 1e-9)
        }
        #expect(forward.snapshot.points.map(\.body) == reverse.snapshot.points.map(\.body))
        for (lhs, rhs) in zip(forward.snapshot.points, reverse.snapshot.points) {
            #expect(absAngularDifference(lhs.longitudeDegrees, rhs.longitudeDegrees) < 1e-9)
            #expect(abs(lhs.position.latitudeDegrees - rhs.position.latitudeDegrees) < 1e-9)
            #expect(abs(lhs.position.distanceAU - rhs.position.distanceAU) < 1e-9)
            #expect(abs(lhs.position.longitudeSpeedDegreesPerDay - rhs.position.longitudeSpeedDegreesPerDay) < 1e-9)
        }
        for houseNumber in 1 ... 12 {
            let lhs = try #require(forward.snapshot.houses.first(where: { $0.number == houseNumber })).cuspDegrees
            let rhs = try #require(reverse.snapshot.houses.first(where: { $0.number == houseNumber })).cuspDegrees
            #expect(absAngularDifference(lhs, rhs) < 1e-9)
        }
        #expect(absAngularDifference(forward.snapshot.angles.ascendantDegrees, reverse.snapshot.angles.ascendantDegrees) < 1e-9)
        #expect(absAngularDifference(forward.snapshot.angles.midheavenDegrees, reverse.snapshot.angles.midheavenDegrees) < 1e-9)
    }

    @Test("Davison midpoint charts are participant-order invariant")
    func davisonSymmetry() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let forward = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .davison, first: firstPerson, second: secondPerson, preset: .modern)
        )
        let reverse = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .davison, first: secondPerson, second: firstPerson, preset: .modern)
        )
        #expect(forward.snapshot == reverse.snapshot)
    }

    @Test("Davison recalculates a physical chart from midpoint birth data")
    func davisonMidpointInput() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let result = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .davison, first: firstPerson, second: secondPerson, preset: .modern)
        )
        let expectedDate = firstPerson.birthDate.addingTimeInterval(
            secondPerson.birthDate.timeIntervalSince(firstPerson.birthDate) / 2
        )
        let expectedLocation = GeographicLocation(
            latitudeDegrees: 19.378701860433612,
            longitudeDegrees: 119.82019121383803
        )

        #expect(abs(result.snapshot.utcDate.timeIntervalSince(expectedDate)) < 0.001)
        #expect(abs(result.snapshot.location.latitudeDegrees - expectedLocation.latitudeDegrees) < 1e-9)
        #expect(absAngularDifference(result.snapshot.location.longitudeDegrees, expectedLocation.longitudeDegrees) < 1e-9)
        #expect(result.metadata.basis == .timeSpaceMidpoint)
        #expect(result.metadata.midpointAlgorithm == .shortestDistance)
    }

    @Test("Marks A and B use distinct nested midpoint radices")
    func marksPerspectives() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let marksA = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .marksA, first: firstPerson, second: secondPerson, preset: .modern)
        )
        let marksB = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .marksB, first: firstPerson, second: secondPerson, preset: .modern)
        )

        let relationshipDate = firstPerson.birthDate.addingTimeInterval(
            secondPerson.birthDate.timeIntervalSince(firstPerson.birthDate) / 2
        )
        let expectedADate = firstPerson.birthDate.addingTimeInterval(
            relationshipDate.timeIntervalSince(firstPerson.birthDate) / 2
        )
        let expectedBDate = secondPerson.birthDate.addingTimeInterval(
            relationshipDate.timeIntervalSince(secondPerson.birthDate) / 2
        )

        #expect(abs(marksA.snapshot.utcDate.timeIntervalSince(expectedADate)) < 0.001)
        #expect(abs(marksB.snapshot.utcDate.timeIntervalSince(expectedBDate)) < 0.001)
        #expect(marksA.snapshot != marksB.snapshot)
        #expect(marksA.metadata.perspective == .first)
        #expect(marksB.metadata.perspective == .second)
        #expect(marksA.metadata.basis == .marks)
        #expect(marksB.metadata.basis == .marks)
    }

    @Test("Classical relationship base charts retain the supplied classical point set")
    func classicalBasePointSet() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let composite = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: firstPerson, second: secondPerson, preset: .classical)
        )
        let synastry = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .synastryA, first: firstPerson, second: secondPerson, preset: .classical)
        )
        let expected = RelationshipPresetConfiguration(preset: .classical, orbFamily: .a).pointIDs
        #expect(composite.snapshot.points.map(\.body) == expected)
        #expect(synastry.snapshot.points.map(\.body) == RelationshipPresetConfiguration(preset: .classical, orbFamily: .b).pointIDs)
        #expect(synastry.reference?.points.map(\.body) == RelationshipPresetConfiguration(preset: .classical, orbFamily: .b).pointIDs)
    }


    @Test("All timing relationship techniques require an explicit target date")
    func timingRequiresTargetDate() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let timingKinds: [RelationshipChartKind] = [
            .compositeTransit,
            .compositeSecondary,
            .compositeTertiary,
            .compositeSecondaryCompare,
            .compositeTertiaryCompare,
            .davisonTransit,
            .davisonSecondary,
            .davisonTertiary,
            .marksSecondary,
            .marksTertiary,
        ]
        for kind in timingKinds {
            await #expect(throws: RelationshipChartError.targetDateRequired(kind)) {
                try await calculator.calculateRelationshipChart(
                    RelationshipChartRequest(kind: kind, first: firstPerson, second: secondPerson, preset: .modern)
                )
            }
        }
    }

    @Test("Composite transit overlays a physical target-date sky on the natal composite")
    func compositeTransit() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        let currentLocation = GeographicLocation(latitudeDegrees: 51.5074, longitudeDegrees: -0.1278)
        let result = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .compositeTransit,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target,
                transitLocation: currentLocation
            )
        )
        #expect(result.snapshot.utcDate == target)
        #expect(result.snapshot.location == currentLocation)
        #expect(result.reference != nil)
        #expect(result.metadata.basis == .transit)
        #expect(result.metadata.targetDate == target)
        #expect(!result.comparisonAspects.isEmpty)
    }

    @Test("Composite secondary progresses both participants before taking the relationship midpoint")
    func compositeSecondaryProgression() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        let configuration = RelationshipPresetConfiguration(preset: .modern, orbFamily: .b)
        let firstProgressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: firstPerson.birthDate,
            targetDate: target
        )
        let secondProgressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: secondPerson.birthDate,
            targetDate: target
        )
        let firstProgressed = try await calculator.calculateSnapshot(
            NatalInput(utcDate: firstProgressedDate, location: firstPerson.location),
            configuration: configuration.chartConfiguration
        )
        let secondProgressed = try await calculator.calculateSnapshot(
            NatalInput(utcDate: secondProgressedDate, location: secondPerson.location),
            configuration: configuration.chartConfiguration
        )
        let result = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .compositeSecondary,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target
            )
        )
        let expectedSun = RelationshipMidpoint.shortestArcDegrees(
            try #require(firstProgressed.point(.sun)).longitudeDegrees,
            try #require(secondProgressed.point(.sun)).longitudeDegrees
        )
        #expect(absAngularDifference(try #require(result.snapshot.point(.sun)).longitudeDegrees, expectedSun) < 1e-9)
        #expect(result.reference == nil)
        #expect(result.metadata.basis == .progression)
        #expect(result.metadata.targetDate == target)
    }

    @Test("Composite compare techniques retain the natal composite as the inner reference")
    func compositeProgressionCompare() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        for kind in [RelationshipChartKind.compositeSecondaryCompare, .compositeTertiaryCompare] {
            let result = try await calculator.calculateRelationshipChart(
                RelationshipChartRequest(
                    kind: kind,
                    first: firstPerson,
                    second: secondPerson,
                    preset: .modern,
                    targetDate: target
                )
            )
            #expect(result.reference != nil)
            #expect(result.metadata.basis == .progression)
            #expect(result.metadata.targetDate == target)
            #expect(!result.comparisonAspects.isEmpty)
        }
    }

    @Test("Davison timing techniques honour their documented average midpoint default")
    func davisonTimingMidpoint() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        for kind in [RelationshipChartKind.davisonTransit, .davisonSecondary, .davisonTertiary] {
            let result = try await calculator.calculateRelationshipChart(
                RelationshipChartRequest(
                    kind: kind,
                    first: firstPerson,
                    second: secondPerson,
                    preset: .modern,
                    targetDate: target
                )
            )
            #expect(result.metadata.midpointAlgorithm == .average)
            #expect(result.metadata.targetDate == target)
        }
    }

    @Test("Marks progressions retain an explicit A/B perspective")
    func marksProgressions() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        for kind in [RelationshipChartKind.marksSecondary, .marksTertiary] {
            let firstResult = try await calculator.calculateRelationshipChart(
                RelationshipChartRequest(
                    kind: kind,
                    first: firstPerson,
                    second: secondPerson,
                    preset: .modern,
                    targetDate: target,
                    perspective: .first
                )
            )
            let secondResult = try await calculator.calculateRelationshipChart(
                RelationshipChartRequest(
                    kind: kind,
                    first: firstPerson,
                    second: secondPerson,
                    preset: .modern,
                    targetDate: target,
                    perspective: .second
                )
            )
            #expect(firstResult.metadata.perspective == .first)
            #expect(secondResult.metadata.perspective == .second)
            #expect(firstResult.snapshot != secondResult.snapshot)
            #expect(firstResult.metadata.midpointAlgorithm == .shortestDistance)
        }
    }

    @Test("Davison progressions equal a normal progression of the derived time-space radix")
    func davisonProgressionReferenceFormula() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        let algorithm = RelationshipMidpointAlgorithm.average
        let radixInput = RelationshipMidpoint.natalInput(
            firstPerson.natalInput,
            secondPerson.natalInput,
            algorithm: algorithm
        )
        let configuration = RelationshipPresetConfiguration(preset: .modern, orbFamily: .b)

        let secondaryDate = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: radixInput.utcDate,
            targetDate: target
        )
        let expectedSecondary = try await calculator.calculateSnapshot(
            NatalInput(utcDate: secondaryDate, location: radixInput.location),
            configuration: configuration.chartConfiguration
        )
        let actualSecondary = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .davisonSecondary,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target
            )
        )
        #expect(actualSecondary.snapshot == expectedSecondary)

        let tertiaryDate = SwissEphemerisCalculator.tertiaryProgressedDate(
            birthDate: radixInput.utcDate,
            targetDate: target
        )
        let expectedTertiary = try await calculator.calculateSnapshot(
            NatalInput(utcDate: tertiaryDate, location: radixInput.location),
            configuration: configuration.chartConfiguration
        )
        let actualTertiary = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .davisonTertiary,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target
            )
        )
        #expect(actualTertiary.snapshot == expectedTertiary)
    }

    @Test("Marks progressions equal a normal progression of the nested person-Davison radix")
    func marksProgressionReferenceFormula() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        let algorithm = RelationshipMidpointAlgorithm.shortestDistance
        let davisonInput = RelationshipMidpoint.natalInput(
            firstPerson.natalInput,
            secondPerson.natalInput,
            algorithm: algorithm
        )
        let marksAInput = RelationshipMidpoint.natalInput(
            firstPerson.natalInput,
            davisonInput,
            algorithm: algorithm
        )
        let configuration = RelationshipPresetConfiguration(preset: .modern, orbFamily: .b)

        let secondaryDate = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: marksAInput.utcDate,
            targetDate: target
        )
        let expectedSecondary = try await calculator.calculateSnapshot(
            NatalInput(utcDate: secondaryDate, location: marksAInput.location),
            configuration: configuration.chartConfiguration
        )
        let actualSecondary = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .marksSecondary,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target,
                perspective: .first
            )
        )
        #expect(actualSecondary.snapshot == expectedSecondary)

        let tertiaryDate = SwissEphemerisCalculator.tertiaryProgressedDate(
            birthDate: marksAInput.utcDate,
            targetDate: target
        )
        let expectedTertiary = try await calculator.calculateSnapshot(
            NatalInput(utcDate: tertiaryDate, location: marksAInput.location),
            configuration: configuration.chartConfiguration
        )
        let actualTertiary = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .marksTertiary,
                first: firstPerson,
                second: secondPerson,
                preset: .modern,
                targetDate: target,
                perspective: .first
            )
        )
        #expect(actualTertiary.snapshot == expectedTertiary)
    }

    @Test("All 16 supplied relationship subtypes produce renderer-ready artifacts in both presets")
    func allRelationshipKindsCalculate() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let target = Date(timeIntervalSince1970: 1_775_000_000)
        let targetKinds: Set<RelationshipChartKind> = [
            .compositeTransit,
            .compositeSecondary,
            .compositeTertiary,
            .compositeSecondaryCompare,
            .compositeTertiaryCompare,
            .davisonTransit,
            .davisonSecondary,
            .davisonTertiary,
            .marksSecondary,
            .marksTertiary,
        ]
        for preset in RelationshipPreset.allCases {
            for kind in RelationshipChartKind.allCases {
                let artifact = try await calculator.calculateRelationshipChart(
                    RelationshipChartRequest(
                        kind: kind,
                        first: firstPerson,
                        second: secondPerson,
                        preset: preset,
                        targetDate: targetKinds.contains(kind) ? target : nil,
                        transitLocation: GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503),
                        perspective: .first
                    )
                )
                #expect(artifact.kind == kind)
                #expect(!artifact.snapshot.points.isEmpty)
                #expect(artifact.snapshot.houses.count == 12)
                #expect(artifact.snapshot.points.map(\.body) == RelationshipPresetConfiguration(
                    preset: preset,
                    orbFamily: kind.orbFamily
                ).pointIDs)
            }
        }
    }


    @Test("Relationship point visibility follows the supplied modern/classical tables without changing public chart presets")
    func relationshipPresetPointVisibility() {
        let modernA = RelationshipPresetConfiguration(preset: .modern, orbFamily: .a)
        let modernB = RelationshipPresetConfiguration(preset: .modern, orbFamily: .b)
        let classicalA = RelationshipPresetConfiguration(preset: .classical, orbFamily: .a)
        let classicalB = RelationshipPresetConfiguration(preset: .classical, orbFamily: .b)

        #expect(modernA.pointIDs == CalculationPreset.modern.pointIDs + [.lilith, .partOfFortune, .juno])
        #expect(modernB.pointIDs == CalculationPreset.modern.pointIDs)
        #expect(classicalA.pointIDs == CalculationPreset.classical.pointIDs + [.partOfFortune])
        #expect(classicalB.pointIDs == CalculationPreset.classical.pointIDs + [.partOfFortune])
        #expect(modernA.documentedSupplementalPoints == ["lilith", "fortune", "juno"])
        #expect(modernB.documentedSupplementalPoints.isEmpty)
        #expect(classicalA.documentedSupplementalPoints == ["fortune"])
        #expect(classicalB.documentedSupplementalPoints == ["fortune"])

        #expect(CalculationPreset.modern.pointIDs == [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto, .trueNode])
        #expect(CalculationPreset.classical.pointIDs == [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .trueNode])
    }

    @Test("Relationship supplemental points match independent local Swiss Ephemeris references")
    func supplementalPointsMatchIndependentSwissReferences() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)

        let composite = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: firstPerson, second: secondPerson, preset: .modern)
        )
        #expect(absAngularDifference(try #require(composite.snapshot.point(.lilith)).longitudeDegrees, 187.77389617608486) < 2e-7)
        #expect(absAngularDifference(try #require(composite.snapshot.point(.juno)).longitudeDegrees, 306.76972589604435) < 2e-7)
        #expect(absAngularDifference(try #require(composite.snapshot.point(.partOfFortune)).longitudeDegrees, 18.696291513191227) < 2e-7)

        let davison = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .davison, first: firstPerson, second: secondPerson, preset: .modern)
        )
        #expect(absAngularDifference(try #require(davison.snapshot.point(.lilith)).longitudeDegrees, 187.63823633582174) < 2e-7)
        #expect(absAngularDifference(try #require(davison.snapshot.point(.juno)).longitudeDegrees, 184.31019514388143) < 2e-7)
        #expect(absAngularDifference(try #require(davison.snapshot.point(.partOfFortune)).longitudeDegrees, 312.40945883764385) < 2e-7)

        let marksA = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .marksA, first: firstPerson, second: secondPerson, preset: .modern)
        )
        #expect(absAngularDifference(try #require(marksA.snapshot.point(.lilith)).longitudeDegrees, 146.69545951317858) < 2e-7)
        #expect(absAngularDifference(try #require(marksA.snapshot.point(.juno)).longitudeDegrees, 35.75494805847472) < 2e-7)
        #expect(absAngularDifference(try #require(marksA.snapshot.point(.partOfFortune)).longitudeDegrees, 269.07638951719105) < 2e-7)

        let marksB = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .marksB, first: firstPerson, second: secondPerson, preset: .modern)
        )
        #expect(absAngularDifference(try #require(marksB.snapshot.point(.lilith)).longitudeDegrees, 228.8638048322223) < 2e-7)
        #expect(absAngularDifference(try #require(marksB.snapshot.point(.juno)).longitudeDegrees, 249.15478713609627) < 2e-7)
        #expect(absAngularDifference(try #require(marksB.snapshot.point(.partOfFortune)).longitudeDegrees, 135.24537005105134) < 2e-7)
    }

    @Test("Composite Part of Fortune is recalculated from composite Sun Moon and Ascendant")
    func compositePartOfFortuneUsesCompositeFormula() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let configuration = RelationshipPresetConfiguration(preset: .modern, orbFamily: .a)
        let first = RelationshipPersonInput(
            id: "fortune-first",
            birthDate: ISO8601DateFormatter().date(from: "2005-05-05T15:00:00Z")!,
            location: GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)
        )
        let second = RelationshipPersonInput(
            id: "fortune-second",
            birthDate: ISO8601DateFormatter().date(from: "2000-12-01T09:00:00Z")!,
            location: GeographicLocation(latitudeDegrees: 34.0522, longitudeDegrees: -118.2437)
        )
        let firstNatal = try await calculator.calculateSnapshot(
            first.natalInput,
            configuration: configuration.chartConfiguration
        )
        let secondNatal = try await calculator.calculateSnapshot(
            second.natalInput,
            configuration: configuration.chartConfiguration
        )
        let composite = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(kind: .composite, first: first, second: second, preset: .modern)
        )

        let sun = try #require(composite.snapshot.point(.sun)).longitudeDegrees
        let moon = try #require(composite.snapshot.point(.moon)).longitudeDegrees
        let fortune = try #require(composite.snapshot.point(.partOfFortune)).longitudeDegrees
        let sunHouse = houseNumber(containing: sun, houses: composite.snapshot.houses)
        let expected = RelationshipMidpoint.normalizedDegrees(
            (7 ... 12).contains(sunHouse)
                ? composite.snapshot.angles.ascendantDegrees + moon - sun
                : composite.snapshot.angles.ascendantDegrees + sun - moon
        )
        #expect(absAngularDifference(fortune, expected) < 1e-9)

        let midpointOfNatalFortunes = RelationshipMidpoint.shortestArcDegrees(
            try #require(firstNatal.point(.partOfFortune)).longitudeDegrees,
            try #require(secondNatal.point(.partOfFortune)).longitudeDegrees
        )
        #expect(absAngularDifference(fortune, midpointOfNatalFortunes) > 100)
    }

    @Test("Composite midpoint matches an independent local PySwissEphemeris reference fixture")
    func compositeIndependentReference() async throws {
        // Generated independently with local pyswisseph 2.10.03 using the
        // bundled Swiss Ephemeris files, then applying midpoint-method formulas
        // outside this Swift implementation. No network calculation is used.
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let result = try await calculator.calculateRelationshipChart(
            RelationshipChartRequest(
                kind: .composite,
                first: firstPerson,
                second: secondPerson,
                preset: .modern
            )
        )

        #expect(absAngularDifference(try #require(result.snapshot.point(.sun)).longitudeDegrees, 332.8378376986386) < 2e-7)
        #expect(absAngularDifference(try #require(result.snapshot.point(.moon)).longitudeDegrees, 271.05603629225186) < 2e-7)
        #expect(absAngularDifference(try #require(result.snapshot.point(.mercury)).longitudeDegrees, 320.21611639838653) < 2e-7)
        #expect(absAngularDifference(result.snapshot.angles.ascendantDegrees, 80.47809291957799) < 2e-7)
        #expect(absAngularDifference(result.snapshot.angles.midheavenDegrees, 344.4938172385559) < 2e-7)
        #expect(absAngularDifference(try #require(result.snapshot.houses.first(where: { $0.number == 1 })).cuspDegrees, 80.47809291957799) < 2e-7)
    }

    @Test("Arithmetic Davison midpoint keeps the documented coordinate-average semantics")
    func arithmeticDavisonMidpointReference() {
        let first = GeographicLocation(latitudeDegrees: 20, longitudeDegrees: 170)
        let second = GeographicLocation(latitudeDegrees: 40, longitudeDegrees: -170)
        let midpoint = RelationshipMidpoint.location(first, second, algorithm: .average)
        #expect(abs(midpoint.latitudeDegrees - 30) < 1e-12)
        #expect(abs(midpoint.longitudeDegrees - 0) < 1e-12)
    }

    @Test("All relationship techniques match independent local PySwissEphemeris fixtures")
    func allRelationshipKindsMatchIndependentReference() async throws {
        let fixtureURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/relationship-pyswisseph-reference.json")
        let fixtures = try JSONDecoder().decode(
            [RelationshipReferenceFixture].self,
            from: Data(contentsOf: fixtureURL)
        )
        #expect(fixtures.count == 36)

        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let targetDate = Date(timeIntervalSince1970: 1_775_000_000)
        let targetKinds: Set<RelationshipChartKind> = [
            .compositeTransit, .compositeSecondary, .compositeTertiary,
            .compositeSecondaryCompare, .compositeTertiaryCompare,
            .davisonTransit, .davisonSecondary, .davisonTertiary,
            .marksSecondary, .marksTertiary,
        ]
        let transitLocation = GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)

        for fixture in fixtures {
            let kind = try #require(RelationshipChartKind(rawValue: fixture.kind))
            let preset = try #require(RelationshipPreset(rawValue: fixture.preset))
            let perspective = fixture.perspective.flatMap(RelationshipPerspective.init(rawValue:))
            let artifact = try await calculator.calculateRelationshipChart(
                RelationshipChartRequest(
                    kind: kind,
                    first: firstPerson,
                    second: secondPerson,
                    preset: preset,
                    targetDate: targetKinds.contains(kind) ? targetDate : nil,
                    transitLocation: transitLocation,
                    perspective: perspective
                )
            )

            #expect(abs(artifact.snapshot.utcDate.timeIntervalSince1970 - fixture.snapshotDate) < 2e-5)
            #expect(abs(artifact.snapshot.location.latitudeDegrees - fixture.lat) < 2e-7)
            #expect(absAngularDifference(artifact.snapshot.location.longitudeDegrees, fixture.lon) < 2e-7)
            #expect(absAngularDifference(artifact.snapshot.angles.ascendantDegrees, fixture.asc) < 2e-7)
            #expect(absAngularDifference(artifact.snapshot.angles.midheavenDegrees, fixture.mc) < 2e-7)
            let house1 = try #require(artifact.snapshot.houses.first(where: { $0.number == 1 }))
            #expect(absAngularDifference(house1.cuspDegrees, fixture.house1) < 2e-7)
            #expect(absAngularDifference(try #require(artifact.snapshot.point(.sun)).longitudeDegrees, fixture.sun) < 2e-7)
            #expect(absAngularDifference(try #require(artifact.snapshot.point(.moon)).longitudeDegrees, fixture.moon) < 2e-7)
            #expect(absAngularDifference(try #require(artifact.snapshot.point(.mercury)).longitudeDegrees, fixture.mercury) < 2e-7)

            if let expectedReferenceSun = fixture.referenceSun {
                let reference = try #require(artifact.reference)
                #expect(absAngularDifference(try #require(reference.point(.sun)).longitudeDegrees, expectedReferenceSun) < 2e-7)
                let expectedReferenceAsc = try #require(fixture.referenceAsc)
                #expect(absAngularDifference(reference.angles.ascendantDegrees, expectedReferenceAsc) < 2e-7)
            } else {
                #expect(artifact.reference == nil)
            }
        }
    }

    private struct RelationshipReferenceFixture: Decodable {
        let kind: String
        let preset: String
        let perspective: String?
        let snapshotDate: Double
        let lat: Double
        let lon: Double
        let asc: Double
        let mc: Double
        let house1: Double
        let sun: Double
        let moon: Double
        let mercury: Double
        let referenceSun: Double?
        let referenceAsc: Double?
    }

    private var firstPerson: RelationshipPersonInput {
        RelationshipPersonInput(
            id: "first",
            birthDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)
        )
    }

    private var secondPerson: RelationshipPersonInput {
        RelationshipPersonInput(
            id: "second",
            birthDate: Date(timeIntervalSince1970: 951_899_400),
            location: GeographicLocation(latitudeDegrees: 1.3521, longitudeDegrees: 103.8198)
        )
    }

    private func houseNumber(containing longitude: Double, houses: [ChartHouse]) -> Int {
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

    private func absAngularDifference(_ lhs: Double, _ rhs: Double) -> Double {
        let raw = abs(RelationshipMidpoint.normalizedDegrees(lhs) - RelationshipMidpoint.normalizedDegrees(rhs))
        return min(raw, 360 - raw)
    }

    private var ephemerisDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }

}
