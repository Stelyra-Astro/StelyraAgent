import AstroCore
import CoreGraphics
import XCTest
@testable import StelyraAgent

final class TransitContentPlannerTests: XCTestCase {
    func testChartRequestBodyOnlyContainsProviderSafeContextAndCalculatedFacts() throws {
        let service = AppAIReportService()
        let rawParams = [
            "place": "Paris, France",
            "timezone": "Europe/Paris",
            "latitude": "48.856600",
            "longitude": "2.352200",
            "instant": "1992-05-14T06:20:00Z",
            "relationship": "friend",
        ]
        let body = service.chartRequestBody(
            chart: .natal,
            preset: .modern,
            primarySubjectHash: "profile-hash",
            params: rawParams,
            facts: [
                "params": rawParams,
                "person": ["name": "Nickname"],
                "chart": [
                    "utcDate": "1992-05-14T06:20:00Z",
                    "julianDay": 2_448_756.7639,
                    "points": [["body": "sun", "longitude": 53.4]],
                ],
                "evidenceFacts": [
                    ["id": "point.sun"],
                    ["id": "event.ingress", "date": "2026-09-01T10:00:00Z", "timeZone": "Europe/Paris"],
                ],
            ],
            semanticFingerprint: "semantic",
            factsHash: "facts",
            locale: "en",
            userID: UUID().uuidString.lowercased(),
            forceRegenerate: false
        )

        XCTAssertEqual(body["params"] as? [String: String], ["relationship": "friend"])
        let facts = try XCTUnwrap(body["facts"] as? [String: Any])
        XCTAssertEqual(facts["params"] as? [String: String], ["relationship": "friend"])
        let chart = try XCTUnwrap(facts["chart"] as? [String: Any])
        XCTAssertNil(chart["utcDate"])
        XCTAssertNil(chart["julianDay"])
        let points = try XCTUnwrap(chart["points"] as? [[String: Any]])
        XCTAssertEqual(points.first?["longitude"] as? Double, 53.4)
        let evidence = try XCTUnwrap(facts["evidenceFacts"] as? [[String: Any]])
        XCTAssertEqual(evidence.last?["date"] as? String, "2026-09-01T10:00:00Z")
        XCTAssertNil(evidence.last?["timeZone"])
    }

    func testSynastryUnobservedExactFactUsesReviewedBaseSelector() throws {
        let factID = "synastry.test.aspect.personA.jupiter.conjunction.personB.jupiter"
        let fact = SynastryFact.aspect(
            SynastryAspectFact(
                factID: factID,
                firstBody: .jupiter,
                secondBody: .jupiter,
                kind: .conjunction,
                orbDegrees: 0.5,
                phase: .applying,
                strength: 0.95,
                firstLongitude: 10,
                secondLongitude: 10.5,
                firstBodyInSecondHouse: 1,
                secondBodyInFirstHouse: 1,
                classicalReception: nil
            )
        )
        let plan = SynastryCardEvidencePlan(
            cardID: "relationship-overview",
            preset: CalculationPreset.modern.rawValue,
            scopeID: "test",
            themeID: .balanced,
            evidence: [fact],
            overviewDimensions: [],
            evidenceRoles: [:],
            perspectives: []
        )
        let exactPath = "modern.synastry.fact.relationship-overview.general.aspect.jupiter.conjunction.jupiter.interpretation"

        for language in AppLanguage.allCases {
            let matcher = try CopyCatalogMatcher(language: language)
            XCTAssertThrowsError(try matcher.value(at: exactPath))
            XCTAssertFalse(
                try matcher.synastryFactInterpretation(fact: fact, plan: plan)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty,
                language.rawValue
            )
            for body in [
                "sun", "moon", "mercury", "venus", "mars", "jupiter",
                "saturn", "uranus", "neptune", "pluto", "trueNode",
            ] {
                XCTAssertFalse(try matcher.value(at: "shared.synastryRoles.\(body)").isEmpty, "\(language.rawValue): \(body)")
            }
            for house in 1 ... 12 {
                XCTAssertFalse(try matcher.value(at: "shared.synastry.houseOverlay.\(house)").isEmpty, "\(language.rawValue): house \(house)")
            }
        }
    }

