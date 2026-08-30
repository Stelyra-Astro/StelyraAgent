import AstroCore
import XCTest
@testable import StelyraAgent

final class ClassicalTransitPlanningTests: XCTestCase {
    func testTodayLongTermChoosesInitialExactWhenItIsStillAhead() {
        let now = Date(timeIntervalSince1970: 10_000)
        let initial = now.addingTimeInterval(100)
        let window = todayWindow(
            exact: initial,
            repeatExact: now.addingTimeInterval(200),
            nextExact: now.addingTimeInterval(300)
        )

        XCTAssertEqual(
            window.upcomingExactOccurrence(after: now),
            TransitExactOccurrence(date: initial, isReturn: false)
        )
    }

    func testTodayLongTermChoosesFirstFutureReturnInsteadOfPastRange() {
        let now = Date(timeIntervalSince1970: 10_000)
        let firstReturn = now.addingTimeInterval(200)
        let window = todayWindow(
            exact: now.addingTimeInterval(-100),
            repeatExact: firstReturn,
            nextExact: now.addingTimeInterval(300)
        )

        XCTAssertEqual(
            window.upcomingExactOccurrence(after: now),
            TransitExactOccurrence(date: firstReturn, isReturn: true)
        )
    }

    func testTodayLongTermHasNoUpcomingExactAfterLastPass() {
        let now = Date(timeIntervalSince1970: 10_000)
        let window = todayWindow(
            exact: now.addingTimeInterval(-300),
            repeatExact: now.addingTimeInterval(-200),
            nextExact: now.addingTimeInterval(-100)
        )

        XCTAssertNil(window.upcomingExactOccurrence(after: now))
    }

    func testTodayLongTermDatesAlwaysIncludeYear() {
        let date = utcDate(2026, 8, 14, 12)
        let timeZone = TimeZone(secondsFromGMT: 0)!

        XCTAssertTrue(
            LocalizedFormatters.shortDateWithYear(date, language: .english, timeZone: timeZone)
                .contains("2026")
        )
        XCTAssertTrue(
            LocalizedFormatters.shortDateWithYear(date, language: .simplifiedChinese, timeZone: timeZone)
                .contains("2026")
        )
    }

    func testTwentyFourFixturesPreserveTheFrozenSixCardContract() {
        let fixtures = makeFixtures()
        XCTAssertEqual(fixtures.count, 24)
        for fixture in fixtures {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            XCTAssertEqual(plan.preset, CalculationPreset.classical.rawValue, fixture.id)
            XCTAssertEqual(plan.cards.map(\.cardID), TransitContentPlan.cardIDs, fixture.id)
            XCTAssertTrue(plan.cards.allSatisfy { $0.scopeID == fixture.bundle.scopeID }, fixture.id)
            XCTAssertTrue(plan.cards.flatMap(\.sourceFactIDs).allSatisfy {
                $0.hasPrefix("transit.\(fixture.bundle.scopeID).")
            }, fixture.id)
            XCTAssertTrue(plan.cards.allSatisfy { $0.integratedThemeID == nil && $0.signalRoles.isEmpty }, fixture.id)
        }
    }

    func testUnsupportedConditionsRemainExplicitlyUnavailable() {
        let unsupported = makeFixtures().filter { !$0.supported }
        XCTAssertEqual(Set(unsupported.map(\.id)), Set(["day-sect", "night-sect", "prohibited-completion"]))
        XCTAssertTrue(unsupported.allSatisfy { $0.capabilityGap != nil })
        XCTAssertTrue(unsupported.allSatisfy {
            TransitContentPlanner.plan($0.bundle).card("current-story")?.evidence.isEmpty == true
        })
    }

