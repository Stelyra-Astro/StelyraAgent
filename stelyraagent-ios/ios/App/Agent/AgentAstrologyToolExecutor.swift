import AstroCore
import Foundation

struct AgentEvidenceFact: Codable, Equatable, Sendable {
    let id: String
    let sourceChart: String
    let evidenceRole: String
    let factType: String
    let data: [String: String]
    let priority: Double?

    enum CodingKeys: String, CodingKey {
        case id
        case sourceChart = "source_chart"
        case evidenceRole = "evidence_role"
        case factType = "fact_type"
        case data
        case priority
    }
}

struct AgentEvidenceBundle: Codable, Equatable, Sendable {
    let facts: [AgentEvidenceFact]
    let chartAssetIDs: [UUID]
    let semanticFingerprints: [String]

    enum CodingKeys: String, CodingKey {
        case facts
        case chartAssetIDs = "chart_asset_ids"
        case semanticFingerprints = "semantic_fingerprints"
    }
}

struct AgentComputedChartPayload: Codable, Sendable {
    let capability: String
    let snapshots: [ChartSnapshot]
    let relationshipArtifacts: [RelationshipChartArtifact]
    let comparisonAspects: [ChartAspect]
}

struct AgentKnownLocation: Equatable, Sendable {
    let id: String
    let selection: ChartLocationSelection
}

struct AgentLocalContextSnapshot {
    let primaryID: String
    let primary: UserProfile
    let savedPeople: [String: UserProfile]
    let locations: [String: ChartLocationSelection]
    let preset: CalculationPreset

    @MainActor
    static func from(model: AppModel) -> AgentLocalContextSnapshot {
        var people = Dictionary(uniqueKeysWithValues: model.savedPeople.map { ($0.id.uuidString, $0.profile) })
        people["primary"] = model.profile
        let primaryLocation = ChartLocationSelection(
            placeName: model.profile.placeName,
            timezoneID: model.profile.timezoneID,
            latitude: model.profile.latitude,
            longitude: model.profile.longitude
        )
        var locations = ["primary": primaryLocation]
        for person in model.savedPeople {
            locations[person.id.uuidString] = ChartLocationSelection(
                placeName: person.profile.placeName,
                timezoneID: person.profile.timezoneID,
                latitude: person.profile.latitude,
                longitude: person.profile.longitude
            )
        }
        return AgentLocalContextSnapshot(
            primaryID: "primary",
            primary: model.profile,
            savedPeople: people,
            locations: locations,
            preset: model.presets[.natal] ?? .modern
        )
    }
}

private struct ParsedEvidenceRequest {
    let capability: AgentCapability
    let subjects: [String]
    let startDate: Date?
    let endDate: Date?
    let locationIDs: [String]
    let resolution: String?

    var targetDate: Date? { startDate }
    var rangeFingerprint: String? {
        guard let startDate, let endDate else { return nil }
        let formatter = ISO8601DateFormatter()
        return "\(formatter.string(from: startDate))...\(formatter.string(from: endDate))"
    }
}

@MainActor
final class AgentAstrologyToolExecutor {
    enum ToolError: Error, LocalizedError {
        case malformedRequest
        case unsupportedCapability(String)
        case missingSubject(String)
        case relationshipNeedsTwoSubjects
        case missingLocation(String)
        case missingEphemeris

        var code: String {
            switch self {
            case .malformedRequest: "malformed_request"
            case .unsupportedCapability: "unsupported_capability"
            case .missingSubject: "missing_subject"
            case .relationshipNeedsTwoSubjects: "relationship_needs_two_subjects"
            case .missingLocation: "missing_location"
            case .missingEphemeris: "missing_ephemeris"
            }
        }

        var errorDescription: String? {
            switch self {
            case .malformedRequest: "The astrology evidence request is malformed."
            case let .unsupportedCapability(value): "Unsupported astrology capability: \(value)."
            case let .missingSubject(value): "A required profile is missing: \(value)."
            case .relationshipNeedsTwoSubjects: "Relationship analysis requires two selected profiles."
            case let .missingLocation(value): "A required structured location is missing: \(value)."
            case .missingEphemeris: "The bundled Swiss Ephemeris data could not be found."
            }
        }
    }