    func testExportSynastryPlannerObservationsFromRealCalculatedPairs() async throws {
        struct PersonInput {
            let date: Date
            let latitude: Double
            let longitude: Double
        }
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let factMatchers = try AppLanguage.allCases.map { language in
            (language, try CopyCatalogMatcher(language: language))
        }
        let pairs: [(String, PersonInput, PersonInput)] = [
            ("france-canada", .init(date: utcDate(1992, 5, 14, 6), latitude: 48.8566, longitude: 2.3522), .init(date: utcDate(1988, 10, 3, 2), latitude: 45.5019, longitude: -73.5674)),
            ("britain-italy", .init(date: utcDate(1984, 2, 19, 6), latitude: 51.5074, longitude: -0.1278), .init(date: utcDate(1991, 7, 28, 12), latitude: 41.9028, longitude: 12.4964)),
            ("usa-germany", .init(date: utcDate(1979, 11, 9, 18), latitude: 42.3601, longitude: -71.0589), .init(date: utcDate(1994, 3, 22, 4), latitude: 52.5200, longitude: 13.4050)),
            ("spain-ireland", .init(date: utcDate(1987, 6, 2, 9), latitude: 40.4168, longitude: -3.7038), .init(date: utcDate(1990, 12, 17, 23), latitude: 53.3498, longitude: -6.2603)),
            ("sweden-usa", .init(date: utcDate(1996, 1, 30, 15), latitude: 59.3293, longitude: 18.0686), .init(date: utcDate(1982, 8, 11, 7), latitude: 34.0522, longitude: -118.2437)),
            ("netherlands-portugal", .init(date: utcDate(1976, 4, 6, 3), latitude: 52.3676, longitude: 4.9041), .init(date: utcDate(1998, 9, 25, 20), latitude: 38.7223, longitude: -9.1393)),
            ("china-usa", .init(date: utcDate(1985, 8, 20, 10), latitude: 39.9042, longitude: 116.4074), .init(date: utcDate(1995, 3, 8, 14), latitude: 40.7128, longitude: -74.0060)),
            ("japan-brazil", .init(date: utcDate(1978, 1, 12, 20), latitude: 35.6762, longitude: 139.6503), .init(date: utcDate(1992, 6, 30, 22), latitude: -23.5505, longitude: -46.6333)),
            ("india-southafrica", .init(date: utcDate(1990, 10, 5, 2), latitude: 19.0760, longitude: 72.8777), .init(date: utcDate(1983, 4, 17, 16), latitude: -33.9249, longitude: 18.4241)),
            ("argentina-egypt", .init(date: utcDate(1982, 7, 25, 12), latitude: -34.6037, longitude: -58.3816), .init(date: utcDate(1997, 9, 11, 8), latitude: 30.0444, longitude: 31.2357)),
            ("russia-australia", .init(date: utcDate(1993, 12, 3, 18), latitude: 55.7558, longitude: 37.6173), .init(date: utcDate(1986, 5, 29, 4), latitude: -33.8688, longitude: 151.2093)),
            ("mexico-uk", .init(date: utcDate(1980, 3, 14, 7), latitude: 19.4326, longitude: -99.1332), .init(date: utcDate(1989, 11, 2, 1), latitude: 51.5074, longitude: -0.1278)),
            ("turkey-indonesia", .init(date: utcDate(1987, 6, 9, 21), latitude: 41.0082, longitude: 28.9784), .init(date: utcDate(1999, 2, 27, 11), latitude: -6.2088, longitude: 106.8456)),
            ("newzealand-egypt", .init(date: utcDate(1991, 4, 22, 0), latitude: -36.8485, longitude: 174.7633), .init(date: utcDate(1975, 8, 6, 6), latitude: 30.0444, longitude: 31.2357)),
        ]
        var observations: [[String: Any]] = []
        func factObservation(_ fact: SynastryFact, role: String?) -> [String: Any] {
            switch fact {
            case let .aspect(value):
                return [
                    "factID": value.factID,
                    "kind": "aspect",
                    "role": role ?? "",
                    "firstBody": value.firstBody.rawValue,
                    "aspectKind": value.kind.rawValue,
                    "secondBody": value.secondBody.rawValue,
                    "orbDegrees": value.orbDegrees,
                    "phase": value.phase.rawValue,
                ]
            case let .overlay(value):
                return [
                    "factID": value.factID,
                    "kind": "overlay",
                    "role": role ?? "",
                    "direction": value.direction.rawValue,
                    "body": value.body.rawValue,
                    "house": value.receivingHouse,
                    "signIndex": value.signIndex,
                ]
            case let .planetCondition(value):
                return [
                    "factID": value.factID,
                    "kind": "planet-condition",
                    "role": role ?? "",
                    "person": value.person.rawValue,
                    "body": value.assessment.body.rawValue,
                    "score": value.assessment.score,
                ]
            }
        }
        for preset in [CalculationPreset.modern, .classical] {
            for (scenarioID, first, second) in pairs {
                let comparison = try await calculator.calculateSynastry(
                    first: NatalInput(utcDate: first.date, location: .init(latitudeDegrees: first.latitude, longitudeDegrees: first.longitude)),
                    second: NatalInput(utcDate: second.date, location: .init(latitudeDegrees: second.latitude, longitudeDegrees: second.longitude)),
                    preset: preset
                )
                let bundle = SynastryFactBundleBuilder.build(comparison: comparison, preset: preset.rawValue)
                let plan = SynastryContentPlanner.plan(bundle)
                XCTAssertEqual(plan.cards.map(\.cardID), SynastryContentPlanner.cardIDs)
                XCTAssertEqual(plan, SynastryContentPlanner.plan(bundle))
                for card in plan.cards {
                    XCTAssertFalse(
                        card.evidence.isEmpty,
                        "Empty calculated evidence in \(scenarioID) / \(preset.rawValue) / \(card.cardID)"
                    )
                    XCTAssertEqual(
                        card.sourceFactIDs.count,
                        Set(card.sourceFactIDs).count,
                        "Duplicate fact in \(scenarioID) / \(preset.rawValue) / \(card.cardID)"
                    )
                    for (language, matcher) in factMatchers {
                        for fact in card.evidence {
                            let interpretation = try matcher.synastryFactInterpretation(fact: fact, plan: card)
                            XCTAssertFalse(
                                interpretation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                                "Missing \(language.rawValue) fact copy in \(scenarioID) / \(preset.rawValue) / \(card.cardID) / \(fact.factID)"
                            )
                        }
                    }
                }
                let overview = try XCTUnwrap(plan.card("relationship-overview"))
                XCTAssertEqual(overview.overviewDimensions.map(\.id), [.communication, .emotionalPace, .chemistry])
                XCTAssertTrue(overview.overviewDimensions.flatMap(\.sourceFactIDs).allSatisfy {
                    Set(bundle.aspects.map(\.factID)).contains($0)
                })
                let perspectives = try XCTUnwrap(plan.card("perspectives"))
                XCTAssertEqual(perspectives.perspectives.map(\.person), [.personA, .personB])
                XCTAssertTrue(perspectives.perspectives[0].evidence.allSatisfy {
                    guard case let .overlay(value) = $0 else { return false }
                    return value.direction == .personBToA
                })
                XCTAssertTrue(perspectives.perspectives[1].evidence.allSatisfy {
                    guard case let .overlay(value) = $0 else { return false }
                    return value.direction == .personAToB
                })
                let houseOverlays = try XCTUnwrap(plan.card("house-overlays"))
                XCTAssertEqual(houseOverlays.evidence.count, 4)
                let overlayDirections: [SynastryOverlayDirection] = houseOverlays.evidence.compactMap {
                    guard case let .overlay(value) = $0 else { return nil }
                    return value.direction
                }
                XCTAssertEqual(Set(overlayDirections), Set<SynastryOverlayDirection>([.personAToB, .personBToA]))
                let emotional = try XCTUnwrap(plan.card("emotional-connection"))
                XCTAssertEqual(Set(emotional.evidenceRoles.values), Set(["flow", "difference"]))
                XCTAssertEqual(emotional.sourceFactIDs.count, 2)
                XCTAssertEqual(Set(emotional.sourceFactIDs).count, 2)
                let domainFactIDs = Set(
                    ["emotional-connection", "communication", "chemistry", "commitment"]
                        .compactMap(plan.card)
                        .flatMap(\.sourceFactIDs)
                )
                let keyInterAspects = try XCTUnwrap(plan.card("key-inter-aspects"))
                let unusedAspectCount = bundle.aspects.filter { !domainFactIDs.contains($0.factID) }.count
                if unusedAspectCount >= 3 {
                    XCTAssertTrue(
                        Set(keyInterAspects.sourceFactIDs).isDisjoint(with: domainFactIDs),
                        "Key aspects repeat domain facts despite enough alternatives in \(scenarioID) / \(preset.rawValue)"
                    )
                }
                if preset == .classical {
                    XCTAssertTrue(bundle.first.points.allSatisfy { ClassicalSynastryMVPCapability.traditionalBodies.contains($0.body) })
                    XCTAssertTrue(bundle.second.points.allSatisfy { ClassicalSynastryMVPCapability.traditionalBodies.contains($0.body) })
                }
                observations.append([
                    "scenarioID": scenarioID,
                    "preset": preset.rawValue,
                    "scopeID": plan.scopeID,
                    "aspectCount": bundle.aspects.count,
                    "overlayCount": bundle.overlays.count,
                    "conditionCount": bundle.planetConditions.count,
                    "copyKeys": plan.cards.map(\.copyKey),
                    "themes": Dictionary(uniqueKeysWithValues: plan.cards.map { ($0.cardID, $0.themeID.rawValue) }),
                    "cards": plan.cards.map { card in
                        [
                            "cardID": card.cardID,
                            "themeID": card.themeID.rawValue,
                            "facts": card.evidence.map {
                                factObservation($0, role: card.evidenceRoles[$0.factID])
                            },
                        ] as [String: Any]
                    },
                    "overviewDimensions": overview.overviewDimensions.map {
                        ["id": $0.id.rawValue, "state": $0.state.rawValue, "sourceFactIDs": $0.sourceFactIDs]
                    },
                ])
            }
        }
        let payload: [String: Any] = ["schemaVersion": 1, "observations": observations]
        let data = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        print("SYNASTRY_PLANNER_OBSERVATIONS_BASE64:\(data.base64EncodedString())")
    }

    func testLunarPhaseGeometryUsesSunMoonElongation() {
        XCTAssertEqual(LunarPhaseGeometry.elongation(sunLongitude: 350, moonLongitude: 10), 20, accuracy: 0.000_001)
        XCTAssertEqual(LunarPhaseGeometry.elongation(sunLongitude: 10, moonLongitude: 350), 340, accuracy: 0.000_001)
        XCTAssertEqual(LunarPhaseGeometry.illuminationFraction(elongation: 0), 0, accuracy: 0.000_001)
        XCTAssertEqual(LunarPhaseGeometry.illuminationFraction(elongation: 90), 0.5, accuracy: 0.000_001)
        XCTAssertEqual(LunarPhaseGeometry.illuminationFraction(elongation: 180), 1, accuracy: 0.000_001)
        XCTAssertEqual(LunarPhaseGeometry.illuminationFraction(elongation: 270), 0.5, accuracy: 0.000_001)
    }

    func testSynastryAIRequestIsPresetSpecificNamedAndBounded() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let first = NatalInput(
            utcDate: Date(timeIntervalSince1970: 824_259_600),
            location: GeographicLocation(latitudeDegrees: 48.8566, longitudeDegrees: 2.3522)
        )
        let second = NatalInput(
            utcDate: Date(timeIntervalSince1970: 818_035_200),
            location: GeographicLocation(latitudeDegrees: 43.6532, longitudeDegrees: -79.3832)
        )