    func testClassicalPlannerUsesOnlyClassicalSemanticOutput() throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        for fixture in makeFixtures() where fixture.supported {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            let requests = plan.cards.flatMap { matcher.transitCopyRequests(plan: $0) }
            XCTAssertTrue(requests.allSatisfy { $0.key.hasPrefix("classical.transit.") }, fixture.id)
            XCTAssertFalse(requests.contains { $0.key.hasPrefix("modern.transit.") }, fixture.id)
            XCTAssertTrue(matcher.transitCopyRequests(plan: plan.card("transit-timeline")!).isEmpty, fixture.id)
        }
    }

    func testMissingClassicalCopyFailsExplicitly() throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let missingPath = "classical.transit.test-only.missing-copy"
        XCTAssertThrowsError(try matcher.value(at: missingPath)) { error in
            guard case let CopyCatalogError.missingCopy(path) = error else {
                return XCTFail("Expected missing-copy, got \(error)")
            }
            XCTAssertEqual(path, missingPath)
        }
    }

    func testApprovedClassicalCopyRendersInEnglishAndSimplifiedChinese() throws {
        for language in [AppLanguage.english, .simplifiedChinese] {
            let matcher = try CopyCatalogMatcher(language: language)
            for fixture in domainProbeFixtures() {
                let plan = TransitContentPlanner.plan(fixture.bundle)
                for card in plan.cards where !matcher.transitCopyRequests(plan: card).isEmpty {
                    XCTAssertNoThrow(try matcher.transitCardText(plan: card), "\(language.rawValue):\(fixture.id):\(card.cardID)")
                }
            }
        }
    }

    func testCrossChartReceptionUsesAspectLongitudes() {
        XCTAssertTrue(
            HoraryEngine.reception(from: .jupiter, to: .mars, fromSignIndex: 0).isPresent
        )
        XCTAssertFalse(
            HoraryEngine.reception(from: .jupiter, to: .venus, fromSignIndex: 0).isPresent
        )
    }

    func testClassicalWindowThemeTracksTheAnchorPhase() {
        let applyingPlan = TransitContentPlanner.plan(
            makeBundle(scopeID: "window-applying", aspects: [aspect()], windows: [window()])
        )
        XCTAssertEqual(
            applyingPlan.card("current-cycles")?.themeInputs.first?.classicalThemeID,
            .applyingContact
        )

        let separatingWindow = TransitWindowFact(
            factID: "window.jupiter.trine.sun.separating",
            sourceAspectFactID: nil,
            movingID: CelestialBody.jupiter.rawValue,
            referenceID: CelestialBody.sun.rawValue,
            kind: .trine,
            movingLongitude: 15,
            natalHouse: 1,
            start: anchor.addingTimeInterval(-172_800),
            exact: anchor.addingTimeInterval(-86_400),
            end: anchor.addingTimeInterval(86_400),
            repeatExact: nil,
            nextExact: nil,
            passIndex: 1,
            passCount: 1,
            returning: false,
            timeZoneIdentifier: "Asia/Shanghai",
            cycleBand: .current
        )
        let separatingPlan = TransitContentPlanner.plan(
            makeBundle(scopeID: "window-separating", aspects: [aspect()], windows: [separatingWindow])
        )
        XCTAssertEqual(
            separatingPlan.card("current-cycles")?.themeInputs.first?.classicalThemeID,
            .separatingContact
        )
    }

    func testClassicalClaimModesAndEmptyStatesStayContracted() {
        for fixture in makeFixtures() {
            let plan = TransitContentPlanner.plan(fixture.bundle)
            let full = plan.cards.flatMap(\.evidence).filter { $0.claimMode == .full }
            XCTAssertLessThanOrEqual(full.count, 1, fixture.id)
            XCTAssertTrue(plan.card("current-cycles")!.evidence.allSatisfy { $0.claimMode == .aggregate }, fixture.id)
            XCTAssertTrue(plan.card("transit-timeline")!.evidence.allSatisfy { $0.claimMode == .technical }, fixture.id)
            XCTAssertTrue(plan.card("life-areas")!.evidence.allSatisfy { $0.claimMode == .aggregate }, fixture.id)
            XCTAssertTrue(plan.card("active-transits")!.evidence.allSatisfy { $0.claimMode != .full }, fixture.id)
            XCTAssertTrue(plan.cards.allSatisfy { $0.emptyState == .showInsufficientFacts }, fixture.id)
        }
    }

    func testDeterministicProbesCoverTheStaticClassicalCopyDomain() throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let identities = Set(domainProbeFixtures().flatMap { fixture in
            TransitContentPlanner.plan(fixture.bundle).cards.flatMap {
                matcher.transitCopyRequests(plan: $0).map(\.identity)
            }
        })
        let expectedCount = ClassicalTransitIntegratedThemeID.allCases.count
            + ClassicalTransitSignalRoleID.allCases.count
            + (3 * ClassicalTransitCopyDomain.cycleThemeIDs.count)
            + ClassicalTransitCopyDomain.planetPathThemeIDs.count
            + 12
            + ClassicalTransitCopyDomain.activeAspectThemeIDs.count
            + 4
        XCTAssertEqual(expectedCount, 71)
        XCTAssertEqual(identities.count, expectedCount)
    }

    func testExportClassicalTransitCopyReachability() async throws {
        let matcher = try CopyCatalogMatcher(language: .english)
        let fixtures = makeFixtures()
        var observations: [String: Observation] = [:]
        var validatedPlans: [TransitContentPlan] = []

        func record(_ plan: TransitContentPlan, scenarioID: String, kind: String) {
            validatedPlans.append(plan)
            for request in plan.cards.flatMap({ matcher.transitCopyRequests(plan: $0) }) {
                var value = observations[request.identity] ?? Observation(request: request)
                value.scenarioIDs.insert(scenarioID)
                value.scenarioKinds.insert(kind)
                value.occurrenceCount += 1
                observations[request.identity] = value
            }
        }

        for fixture in fixtures where fixture.supported {
            record(TransitContentPlanner.plan(fixture.bundle), scenarioID: fixture.id, kind: "fixed-fixture")
        }
        let domainProbes = domainProbeFixtures()
        for fixture in domainProbes {
            record(TransitContentPlanner.plan(fixture.bundle), scenarioID: fixture.id, kind: "finite-domain-probe")
        }

        let realRuns = try await makeRealRuns()
        for run in realRuns {
            record(run.plan, scenarioID: run.id, kind: "real-chart")
        }

        let payload = ExportPayload(
            schemaVersion: 1,
            fixtureCount: fixtures.count,
            fixtures: fixtures.map(\.record),
            realRunCount: realRuns.count,
            realRuns: realRuns.map { .init(id: $0.id, scopeID: $0.plan.scopeID, requestCount: $0.plan.cards.flatMap { matcher.transitCopyRequests(plan: $0) }.count) },
            finiteProbeCount: domainProbes.count,
            observations: observations.values.map(\.exported).sorted { $0.key < $1.key },
            capabilityGaps: fixtures.compactMap(\.capabilityGap).sorted(),
            contractMetrics: ContractMetrics(
                duplicateFullClaimCount: validatedPlans.reduce(0) { count, plan in
                    count + max(0, plan.cards.flatMap(\.evidence).filter { $0.claimMode == .full }.count - 1)
                },
                unstableScopeIDCount: validatedPlans.filter { plan in
                    plan.cards.contains { $0.scopeID != plan.scopeID }
                }.count,
                cardContractErrorCount: validatedPlans.filter {
                    $0.cards.map(\.cardID) != TransitContentPlan.cardIDs
                }.count,
                emptyStateContractErrorCount: validatedPlans.filter { plan in
                    plan.cards.contains { $0.emptyState != .showInsufficientFacts }
                }.count
            )
        )
        let data = try JSONEncoder().encode(payload)
        print("CLASSICAL_TRANSIT_COPY_OBSERVATIONS_BASE64:\(data.base64EncodedString())")
    }

    private struct Fixture {
        let id: String
        let supported: Bool
        let capabilityGap: String?
        let bundle: TransitFactBundle

        var record: FixtureRecord {
            FixtureRecord(id: id, supported: supported, capabilityGap: capabilityGap)
        }
    }

    private struct FixtureRecord: Codable {
        let id: String
        let supported: Bool
        let capabilityGap: String?
    }

    private struct RealRun {
        let id: String
        let plan: TransitContentPlan
    }

    private struct ExportRealRun: Codable {
        let id: String
        let scopeID: String
        let requestCount: Int
    }

    private struct ExportObservation: Codable {
        let key: String
        let cardID: String
        let copySlot: String
        let themeID: String?
        let integratedThemeID: String?
        let roleID: String?
        let variables: [String: String]
        let sourceFactIDs: [String]
        let occurrenceCount: Int
        let scenarioKinds: [String]
        let scenarioIDs: [String]
    }

    private struct Observation {
        let request: TransitCopyRequest
        var occurrenceCount = 0
        var scenarioKinds = Set<String>()
        var scenarioIDs = Set<String>()

        var exported: ExportObservation {
            ExportObservation(
                key: request.key,
                cardID: request.cardID,
                copySlot: request.copySlot,
                themeID: request.themeID,
                integratedThemeID: request.integratedThemeID,
                roleID: request.roleID,
                variables: request.variables,
                sourceFactIDs: request.sourceFactIDs,
                occurrenceCount: occurrenceCount,
                scenarioKinds: scenarioKinds.sorted(),
                scenarioIDs: scenarioIDs.sorted()
            )
        }
    }

    private struct ExportPayload: Codable {
        let schemaVersion: Int
        let fixtureCount: Int
        let fixtures: [FixtureRecord]
        let realRunCount: Int
        let realRuns: [ExportRealRun]
        let finiteProbeCount: Int
        let observations: [ExportObservation]
        let capabilityGaps: [String]
        let contractMetrics: ContractMetrics
    }

    private struct ContractMetrics: Codable {
        let duplicateFullClaimCount: Int
        let unstableScopeIDCount: Int
        let cardContractErrorCount: Int
        let emptyStateContractErrorCount: Int
    }

    private func makeFixtures() -> [Fixture] {
        let unsupported = { [self] (id: String, gap: String) in
            Fixture(id: id, supported: false, capabilityGap: gap, bundle: self.makeBundle(scopeID: id, aspects: [], placements: [], lifeAreas: []))
        }
        return [
            fixture("benefic-dominant", aspects: [aspect(body: .jupiter)]),
            fixture("malefic-dominant", aspects: [aspect(body: .saturn, kind: .square)]),
            fixture("mixed-testimony", aspects: [aspect(body: .jupiter), aspect(body: .saturn, kind: .square, reference: .moon)]),
            fixture("essential-dignity", aspects: [aspect(conditions: [.domicile])]),
            fixture("essential-debility", aspects: [aspect(conditions: [.fall])]),
            unsupported("day-sect", "AstroCore does not expose a sect/day-chart fact for Transit planning."),
            unsupported("night-sect", "AstroCore does not expose a sect/night-chart fact for Transit planning."),
            fixture("reception", aspects: [aspect(reception: true)]),
            fixture("no-reception", aspects: [aspect(reception: false)]),
            fixture("applying", aspects: [aspect(phase: .applying)]),
            fixture("separating", aspects: [aspect(phase: .separating)]),
            fixture("completion-window", aspects: [aspect()], windows: [window()]),
            unsupported("prohibited-completion", "AstroCore does not expose prohibition, frustration, or prevented-perfection facts."),
            fixture("retrograde", aspects: [aspect(conditions: [.retrograde])]),
            fixture("station-retrograde", aspects: [], events: [event(.stationRetrograde)]),
            fixture("station-direct", aspects: [], events: [event(.stationDirect)]),
            fixture("solar-condition", aspects: [aspect(conditions: [.cazimi]), aspect(reference: .moon, conditions: [.combust]), aspect(reference: .venus, conditions: [.underBeams])]),
            fixture("house-strength", aspects: [aspect(conditions: [.angular]), aspect(reference: .moon, conditions: [.succedent]), aspect(reference: .venus, conditions: [.cadent])]),
            fixture("returning-pass", aspects: [aspect()], windows: [window(returning: true)]),
            fixture("events-only", aspects: [], events: [event(.signIngress), event(.houseIngress)]),
            fixture("aspects-no-window", aspects: [aspect()], windows: []),
            fixture("sparse-facts", aspects: [aspect()], placements: [], lifeAreas: []),
            fixture("duplicate-theme-evidence", aspects: [aspect(), aspect(reference: .moon)]),
            fixture("empty", aspects: [], placements: [], lifeAreas: []),
        ]
    }

    private func fixture(
        _ id: String,
        aspects: [TransitAspectFact],
        windows: [TransitWindowFact] = [],
        events: [TransitPlanetEventFact] = [],
        placements: [TransitPlanetPlacementFact]? = nil,
        lifeAreas: [TransitLifeAreaFact]? = nil
    ) -> Fixture {
        Fixture(
            id: id,
            supported: true,
            capabilityGap: nil,
            bundle: makeBundle(scopeID: id, aspects: aspects, windows: windows, events: events, placements: placements, lifeAreas: lifeAreas)
        )
    }

    private func makeBundle(
        scopeID: String,
        aspects: [TransitAspectFact],
        windows: [TransitWindowFact] = [],
        events: [TransitPlanetEventFact] = [],
        placements: [TransitPlanetPlacementFact]? = nil,
        lifeAreas: [TransitLifeAreaFact]? = nil
    ) -> TransitFactBundle {
        let prefix = "transit.\(scopeID)."
        let scopedAspects = aspects.map { scoped($0, prefix: prefix) }
        let firstAspectID = scopedAspects.first?.factID
        let scopedWindows = windows.map { value in
            TransitWindowFact(
                factID: prefix + value.factID,
                sourceAspectFactID: firstAspectID,
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
        let scopedEvents = events.map { value in
            TransitPlanetEventFact(
                factID: prefix + value.factID,
                body: value.body,
                kind: value.kind,
                timestamp: value.timestamp,
                timeZoneIdentifier: value.timeZoneIdentifier,
                fromIndex: value.fromIndex,
                toIndex: value.toIndex
            )
        }
        let resolvedPlacements = placements ?? [placement()]
        let scopedPlacements = resolvedPlacements.map { value in
            TransitPlanetPlacementFact(
                factID: prefix + value.factID,
                body: value.body,
                longitudeDegrees: value.longitudeDegrees,
                signIndex: value.signIndex,
                degreeInSign: value.degreeInSign,
                natalHouse: value.natalHouse,
                retrograde: value.retrograde,
                longitudeSpeedDegreesPerDay: value.longitudeSpeedDegreesPerDay,
                classicalScore: value.classicalScore,
                classicalConditions: value.classicalConditions
            )
        }
        let contributors = scopedAspects.map(\.factID) + scopedPlacements.map(\.factID)
        let scopedAreas = (lifeAreas ?? (1 ... 12).map { house in
            TransitLifeAreaFact(factID: "area.\(house)", house: house, normalizedScore: Double(13 - house) / 12, contributingFactIDs: contributors)
        }).map {
            TransitLifeAreaFact(factID: prefix + $0.factID, house: $0.house, normalizedScore: $0.normalizedScore, contributingFactIDs: contributors)
        }
        return TransitFactBundle(
            scopeID: scopeID,
            anchorDate: anchor,
            timeZoneIdentifier: "Asia/Shanghai",
            rangeDays: 30,
            preset: CalculationPreset.classical.rawValue,
            crossAspects: scopedAspects,
            transitWindows: scopedWindows,
            aspectWindowFactIDs: firstAspectID.map { [$0: scopedWindows.map(\.factID)] } ?? [:],
            planetEvents: scopedEvents,
            planetPlacements: scopedPlacements,
            lifeAreaScores: scopedAreas,
            transitCalendar: []
        )
    }

    private func aspect(
        body: CelestialBody = .jupiter,
        kind: AspectKind = .trine,
        reference: CelestialBody = .sun,
        phase: AspectPhase = .applying,
        conditions: [TraditionalCondition] = [],
        reception: Bool = false
    ) -> TransitAspectFact {
        TransitAspectFact(
            factID: "aspect.\(body.rawValue).\(kind.rawValue).\(reference.rawValue)",
            movingID: body.rawValue,
            referenceID: reference.rawValue,
            kind: kind,
            orbDegrees: 1,
            phase: phase,
            strength: 0.9,
            movingLongitude: 15,
            referenceLongitude: 135,
            natalHouse: 1,
            cycleBand: TransitCycleBand(movingID: body.rawValue),
            classicalContext: ClassicalTransitAspectContext(
                movingScore: conditions.contains(.fall) ? -15 : conditions.contains(.domicile) ? 15 : 0,
                movingConditions: conditions,
                receptionFromMoving: reception,
                receptionFromReference: false
            )
        )
    }

    private func scoped(_ value: TransitAspectFact, prefix: String) -> TransitAspectFact {
        TransitAspectFact(
            factID: prefix + value.factID,
            movingID: value.movingID,
            referenceID: value.referenceID,
            kind: value.kind,
            orbDegrees: value.orbDegrees,
            phase: value.phase,
            strength: value.strength,
            movingLongitude: value.movingLongitude,
            referenceLongitude: value.referenceLongitude,
            natalHouse: value.natalHouse,
            cycleBand: value.cycleBand,
            classicalContext: value.classicalContext
        )
    }

    private func placement(_ conditions: [TraditionalCondition] = [.angular]) -> TransitPlanetPlacementFact {
        TransitPlanetPlacementFact(
            factID: "placement.jupiter",
            body: .jupiter,
            longitudeDegrees: 15,
            signIndex: 0,
            degreeInSign: 15,
            natalHouse: 1,
            retrograde: conditions.contains(.retrograde),
            longitudeSpeedDegreesPerDay: conditions.contains(.retrograde) ? -0.1 : 0.1,
            classicalScore: 10,
            classicalConditions: conditions
        )
    }

    private func window(
        body: CelestialBody = .jupiter,
        cycleBand: TransitCycleBand = .current,
        returning: Bool = false
    ) -> TransitWindowFact {
        TransitWindowFact(
            factID: "window.\(body.rawValue).trine.sun",
            sourceAspectFactID: nil,
            movingID: body.rawValue,
            referenceID: CelestialBody.sun.rawValue,
            kind: .trine,
            movingLongitude: 15,
            natalHouse: 1,
            start: anchor.addingTimeInterval(-86_400),
            exact: anchor.addingTimeInterval(86_400),
            end: anchor.addingTimeInterval(172_800),
            repeatExact: returning ? anchor.addingTimeInterval(259_200) : nil,
            nextExact: nil,
            passIndex: 1,
            passCount: returning ? 2 : 1,
            returning: returning,
            timeZoneIdentifier: "Asia/Shanghai",
            cycleBand: cycleBand
        )
    }

    private func event(_ kind: TransitPlanetEventKind) -> TransitPlanetEventFact {
        TransitPlanetEventFact(
            factID: "event.mercury.\(kind.rawValue)",
            body: .mercury,
            kind: kind,
            timestamp: anchor.addingTimeInterval(86_400),
            timeZoneIdentifier: "Asia/Shanghai",
            fromIndex: kind == .signIngress || kind == .houseIngress ? 2 : nil,
            toIndex: kind == .signIngress || kind == .houseIngress ? 3 : nil
        )
    }

    private func probeFixture(_ theme: ClassicalTransitThemeID) -> Fixture {
        let id = "probe-\(theme.rawValue)"
        switch theme {
        case .fortifiedPlanet: return fixture(id, aspects: [aspect(conditions: [.domicile])], placements: [placement([.domicile])])
        case .debilitatedPlanet: return fixture(id, aspects: [aspect(conditions: [.fall])], placements: [placement([.fall])])
        case .receptionSupport: return fixture(id, aspects: [aspect(reception: true)])
        case .applyingContact: return fixture(id, aspects: [aspect(phase: .applying)])
        case .exactContact: return fixture(id, aspects: [aspect(phase: .exact)])
        case .separatingContact: return fixture(id, aspects: [aspect(phase: .separating)])
        case .retrogradeReview: return fixture(id, aspects: [aspect(conditions: [.retrograde])], placements: [placement([.retrograde])])
        case .solarFortification: return fixture(id, aspects: [aspect(conditions: [.cazimi])], placements: [placement([.cazimi])])
        case .solarImpairment: return fixture(id, aspects: [aspect(conditions: [.combust])], placements: [placement([.combust])])
        case .angularEmphasis: return fixture(id, aspects: [aspect()], placements: [placement([.angular])])
        case .succedentContinuity: return fixture(id, aspects: [aspect()], placements: [placement([.succedent])])
        case .cadentDelay: return fixture(id, aspects: [aspect()], placements: [placement([.cadent])])
        case .motionChange: return fixture(id, aspects: [], events: [event(.stationRetrograde)])
        case .houseActivation: return fixture(id, aspects: [])
        }
    }

    private func domainProbeFixtures() -> [Fixture] {
        var probes = ClassicalTransitThemeID.allCases.map(probeFixture)
        probes += [
            fixture("probe-integrated-supported", aspects: [aspect(body: .jupiter)]),
            fixture("probe-integrated-constrained", aspects: [aspect(body: .saturn, kind: .square)]),
            fixture("probe-integrated-mixed", aspects: [aspect(body: .jupiter), aspect(body: .saturn, kind: .square, reference: .moon)]),
            fixture("probe-role-benefic", aspects: [aspect(body: .jupiter)]),
            fixture("probe-role-malefic", aspects: [aspect(body: .saturn, kind: .square)]),
            fixture("probe-role-fortified", aspects: [aspect(conditions: [.domicile])]),
            fixture("probe-role-impaired", aspects: [aspect(conditions: [.fall])]),
            fixture("probe-role-received", aspects: [aspect(reception: true)]),
        ]
        let cycleRoles: [(TransitEvidenceRole, TransitCycleBand, CelestialBody)] = [
            (.longCycle, .longTerm, .saturn),
            (.currentCycle, .current, .jupiter),
            (.dailyCycle, .daily, .mercury),
        ]
        for (role, band, body) in cycleRoles {
            for theme in ClassicalTransitCopyDomain.cycleThemeIDs {
                let id = "probe-cycle-\(role.rawValue)-\(theme.rawValue)"
                if theme == .motionChange {
                    probes.append(
                        fixture(
                            id,
                            aspects: [aspect(body: body)],
                            windows: [window(body: body, cycleBand: band, returning: true)]
                        )
                    )
                } else {
                    probes.append(fixture(id, aspects: [aspect(body: body, theme: theme)]))
                }
            }
        }
        probes += (1 ... 12).map { house in
            fixture(
                "probe-life-area-\(house)",
                aspects: [],
                placements: [],
                lifeAreas: [
                    TransitLifeAreaFact(
                        factID: "area.\(house)",
                        house: house,
                        normalizedScore: 1,
                        contributingFactIDs: []
                    ),
                ]
            )
        }
        probes += [
            fixture("probe-active-sign-ingress", aspects: [], events: [event(.signIngress)]),
            fixture("probe-active-house-ingress", aspects: [], events: [event(.houseIngress)]),
            fixture("probe-active-station-retrograde", aspects: [], events: [event(.stationRetrograde)]),
            fixture("probe-active-station-direct", aspects: [], events: [event(.stationDirect)]),
        ]
        return probes
    }

    private func aspect(body: CelestialBody, theme: ClassicalTransitThemeID) -> TransitAspectFact {
        switch theme {
        case .fortifiedPlanet: aspect(body: body, conditions: [.domicile])
        case .debilitatedPlanet: aspect(body: body, conditions: [.fall])
        case .receptionSupport: aspect(body: body, reception: true)
        case .applyingContact: aspect(body: body, phase: .applying)
        case .exactContact: aspect(body: body, phase: .exact)
        case .separatingContact: aspect(body: body, phase: .separating)
        case .retrogradeReview: aspect(body: body, conditions: [.retrograde])
        case .solarFortification: aspect(body: body, conditions: [.cazimi])
        case .solarImpairment: aspect(body: body, conditions: [.combust])
        case .angularEmphasis, .succedentContinuity, .cadentDelay, .motionChange, .houseActivation:
            aspect(body: body)
        }
    }

    private func makeRealRuns() async throws -> [RealRun] {
        let calculator = try SwissEphemerisCalculator(ephemerisDirectory: ephemerisDirectory)
        let profiles: [(String, Date, GeographicLocation)] = [
            ("shanghai", utcDate(1995, 11, 23, 2), .init(latitudeDegrees: 31.2304, longitudeDegrees: 121.4737)),
            ("london", utcDate(1984, 2, 19, 6), .init(latitudeDegrees: 51.5074, longitudeDegrees: -0.1278)),
            ("new-york", utcDate(1990, 7, 8, 14), .init(latitudeDegrees: 40.7128, longitudeDegrees: -74.0060)),
        ]
        let dates = [utcDate(2026, 2, 1, 12), utcDate(2026, 8, 2, 12), utcDate(2026, 11, 1, 12)]
        var result: [RealRun] = []
        for profile in profiles {
            let natal = try await calculator.calculateSnapshot(NatalInput(utcDate: profile.1, location: profile.2), preset: .classical)
            for date in dates {
                let moving = try await calculator.calculateSnapshot(NatalInput(utcDate: date, location: profile.2), preset: .classical)
                let aspects = SwissEphemerisCalculator.compare(moving: moving, reference: natal, orbDegrees: CalculationPreset.classical.defaultOrbDegrees)
                let bundle = TransitFactBundleBuilder.build(
                    snapshot: moving,
                    natal: natal,
                    crossAspects: aspects,
                    transitWindows: [],
                    planetEvents: [],
                    transitCalendar: [],
                    rangeDays: 30,
                    preset: CalculationPreset.classical.rawValue,
                    timeZone: TimeZone(secondsFromGMT: 0)!
                )
                result.append(RealRun(id: "\(profile.0)-\(Int(date.timeIntervalSince1970))", plan: TransitContentPlanner.plan(bundle)))
            }
        }
        return result
    }

    private func utcDate(_ year: Int, _ month: Int, _ day: Int, _ hour: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!
    }

    private func todayWindow(
        exact: Date,
        repeatExact: Date?,
        nextExact: Date?
    ) -> ChartEventData.TransitWindow {
        ChartEventData.TransitWindow(
            first: .saturn,
            second: .sun,
            kind: .conjunction,
            firstLongitude: 0,
            start: exact.addingTimeInterval(-1_000),
            exact: exact,
            end: exact.addingTimeInterval(1_000),
            repeatExact: repeatExact,
            nextExact: nextExact,
            passIndex: 1,
            passCount: 3,
            returning: repeatExact != nil || nextExact != nil
        )
    }

    private var ephemerisDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("vendor/swisseph/ephe", isDirectory: true)
    }

    private let anchor = Date(timeIntervalSince1970: 1_775_232_000)
}