    private let assetStore: AgentChartAssetStore
    private let relationshipService = AppRelationshipChartCalculationService()
    private let evidenceBuilder = AgentEvidenceBuilder()
    private let techniquePlanner = AgentTechniquePlanner()
    private var calculator: SwissEphemerisCalculator?

    init(assetStore: AgentChartAssetStore) {
        self.assetStore = assetStore
    }

    func execute(
        actionPayload: [String: AgentJSONValue],
        conversationID: UUID,
        context: AgentLocalContextSnapshot
    ) async throws -> [String: AgentJSONValue] {
        let requests = try parseRequests(actionPayload)
        var allFacts: [AgentEvidenceFact] = []
        var logicalAssets: [ConversationChartAsset] = []

        for request in requests {
            let subjectProfiles = try request.subjects.map { try resolveProfile($0, context: context) }
            let computed = try await calculate(request: request, context: context)
            let calculator = try calculatorInstance()
            let timingFacts: [AgentEvidenceFact]
            if request.capability.isRelationship, subjectProfiles.count == 2 {
                let scanLocation = computed.location ?? profileLocation(subjectProfiles[0])
                timingFacts = try await techniquePlanner.relationshipTimingFacts(
                    capability: request.capability,
                    start: request.startDate,
                    end: request.endDate,
                    outputResolution: request.resolution,
                    firstID: request.subjects[0],
                    first: subjectProfiles[0],
                    secondID: request.subjects[1],
                    second: subjectProfiles[1],
                    location: scanLocation,
                    preset: context.preset,
                    calculator: calculator
                )
            } else if let profile = subjectProfiles.first {
                let scanLocation = computed.location ?? profileLocation(profile)
                timingFacts = try await techniquePlanner.timingFacts(
                    capability: request.capability,
                    start: request.startDate,
                    end: request.endDate,
                    outputResolution: request.resolution,
                    profile: profile,
                    location: scanLocation,
                    preset: context.preset,
                    calculator: calculator
                )
            } else {
                timingFacts = []
            }

            let payloadData = try JSONEncoder().encode(computed.payload)
            let fingerprint = try AgentChartFingerprint.make(
                AgentChartFingerprintInput(
                    chartKind: request.capability.rawValue,
                    subjects: request.subjects,
                    birthDataIdentityHashes: try subjectProfiles.map(profileIdentityHash),
                    targetDate: request.targetDate,
                    targetLocation: computed.location?.placeName,
                    preset: context.preset.rawValue,
                    range: request.rangeFingerprint,
                    resolution: request.resolution,
                    calculationSchemaVersion: 2
                )
            )
            _ = assetStore.savePhysicalArtifact(
                AgentChartArtifactFile(
                    semanticFingerprint: fingerprint,
                    schemaVersion: 2,
                    calculationSchemaVersion: 2,
                    payload: payloadData,
                    createdAt: Date(),
                    lastAccessedAt: Date()
                )
            )
            let asset = assetStore.addLogicalAsset(
                conversationID: conversationID,
                semanticFingerprint: fingerprint,
                chartKind: request.capability.rawValue,
                subjectRefs: request.subjects,
                displaySubjects: subjectProfiles.map(\.name),
                locationSummary: computed.location?.placeName,
                timeSummary: timeSummary(for: request),
                resolution: request.resolution
            )
            logicalAssets.append(asset)
            allFacts.append(contentsOf: evidenceBuilder.build(
                capability: request.capability,
                snapshots: computed.payload.snapshots,
                aspects: computed.payload.comparisonAspects,
                relationshipArtifacts: computed.payload.relationshipArtifacts,
                timingFacts: timingFacts
            ))
        }

        let finalEvidenceBuilder = AgentEvidenceBuilder(targetTokenBudget: 16_000)
        let facts = finalEvidenceBuilder.compress(
            finalEvidenceBuilder.group(
                finalEvidenceBuilder.select(
                    finalEvidenceBuilder.rank(
                        finalEvidenceBuilder.deduplicate(allFacts)
                    )
                )
            )
        )
        let bundle = AgentEvidenceBundle(
            facts: facts,
            chartAssetIDs: logicalAssets.map(\.assetID),
            semanticFingerprints: logicalAssets.map(\.semanticFingerprint)
        )
        return try jsonObject(bundle)
    }

