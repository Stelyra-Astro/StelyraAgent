import AstroCore
import Foundation

/// Technique-specific local event discovery. Output resolution is a grouping
/// preference for the answer, never a command to render one full chart per
/// bucket. Internal scan cadence is bounded independently from UI resolution.
@MainActor
final class AgentTechniquePlanner {
    let maxScanAnchors = 128

    func timingFacts(
        capability: AgentCapability,
        start: Date?,
        end: Date?,
        outputResolution: String?,
        profile: UserProfile,
        location: ChartLocationSelection,
        preset: CalculationPreset,
        calculator: SwissEphemerisCalculator
    ) async throws -> [AgentEvidenceFact] {
        guard let start, let end, end > start else { return [] }
        switch capability {
        case .transit:
            return try await scanTransit(
                start: start, end: end, outputResolution: outputResolution,
                profile: profile, location: location, preset: preset, calculator: calculator
            )
        case .secondary:
            return try await scanSecondary(
                start: start, end: end, outputResolution: outputResolution,
                profile: profile, preset: preset, calculator: calculator
            )
        case .solarArc:
            return try await scanSolarArc(
                start: start, end: end, outputResolution: outputResolution,
                profile: profile, preset: preset, calculator: calculator
            )
        default:
            return []
        }
    }

    func relationshipTimingFacts(
        capability: AgentCapability,
        start: Date?,
        end: Date?,
        outputResolution: String?,
        firstID: String,
        first: UserProfile,
        secondID: String,
        second: UserProfile,
        location: ChartLocationSelection?,
        preset: CalculationPreset,
        calculator: SwissEphemerisCalculator
    ) async throws -> [AgentEvidenceFact] {
        guard let start, let end, end > start,
              let kind = relationshipTimingKind(capability),
              let relationshipPreset = relationshipPreset(preset)
        else { return [] }

        let cadence = relationshipScanCadence(start: start, end: end)
        let iso = ISO8601DateFormatter()
        var facts: [AgentEvidenceFact] = []
        var seen = Set<String>()
        var anchor = start
        var count = 0
        let perspectives: [RelationshipPerspective?] = {
            switch capability {
            case .marksSecondary, .marksTertiary: return [.first, .second]
            default: return [nil]
            }
        }()

        while anchor <= end && count < maxScanAnchors {
            let nextAnchor = min(end, anchor.addingTimeInterval(cadence))
            for perspective in perspectives {
                let artifact = try await calculator.calculateRelationshipChart(
                    RelationshipChartRequest(
                        kind: kind,
                        first: RelationshipPersonInput(id: firstID, birthDate: first.birthDateUTC, location: first.location),
                        second: RelationshipPersonInput(id: secondID, birthDate: second.birthDateUTC, location: second.location),
                        preset: relationshipPreset,
                        targetDate: anchor,
                        transitLocation: relationshipNeedsTransitLocation(kind) ? location?.geographicLocation : nil,
                        perspective: perspective
                    )
                )
                let aspects = artifact.comparisonAspects.isEmpty
                    ? artifact.snapshot.aspects
                    : artifact.comparisonAspects
                for aspect in aspects.sorted(by: { $0.strength > $1.strength }).prefix(8) {
                    guard aspect.strength >= 0.55 else { continue }
                    let key = "\(kind.rawValue)|\(perspective?.rawValue ?? "shared")|\(aspect.firstID)|\(aspect.secondID)|\(aspect.kind.rawValue)|\(Int(anchor.timeIntervalSince1970 / cadence))"
                    guard seen.insert(key).inserted else { continue }
                    facts.append(AgentEvidenceFact(
                        id: "\(capability.rawValue).timing.\(key)",
                        sourceChart: capability.rawValue,
                        evidenceRole: "timing_window",
                        factType: "timing_event",
                        data: [
                            "technique": kind.rawValue,
                            "perspective": perspective?.rawValue ?? "shared",
                            "first": aspect.firstID,
                            "second": aspect.secondID,
                            "aspect": aspect.kind.rawValue,
                            "active_start": iso.string(from: anchor),
                            "active_end": iso.string(from: nextAnchor),
                            "output_resolution": outputResolution ?? "balanced",
                        ],
                        priority: min(0.95, max(0.45, aspect.strength))
                    ))
                }
            }
            count += 1
            anchor = nextAnchor >= end ? end.addingTimeInterval(1) : nextAnchor
        }
        return Array(facts.sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }.prefix(48))
    }

    private func scanTransit(
        start: Date,
        end: Date,
        outputResolution: String?,
        profile: UserProfile,
        location: ChartLocationSelection,
        preset: CalculationPreset,
        calculator: SwissEphemerisCalculator
    ) async throws -> [AgentEvidenceFact] {
        let reference = try await calculator.calculateSnapshot(
            NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
            preset: preset
        )
        let cadence = scanCadence(start: start, end: end)
        let allowedBodies = movingBodies(start: start, end: end)
        let iso = ISO8601DateFormatter()
        var facts: [AgentEvidenceFact] = []
        var seen = Set<String>()
        var anchor = start
        var anchorCount = 0

        while anchor <= end && anchorCount < maxScanAnchors {
            let moving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: anchor, location: location.geographicLocation),
                preset: preset
            )
            let aspects = SwissEphemerisCalculator.compare(
                moving: moving,
                reference: reference,
                orbDegrees: ChartEventBuilder.transitAspectOrbDegrees
            )
            .filter { aspect in
                guard let body = CelestialBody(rawValue: aspect.firstID) else { return false }
                return allowedBodies.contains(body)
            }
            .sorted { $0.strength > $1.strength }
            .prefix(18)

            for aspect in aspects {
                guard let movingBody = CelestialBody(rawValue: aspect.firstID) else { continue }
                let exact: Date?
                switch aspect.phase {
                case .applying:
                    exact = try? await calculator.nextTransitNatalExactDate(
                        moving: movingBody,
                        natalReferenceLongitude: aspect.secondLongitude,
                        kind: aspect.kind,
                        after: anchor
                    )
                case .exact:
                    exact = anchor
                case .separating:
                    exact = try? await calculator.previousTransitNatalExactDate(
                        moving: movingBody,
                        natalReferenceLongitude: aspect.secondLongitude,
                        kind: aspect.kind,
                        before: anchor
                    )
                }
                guard let exact, exact >= start, exact <= end,
                      let window = try? await calculator.transitNatalAspectWindow(
                        moving: movingBody,
                        natalReferenceLongitude: aspect.secondLongitude,
                        kind: aspect.kind,
                        exactDate: exact,
                        orbDegrees: ChartEventBuilder.transitAspectOrbDegrees
                      )
                else { continue }

                let dayKey = Int(exact.timeIntervalSince1970 / 86_400)
                let key = "\(aspect.firstID)|\(aspect.secondID)|\(aspect.kind.rawValue)|\(dayKey)"
                guard seen.insert(key).inserted else { continue }
                facts.append(AgentEvidenceFact(
                    id: "\(AgentCapability.transit.rawValue).timing.\(key)",
                    sourceChart: AgentCapability.transit.rawValue,
                    evidenceRole: "timing_window",
                    factType: "timing_event",
                    data: [
                        "moving": aspect.firstID,
                        "reference": aspect.secondID,
                        "aspect": aspect.kind.rawValue,
                        "active_start": iso.string(from: max(window.start, start)),
                        "exact_at": iso.string(from: exact),
                        "active_end": iso.string(from: min(window.end, end)),
                        "phase_at_scan": aspect.phase.rawValue,
                        "output_resolution": outputResolution ?? "balanced",
                    ],
                    priority: min(1, max(0, aspect.strength + 0.15))
                ))
            }

            anchorCount += 1
            anchor = min(end.addingTimeInterval(1), anchor.addingTimeInterval(cadence))
        }
        return Array(facts.sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }.prefix(48))
    }

    private func scanSecondary(
        start: Date,
        end: Date,
        outputResolution: String?,
        profile: UserProfile,
        preset: CalculationPreset,
        calculator: SwissEphemerisCalculator
    ) async throws -> [AgentEvidenceFact] {
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
            preset: preset
        )
        return try await scanDevelopmentTechnique(
            capability: .secondary,
            start: start,
            end: end,
            outputResolution: outputResolution,
            cadence: developmentScanCadence(start: start, end: end),
            snapshotAt: { anchor in
                let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(birthDate: profile.birthDateUTC, targetDate: anchor)
                return try await calculator.calculateSnapshot(
                    NatalInput(utcDate: progressedDate, location: profile.location),
                    preset: preset,
                    aspectOrbDegrees: 3
                )
            },
            natal: natal,
            exactDate: { aspect, anchor in
                guard aspect.phase == .applying,
                      let body = CelestialBody(rawValue: aspect.firstID)
                else { return aspect.phase == .exact ? anchor : nil }
                return try? await calculator.nextProgressedNatalExactDate(
                    moving: body,
                    natalReferenceLongitude: aspect.secondLongitude,
                    kind: aspect.kind,
                    birthDate: profile.birthDateUTC,
                    after: anchor,
                    maxYears: 8
                )
            }
        )
    }

    private func scanSolarArc(
        start: Date,
        end: Date,
        outputResolution: String?,
        profile: UserProfile,
        preset: CalculationPreset,
        calculator: SwissEphemerisCalculator
    ) async throws -> [AgentEvidenceFact] {
        let natal = try await calculator.calculateSnapshot(
            NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
            preset: preset
        )
        return try await scanDevelopmentTechnique(
            capability: .solarArc,
            start: start,
            end: end,
            outputResolution: outputResolution,
            cadence: developmentScanCadence(start: start, end: end),
            snapshotAt: { anchor in
                try await calculator.calculateSolarArc(
                    birthDate: profile.birthDateUTC,
                    targetDate: anchor,
                    location: profile.location,
                    preset: preset
                ).snapshot
            },
            natal: natal,
            exactDate: { _, _ in nil }
        )
    }

    private func scanDevelopmentTechnique(
        capability: AgentCapability,
        start: Date,
        end: Date,
        outputResolution: String?,
        cadence: TimeInterval,
        snapshotAt: @escaping (Date) async throws -> ChartSnapshot,
        natal: ChartSnapshot,
        exactDate: @escaping (ChartAspect, Date) async -> Date?
    ) async throws -> [AgentEvidenceFact] {
        let iso = ISO8601DateFormatter()
        var anchor = start
        var count = 0
        var seen = Set<String>()
        var facts: [AgentEvidenceFact] = []
        while anchor <= end && count < maxScanAnchors {
            let snapshot = try await snapshotAt(anchor)
            let aspects = SwissEphemerisCalculator.compare(moving: snapshot, reference: natal, orbDegrees: 2)
                .sorted { $0.strength > $1.strength }
                .prefix(12)
            let nextAnchor = min(end, anchor.addingTimeInterval(cadence))
            for aspect in aspects where aspect.strength >= 0.55 {
                let exact = await exactDate(aspect, anchor)
                if let exact, (exact < start || exact > end) { continue }
                let key = "\(aspect.firstID)|\(aspect.secondID)|\(aspect.kind.rawValue)|\(exact.map { Int($0.timeIntervalSince1970 / 86_400) } ?? Int(anchor.timeIntervalSince1970 / cadence))"
                guard seen.insert(key).inserted else { continue }
                var data = [
                    "moving": aspect.firstID,
                    "reference": aspect.secondID,
                    "aspect": aspect.kind.rawValue,
                    "active_start": iso.string(from: anchor),
                    "active_end": iso.string(from: nextAnchor),
                    "phase_at_scan": aspect.phase.rawValue,
                    "output_resolution": outputResolution ?? "balanced",
                ]
                if let exact { data["exact_at"] = iso.string(from: exact) }
                facts.append(AgentEvidenceFact(
                    id: "\(capability.rawValue).timing.\(key)",
                    sourceChart: capability.rawValue,
                    evidenceRole: "timing_window",
                    factType: "timing_event",
                    data: data,
                    priority: min(0.98, aspect.strength + (exact == nil ? 0 : 0.1))
                ))
            }
            count += 1
            anchor = nextAnchor >= end ? end.addingTimeInterval(1) : nextAnchor
        }
        return Array(facts.sorted { ($0.priority ?? 0) > ($1.priority ?? 0) }.prefix(48))
    }

    /// Bounded technique-specific discovery cadence. Long spans intentionally
    /// favor slow planets and coarse anchors; exact dates are solved only after
    /// an aspect candidate is found.
    func scanCadence(start: Date, end: Date) -> TimeInterval {
        let days = end.timeIntervalSince(start) / 86_400
        if days <= 31 { return 86_400 }
        if days <= 183 { return 2 * 86_400 }
        if days <= 730 { return 7 * 86_400 }
        if days <= 3_650 { return 30 * 86_400 }
        if days <= 10_950 { return 120 * 86_400 }
        return 365 * 86_400
    }

    private func developmentScanCadence(start: Date, end: Date) -> TimeInterval {
        let years = end.timeIntervalSince(start) / (365.2425 * 86_400)
        if years <= 2 { return 30 * 86_400 }
        if years <= 10 { return 90 * 86_400 }
        if years <= 30 { return 180 * 86_400 }
        return 365 * 86_400
    }

    private func relationshipScanCadence(start: Date, end: Date) -> TimeInterval {
        let years = end.timeIntervalSince(start) / (365.2425 * 86_400)
        if years <= 1 { return 14 * 86_400 }
        if years <= 2 { return 30 * 86_400 }
        if years <= 10 { return 90 * 86_400 }
        return 365 * 86_400
    }

    private func movingBodies(start: Date, end: Date) -> Set<CelestialBody> {
        let years = end.timeIntervalSince(start) / (365.2425 * 86_400)
        if years > 10 { return [.jupiter, .saturn, .uranus, .neptune, .pluto, .trueNode] }
        if years > 2 { return [.mars, .jupiter, .saturn, .uranus, .neptune, .pluto, .trueNode] }
        return [.sun, .moon, .mercury, .venus, .mars, .jupiter, .saturn, .uranus, .neptune, .pluto, .trueNode]
    }

    private func relationshipTimingKind(_ capability: AgentCapability) -> RelationshipChartKind? {
        switch capability {
        case .compositeTransit: .compositeTransit
        case .compositeSecondaryCompare: .compositeSecondaryCompare
        case .compositeTertiaryCompare: .compositeTertiaryCompare
        case .davisonTransit: .davisonTransit
        case .davisonSecondary: .davisonSecondary
        case .davisonTertiary: .davisonTertiary
        case .marksSecondary: .marksSecondary
        case .marksTertiary: .marksTertiary
        default: nil
        }
    }

    private func relationshipPreset(_ preset: CalculationPreset) -> RelationshipPreset? {
        switch preset {
        case .modern: .modern
        case .classical: .classical
        case .special: nil
        }
    }

    private func relationshipNeedsTransitLocation(_ kind: RelationshipChartKind) -> Bool {
        kind == .compositeTransit || kind == .davisonTransit
    }
}
