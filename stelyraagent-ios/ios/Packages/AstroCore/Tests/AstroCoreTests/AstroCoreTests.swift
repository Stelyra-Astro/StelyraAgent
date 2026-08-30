import AstroCore
import Foundation
import Testing

@Suite("Swiss Ephemeris bridge")
struct AstroCoreTests {
    @Test("Beijing reference matches the Python core")
    func beijingReference() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 951_899_400),
            location: GeographicLocation(latitudeDegrees: 39.93, longitudeDegrees: 116.41)
        )

        let result = try await calculator.calculateNatal(input)

        #expect(abs(result.julianDayUT - 2_451_604.8541666665) < 1e-9)
        #expect(abs(result.sun.longitudeDegrees - 341.063363658783) < 1e-9)
        #expect(abs(result.moon.longitudeDegrees - 285.659216345170) < 1e-9)
        #expect(abs(result.angles.ascendantDegrees - 142.945380617135) < 1e-9)
        #expect(abs(result.angles.midheavenDegrees - 45.828150425796) < 1e-9)
    }

    @Test("Invalid coordinates are rejected")
    func invalidCoordinates() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 951_899_400),
            location: GeographicLocation(latitudeDegrees: 91, longitudeDegrees: 116.41)
        )

        await #expect(throws: AstroCoreError.invalidLatitude(91)) {
            try await calculator.calculateNatal(input)
        }
    }

    @Test("Snapshot presets share one deterministic chart model")
    func snapshotPresets() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )

        let modern = try await calculator.calculateSnapshot(input, preset: .modern)
        let classical = try await calculator.calculateSnapshot(input, preset: .classical)
        let special = try await calculator.calculateSnapshot(input, preset: .special)

        #expect(modern.points.count == 11)
        #expect(classical.points.count == 8)
        #expect(special.points.count == 8)
        #expect(modern.houses.count == 12)
        #expect(classical.houses.count == 12)
        #expect(special.houses.count == 12)
        #expect(modern.point(.sun) != nil)
        #expect(modern.house(containing: modern.point(.moon)?.longitudeDegrees ?? 0) > 0)
    }

    @Test("Secondary progression uses one ephemeris day per tropical year")
    func secondaryProgressedDate() {
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let target = birth.addingTimeInterval(30 * 365.2425 * 86_400)
        let progressed = SwissEphemerisCalculator.secondaryProgressedDate(
            birthDate: birth,
            targetDate: target
        )

        #expect(abs(progressed.timeIntervalSince(birth) - 30 * 86_400) < 0.001)
        let mappedTarget = SwissEphemerisCalculator.secondaryTargetDate(
            birthDate: birth,
            progressedDate: progressed
        )
        #expect(abs(mappedTarget.timeIntervalSince(target)) < 0.001)
    }

    @Test("Cross-chart comparison returns only aspects inside the requested orb")
    func comparisonOrb() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: Date(timeIntervalSince1970: 824_259_600), location: location)
        )
        let moving = try await calculator.calculateSnapshot(
            NatalInput(utcDate: Date(timeIntervalSince1970: 1_775_000_000), location: location)
        )

        let aspects = SwissEphemerisCalculator.compare(
            moving: moving,
            reference: natal,
            orbDegrees: 2
        )

        #expect(aspects.allSatisfy { $0.orbDegrees <= 2.000_000_1 })
        #expect(aspects == aspects.sorted { $0.strength > $1.strength })
    }

    @Test("Representative charts remain valid across regions and eras")
    func representativeCharts() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let examples = [
            (
                Date(timeIntervalSince1970: 824_259_600),
                GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            (
                Date(timeIntervalSince1970: 315_532_800),
                GeographicLocation(latitudeDegrees: 51.5074, longitudeDegrees: -0.1278)
            ),
            (
                Date(timeIntervalSince1970: 1_104_537_600),
                GeographicLocation(latitudeDegrees: 40.7128, longitudeDegrees: -74.0060)
            ),
            (
                Date(timeIntervalSince1970: 1_577_880_000),
                GeographicLocation(latitudeDegrees: -33.8688, longitudeDegrees: 151.2093)
            ),
            (
                Date(timeIntervalSince1970: 946_684_800),
                GeographicLocation(latitudeDegrees: 35.6762, longitudeDegrees: 139.6503)
            ),
            (
                Date(timeIntervalSince1970: -157_766_400),
                GeographicLocation(latitudeDegrees: -23.5505, longitudeDegrees: -46.6333)
            ),
            (
                Date(timeIntervalSince1970: 1_893_456_000),
                GeographicLocation(latitudeDegrees: 64.1466, longitudeDegrees: -21.9426)
            ),
            (
                Date(timeIntervalSince1970: -946_771_200),
                GeographicLocation(latitudeDegrees: -33.9249, longitudeDegrees: 18.4241)
            ),
        ]

        for (date, location) in examples {
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: date, location: location),
                preset: .modern
            )

            #expect(snapshot.points.count == 11)
            #expect(snapshot.houses.count == 12)
            #expect(snapshot.points.allSatisfy { (0 ..< 360).contains($0.longitudeDegrees) })
            #expect(snapshot.houses.allSatisfy { (0 ..< 360).contains($0.cuspDegrees) })
            #expect((0 ..< 360).contains(snapshot.angles.ascendantDegrees))
            #expect((0 ..< 360).contains(snapshot.angles.midheavenDegrees))
        }
    }

    @Test("Aspect event interpolation handles angular wraparound")
    func aspectEventInterpolation() {
        let conjunction = AspectEventInterpolation.exactCrossingFraction(
            from: -0.25,
            to: 0.75,
            aspectAngleDegrees: 0
        )
        let opposition = AspectEventInterpolation.exactCrossingFraction(
            from: 179.5,
            to: -179.5,
            aspectAngleDegrees: 180
        )
        let noCrossing = AspectEventInterpolation.exactCrossingFraction(
            from: 40,
            to: 42,
            aspectAngleDegrees: 60
        )

        #expect(abs((conjunction ?? -1) - 0.25) < 0.000_001)
        #expect(abs((opposition ?? -1) - 0.5) < 0.000_001)
        #expect(noCrossing == nil)
    }

    @Test("Local calendar days preserve daylight-saving boundaries")
    func localCalendarDayDST() throws {
        let timeZone = try #require(TimeZone(identifier: "America/New_York"))
        let spring = LocalCalendarDay.interval(
            containing: Date(timeIntervalSince1970: 1_710_072_000),
            timeZone: timeZone
        )
        let autumn = LocalCalendarDay.interval(
            containing: Date(timeIntervalSince1970: 1_730_635_200),
            timeZone: timeZone
        )

        #expect(spring.duration == 23 * 3_600)
        #expect(autumn.duration == 25 * 3_600)
    }

    @Test("Horary charts use Regiomontanus and the traditional seven planets")
    func horarySnapshotAndAnalysis() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 40.7128, longitudeDegrees: -74.006)
            ),
            configuration: .horary
        )

        #expect(snapshot.points.map(\.body) == HoraryEngine.traditionalPlanets)
        #expect(snapshot.houses.count == 12)
        let analysis = HoraryEngine.analyze(snapshot: snapshot, targetHouse: 10)
        #expect((0 ... 100).contains(analysis.score))
        #expect(analysis.querentHouse == 1)
        #expect(analysis.targetHouse == 10)
        #expect(!analysis.components.isEmpty)
        #expect(analysis.moon.isVoidOfCourse == (analysis.moon.nextAspect == nil))
    }

    @Test("Traditional rulers and choice support are deterministic")
    func rulersAndChoiceSupport() async throws {
        let expected: [CelestialBody] = [
            .mars, .venus, .mercury, .moon, .sun, .mercury,
            .venus, .mars, .jupiter, .saturn, .saturn, .jupiter,
        ]
        #expect((0 ..< 12).map(HoraryEngine.ruler(ofSign:)) == expected)

        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let choices = HoraryEngine.analyzeChoices(
            snapshot: snapshot,
            candidates: [
                HoraryChoiceCandidate(label: "A", house: 4),
                HoraryChoiceCandidate(label: "B", house: 7),
                HoraryChoiceCandidate(label: "C", house: 10),
            ]
        )

        #expect(choices.count == 3)
        #expect(choices.allSatisfy { (0 ... 100).contains($0.supportScore) })
        #expect(choices == choices.sorted { $0.supportScore > $1.supportScore })
    }

    @Test("Same-area choices receive distinct sect-aware triplicity rulers")
    func sameAreaChoiceRulers() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let original = [
            HoraryChoiceCandidate(label: "A", house: 10, relatedHouses: [2, 9]),
            HoraryChoiceCandidate(label: "B", house: 10, relatedHouses: [2]),
            HoraryChoiceCandidate(label: "C", house: 10),
        ]
        let results = HoraryEngine.analyzeChoices(
            snapshot: snapshot,
            candidates: original.enumerated().map {
                HoraryChoiceCandidate(
                    id: $0.element.id,
                    label: $0.element.label,
                    house: $0.element.house,
                    relatedHouses: $0.element.relatedHouses,
                    originalIndex: $0.offset
                )
            },
            mode: .sharedPrimary(house: 10)
        )
        let byID = Dictionary(uniqueKeysWithValues: results.map { ($0.id, $0) })
        let cusp = try #require(snapshot.houses.first { $0.number == 10 })
        let sign = Int(cusp.cuspDegrees / 30)
        let expected = HoraryEngine.triplicityRulers(
            ofSign: sign,
            isDayChart: HoraryEngine.isDayChart(snapshot)
        )

        #expect(original.enumerated().allSatisfy { byID[$0.element.id]?.ruler == expected[$0.offset] })
        #expect(byID[original[0].id]?.relatedHouses == [2, 9])
        #expect(Set(results.map(\.ruler)).count == 3)
    }

    @Test("Independent repeated areas keep their house ruler")
    func independentRepeatedAreas() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let expected = HoraryEngine.ruler(ofHouse: 10, in: snapshot)
        let results = HoraryEngine.analyzeChoices(
            snapshot: snapshot,
            candidates: [
                HoraryChoiceCandidate(label: "A", house: 10, originalIndex: 0),
                HoraryChoiceCandidate(label: "B", house: 10, originalIndex: 1),
                HoraryChoiceCandidate(label: "C", house: 9, originalIndex: 2),
            ],
            mode: .independentPrimary
        )

        #expect(results.filter { $0.house == 10 }.allSatisfy { $0.ruler == expected })
    }

    @Test("Horary judgment resolves bounded ephemeris evidence")
    func horaryJudgmentEvidence() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let analysis = try await HoraryEngine.judgedAnalysis(
            snapshot: snapshot,
            targetHouse: 10,
            calculator: calculator
        )
        let judgment = try #require(analysis.judgment)

        #expect((0 ... 100).contains(analysis.score))
        if let path = judgment.perfection.primaryPath {
            #expect(path.exactDate >= snapshot.utcDate)
            #expect(judgment.perfection.interruptions.allSatisfy { $0.date <= path.exactDate })
        }

        let choices = try await HoraryEngine.judgedChoices(
            snapshot: snapshot,
            candidates: [
                HoraryChoiceCandidate(label: "A", house: 10, originalIndex: 0),
                HoraryChoiceCandidate(label: "B", house: 10, originalIndex: 1),
                HoraryChoiceCandidate(label: "C", house: 10, originalIndex: 2),
            ],
            mode: .sharedPrimary(house: 10),
            calculator: calculator
        )
        #expect(Set(choices.map(\.originalIndex)) == Set([0, 1, 2]))
        #expect(choices.allSatisfy { $0.analysis.judgment != nil })
        #expect(choices.allSatisfy { (0 ... 100).contains($0.supportScore) })
    }

    @Test("Election timing returns ranked non-overlapping days")
    func electionTimingSearch() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let start = Date(timeIntervalSince1970: 1_775_000_000)
        let request = ElectionTimingRequest(
            targetHouse: 10,
            startDate: start,
            endDate: start.addingTimeInterval(3 * 86_400),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073),
            timeZone: try #require(TimeZone(identifier: "Asia/Shanghai")),
            precision: .day
        )

        let candidates = try await ElectionTimingEngine(calculator: calculator).search(request)
        #expect(candidates.count == 3)
        #expect(candidates == candidates.sorted { $0.score > $1.score })
        #expect(candidates.allSatisfy { (0 ... 100).contains($0.score) })
        for index in candidates.indices {
            for otherIndex in candidates.indices where otherIndex > index {
                let overlap = candidates[index].interval
                    .intersection(with: candidates[otherIndex].interval)
                #expect(overlap == nil || overlap?.duration == 0)
            }
        }
    }

    @Test("Election timing enforces the precision range cap")
    func electionTimingRangeCap() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let start = Date(timeIntervalSince1970: 1_775_000_000)
        let request = ElectionTimingRequest(
            targetHouse: 10,
            startDate: start,
            endDate: start.addingTimeInterval(92 * 86_400),
            location: GeographicLocation(latitudeDegrees: 0, longitudeDegrees: 0),
            timeZone: .gmt,
            precision: .day
        )

        await #expect(throws: ElectionTimingError.rangeTooLong) {
            try await ElectionTimingEngine(calculator: calculator).search(request)
        }
    }


    @Test("Solar return moment matches the natal Sun and repeats yearly")
    func solarReturnMomentsAndSnapshot() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: birth, location: location)
        )
        let natalSun = try #require(natal.point(.sun)).longitudeDegrees

        var anchor = birth.addingTimeInterval(30 * 365.2425 * 86_400)
        var previousMoment: Date?
        for _ in 0 ..< 3 {
            let moment = try await calculator.solarReturnMoment(birthDate: birth, after: anchor)
            let snapshot = try await calculator.calculateSolarReturn(
                birthDate: birth,
                after: anchor,
                location: location
            )
            // The return snapshot's Sun sits exactly on the natal Sun longitude.
            #expect(abs(try #require(snapshot.point(.sun)).longitudeDegrees - natalSun) < 1e-6)
            #expect(moment >= anchor)
            if let previousMoment {
                // Return moments recur once per tropical year.
                let gap = abs(moment.timeIntervalSince(previousMoment) - 365.242_189 * 86_400)
                #expect(gap < 12 * 3_600)
            }
            previousMoment = moment
            anchor = moment.addingTimeInterval(86_400)
        }
    }

    @Test("Solar return honours the selected consumer preset")
    func solarReturnPresets() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let natalSun = try #require(
            try await calculator.calculateSnapshot(NatalInput(utcDate: birth, location: location)).point(.sun)
        ).longitudeDegrees

        let modern = try await calculator.calculateSolarReturn(
            birthDate: birth,
            after: birth.addingTimeInterval(30 * 365.2425 * 86_400),
            location: location,
            preset: .modern
        )
        let classical = try await calculator.calculateSolarReturn(
            birthDate: birth,
            after: birth.addingTimeInterval(30 * 365.2425 * 86_400),
            location: location,
            preset: .classical
        )

        #expect(modern.points.count == 11)
        #expect(classical.points.count == 8)
        #expect(abs(try #require(modern.point(.sun)).longitudeDegrees - natalSun) < 1e-6)
        #expect(abs(try #require(classical.point(.sun)).longitudeDegrees - natalSun) < 1e-6)
    }

    @Test("Synastry compares two natal charts deterministically")
    func synastryComparison() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let first = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )
        let second = NatalInput(
            utcDate: Date(timeIntervalSince1970: 818_035_200),
            location: GeographicLocation(latitudeDegrees: 47.34, longitudeDegrees: 123.97)
        )

        let modern = try await calculator.calculateSynastry(first: first, second: second, preset: .modern)
        #expect(modern.first.points.count == 11)
        #expect(modern.second.points.count == 11)
        #expect(modern.crossAspects.allSatisfy { $0.orbDegrees <= 3.000_000_1 })
        #expect(modern.crossAspects == modern.crossAspects.sorted { $0.strength > $1.strength })

        // Direct comparison agrees with the synastry helper's cross aspects
        // when both use the same B-family orb profile.
        let direct = SwissEphemerisCalculator.compare(
            moving: modern.first,
            reference: modern.second,
            orbsByKind: ChartOrbProfile.comparisonB
        )
        #expect(modern.crossAspects == direct)

        let classical = try await calculator.calculateSynastry(first: first, second: second, preset: .classical)
        #expect(classical.first.points.count == 7)
        #expect(classical.second.points.count == 7)
        #expect(classical.first.point(.trueNode) == nil)
        #expect(classical.second.point(.trueNode) == nil)
        #expect(classical.first.aspects.allSatisfy { $0.firstID != "trueNode" && $0.secondID != "trueNode" })
        #expect(classical.second.aspects.allSatisfy { $0.firstID != "trueNode" && $0.secondID != "trueNode" })
        #expect(classical.crossAspects.allSatisfy { $0.firstID != "trueNode" && $0.secondID != "trueNode" })
        // Same preset is used for both sides of the comparison.
        #expect(classical.first.points.map(\.body) == classical.second.points.map(\.body))

        let assessment = try #require(classical.classicalAssessment)
        #expect(assessment.firstPlanets.map(\.body) == ClassicalSynastryMVPCapability.traditionalBodies)
        #expect(assessment.secondPlanets.map(\.body) == ClassicalSynastryMVPCapability.traditionalBodies)
        #expect(assessment.crossChartReceptions.count == classical.crossAspects.count)
        #expect(assessment.crossChartReceptions.contains {
            $0.receptionFromFirst.isPresent || $0.receptionFromSecond.isPresent
        })
        for reception in assessment.crossChartReceptions {
            #expect(reception.receptionFromFirst == HoraryEngine.reception(
                from: reception.firstBody,
                to: reception.secondBody,
                in: classical.first
            ))
            #expect(reception.receptionFromSecond == HoraryEngine.reception(
                from: reception.secondBody,
                to: reception.firstBody,
                in: classical.second
            ))
        }

        let repeated = try await calculator.calculateSynastry(first: first, second: second, preset: .classical)
        #expect(repeated == classical)
    }


    @Test("Solar return uses the Obsidian A-family and starlight orb profiles")
    func solarReturnOrbProfiles() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let anchor = birth.addingTimeInterval(30 * 365.2425 * 86_400)

        let modern = try await calculator.calculateSolarReturn(
            birthDate: birth, after: anchor, location: location, preset: .modern
        )
        for aspect in modern.aspects {
            let limit = aspect.kind == .conjunction ? 7.0 : 6.0
            #expect(aspect.orbDegrees <= limit + 0.000_001)
        }

        let classical = try await calculator.calculateSolarReturn(
            birthDate: birth, after: anchor, location: location, preset: .classical
        )
        let starlight = ChartOrbProfile.classicalStarlight
        for aspect in classical.aspects {
            let firstOrb = starlight[CelestialBody(rawValue: aspect.firstID) ?? .sun] ?? 5
            let secondOrb = starlight[CelestialBody(rawValue: aspect.secondID) ?? .sun] ?? 5
            #expect(aspect.orbDegrees <= min(firstOrb, secondOrb) + 0.000_001)
        }
    }

    @Test("Solar return to natal comparison uses tight B-family orbs")
    func solarReturnNatalOrbs() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let location = GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        let natal = try await calculator.calculateSnapshot(NatalInput(utcDate: birth, location: location))
        let solarReturn = try await calculator.calculateSolarReturn(
            birthDate: birth,
            after: birth.addingTimeInterval(30 * 365.2425 * 86_400),
            location: location
        )
        let aspects = SwissEphemerisCalculator.solarReturnNatalAspects(
            solarReturn: solarReturn,
            natal: natal
        )
        for aspect in aspects {
            let limit = aspect.kind == .conjunction ? 2.0 : 1.0
            #expect(aspect.orbDegrees <= limit + 0.000_001)
        }
    }

    @Test("Synastry uses B-family for modern and starlight for classical")
    func synastryOrbProfiles() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let first = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )
        let second = NatalInput(
            utcDate: Date(timeIntervalSince1970: 818_035_200),
            location: GeographicLocation(latitudeDegrees: 47.34, longitudeDegrees: 123.97)
        )

        let modern = try await calculator.calculateSynastry(first: first, second: second, preset: .modern)
        for aspect in modern.crossAspects {
            let limit = aspect.kind == .conjunction ? 2.0 : 1.0
            #expect(aspect.orbDegrees <= limit + 0.000_001)
        }

        let classical = try await calculator.calculateSynastry(first: first, second: second, preset: .classical)
        let starlight = ChartOrbProfile.classicalStarlight
        for aspect in classical.crossAspects {
            let firstOrb = starlight[CelestialBody(rawValue: aspect.firstID) ?? .sun] ?? 5
            let secondOrb = starlight[CelestialBody(rawValue: aspect.secondID) ?? .sun] ?? 5
            #expect(aspect.orbDegrees <= min(firstOrb, secondOrb) + 0.000_001)
        }
    }
    @Test("Named elements of a question are assessed by their house rulers")
    func significatorAssessment() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let input = NatalInput(
            utcDate: Date(timeIntervalSince1970: 1_775_000_000),
            location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
        )
        let snapshot = try await calculator.calculateSnapshot(input, configuration: .horary)

        let elements = [
            HorarySignificator(label: "我", house: 1),
            HorarySignificator(label: "吃饭", house: 5),
            HorarySignificator(label: "家", house: 4),
            HorarySignificator(label: "单位", house: 6),
        ]
        let assessments = HoraryEngine.assessSignificators(elements, snapshot: snapshot)

        #expect(assessments.count == 4)
        for assessment in assessments {
            #expect((1 ... 12).contains(assessment.house))
            #expect(assessment.score.isFinite)
            if let relationship = assessment.relationship {
                #expect([assessment.ruler.id, HoraryEngine.ruler(ofHouse: 1, in: snapshot).id].contains(relationship.firstID))
            }
        }
        // The querent element is always assessed against house 1.
        #expect(assessments[0].house == 1)
        #expect(assessments[0].ruler == HoraryEngine.ruler(ofHouse: 1, in: snapshot))
    }

    @Test("Event search finds the next Moon sign ingress and exact aspect")
    func eventSearchIngressAndExact() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let anchor = Date(timeIntervalSince1970: 1_775_000_000)
        let ingress = try await calculator.nextSignIngress(for: .moon, after: anchor)
        #expect(ingress > anchor)
        let atIngress = try await calculator.calculateSnapshot(
            NatalInput(utcDate: ingress, location: GeographicLocation(latitudeDegrees: 0, longitudeDegrees: 0)),
            preset: .modern
        )
        guard let moon = atIngress.point(.moon) else { return }
        // The Moon sits on a sign boundary at the ingress moment.
        #expect(abs(moon.longitudeDegrees.truncatingRemainder(dividingBy: 30)) < 0.01)

        let exact = try await calculator.nextSkyExactDate(moving: .moon, reference: .sun, kind: .conjunction, after: anchor)
        #expect(exact > anchor)
        let sky = try await calculator.calculateSnapshot(
            NatalInput(utcDate: exact, location: GeographicLocation(latitudeDegrees: 0, longitudeDegrees: 0)),
            preset: .modern
        )
        guard let moon2 = sky.point(.moon), let sun = sky.point(.sun) else { return }
        let sep = abs(moon2.longitudeDegrees - sun.longitudeDegrees).truncatingRemainder(dividingBy: 360)
        let diff = min(sep, 360 - sep)
        #expect(diff < 0.02)
    }

    @Test("Station search finds a real longitude-speed sign change")
    func stationSearch() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let anchor = Date(timeIntervalSince1970: 1_775_000_000)
        let station = try await calculator.nextStation(for: .mercury, after: anchor)
        #expect(station.date > anchor)

        let location = GeographicLocation(latitudeDegrees: 0, longitudeDegrees: 0)
        let before = try await calculator.calculateSnapshot(
            NatalInput(utcDate: station.date.addingTimeInterval(-3_600), location: location),
            preset: .modern
        )
        let after = try await calculator.calculateSnapshot(
            NatalInput(utcDate: station.date.addingTimeInterval(3_600), location: location),
            preset: .modern
        )
        let beforeSpeed = try #require(before.point(.mercury)?.position.longitudeSpeedDegreesPerDay)
        let afterSpeed = try #require(after.point(.mercury)?.position.longitudeSpeedDegreesPerDay)
        #expect((beforeSpeed < 0) != (afterSpeed < 0))
        #expect(station.retrogradeAfter == (afterSpeed < 0))
    }

    @Test("Progressed Moon ingress maps back to the real-world progression axis")
    func progressedMoonWindow() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let birth = Date(timeIntervalSince1970: 824_259_600)
        let target = Date()
        let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(birthDate: birth, targetDate: target)
        let window = try await calculator.progressionWindow(moving: .moon, at: progressedDate, signLabel: "")
        #expect(window.ingressDate > progressedDate)
        #expect(window.daysInSign > 0)
        #expect(window.daysInSign < 365 * 4)
        let targetIngress = SwissEphemerisCalculator.secondaryTargetDate(
            birthDate: birth,
            progressedDate: window.ingressDate
        )
        #expect(targetIngress > target)
        #expect(targetIngress.timeIntervalSince(target) < 4 * 365.2425 * 86_400)
    }

    @Test("Lunar phase is location independent at the same UTC moment")
    func lunarPhaseLocationIndependence() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let moment = try #require(ISO8601DateFormatter().date(from: "2026-08-13T13:20:54Z"))
        let beijing = try await calculator.calculateSnapshot(
            NatalInput(utcDate: moment, location: GeographicLocation(latitudeDegrees: 39.9042, longitudeDegrees: 116.4074)),
            preset: .modern
        )
        let paris = try await calculator.calculateSnapshot(
            NatalInput(utcDate: moment, location: GeographicLocation(latitudeDegrees: 48.8566, longitudeDegrees: 2.3522)),
            preset: .modern
        )
        let beijingSun = try #require(beijing.point(.sun)?.longitudeDegrees)
        let beijingMoon = try #require(beijing.point(.moon)?.longitudeDegrees)
        let parisSun = try #require(paris.point(.sun)?.longitudeDegrees)
        let parisMoon = try #require(paris.point(.moon)?.longitudeDegrees)
        let beijingElongation = (beijingMoon - beijingSun + 360).truncatingRemainder(dividingBy: 360)
        let parisElongation = (parisMoon - parisSun + 360).truncatingRemainder(dividingBy: 360)
        let illumination = (1 - cos(beijingElongation * .pi / 180)) / 2

        #expect(abs(beijingElongation - parisElongation) < 0.000_001)
        #expect(Int((illumination * 100).rounded()) == 1)
    }

    private var ephemerisDirectory: URL {
        var url = URL(fileURLWithPath: #filePath)
        for _ in 0 ..< 6 {
            url.deleteLastPathComponent()
        }
        return url.appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }

    @Test("Horary deterministic result types round-trip through JSON")
    func horaryResultCodableRoundTrip() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let snapshot = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: Date(timeIntervalSince1970: 1_775_000_000),
                location: GeographicLocation(latitudeDegrees: 35.0263, longitudeDegrees: 111.0073)
            ),
            configuration: .horary
        )
        let analysis = HoraryEngine.analyze(snapshot: snapshot, targetHouse: 10)
        let choice = try #require(HoraryEngine.analyzeChoices(
            snapshot: snapshot,
            candidates: [HoraryChoiceCandidate(label: "A", house: 10)]
        ).first)
        let timing = ElectionTimingCandidate(
            id: "sample-window",
            interval: DateInterval(start: snapshot.utcDate, duration: 86_400),
            peakDate: snapshot.utcDate.addingTimeInterval(43_200),
            score: analysis.score,
            snapshot: snapshot,
            analysis: analysis
        )
        let significator = try #require(HoraryEngine.assessSignificators(
            [HorarySignificator(label: "work", house: 10)],
            snapshot: snapshot
        ).first)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let decodedAnalysis = try decoder.decode(HoraryAnalysis.self, from: encoder.encode(analysis))
        let decodedChoice = try decoder.decode(HoraryChoiceResult.self, from: encoder.encode(choice))
        let decodedTiming = try decoder.decode(ElectionTimingCandidate.self, from: encoder.encode(timing))
        let decodedSignificator = try decoder.decode(HorarySignificatorAssessment.self, from: encoder.encode(significator))

        #expect(decodedAnalysis == analysis)
        #expect(decodedChoice == choice)
        #expect(decodedTiming == timing)
        #expect(decodedSignificator == significator)
    }

}