    private func calculate(
        request: ParsedEvidenceRequest,
        context: AgentLocalContextSnapshot
    ) async throws -> (payload: AgentComputedChartPayload, location: ChartLocationSelection?) {
        let calculator = try calculatorInstance()
        let profiles = try request.subjects.map { try resolveProfile($0, context: context) }
        let targetDate = request.targetDate ?? Date()
        let location = try resolveLocation(request.locationIDs.first, context: context, fallbackProfile: profiles.first)

        switch request.capability {
        case .natal:
            guard let profile = profiles.first else { throw ToolError.malformedRequest }
            let natal = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            return (payload(request.capability, [natal]), nil)

        case .currentSky:
            guard let location else { throw ToolError.malformedRequest }
            let sky = try await calculator.calculateSnapshot(
                NatalInput(utcDate: targetDate, location: location.geographicLocation),
                preset: context.preset
            )
            return (payload(request.capability, [sky]), location)

        case .transit:
            guard let profile = profiles.first, let location else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            let moving = try await calculator.calculateSnapshot(
                NatalInput(utcDate: targetDate, location: location.geographicLocation),
                preset: context.preset
            )
            let aspects = SwissEphemerisCalculator.compare(
                moving: moving,
                reference: reference,
                orbDegrees: ChartEventBuilder.transitAspectOrbDegrees
            )
            return (payload(request.capability, [reference, moving], aspects: aspects), location)

        case .secondary:
            guard let profile = profiles.first else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            let progressedDate = SwissEphemerisCalculator.secondaryProgressedDate(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate
            )
            let progressed = try await calculator.calculateSnapshot(
                NatalInput(utcDate: progressedDate, location: profile.location),
                preset: context.preset,
                aspectOrbDegrees: 3
            )
            let aspects = SwissEphemerisCalculator.compare(moving: progressed, reference: reference, orbDegrees: 2)
            return (payload(request.capability, [reference, progressed], aspects: aspects), nil)

        case .tertiary:
            guard let profile = profiles.first else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            let progressed = try await calculator.calculateTertiaryProgression(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate,
                location: profile.location,
                preset: context.preset
            )
            let aspects = SwissEphemerisCalculator.advancedComparisonAspects(moving: progressed, reference: reference, preset: context.preset)
            return (payload(request.capability, [reference, progressed], aspects: aspects), nil)

        case .solarArc:
            guard let profile = profiles.first else { throw ToolError.malformedRequest }
            let result = try await calculator.calculateSolarArc(
                birthDate: profile.birthDateUTC,
                targetDate: targetDate,
                location: profile.location,
                preset: context.preset
            )
            let aspects = SwissEphemerisCalculator.advancedComparisonAspects(moving: result.snapshot, reference: result.natal, preset: context.preset)
            return (payload(request.capability, [result.natal, result.snapshot], aspects: aspects), nil)

        case .solarReturn:
            guard let profile = profiles.first, let location else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: location.timezoneID) ?? TimeZone(secondsFromGMT: 0)!
            let year = calendar.component(.year, from: targetDate)
            let anchor = calendar.date(from: DateComponents(year: year, month: 1, day: 1)) ?? targetDate
            let returnChart = try await calculator.calculateSolarReturn(
                birthDate: profile.birthDateUTC,
                after: anchor.addingTimeInterval(-1),
                location: location.geographicLocation,
                preset: context.preset
            )
            let aspects = SwissEphemerisCalculator.solarReturnNatalAspects(solarReturn: returnChart, natal: reference)
            return (payload(request.capability, [reference, returnChart], aspects: aspects), location)

        case .lunarReturn:
            guard let profile = profiles.first, let location else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            let result = try await calculator.calculateLunarReturn(
                birthDate: profile.birthDateUTC,
                onOrBefore: targetDate,
                location: location.geographicLocation,
                preset: context.preset
            )
            let aspects = SwissEphemerisCalculator.advancedComparisonAspects(moving: result.snapshot, reference: reference, preset: context.preset)
            return (payload(request.capability, [reference, result.snapshot], aspects: aspects), location)

        case .relocation:
            guard let profile = profiles.first, let location else { throw ToolError.malformedRequest }
            let relocated = try await calculator.calculateRelocation(
                birthDate: profile.birthDateUTC,
                location: location.geographicLocation,
                preset: context.preset
            )
            return (payload(request.capability, [relocated], aspects: relocated.aspects), location)

        case .harmonic12, .harmonic13:
            guard let profile = profiles.first else { throw ToolError.malformedRequest }
            let reference = try await calculator.calculateSnapshot(
                NatalInput(utcDate: profile.birthDateUTC, location: profile.location),
                preset: context.preset
            )
            let number = request.capability == .harmonic12 ? 12 : 13
            let harmonic = SwissEphemerisCalculator.harmonicSnapshot(from: reference, harmonic: number, preset: context.preset)
            let aspects = SwissEphemerisCalculator.advancedComparisonAspects(moving: harmonic, reference: reference, preset: context.preset)
            return (payload(request.capability, [reference, harmonic], aspects: aspects), nil)

        case .synastry, .composite, .compositeTransit,
             .compositeSecondaryCompare, .compositeTertiaryCompare,
             .davison, .davisonTransit, .davisonSecondary, .davisonTertiary,
             .marks, .marksSecondary, .marksTertiary:
            guard profiles.count == 2 else { throw ToolError.relationshipNeedsTwoSubjects }
            let firstID = request.subjects[0]
            let secondID = request.subjects[1]
            var artifacts: [RelationshipChartArtifact] = []
            for (index, kind) in request.capability.relationshipKinds.enumerated() {
                let needsLocation = kind == .compositeTransit || kind == .davisonTransit
                let artifact = try await relationshipService.calculate(
                    request: AppRelationshipChartRequest(
                        kind: kind,
                        firstID: firstID,
                        firstProfile: profiles[0],
                        secondID: secondID,
                        secondProfile: profiles[1],
                        preset: context.preset,
                        targetDate: kind.needsTargetDate ? targetDate : nil,
                        transitLocation: needsLocation ? location : nil,
                        perspective: request.capability.perspective(at: index)
                    ),
                    calculator: calculator
                )
                artifacts.append(artifact)
            }
            let snapshots = artifacts.flatMap { artifact in [artifact.reference, artifact.snapshot].compactMap { $0 } }
            let aspects = artifacts.flatMap(\.comparisonAspects)
            let usesLocation = request.capability == .compositeTransit || request.capability == .davisonTransit
            return (
                AgentComputedChartPayload(
                    capability: request.capability.rawValue,
                    snapshots: snapshots,
                    relationshipArtifacts: artifacts,
                    comparisonAspects: aspects
                ),
                usesLocation ? location : nil
            )
        }
    }

    private func payload(
        _ capability: AgentCapability,
        _ snapshots: [ChartSnapshot],
        aspects: [ChartAspect] = []
    ) -> AgentComputedChartPayload {
        AgentComputedChartPayload(
            capability: capability.rawValue,
            snapshots: snapshots,
            relationshipArtifacts: [],
            comparisonAspects: aspects
        )
    }

    private func parseRequests(_ payload: [String: AgentJSONValue]) throws -> [ParsedEvidenceRequest] {
        guard case let .array(rawRequests)? = payload["requests"] else { throw ToolError.malformedRequest }
        return try rawRequests.map { raw in
            guard case let .object(object) = raw,
                  case let .string(capabilityValue)? = object["capability"],
                  let capability = AgentCapability(rawValue: capabilityValue)
            else {
                if case let .object(object) = raw,
                   case let .string(value)? = object["capability"] {
                    throw ToolError.unsupportedCapability(value)
                }
                throw ToolError.malformedRequest
            }
            let subjects = stringArray(object["subjects"])
            let locationIDs = stringArray(object["locations"])
            var startDate: Date?
            var endDate: Date?
            var resolution: String?
            if case let .object(scope)? = object["time_scope"] {
                if case let .string(value)? = scope["start"] { startDate = parseAgentDate(value) }
                if case let .string(value)? = scope["end"] { endDate = parseAgentDate(value) }
                if case let .string(value)? = scope["resolution"] { resolution = value }
            }
            return ParsedEvidenceRequest(
                capability: capability,
                subjects: subjects.isEmpty ? ["primary"] : subjects,
                startDate: startDate,
                endDate: endDate,
                locationIDs: locationIDs,
                resolution: resolution
            )
        }
    }

    private func parseAgentDate(_ value: String) -> Date? {
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }

        let dateOnly = DateFormatter()
        dateOnly.locale = Locale(identifier: "en_US_POSIX")
        dateOnly.calendar = Calendar(identifier: .gregorian)
        dateOnly.timeZone = TimeZone(secondsFromGMT: 0)
        dateOnly.dateFormat = "yyyy-MM-dd"
        return dateOnly.date(from: value)
    }

    private func stringArray(_ value: AgentJSONValue?) -> [String] {
        guard case let .array(values)? = value else { return [] }
        return values.compactMap { if case let .string(value) = $0 { value } else { nil } }
    }

    private func resolveProfile(_ id: String, context: AgentLocalContextSnapshot) throws -> UserProfile {
        if id == "primary" { return context.primary }
        guard let profile = context.savedPeople[id] else { throw ToolError.missingSubject(id) }
        return profile
    }

    private func resolveLocation(
        _ id: String?,
        context: AgentLocalContextSnapshot,
        fallbackProfile: UserProfile?
    ) throws -> ChartLocationSelection? {
        if let id {
            guard let location = context.locations[id] else { throw ToolError.missingLocation(id) }
            return location
        }
        guard let profile = fallbackProfile else { return nil }
        return ChartLocationSelection(
            placeName: profile.placeName,
            timezoneID: profile.timezoneID,
            latitude: profile.latitude,
            longitude: profile.longitude
        )
    }

    private func profileLocation(_ profile: UserProfile) -> ChartLocationSelection {
        ChartLocationSelection(
            placeName: profile.placeName,
            timezoneID: profile.timezoneID,
            latitude: profile.latitude,
            longitude: profile.longitude
        )
    }

    private func calculatorInstance() throws -> SwissEphemerisCalculator {
        if let calculator { return calculator }
        let candidates = [
            Bundle.main.url(forResource: "ephe", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("ephe"),
        ].compactMap { $0 }
        guard let directory = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else {
            throw ToolError.missingEphemeris
        }
        let created = try SwissEphemerisCalculator(ephemerisDirectory: directory)
        calculator = created
        return created
    }

    private func profileIdentityHash(_ profile: UserProfile) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return SHA256Digest.hash(try encoder.encode(profile)).hex
    }

    private func timeSummary(for request: ParsedEvidenceRequest) -> String? {
        let formatter = ISO8601DateFormatter()
        if let start = request.startDate, let end = request.endDate {
            return "\(formatter.string(from: start)) – \(formatter.string(from: end))"
        }
        return request.startDate.map { formatter.string(from: $0) }
    }

    private func jsonObject<T: Encodable>(_ value: T) throws -> [String: AgentJSONValue] {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode([String: AgentJSONValue].self, from: data)
    }
}