        for preset in [CalculationPreset.modern, .classical] {
            let comparison = try await calculator.calculateSynastry(
                first: first,
                second: second,
                preset: preset
            )
            let document = AIFactsBuilder.synastryDocument(
                firstName: "Elena Hart",
                firstChart: comparison.first,
                secondName: "Julian Mercer",
                secondChart: comparison.second,
                crossAspects: comparison.crossAspects,
                classicalAssessment: comparison.classicalAssessment,
                preset: preset,
                params: ["partnerHash": "test", "relationship": "friend"],
                locale: "en"
            )
            let people = try XCTUnwrap(document["people"] as? [[String: Any]])
            let facts = try XCTUnwrap(document["evidenceFacts"] as? [[String: Any]])
            let factIDs = facts.compactMap { $0["id"] as? String }
            let data = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])

            XCTAssertEqual(document["preset"] as? String, preset.rawValue)
            XCTAssertEqual(people.compactMap { $0["name"] as? String }, ["Elena Hart", "Julian Mercer"])
            XCTAssertEqual(factIDs.count, Set(factIDs).count)
            XCTAssertLessThanOrEqual(facts.count, 200)
            XCTAssertLessThan(data.count, 80_000)
            XCTAssertNil(document["reference"])
            XCTAssertNil(document["partner"])
            XCTAssertNil(document["chart"])
            XCTAssertNil(document["comparisonAspects"])
            let params = try XCTUnwrap(document["params"] as? [String: String])
            XCTAssertEqual(params["relationship"], "friend")
        }
    }

    func testAIArtifactFactsIdentityIgnoresNarrationLocale() throws {
        let english: [String: Any] = [
            "kind": "natal",
            "locale": "en",
            "evidenceFacts": [["id": "point.sun", "longitude": 10.5]],
        ]
        let chinese: [String: Any] = [
            "kind": "natal",
            "locale": "zh-Hans",
            "evidenceFacts": [["id": "point.sun", "longitude": 10.5]],
        ]

        XCTAssertEqual(
            try AIArtifactIdentity.factsIdentityHash(english),
            try AIArtifactIdentity.factsIdentityHash(chinese)
        )
    }

    func testAIReportRequestLanguageNeverUsesCorpusFallback() {
        XCTAssertEqual(AppLanguage.allCases.map(\.reportRequestLanguage), AppLanguage.allCases)
        XCTAssertEqual(AppLanguage.german.corpusLanguage, .english)
        XCTAssertEqual(AppLanguage.german.reportRequestLanguage, .german)
        XCTAssertEqual(AppLanguage.italian.reportRequestLanguage, .italian)
        XCTAssertEqual(AppLanguage.turkish.reportRequestLanguage, .turkish)
        XCTAssertEqual(AppLanguage.korean.reportRequestLanguage, .korean)
    }

    func testFirstInstallLanguageMatchesSupportedSystemLanguageAndFallsBackToEnglish() {
        XCTAssertEqual(AppLanguage.matchingSystemLanguage("zh-Hans-CN"), .simplifiedChinese)
        XCTAssertEqual(AppLanguage.matchingSystemLanguage("fr-FR"), .french)
        XCTAssertEqual(AppLanguage.matchingSystemLanguage("de_DE"), .german)
        XCTAssertEqual(AppLanguage.matchingSystemLanguage("ko-KR"), .korean)
        XCTAssertEqual(AppLanguage.matchingSystemLanguage("ja-JP"), .english)
        XCTAssertEqual(AppLanguage.matchingSystemLanguage(nil), .english)
    }

    func testAIArtifactFactsIdentityStillChangesWithCalculatedFacts() throws {
        let first: [String: Any] = [
            "locale": "en",
            "evidenceFacts": [["id": "point.sun", "longitude": 10.5]],
        ]
        let changed: [String: Any] = [
            "locale": "en",
            "evidenceFacts": [["id": "point.sun", "longitude": 11.5]],
        ]

        XCTAssertNotEqual(
            try AIArtifactIdentity.factsIdentityHash(first),
            try AIArtifactIdentity.factsIdentityHash(changed)
        )
    }

    func testWholeChartAIFactsAreChartSpecificBoundedAndDeterministic() async throws {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let location = GeographicLocation(latitudeDegrees: 48.8566, longitudeDegrees: 2.3522)
        let birthDate = utcDate(1990, 4, 18, 10)
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: birthDate, location: location),
            preset: .modern
        )
        let sky = try await calculator.calculateSnapshot(
            NatalInput(utcDate: utcDate(2026, 8, 10, 12), location: location),
            preset: .modern
        )
        let progressed = try await calculator.calculateSnapshot(
            NatalInput(
                utcDate: SwissEphemerisCalculator.secondaryProgressedDate(
                    birthDate: birthDate,
                    targetDate: utcDate(2026, 8, 10, 12)
                ),
                location: location
            ),
            preset: .modern
        )
        let solarReturn = try await calculator.calculateSnapshot(
            NatalInput(utcDate: utcDate(2026, 4, 18, 12), location: location),
            preset: .modern
        )
        let progressedComparison = SwissEphemerisCalculator.compare(
            moving: progressed,
            reference: natal,
            orbDegrees: 2
        )
        let solarComparison = SwissEphemerisCalculator.compare(
            moving: solarReturn,
            reference: natal,
            orbDegrees: 3
        )

        let anchor = utcDate(2026, 8, 10, 12)
        var events = ChartEventData.empty
        events.skyIngresses = [.init(body: .moon, signIndex: 5, date: anchor, nextDate: nil)]
        events.skyExactEvents = [.init(first: .sun, second: .moon, kind: .trine, date: anchor)]
        events.skyStations = [.init(body: .mercury, date: anchor, retrogradeAfter: true)]
        events.progressedMoon = .init(signIndex: 3, daysInSign: 120, nextIngress: anchor)
        events.progressedTurningPoints = [
            .init(
                first: .moon,
                second: .sun,
                kind: .square,
                exactDate: anchor,
                separationDegrees: 0.4,
                phase: .applying
            ),
        ]
        events.solarYearStart = anchor
        events.solarSeasons = (0 ..< 4).map {
            .init(
                index: $0,
                start: anchor.addingTimeInterval(Double($0) * 90 * 86_400),
                end: anchor.addingTimeInterval(Double($0 + 1) * 90 * 86_400)
            )
        }

        let cases: [(ChartKind, ChartSnapshot, ChartSnapshot?, [ChartAspect], Set<String>)] = [
            (.natal, natal, nil, [], []),
            (.currentSky, sky, nil, [], ["skyIngress", "skyExactAspect", "station"]),
            (.secondary, progressed, natal, progressedComparison, ["progressedTurningPoint", "progressedMoonWindow"]),
            (.solarReturn, solarReturn, natal, solarComparison, ["solarReturnStart", "solarSeason"]),
        ]

        for (chart, snapshot, reference, comparison, allowedEvents) in cases {
            let makeDocument = {
                AIFactsBuilder.document(
                    chart: chart,
                    snapshot: snapshot,
                    reference: reference,
                    comparisonAspects: comparison,
                    preset: .modern,
                    personName: "Elena Hart",
                    partnerName: nil,
                    partnerChart: nil,
                    events: events,
                    params: [:],
                    locale: "en"
                )
            }
            let document = makeDocument()
            let facts = try XCTUnwrap(document["evidenceFacts"] as? [[String: Any]])
            let factIDs = facts.compactMap { $0["id"] as? String }
            let eventTypes = Set(
                (try XCTUnwrap(document["events"] as? [[String: Any]]))
                    .compactMap { $0["type"] as? String }
            )
            let data = try JSONSerialization.data(withJSONObject: document, options: [.sortedKeys])
            let repeatedData = try JSONSerialization.data(withJSONObject: makeDocument(), options: [.sortedKeys])

            XCTAssertEqual(eventTypes, allowedEvents, chart.rawValue)
            XCTAssertEqual(factIDs.count, Set(factIDs).count, chart.rawValue)
            XCTAssertEqual(data, repeatedData, chart.rawValue)
            // Eleven moving bodies, eleven reference bodies and their finite
            // internal/cross aspect domains keep every whole-chart request
            // bounded without applying an AI-specific Top-N filter.
            XCTAssertLessThanOrEqual(facts.count, 262, chart.rawValue)
            XCTAssertLessThan(data.count, 180_000, chart.rawValue)

            if chart == .currentSky {
                XCTAssertNil(document["person"])
            }
            if chart == .secondary || chart == .solarReturn {
                let types = Set(facts.compactMap { $0["type"] as? String })
                XCTAssertTrue(types.contains("comparisonAspect"), chart.rawValue)
                XCTAssertTrue(types.contains("internalAspect"), chart.rawValue)
                XCTAssertTrue(types.contains("referencePoint"), chart.rawValue)
            }
        }
    }

    func testFixedFixturesProduceTheFrozenSixCardContract() {
        let fixtures = makeFixtures()

        XCTAssertGreaterThanOrEqual(fixtures.count, 12)
        for fixture in fixtures {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            XCTAssertEqual(plan.cards.map(\.cardID), TransitContentPlan.cardIDs, fixture.name)
            XCTAssertEqual(
                plan.cards.map(\.copySlot),
                [.integratedStory, .cycleChapter, nil, .planetPathShort, .lifeAreaShort, .activeTransitShort],
                fixture.name
            )
            XCTAssertTrue(plan.cards.allSatisfy { $0.scopeID == fixture.bundle.scopeID }, fixture.name)
        }
    }

    func testAllFixturesAreDeterministicAcrossInputOrder() {
        for fixture in makeFixtures() {
            let bundle = fixture.bundle
            let reversed = TransitFactBundle(
                scopeID: bundle.scopeID,
                anchorDate: bundle.anchorDate,
                timeZoneIdentifier: bundle.timeZoneIdentifier,
                rangeDays: bundle.rangeDays,
                preset: bundle.preset,
                crossAspects: Array(bundle.crossAspects.reversed()),
                transitWindows: Array(bundle.transitWindows.reversed()),
                aspectWindowFactIDs: bundle.aspectWindowFactIDs,
                planetEvents: Array(bundle.planetEvents.reversed()),
                planetPlacements: Array(bundle.planetPlacements.reversed()),
                lifeAreaScores: Array(bundle.lifeAreaScores.reversed()),
                transitCalendar: Array(bundle.transitCalendar.reversed())
            )

            XCTAssertEqual(
                TransitContentPlanner.plan(bundle),
                TransitContentPlanner.plan(reversed),
                fixture.name
            )
        }
    }

    func testFullExplanationIsClaimedAtMostOnce() {
        for fixture in makeFixtures() {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            let fullClaims = plan.cards.flatMap(\.evidence).filter { $0.claimMode == .full }
            XCTAssertLessThanOrEqual(fullClaims.count, 1, fixture.name)
            if let fullClaim = fullClaims.first {
                XCTAssertEqual(fullClaim.role, .primary, fixture.name)
                XCTAssertEqual(plan.card("current-story")?.primaryFactID, fullClaim.fact.factID, fixture.name)
            }
        }
    }

    func testStoryIntegratedThemesAndSignalRolesAreStable() {
        let cases: [(String, [TransitAspectFact], TransitIntegratedThemeID, [TransitStorySignalRoleID])] = [
            ("mixed", [saturnAspect(), jupiterAspect()], .expansionStructure, [.expanding, .structuring]),
            ("supportive", [jupiterAspect()], .focusedExpansion, [.expanding]),
            ("challenging", [saturnAspect()], .durableStructure, [.structuring]),
            ("neutral", [mercuryAspect()], .steadyRealignment, [.supporting]),
        ]

        for item in cases {
            let plan = TransitContentPlanner.plan(makeBundle(scopeID: item.0, aspects: item.1))
            let story = plan.card("current-story")!
            XCTAssertEqual(story.integratedThemeID, item.2, item.0)
            XCTAssertEqual(story.signalRoles.map(\.signalRole), item.3, item.0)
            XCTAssertTrue(story.signalRoles.allSatisfy {
                Set($0.sourceFactIDs).isSubset(of: Set(story.sourceFactIDs))
                    && !$0.movingID.isEmpty
                    && $0.lifeAreas.allSatisfy { (1 ... 12).contains($0) }
            }, item.0)
        }
    }

    func testFixedFixturesCoverEveryStoryRoleAndRequiredEdgeCase() throws {
        let fixtures = makeFixtures()
        let plans = fixtures.map { TransitContentPlanner.plan($0.bundle) }

        XCTAssertEqual(
            Set(plans.compactMap { $0.card("current-story")?.integratedThemeID }),
            Set(TransitIntegratedThemeID.allCases)
        )
        XCTAssertEqual(
            Set(plans.flatMap { $0.card("current-story")?.signalRoles.map(\.signalRole) ?? [] }),
            Set(TransitStorySignalRoleID.allCases)
        )
        XCTAssertTrue(fixtures.contains { $0.name == "no-window-signals" && $0.bundle.transitWindows.isEmpty })
        XCTAssertTrue(fixtures.contains { $0.name == "same-theme-multi-signal" && $0.bundle.crossAspects.count > 1 })
        XCTAssertTrue(fixtures.contains { $0.bundle.crossAspects.count == 1 })
        XCTAssertTrue(fixtures.contains { $0.bundle.transitWindows.contains(where: { $0.passCount > 1 }) })
        let matcher = try CopyCatalogMatcher(language: .english)
        let sameTheme = fixtures.first { $0.name == "same-theme-multi-signal" }!
        let activeThemeKeys = sameTheme.bundle.crossAspects.map { aspect in
            let bundle = makeBundle(
                scopeID: "same-theme-probe-\(aspect.movingID)",
                aspects: [aspect],
                windows: [],
                events: [],
                placements: [],
                lifeAreas: [],
                calendar: []
            )
            let plan = TransitContentPlanner.plan(bundle).card("active-transits")!
            return matcher.transitCopyRequests(plan: plan).first?.key
        }
        XCTAssertEqual(Set(activeThemeKeys.compactMap { $0 }).count, 1)
    }

    func testCurrentStoryRendersIntegratedGuidanceAndRoleCopy() throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let story = TransitContentPlanner.plan(makeBundle()).card("current-story")!
        let text = try matcher.transitCardText(plan: story)

        XCTAssertNotNil(text.headline)
        XCTAssertNotNil(text.body)
        XCTAssertNotNil(text.secondaryBody)
        XCTAssertEqual(text.roleTexts?.count, story.signalRoles.count)
        XCTAssertTrue(text.roleTexts?.allSatisfy { roleText in
            !roleText.text.contains("{{")
                && Set(roleText.sourceFactIDs).isSubset(of: Set(story.sourceFactIDs))
        } == true)
    }

    func testCurrentCyclesRequestAndRenderAllThreeTimeScales() throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let cycles = TransitContentPlanner.plan(makeBundle(windows: [])).card("current-cycles")!
        let requests = matcher.transitCopyRequests(plan: cycles)
        let text = try matcher.transitCardText(plan: cycles)

        XCTAssertEqual(
            Set(requests.compactMap(\.roleID)),
            Set(["longCycle", "currentCycle", "dailyCycle"])
        )
        XCTAssertEqual(
            Set(text.cycleTexts?.map(\.roleID) ?? []),
            Set(["longCycle", "currentCycle", "dailyCycle"])
        )
        XCTAssertTrue(text.cycleTexts?.allSatisfy { !$0.headline.isEmpty && !$0.body.isEmpty } == true)
    }

    func testCurrentCyclesUseOnlyActiveMultiMonthLongWindow() {
        let aspect = saturnAspect()
        let ended = window(aspect: aspect, exactOffsetDays: -60, startOffsetDays: -120, endOffsetDays: -1)
        let future = window(aspect: aspect, exactOffsetDays: 40, startOffsetDays: 20, endOffsetDays: 120)
        let active = window(aspect: aspect, exactOffsetDays: 10, startOffsetDays: -90, endOffsetDays: 90)
        let plan = TransitContentPlanner.plan(
            makeBundle(scopeID: "active-long-window", aspects: [aspect], windows: [ended, future, active])
        )
        let longEvidence = plan.card("current-cycles")?.evidence.first {
            $0.role == TransitEvidenceRole.longCycle
        }

        guard case let .window(selected)? = longEvidence?.fact else {
            return XCTFail("Long-term cycle must use an active multi-month window")
        }
        XCTAssertEqual(selected.exact, active.exact)
        XCTAssertLessThanOrEqual(selected.start, testAnchor)
        XCTAssertGreaterThanOrEqual(selected.end, testAnchor)
        XCTAssertGreaterThanOrEqual(
            selected.end.timeIntervalSince(selected.start),
            TransitCycleContract.minimumLongTermDuration
        )
    }

    func testEachCardOwnsOnlyItsContractedFactKinds() {
        let plan = TransitContentPlanner.plan(makeBundle())

        XCTAssertTrue(plan.card("transit-timeline")!.evidence.allSatisfy { evidence in
            switch evidence.fact {
            case .window, .planetEvent, .calendar:
                evidence.claimMode == .technical
            default:
                false
            }
        })
        XCTAssertTrue(plan.card("planet-paths")!.evidence.allSatisfy { evidence in
            switch evidence.fact {
            case .placement:
                evidence.claimMode == .technical && evidence.role == .path
            case .planetEvent:
                evidence.claimMode == .technical && evidence.role == .pathEvent
            default:
                false
            }
        })
        XCTAssertTrue(plan.card("life-areas")!.evidence.allSatisfy { if case .lifeArea = $0.fact { true } else { false } })
        XCTAssertTrue(plan.card("current-cycles")!.evidence.allSatisfy { $0.claimMode == .aggregate })

        let active = plan.card("active-transits")!.evidence
        XCTAssertTrue(active.allSatisfy { evidence in
            switch evidence.fact {
            case .aspect, .planetEvent:
                evidence.claimMode == .short
            case .window:
                evidence.claimMode == .technical
            default:
                false
            }
        })
    }

    func testTimelineKeepsOnlyInRangeTimestampedWindowsAndRepeatedPasses() {
        let anchor = testAnchor
        let aspect = saturnAspect()
        let returning = window(
            aspect: aspect,
            exactOffsetDays: 2,
            repeatOffsetDays: 12,
            nextOffsetDays: 24,
            passCount: 3
        )
        let outside = window(aspect: aspect, exactOffsetDays: 40)
        let plan = TransitContentPlanner.plan(
            makeBundle(
                scopeID: "returning",
                aspects: [aspect],
                windows: [outside, returning],
                events: [],
                calendar: [],
                rangeDays: 30
            )
        )
        let timeline = plan.card("transit-timeline")!

        XCTAssertNil(timeline.copySlot)
        XCTAssertEqual(timeline.evidence.count, 1)
        guard case let .window(value) = timeline.evidence[0].fact else {
            return XCTFail("Timeline must contain a transit window")
        }
        XCTAssertEqual(value.exact, anchor.addingTimeInterval(2 * day))
        XCTAssertEqual(value.repeatExact, anchor.addingTimeInterval(12 * day))
        XCTAssertEqual(value.nextExact, anchor.addingTimeInterval(24 * day))
        XCTAssertEqual(value.passIndex, 1)
        XCTAssertEqual(value.passCount, 3)
        XCTAssertTrue(value.returning)
        XCTAssertEqual(value.timeZoneIdentifier, testTimeZone)
    }

    func testTimelineProjectionPairsHouseIngressesWithoutInventingAnEnd() {
        let first = planetEvent(kind: .houseIngress, offsetDays: 2, body: .mars, fromIndex: 2, toIndex: 3)
        let second = planetEvent(kind: .houseIngress, offsetDays: 18, body: .mars, fromIndex: 3, toIndex: 4)
        let plan = TransitContentPlanner.plan(
            makeBundle(
                scopeID: "house-residence",
                aspects: [],
                windows: [],
                events: [second, first],
                placements: [],
                lifeAreas: [],
                calendar: [],
                rangeDays: 365
            )
        )
        let entries = TransitTimelineProjection.entries(from: plan.card("transit-timeline")!.evidence)
        let houseEntries = entries.filter {
            if case .houseResidence = $0.kind { return true }
            return false
        }

        XCTAssertEqual(houseEntries.count, 2)
        XCTAssertEqual(houseEntries[0].start, testAnchor.addingTimeInterval(2 * day))
        XCTAssertEqual(houseEntries[0].end, testAnchor.addingTimeInterval(18 * day))
        XCTAssertEqual(houseEntries[0].sourceFactIDs.count, 2)
        XCTAssertNil(houseEntries[1].end)
        XCTAssertEqual(houseEntries[1].sourceFactIDs.count, 1)
    }

    func testTimelineOwnsCalendarScoresAndAuthoritativeSourceIDs() {
        let calendar = makeCalendar()
        let plan = TransitContentPlanner.plan(
            makeBundle(
                scopeID: "timeline-calendar",
                aspects: [],
                windows: [],
                events: [],
                placements: [],
                lifeAreas: [],
                calendar: calendar,
                rangeDays: 365
            )
        )
        let plannedCalendar = plan.card("transit-timeline")!.evidence.compactMap { evidence -> TransitCalendarFact? in
            guard case let .calendar(fact) = evidence.fact else { return nil }
            return fact
        }

        XCTAssertEqual(plannedCalendar.map(\.score), calendar.map(\.score))
        XCTAssertTrue(plannedCalendar.allSatisfy { !$0.sourceFactIDs.isEmpty })
        XCTAssertTrue(plan.card("transit-timeline")!.sourceFactIDs.allSatisfy {
            $0.hasPrefix("transit.timeline-calendar.")
        })
    }

    func testTimelineRangeContractIncludesSevenThirtyAndTwelveMonths() {
        XCTAssertEqual(TransitTimelineContract.rangeDays, [30, 7, 365])
        XCTAssertEqual(TransitTimelineContract.defaultRangeDays, 30)
        XCTAssertEqual(TransitTimelineContract.maximumRangeDays, 365)
    }

    func testPlanetPathsAndLifeAreasKeepCompleteCollections() {
        let plan = TransitContentPlanner.plan(makeBundle())
        let paths = plan.card("planet-paths")!
        let areas = plan.card("life-areas")!

        let placementEvidence = paths.evidence.filter { if case .placement = $0.fact { true } else { false } }
        let pathEventEvidence = paths.evidence.filter { if case .planetEvent = $0.fact { true } else { false } }
        XCTAssertEqual(placementEvidence.count, CelestialBody.allCases.count)
        XCTAssertEqual(pathEventEvidence.count, makePlanetEvents().count)
        XCTAssertEqual(
            Set(placementEvidence.map(\.fact.factID)),
            Set(makePlacements().map {
                $0.factID.replacingOccurrences(of: "transit.template.", with: "transit.scope.")
            })
        )
        XCTAssertTrue(pathEventEvidence.allSatisfy { $0.role == .pathEvent && $0.claimMode == .technical })
        XCTAssertTrue(paths.themeInputs.allSatisfy { $0.roleID != TransitEvidenceRole.pathEvent.rawValue })
        XCTAssertEqual(areas.evidence.count, 12)
        XCTAssertEqual(Set(areas.evidence.compactMap { evidence -> Int? in
            guard case let .lifeArea(area) = evidence.fact else { return nil }
            return area.house
        }), Set(1 ... 12))
    }

    func testActiveTransitsSupportAllFourPlanetEventKinds() {
        let plan = TransitContentPlanner.plan(
            makeBundle(scopeID: "events-only", aspects: [], windows: [], events: makePlanetEvents())
        )
        let active = plan.card("active-transits")!

        XCTAssertEqual(Set(active.evidence.compactMap { evidence -> TransitPlanetEventKind? in
            guard case let .planetEvent(event) = evidence.fact else { return nil }
            return event.kind
        }), Set(TransitPlanetEventKind.allCases))
        XCTAssertEqual(
            Set(active.evidence.map(\.role)),
            Set([
                .activeSignIngress,
                .activeHouseIngress,
                .activeStationRetrograde,
                .activeStationDirect,
            ])
        )
    }

    func testEveryPlannedSignalAndTimeFactUsesTheSameScope() {
        for fixture in makeFixtures() {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            XCTAssertEqual(plan.timeZoneIdentifier, fixture.bundle.timeZoneIdentifier, fixture.name)
            for card in plan.cards {
                let plannedSourceIDs = Set(card.sourceFactIDs)
                XCTAssertTrue(card.themeInputs.allSatisfy {
                    Set($0.sourceFactIDs).isSubset(of: plannedSourceIDs)
                        && $0.signalID.hasPrefix("transit.signal.")
                }, fixture.name)
                XCTAssertTrue(card.signalRoles.allSatisfy {
                    Set($0.sourceFactIDs).isSubset(of: plannedSourceIDs)
                }, fixture.name)
                for evidence in card.evidence {
                    XCTAssertTrue(evidence.fact.factID.hasPrefix("transit.\(plan.scopeID)."), fixture.name)
                    switch evidence.fact {
                    case let .window(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    case let .planetEvent(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    case let .calendar(value):
                        XCTAssertFalse(value.timeZoneIdentifier.isEmpty, fixture.name)
                    default:
                        break
                    }
                }
            }
        }
    }

    func testEmptyEvidenceUsesTheFrozenEmptyStateWithoutCrossCardFallback() {
        let plan = TransitContentPlanner.plan(
            makeBundle(
                scopeID: "empty",
                aspects: [],
                windows: [],
                events: [],
                placements: [],
                lifeAreas: [],
                calendar: []
            )
        )

        XCTAssertTrue(plan.cards.allSatisfy { $0.evidence.isEmpty })
        XCTAssertTrue(plan.cards.allSatisfy { $0.primaryFactID == nil })
        XCTAssertTrue(plan.cards.allSatisfy { $0.emptyState == .showInsufficientFacts })
        XCTAssertNil(plan.card("current-story")?.integratedThemeID)
    }

    func testFrozenThemeAndRoleRegistriesRemainFinite() {
        XCTAssertEqual(TransitIntegratedThemeID.allCases.count, 4)
        XCTAssertEqual(TransitStorySignalRoleID.allCases.count, 5)
        XCTAssertEqual(TransitThemeID.allCases.count, 38)
        XCTAssertEqual(TransitCopySlot.allCases.count, 6)
        XCTAssertEqual(Set(TransitThemeID.allCases.map(\.rawValue)).count, TransitThemeID.allCases.count)
    }

    func testExportModernTransitCopyReachability() async throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let fixedFixtures = makeFixtures()
        let realFixtures = try await makeRealChartFixtures()
        let probeFixtures = makeReachabilityProbeFixtures()
        var observationsByIdentity: [String: ObservationAccumulator] = [:]
        var realRuns: [RealRun] = []
        var cycleRoles = Set<String>()
        var integratedThemes = Set<String>()
        var signalRoles = Set<String>()

        func record(_ fixture: Fixture, scenarioKind: String) {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            for card in plan.cards {
                let requests = matcher.transitCopyRequests(plan: card)
                if card.cardID == "transit-timeline" {
                    XCTAssertTrue(requests.isEmpty, fixture.name)
                }
                for request in requests {
                    XCTAssertEqual(request.cardID, card.cardID, fixture.name)
                    XCTAssertTrue(Set(request.sourceFactIDs).isSubset(of: Set(card.sourceFactIDs)), fixture.name)
                    XCTAssertTrue(isAllowedTransitRequest(request), "\(fixture.name): \(request.key)")
                    if request.copySlot == TransitCopySlot.cycleChapter.rawValue,
                       let roleID = request.roleID
                    {
                        cycleRoles.insert(roleID)
                    }
                    if let integratedThemeID = request.integratedThemeID {
                        integratedThemes.insert(integratedThemeID)
                    }
                    if request.copySlot == TransitCopySlot.signalRole.rawValue,
                       let roleID = request.roleID
                    {
                        signalRoles.insert(roleID)
                    }
                    var observation = observationsByIdentity[request.identity]
                        ?? ObservationAccumulator(request: request)
                    observation.occurrenceCount += 1
                    observation.scenarioKinds.insert(scenarioKind)
                    if observation.exampleScenarioIDs.count < 8 {
                        observation.exampleScenarioIDs.insert(fixture.name)
                    }
                    observationsByIdentity[request.identity] = observation
                }
            }
        }

        for fixture in fixedFixtures {
            record(fixture, scenarioKind: "fixed-fixture")
        }
        for item in realFixtures {
            record(item.fixture, scenarioKind: "real-chart")
            let plan = TransitContentPlanner.plan(item.fixture.bundle)
            realRuns.append(
                RealRun(
                    chartID: item.chartID,
                    anchorTimestamp: item.fixture.bundle.anchorDate.timeIntervalSince1970,
                    scopeID: plan.scopeID,
                    requestCount: plan.cards.flatMap { matcher.transitCopyRequests(plan: $0) }.count
                )
            )
        }
        for fixture in probeFixtures {
            record(fixture, scenarioKind: "exhaustive-probe")
        }

        XCTAssertGreaterThanOrEqual(fixedFixtures.count, 12)
        XCTAssertEqual(Set(realFixtures.map(\.chartID)).count, 5)
        XCTAssertEqual(realFixtures.count, 20)
        XCTAssertEqual(integratedThemes, Set(TransitIntegratedThemeID.allCases.map(\.rawValue)))
        XCTAssertEqual(signalRoles, Set(TransitStorySignalRoleID.allCases.map(\.rawValue)))
        XCTAssertEqual(cycleRoles, Set(["longCycle", "currentCycle", "dailyCycle"]))
        XCTAssertEqual(
            Set(probeFixtures.flatMap(\.bundle.planetEvents).filter { $0.kind == .houseIngress }.compactMap(\.toIndex)),
            Set(1 ... 12)
        )
        XCTAssertEqual(
            Set(probeFixtures.flatMap(\.bundle.planetEvents).map(\.kind)),
            Set(TransitPlanetEventKind.allCases)
        )

        let observations = observationsByIdentity.values.map { $0.exported }.sorted {
            if $0.key != $1.key { return $0.key < $1.key }
            if $0.cardID != $1.cardID { return $0.cardID < $1.cardID }
            return $0.copySlot < $1.copySlot
        }
        let payload = ReachabilityPayload(
            schemaVersion: 1,
            fixedFixtureIDs: fixedFixtures.map(\.name).sorted(),
            realRuns: realRuns.sorted {
                if $0.chartID != $1.chartID { return $0.chartID < $1.chartID }
                return $0.anchorTimestamp < $1.anchorTimestamp
            },
            exhaustiveProbeCount: probeFixtures.count,
            coverage: [
                "integratedStory": integratedThemes.sorted(),
                "signalRole": signalRoles.sorted(),
                "cycleRole": cycleRoles.sorted(),
                "planetEvent": TransitPlanetEventKind.allCases.map(\.rawValue).sorted(),
                "houseIngress": (1 ... 12).map(String.init),
            ],
            observations: observations
        )
        let data = try JSONEncoder().encode(payload)
        print("TRANSIT_COPY_OBSERVATIONS_BASE64:\(data.base64EncodedString())")
    }

    private struct RealFixture {
        let chartID: String
        let fixture: Fixture
    }

    private struct RealRun: Codable {
        let chartID: String
        let anchorTimestamp: TimeInterval
        let scopeID: String
        let requestCount: Int
    }

    private struct ReachabilityPayload: Codable {
        let schemaVersion: Int
        let fixedFixtureIDs: [String]
        let realRuns: [RealRun]
        let exhaustiveProbeCount: Int
        let coverage: [String: [String]]
        let observations: [ObservedRequest]
    }

    private struct ObservedRequest: Codable {
        let key: String
        let cardID: String
        let copySlot: String
        let themeID: String?
        let integratedThemeID: String?
        let roleID: String?
        let variables: [String: String]
        let occurrenceCount: Int
        let scenarioKinds: [String]
        let exampleScenarioIDs: [String]
    }

    private struct ObservationAccumulator {
        let request: TransitCopyRequest
        var occurrenceCount = 0
        var scenarioKinds = Set<String>()
        var exampleScenarioIDs = Set<String>()

        var exported: ObservedRequest {
            ObservedRequest(
                key: request.key,
                cardID: request.cardID,
                copySlot: request.copySlot,
                themeID: request.themeID,
                integratedThemeID: request.integratedThemeID,
                roleID: request.roleID,
                variables: request.variables,
                occurrenceCount: occurrenceCount,
                scenarioKinds: scenarioKinds.sorted(),
                exampleScenarioIDs: exampleScenarioIDs.sorted()
            )
        }
    }

    private func isAllowedTransitRequest(_ request: TransitCopyRequest) -> Bool {
        switch request.cardID {
        case "current-story":
            request.key.hasPrefix("modern.transit.integratedStory.")
                || request.key.hasPrefix("modern.transit.signalRole.")
        case "current-cycles":
            request.key.hasPrefix("modern.transit.cycleChapter.")
        case "transit-timeline":
            false
        case "planet-paths":
            request.key.hasPrefix("shared.bodyMotion.")
                || request.key.hasPrefix("shared.lifeAreas.")
        case "life-areas":
            request.key.hasPrefix("shared.lifeAreas.")
        case "active-transits":
            request.key.hasPrefix("modern.transit.activeTransitShort.")
        default:
            false
        }
    }

    private func makeRealChartFixtures() async throws -> [RealFixture] {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let profiles: [(String, Date, GeographicLocation, String)] = [
            ("real-chart-01", utcDate(1984, 2, 19, 6), GeographicLocation(latitudeDegrees: 51.5074, longitudeDegrees: -0.1278), "Europe/London"),
            ("real-chart-02", utcDate(1990, 7, 8, 14), GeographicLocation(latitudeDegrees: 40.7128, longitudeDegrees: -74.0060), "America/New_York"),
            ("real-chart-03", utcDate(1995, 11, 23, 2), GeographicLocation(latitudeDegrees: 31.2304, longitudeDegrees: 121.4737), "Asia/Shanghai"),
            ("real-chart-04", utcDate(2001, 4, 15, 20), GeographicLocation(latitudeDegrees: -33.8688, longitudeDegrees: 151.2093), "Australia/Sydney"),
            ("real-chart-05", utcDate(1978, 9, 30, 10), GeographicLocation(latitudeDegrees: -23.5505, longitudeDegrees: -46.6333), "America/Sao_Paulo"),
        ]
        let transitDates = [
            utcDate(2026, 2, 1, 12),
            utcDate(2026, 5, 1, 12),
            utcDate(2026, 8, 2, 12),
            utcDate(2026, 11, 1, 12),
        ]
        var fixtures: [RealFixture] = []
        for profile in profiles {
            let natal = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.1, location: profile.2),
                preset: .modern
            )
            for transitDate in transitDates {
                let moving = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: transitDate, location: profile.2),
                    preset: .modern
                )
                let aspects = SwissEphemerisCalculator.compare(
                    moving: moving,
                    reference: natal,
                    orbDegrees: 6
                )
                let timeZone = TimeZone(identifier: profile.3) ?? TimeZone(secondsFromGMT: 0)!
                let bundle = TransitFactBundleBuilder.build(
                    snapshot: moving,
                    natal: natal,
                    crossAspects: aspects,
                    transitWindows: [],
                    planetEvents: [],
                    transitCalendar: [],
                    rangeDays: 30,
                    preset: "modern",
                    timeZone: timeZone
                )
                fixtures.append(
                    RealFixture(
                        chartID: profile.0,
                        fixture: Fixture(
                            name: "\(profile.0)-\(Int(transitDate.timeIntervalSince1970))",
                            bundle: bundle
                        )
                    )
                )
            }
        }
        return fixtures
    }

    private func makeReachabilityProbeFixtures() -> [Fixture] {
        var fixtures: [Fixture] = []
        let toneKinds: [(String, AspectKind)] = [
            ("supportive", .trine),
            ("challenging", .square),
            ("neutral", .conjunction),
        ]
        for movingBody in CelestialBody.allCases {
            for referenceBody in CelestialBody.allCases {
                for toneKind in toneKinds {
                    for house in 1 ... 12 {
                        let scopeID = "probe-aspect-\(movingBody.rawValue)-\(referenceBody.rawValue)-\(toneKind.0)-\(house)"
                        let value = aspect(
                            movingID: movingBody.rawValue,
                            referenceID: referenceBody.rawValue,
                            kind: toneKind.1,
                            phase: .applying,
                            strength: 0.9,
                            house: house,
                            band: TransitCycleBand(movingID: movingBody.rawValue)
                        )
                        fixtures.append(
                            Fixture(
                                name: scopeID,
                                bundle: makeBundle(
                                    scopeID: scopeID,
                                    aspects: [value],
                                    windows: [],
                                    events: [],
                                    placements: [],
                                    lifeAreas: [],
                                    calendar: []
                                )
                            )
                        )
                    }
                }
            }
        }
        for body in CelestialBody.allCases {
            let states = body == .sun || body == .moon ? [false] : [false, true]
            for retrograde in states {
                for house in 1 ... 12 {
                    let scopeID = "probe-path-\(body.rawValue)-\(retrograde ? "retrograde" : "direct")-\(house)"
                    let placement = TransitPlanetPlacementFact(
                        factID: "transit.template.placement.\(body.rawValue)",
                        body: body,
                        longitudeDegrees: Double(house * 30 - 15),
                        signIndex: (house - 1) % 12,
                        degreeInSign: 15,
                        natalHouse: house,
                        retrograde: retrograde,
                        longitudeSpeedDegreesPerDay: retrograde ? -0.1 : 0.1
                    )
                    fixtures.append(
                        Fixture(
                            name: scopeID,
                            bundle: makeBundle(
                                scopeID: scopeID,
                                aspects: [],
                                windows: [],
                                events: [],
                                placements: [placement],
                                lifeAreas: [],
                                calendar: []
                            )
                        )
                    )
                }
            }
        }
        for house in 1 ... 12 {
            let scopeID = "probe-life-area-\(house)"
            let area = TransitLifeAreaFact(
                factID: "transit.template.life-area.\(house)",
                house: house,
                normalizedScore: 1,
                contributingFactIDs: []
            )
            fixtures.append(
                Fixture(
                    name: scopeID,
                    bundle: makeBundle(
                        scopeID: scopeID,
                        aspects: [],
                        windows: [],
                        events: [],
                        placements: [],
                        lifeAreas: [area],
                        calendar: []
                    )
                )
            )
        }
        for house in 1 ... 12 {
            fixtures.append(eventProbeFixture(kind: .houseIngress, toIndex: house))
        }
        fixtures.append(eventProbeFixture(kind: .signIngress, toIndex: 4))
        fixtures.append(eventProbeFixture(kind: .stationRetrograde, toIndex: nil))
        fixtures.append(eventProbeFixture(kind: .stationDirect, toIndex: nil))
        return fixtures
    }

    private func eventProbeFixture(kind: TransitPlanetEventKind, toIndex: Int?) -> Fixture {
        let scopeID = "probe-event-\(kind.rawValue)-\(toIndex ?? 0)"
        let event = TransitPlanetEventFact(
            factID: "transit.template.planet-event.mercury.\(kind.rawValue).\(toIndex ?? 0)",
            body: .mercury,
            kind: kind,
            timestamp: testAnchor.addingTimeInterval(day),
            timeZoneIdentifier: testTimeZone,
            fromIndex: toIndex.map { max(1, $0 - 1) },
            toIndex: toIndex
        )
        return Fixture(
            name: scopeID,
            bundle: makeBundle(
                scopeID: scopeID,
                aspects: [],
                windows: [],
                events: [event],
                placements: [],
                lifeAreas: [],
                calendar: []
            )
        )
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private var ephemerisDirectory: URL {
        let bundledCandidates = [
            Bundle.main.url(forResource: "ephe", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("ephe", isDirectory: true),
        ].compactMap { $0 }
        if let bundled = bundledCandidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) {
            return bundled
        }
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }

    private struct Fixture {
        let name: String
        let bundle: TransitFactBundle
    }

    private let testAnchor = Date(timeIntervalSince1970: 1_775_232_000)
    private let testTimeZone = "Asia/Shanghai"
    private let day: TimeInterval = 86_400

    private func makeFixtures() -> [Fixture] {
        let saturn = saturnAspect()
        return [
            Fixture(name: "mixed-complete", bundle: makeBundle()),
            Fixture(name: "supportive-only", bundle: makeBundle(scopeID: "supportive", aspects: [jupiterAspect()])),
            Fixture(name: "challenging-only", bundle: makeBundle(scopeID: "challenging", aspects: [saturn])),
            Fixture(name: "neutral-only", bundle: makeBundle(scopeID: "neutral", aspects: [mercuryAspect()])),
            Fixture(name: "empty", bundle: makeBundle(scopeID: "empty-fixture", aspects: [], windows: [], events: [], placements: [], lifeAreas: [], calendar: [])),
            Fixture(name: "windows-only", bundle: makeBundle(scopeID: "windows", aspects: [], windows: [window(aspect: nil, exactOffsetDays: 2)], events: [])),
            Fixture(name: "events-only", bundle: makeBundle(scopeID: "events", aspects: [], windows: [], events: makePlanetEvents())),
            Fixture(name: "returning-pass", bundle: makeBundle(scopeID: "repeat", aspects: [saturn], windows: [window(aspect: saturn, exactOffsetDays: 2, repeatOffsetDays: 12, nextOffsetDays: 24, passCount: 3)], rangeDays: 30)),
            Fixture(name: "complete-paths-areas", bundle: makeBundle(scopeID: "collections", aspects: [], windows: [], events: [], placements: makePlacements(), lifeAreas: makeLifeAreas())),
            Fixture(name: "range-filter", bundle: makeBundle(scopeID: "range", aspects: [saturn], windows: [window(aspect: saturn, exactOffsetDays: 40)], events: [planetEvent(kind: .signIngress, offsetDays: 40)], rangeDays: 7)),
            Fixture(name: "stabilizing-signal", bundle: makeBundle(scopeID: "stabilizing", aspects: [stabilizingAspect()], windows: [], events: [])),
            Fixture(name: "disrupting-signal", bundle: makeBundle(scopeID: "disrupting", aspects: [uranusAspect()], windows: [], events: [])),
            Fixture(name: "no-window-signals", bundle: makeBundle(scopeID: "no-window", aspects: [saturn, jupiterAspect()], windows: [], events: [])),
            Fixture(name: "same-theme-multi-signal", bundle: makeBundle(scopeID: "same-theme", aspects: [jupiterSunAspect(), marsSunAspect()], windows: [], events: [])),
        ]
    }

    private func makeBundle(
        scopeID: String = "scope",
        preset: String = "modern",
        aspects: [TransitAspectFact]? = nil,
        windows: [TransitWindowFact]? = nil,
        events: [TransitPlanetEventFact]? = nil,
        placements: [TransitPlanetPlacementFact]? = nil,
        lifeAreas: [TransitLifeAreaFact]? = nil,
        calendar: [TransitCalendarFact]? = nil,
        rangeDays: Int = 30
    ) -> TransitFactBundle {
        let resolvedAspects = aspects ?? [marsAspect(), saturnAspect(), jupiterAspect()]
        let resolvedWindows = windows ?? [
            window(aspect: saturnAspect(), exactOffsetDays: 2),
            window(aspect: marsAspect(), exactOffsetDays: 3),
        ]
        let scopedAspects = resolvedAspects.map { scoped($0, scopeID: scopeID) }
        let aspectIDsByKey = Dictionary(uniqueKeysWithValues: scopedAspects.map {
            ("\($0.movingID).\($0.kind.rawValue).\($0.referenceID)", $0.factID)
        })
        let scopedWindows = resolvedWindows.map { value in
            let key = "\(value.movingID).\(value.kind.rawValue).\(value.referenceID)"
            return scoped(value, scopeID: scopeID, sourceAspectFactID: aspectIDsByKey[key])
        }
        let links = Dictionary(
            grouping: scopedWindows.compactMap { value -> (String, String)? in
                value.sourceAspectFactID.map { ($0, value.factID) }
            },
            by: \.0
        ).mapValues { $0.map(\.1).sorted() }

        return TransitFactBundle(
            scopeID: scopeID,
            anchorDate: testAnchor,
            timeZoneIdentifier: testTimeZone,
            rangeDays: rangeDays,
            preset: preset,
            crossAspects: scopedAspects,
            transitWindows: scopedWindows,
            aspectWindowFactIDs: links,
            planetEvents: (events ?? makePlanetEvents()).map { scoped($0, scopeID: scopeID) },
            planetPlacements: (placements ?? makePlacements()).map { scoped($0, scopeID: scopeID) },
            lifeAreaScores: (lifeAreas ?? makeLifeAreas()).map { scoped($0, scopeID: scopeID) },
            transitCalendar: (calendar ?? makeCalendar()).map { scoped($0, scopeID: scopeID) }
        )
    }

    private func saturnAspect() -> TransitAspectFact {
        aspect(movingID: "saturn", referenceID: "sun", kind: .square, phase: .applying, strength: 0.92, house: 10, band: .longTerm)
    }

    private func jupiterAspect() -> TransitAspectFact {
        aspect(movingID: "jupiter", referenceID: "moon", kind: .trine, phase: .separating, strength: 0.80, house: 2, band: .current)
    }

    private func stabilizingAspect() -> TransitAspectFact {
        aspect(movingID: "venus", referenceID: "moon", kind: .trine, phase: .applying, strength: 0.88, house: 4, band: .daily)
    }

    private func uranusAspect() -> TransitAspectFact {
        aspect(movingID: "uranus", referenceID: "moon", kind: .square, phase: .applying, strength: 0.86, house: 4, band: .longTerm)
    }

    private func jupiterSunAspect() -> TransitAspectFact {
        aspect(movingID: "jupiter", referenceID: "sun", kind: .trine, phase: .applying, strength: 0.84, house: 1, band: .current)
    }

    private func marsSunAspect() -> TransitAspectFact {
        aspect(movingID: "mars", referenceID: "sun", kind: .trine, phase: .separating, strength: 0.76, house: 1, band: .daily)
    }

    private func marsAspect() -> TransitAspectFact {
        aspect(movingID: "mars", referenceID: "venus", kind: .opposition, phase: .exact, strength: 0.72, house: 7, band: .daily)
    }

    private func mercuryAspect() -> TransitAspectFact {
        aspect(movingID: "mercury", referenceID: "mercury", kind: .conjunction, phase: .applying, strength: 0.81, house: 3, band: .daily)
    }

    private func aspect(
        movingID: String,
        referenceID: String,
        kind: AspectKind,
        phase: AspectPhase,
        strength: Double,
        house: Int,
        band: TransitCycleBand
    ) -> TransitAspectFact {
        TransitAspectFact(
            factID: "transit.template.aspect.\(movingID).\(kind.rawValue).\(referenceID)",
            movingID: movingID,
            referenceID: referenceID,
            kind: kind,
            orbDegrees: max(0.1, 2 - strength),
            phase: phase,
            strength: strength,
            movingLongitude: Double(house * 30 - 15),
            referenceLongitude: Double((house + 3) * 30 - 15),
            natalHouse: house,
            cycleBand: band
        )
    }

    private func window(
        aspect: TransitAspectFact?,
        exactOffsetDays: Double,
        startOffsetDays: Double? = nil,
        endOffsetDays: Double? = nil,
        repeatOffsetDays: Double? = nil,
        nextOffsetDays: Double? = nil,
        passCount: Int = 1
    ) -> TransitWindowFact {
        let movingID = aspect?.movingID ?? "jupiter"
        let referenceID = aspect?.referenceID ?? "sun"
        let kind = aspect?.kind ?? .trine
        let exact = testAnchor.addingTimeInterval(exactOffsetDays * day)
        return TransitWindowFact(
            factID: "transit.template.window.\(movingID).\(kind.rawValue).\(referenceID).\(Int(exact.timeIntervalSince1970))",
            sourceAspectFactID: aspect?.factID,
            movingID: movingID,
            referenceID: referenceID,
            kind: kind,
            movingLongitude: aspect?.movingLongitude ?? 75,
            natalHouse: aspect?.natalHouse ?? 5,
            start: startOffsetDays.map { testAnchor.addingTimeInterval($0 * day) }
                ?? exact.addingTimeInterval(-day),
            exact: exact,
            end: endOffsetDays.map { testAnchor.addingTimeInterval($0 * day) }
                ?? exact.addingTimeInterval(day),
            repeatExact: repeatOffsetDays.map { testAnchor.addingTimeInterval($0 * day) },
            nextExact: nextOffsetDays.map { testAnchor.addingTimeInterval($0 * day) },
            passIndex: 1,
            passCount: passCount,
            returning: passCount > 1,
            timeZoneIdentifier: testTimeZone,
            cycleBand: aspect?.cycleBand ?? .current
        )
    }

    private func makePlanetEvents() -> [TransitPlanetEventFact] {
        [
            planetEvent(kind: .signIngress, offsetDays: 1),
            planetEvent(kind: .houseIngress, offsetDays: 2),
            planetEvent(kind: .stationRetrograde, offsetDays: 3),
            planetEvent(kind: .stationDirect, offsetDays: 4),
        ]
    }

    private func planetEvent(
        kind: TransitPlanetEventKind,
        offsetDays: Double,
        body: CelestialBody = .mercury,
        fromIndex: Int? = nil,
        toIndex: Int? = nil
    ) -> TransitPlanetEventFact {
        let timestamp = testAnchor.addingTimeInterval(offsetDays * day)
        return TransitPlanetEventFact(
            factID: "transit.template.planet-event.\(body.rawValue).\(kind.rawValue).\(Int(timestamp.timeIntervalSince1970))",
            body: body,
            kind: kind,
            timestamp: timestamp,
            timeZoneIdentifier: testTimeZone,
            fromIndex: fromIndex ?? (kind == .signIngress || kind == .houseIngress ? 2 : nil),
            toIndex: toIndex ?? (kind == .signIngress || kind == .houseIngress ? 3 : nil)
        )
    }

    private func makePlacements() -> [TransitPlanetPlacementFact] {
        CelestialBody.allCases.enumerated().map { index, body in
            TransitPlanetPlacementFact(
                factID: "transit.template.placement.\(body.rawValue)",
                body: body,
                longitudeDegrees: Double(index * 27),
                signIndex: index % 12,
                degreeInSign: Double((index * 7) % 30),
                natalHouse: (index % 12) + 1,
                retrograde: index.isMultiple(of: 3) && body != .sun && body != .moon,
                longitudeSpeedDegreesPerDay: index.isMultiple(of: 3) ? -0.1 : 0.3
            )
        }
    }

    private func makeLifeAreas() -> [TransitLifeAreaFact] {
        (1 ... 12).map { house in
            TransitLifeAreaFact(
                factID: "transit.template.life-area.\(house)",
                house: house,
                normalizedScore: Double(13 - house) / 12,
                contributingFactIDs: ["transit.template.placement.\(CelestialBody.allCases[(house - 1) % CelestialBody.allCases.count].rawValue)"]
            )
        }
    }

    private func makeCalendar() -> [TransitCalendarFact] {
        (0 ..< 7).map { offset in
            TransitCalendarFact(
                factID: "transit.template.calendar.day-\(offset)",
                date: testAnchor.addingTimeInterval(Double(offset) * day),
                score: 40 + offset,
                sourceFactIDs: ["transit.template.calendar-source.day-\(offset)"],
                timeZoneIdentifier: testTimeZone
            )
        }
    }

    private func scoped(_ value: TransitAspectFact, scopeID: String) -> TransitAspectFact {
        TransitAspectFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            movingID: value.movingID,
            referenceID: value.referenceID,
            kind: value.kind,
            orbDegrees: value.orbDegrees,
            phase: value.phase,
            strength: value.strength,
            movingLongitude: value.movingLongitude,
            referenceLongitude: value.referenceLongitude,
            natalHouse: value.natalHouse,
            cycleBand: value.cycleBand
        )
    }

    private func scoped(
        _ value: TransitWindowFact,
        scopeID: String,
        sourceAspectFactID: String?
    ) -> TransitWindowFact {
        TransitWindowFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            sourceAspectFactID: sourceAspectFactID,
            movingID: value.movingID,
            referenceID: value.referenceID,
            kind: value.kind,
            movingLongitude: value.movingLongitude,
            natalHouse: value.natalHouse,
            start: value.start,
            exact: value.exact,
            end: value.end,
            repeatExact: value.repeatExact,
            nextExact: value.nextExact,
            passIndex: value.passIndex,
            passCount: value.passCount,
            returning: value.returning,
            timeZoneIdentifier: value.timeZoneIdentifier,
            cycleBand: value.cycleBand
        )
    }

    private func scoped(_ value: TransitPlanetEventFact, scopeID: String) -> TransitPlanetEventFact {
        TransitPlanetEventFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            body: value.body,
            kind: value.kind,
            timestamp: value.timestamp,
            timeZoneIdentifier: value.timeZoneIdentifier,
            fromIndex: value.fromIndex,
            toIndex: value.toIndex
        )
    }

    private func scoped(_ value: TransitPlanetPlacementFact, scopeID: String) -> TransitPlanetPlacementFact {
        TransitPlanetPlacementFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            body: value.body,
            longitudeDegrees: value.longitudeDegrees,
            signIndex: value.signIndex,
            degreeInSign: value.degreeInSign,
            natalHouse: value.natalHouse,
            retrograde: value.retrograde,
            longitudeSpeedDegreesPerDay: value.longitudeSpeedDegreesPerDay
        )
    }

    private func scoped(_ value: TransitLifeAreaFact, scopeID: String) -> TransitLifeAreaFact {
        TransitLifeAreaFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            house: value.house,
            normalizedScore: value.normalizedScore,
            contributingFactIDs: value.contributingFactIDs.map {
                $0.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID).")
            }
        )
    }

    private func scoped(_ value: TransitCalendarFact, scopeID: String) -> TransitCalendarFact {
        TransitCalendarFact(
            factID: value.factID.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID)."),
            date: value.date,
            score: value.score,
            sourceFactIDs: value.sourceFactIDs.map {
                $0.replacingOccurrences(of: "transit.template.", with: "transit.\(scopeID).")
            },
            timeZoneIdentifier: value.timeZoneIdentifier
        )
    }
}

final class ChartWheelGeometryTests: XCTestCase {
    func testAscendantAndDescendantStayOnHorizontalAxis() {
        let center = CGPoint(x: 100, y: 100)
        let ascendant = AstrologyWheelGeometry.point(
            center: center,
            radius: 80,
            longitude: 42,
            ascendantRotation: 42
        )
        let descendant = AstrologyWheelGeometry.point(
            center: center,
            radius: 80,
            longitude: 222,
            ascendantRotation: 42
        )

        XCTAssertEqual(ascendant.x, 20, accuracy: 0.0001)
        XCTAssertEqual(ascendant.y, 100, accuracy: 0.0001)
        XCTAssertEqual(descendant.x, 180, accuracy: 0.0001)
        XCTAssertEqual(descendant.y, 100, accuracy: 0.0001)
    }

    func testIncreasingLongitudeMovesBelowAscendant() {
        let center = CGPoint(x: 100, y: 100)
        let point = AstrologyWheelGeometry.point(
            center: center,
            radius: 80,
            longitude: 132,
            ascendantRotation: 42
        )

        XCTAssertEqual(point.x, 100, accuracy: 0.0001)
        XCTAssertEqual(point.y, 180, accuracy: 0.0001)
    }
}
