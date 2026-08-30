import AstroCore
import Combine
import CommonCrypto
import Foundation
import Network

@MainActor
final class AppModel: ObservableObject {
    @Published var profile: UserProfile {
        didSet {
            saveProfile()
            invalidateAllAdvancedCharts()
            invalidateAllRelationshipCharts()
        }
    }
    @Published var selectedChart: ChartKind = .natal
    @Published private(set) var chartParameterEditRequest: ChartKind? = nil
    @Published var viewMode: ChartViewMode = .wheel
    @Published private(set) var currentSkyTargetDate = Date()
    @Published private(set) var transitTargetDate = Date()
    @Published private(set) var secondaryTargetDate = Date()
    @Published private(set) var solarReturnYear = Calendar.current.component(.year, from: Date())
    @Published private(set) var currentSkyUsesLiveDefault = true
    @Published private(set) var transitUsesLiveDefault = true
    @Published private(set) var secondaryUsesLiveDefault = true
    @Published private(set) var currentSkyLocationOverride: ChartLocationSelection?
    @Published private(set) var transitLocationOverride: ChartLocationSelection?
    @Published private(set) var solarReturnLocationOverride: ChartLocationSelection?
    @Published private(set) var advancedChartTargetOverrides: [ChartKind: ChartTarget] = [:]
    @Published private(set) var advancedChartResults: [ChartKind: ChartDisplayResult] = [:]
    @Published private(set) var advancedChartLoadStates: [ChartKind: AdvancedChartLoadState] = [:]
    @Published private(set) var transitRangeDays = TransitTimelineContract.defaultRangeDays
    @Published var language: AppLanguage {
        didSet {
            defaults.set(language.rawValue, forKey: "language.v1")
            Task { await refresh() }
        }
    }
    @Published var appearance: AppAppearance {
        didSet {
            defaults.set(appearance.rawValue, forKey: "appearance.v1")
        }
    }
    @Published var fontSize: AppFontSize {
        didSet {
            defaults.set(fontSize.rawValue, forKey: "font-size.v1")
        }
    }
    @Published private(set) var savedPeople: [SavedPerson] = []
    @Published var presets: [ChartKind: CalculationPreset]
    @Published private(set) var natal: ChartSnapshot?
    @Published private(set) var transitReference: ChartSnapshot?
    @Published private(set) var progressedReference: ChartSnapshot?
    @Published private(set) var currentSky: ChartSnapshot?
    @Published private(set) var transit: ChartSnapshot?
    @Published private(set) var progressed: ChartSnapshot?
    @Published private(set) var solarReturn: ChartSnapshot?
    @Published private(set) var solarReturnReference: ChartSnapshot?
    @Published private(set) var solarReturnAspects: [ChartAspect] = []
    @Published private(set) var synastry: SynastryComparison?
    @Published var selectedRelationshipChart: RelationshipChartKind = .composite
    @Published private(set) var relationshipTargetDate = Date()
    @Published private(set) var relationshipLocationOverride: ChartLocationSelection?
    @Published private(set) var relationshipMidpointAlgorithmOverride: RelationshipMidpointAlgorithm?
    @Published private(set) var relationshipPerspective: RelationshipPerspective = .first
    @Published private(set) var relationshipArtifacts: [String: RelationshipChartArtifact] = [:]
    @Published private(set) var relationshipLoadStates: [String: AdvancedChartLoadState] = [:]
    @Published var synastryPartnerID: String? {
        didSet {
            guard oldValue != synastryPartnerID else { return }
            defaults.set(synastryPartnerID, forKey: "synastry.partner.v1")
            synastry = nil
            invalidateAllRelationshipCharts()
            isCalculatingSynastry = synastryPartnerID != nil
            Task { await refresh() }
        }
    }
    @Published private(set) var transitAspects: [ChartAspect] = []
    @Published private(set) var progressedAspects: [ChartAspect] = []
    @Published private(set) var todaySignals: [DailySignal] = []
    @Published private(set) var todayContributions: [WeeklySignalContribution] = []
    /// Local day (profile timezone) the scanned Today events belong to. Nil
    /// until the first successful scan, so Today can tell "quiet day" apart
    /// from "events not scanned for today yet".
    @Published private(set) var todayEventsDayKey: String?
    private var todayReferenceForEvents: ChartSnapshot?
    private var todayActiveSignals: [DailySignal] = []
    private var todayEventsRefreshInFlight = false
    @Published private(set) var todayDashboardModel: TodayDashboardModel?
    @Published private(set) var todayContentErrorMessage: String?
    @Published private(set) var transitCalendar: [TransitCalendarDay] = []
    @Published private(set) var transitContentPlan: TransitContentPlan?
    @Published private(set) var chartEvents = ChartEventData.empty
    @Published private(set) var weeklyForecast: WeeklyForecastModel = .empty
    @Published private(set) var isCalculating = false
    @Published private(set) var isCalculatingSynastry = false
    @Published private(set) var isEnriching = false
    @Published private(set) var isOnline = true
    @Published private(set) var aiConsentGranted: Bool
    @Published private(set) var aiContent: [ChartKind: AIChartContent] = [:]
    @Published private(set) var relationshipAIContent: [String: AIChartContent] = [:]
    @Published private(set) var savedReports: [SavedReport] = []
    @Published private(set) var focusedChart: ChartKind?
    @Published private(set) var focusedChartDate: Date?
    @Published private(set) var isCalculatingFocus = false
    @Published private(set) var errorMessage: String?
	@Published var iCloudBackupEnabled: Bool {
		didSet { defaults.set(iCloudBackupEnabled, forKey: "icloud.backup.enabled.v1"); if iCloudBackupEnabled { scheduleICloudBackup() } }
	}
	@Published private(set) var iCloudBackupStatus = ""

    private var calculator: SwissEphemerisCalculator?
    private var focusedSnapshot: ChartSnapshot?
    private var focusedAspects: [ChartAspect] = []
    private var todayNatalForContent: ChartSnapshot?
    private var todaySkyForContent: ChartSnapshot?
    private var todayTransitForContent: ChartSnapshot?
    private var todayTransitAspectsForContent: [ChartAspect] = []
    private var refreshRequested = false
    private var refreshInFlight = false
    private var refreshGeneration: UInt = 0
    private let defaults: UserDefaults
    private var copyCatalogProviders: [AppLanguage: Result<CopyCatalogProvider, Error>] = [:]
    private let chartCalculationService = AppChartCalculationService()
    private let advancedChartCalculationService = AppAdvancedChartCalculationService()
    private let relationshipChartCalculationService = AppRelationshipChartCalculationService()
    private let enrichmentService = AppEnrichmentService()
    private let aiReportService = AppAIReportService()
    private let aiClient = AIGenerationClient()
    private let artifactStore = GeneratedArtifactStore()
    private let snapshotCache = SnapshotCacheStore()
    private let advancedChartCache = AdvancedChartCacheStore()
    private var advancedChartCalculationFingerprints: [ChartKind: String] = [:]
    private var generatingCharts: Set<ChartKind> = []
    private var generatingRelationships: Set<String> = []
    private var networkMonitor: NWPathMonitor?
	private var isRestoringICloudBackup = false

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
		iCloudBackupEnabled = defaults.object(forKey: "icloud.backup.enabled.v1") as? Bool ?? true
        aiConsentGranted = defaults.bool(forKey: "ai.network.consent.v1")
        synastryPartnerID = defaults.string(forKey: "synastry.partner.v1")
        defaults.removeObject(forKey: "charts.subject.v1")
        let testEnvironment = ProcessInfo.processInfo.environment
        if let data = defaults.data(forKey: "profile.v1"),
           let decoded = try? JSONDecoder().decode(UserProfile.self, from: data)
        {
            profile = decoded
        } else {
            profile = .sample
        }
        language = AppLanguage(rawValue: testEnvironment["STELYRAAGENT_UI_TEST_LANGUAGE"] ?? "")
            ?? AppLanguage(rawValue: defaults.string(forKey: "language.v1") ?? "")
            ?? AppLanguage.matchingSystemLanguage(Locale.preferredLanguages.first)
        appearance = AppAppearance(
            rawValue: testEnvironment["STELYRAAGENT_UI_TEST_APPEARANCE"]
                ?? defaults.string(forKey: "appearance.v1")
                ?? ""
        ) ?? .dark
        fontSize = AppFontSize(
            rawValue: testEnvironment["STELYRAAGENT_UI_TEST_FONT_SIZE"]
                ?? defaults.string(forKey: "font-size.v1")
                ?? ""
        ) ?? .standard
        if let data = defaults.data(forKey: "people.v1"),
           let decoded = try? JSONDecoder().decode([SavedPerson].self, from: data)
        {
            savedPeople = decoded
        }
        var restored: [ChartKind: CalculationPreset] = [:]
        for kind in ChartKind.allCases {
            let raw = defaults.string(forKey: "preset.\(kind.rawValue)")
            let decoded = raw.flatMap(CalculationPreset.init(rawValue:)) ?? .modern
            restored[kind] = decoded == .special ? .modern : decoded
            if decoded == .special {
                defaults.set(CalculationPreset.modern.rawValue, forKey: "preset.\(kind.rawValue)")
            }
        }
        presets = restored
        if testEnvironment["STELYRAAGENT_UI_TEST_SYNASTRY_SAMPLE"] == "1", savedPeople.isEmpty {
            let partner = SavedPerson(
                id: UUID(uuidString: "72A8F98A-2E25-4CC3-91D5-65FCFEC808A4")!,
                profile: UserProfile(
                    name: "Julian Mercer",
                    birthDateUTC: Date(timeIntervalSince1970: 591_849_900),
                    placeName: "Montreal, Canada",
                    timezoneID: "America/Toronto",
                    latitude: 45.5019,
                    longitude: -73.5674
                ),
                relationship: .partner
            )
            savedPeople = [partner]
            synastryPartnerID = partner.id.uuidString
        }
        restoreSnapshotCache()
        reloadSavedReports()
        startNetworkMonitoring()
    }

    func preset(for chart: ChartKind) -> CalculationPreset {
        presets[chart] ?? .modern
    }

    func setPreset(_ preset: CalculationPreset, for chart: ChartKind) {
        guard CalculationPreset.consumerCases.contains(preset) else { return }
        clearChartFocus()
        presets[chart] = preset
        defaults.set(preset.rawValue, forKey: "preset.\(chart.rawValue)")
        if chart == .synastry {
            invalidateAllRelationshipCharts()
        }
        if chart.isAdvancedChart {
            invalidateAdvancedChart(chart)
            if selectedChart == chart {
                Task { await ensureAdvancedChartCalculated(chart) }
            }
        } else {
            Task { await refresh() }
        }
    }

    func savePerson(_ person: SavedPerson) {
        let previous = savedPeople.first(where: { $0.id == person.id })
        let refreshesSelectedSynastry = synastryPartnerID == person.id.uuidString
        if let index = savedPeople.firstIndex(where: { $0.id == person.id }) {
            savedPeople[index] = person
        } else {
			guard CommerceStore.shared.isPremium || savedPeople.count < 2 else {
				CommerceStore.shared.showsPaywall = true
				return
			}
            savedPeople.append(person)
        }
        savedPeople.sort {
            $0.profile.name.localizedCaseInsensitiveCompare($1.profile.name) == .orderedAscending
        }
        persistPeople()
		scheduleICloudBackup()
        if let previous, previous.profile != person.profile {
            artifactStore.remove(subjectHash: profileHash(previous.profile))
            reloadSavedReports()
        }
        if refreshesSelectedSynastry {
            synastry = nil
            invalidateAllRelationshipCharts()
            isCalculatingSynastry = true
            Task { await refresh() }
        }
    }

    var chartSubjectProfile: UserProfile {
        profile
    }

    func profileForPersonID(_ id: String) -> UserProfile? {
        if id == "self" { return profile }
        return savedPeople.first(where: { $0.id.uuidString == id })?.profile
    }

    var synastryReportPeople: (first: String, second: String)? {
        guard let partnerID = synastryPartnerID,
              let partner = savedPeople.first(where: { $0.id.uuidString == partnerID })
        else { return nil }
        return (profile.name, partner.profile.name)
    }

    func selectSynastryPartner(_ id: String?) {
        guard let id else {
            synastryPartnerID = nil
            return
        }
        guard savedPeople.contains(where: { $0.id.uuidString == id }) else { return }
        synastryPartnerID = id
    }

    func selectRelationshipChart(_ kind: RelationshipChartKind) {
        selectedRelationshipChart = kind
        Task { await ensureRelationshipChartCalculated(kind) }
    }

    func relationshipArtifact(for kind: RelationshipChartKind) -> RelationshipChartArtifact? {
        relationshipArtifacts[kind.rawValue]
    }

    func relationshipLoadState(for kind: RelationshipChartKind) -> AdvancedChartLoadState {
        relationshipLoadStates[kind.rawValue] ?? .idle
    }

    func relationshipSnapshot(for kind: RelationshipChartKind) -> ChartSnapshot? {
        relationshipArtifact(for: kind)?.snapshot
    }

    func relationshipReferenceSnapshot(for kind: RelationshipChartKind) -> ChartSnapshot? {
        relationshipArtifact(for: kind)?.reference
    }

    func relationshipComparisonAspects(for kind: RelationshipChartKind) -> [ChartAspect] {
        relationshipArtifact(for: kind)?.comparisonAspects ?? []
    }

    func setRelationshipTargetDate(_ date: Date) {
        relationshipTargetDate = date
        for kind in RelationshipChartKind.allCases where kind.needsTargetDate {
            invalidateRelationshipChart(kind)
        }
        if selectedRelationshipChart.needsTargetDate {
            Task { await ensureRelationshipChartCalculated(selectedRelationshipChart) }
        }
    }

    func resetRelationshipTargetDate() {
        setRelationshipTargetDate(Date())
    }

    func setRelationshipLocation(_ selection: LocationSelection?) {
        relationshipLocationOverride = selection.map { selection in
            ChartLocationSelection(
                placeName: selection.name,
                timezoneID: selection.timezoneID,
                latitude: selection.latitude,
                longitude: selection.longitude
            )
        }
        for kind in RelationshipChartKind.allCases where kind.supportsTransitLocation {
            invalidateRelationshipChart(kind)
        }
        if selectedRelationshipChart.supportsTransitLocation {
            Task { await ensureRelationshipChartCalculated(selectedRelationshipChart) }
        }
    }

    func setRelationshipMidpointAlgorithm(_ algorithm: RelationshipMidpointAlgorithm?) {
        relationshipMidpointAlgorithmOverride = algorithm
        for kind in RelationshipChartKind.allCases where kind.supportsMidpointAlgorithm {
            invalidateRelationshipChart(kind)
        }
        if selectedRelationshipChart.supportsMidpointAlgorithm {
            Task { await ensureRelationshipChartCalculated(selectedRelationshipChart) }
        }
    }

    func setRelationshipPerspective(_ perspective: RelationshipPerspective) {
        relationshipPerspective = perspective
        for kind in [RelationshipChartKind.marksSecondary, .marksTertiary] {
            invalidateRelationshipChart(kind)
        }
        switch selectedRelationshipChart {
        case .marksSecondary, .marksTertiary:
            Task { await ensureRelationshipChartCalculated(selectedRelationshipChart) }
        default:
            break
        }
    }

    func ensureRelationshipChartCalculated(_ kind: RelationshipChartKind) async {
        guard relationshipLoadState(for: kind) != .loading else { return }
        guard let partnerID = synastryPartnerID,
              let partner = profileForPersonID(partnerID)
        else {
            relationshipArtifacts.removeValue(forKey: kind.rawValue)
            relationshipLoadStates[kind.rawValue] = .idle
            return
        }
        relationshipLoadStates[kind.rawValue] = .loading
        do {
            let calculator = try calculatorInstance()
            let perspective: RelationshipPerspective? = switch kind {
            case .synastryA, .marksA: .first
            case .synastryB, .marksB: .second
            case .marksSecondary, .marksTertiary: relationshipPerspective
            default: nil
            }
            let artifact = try await relationshipChartCalculationService.calculate(
                request: AppRelationshipChartRequest(
                    kind: kind,
                    firstID: "self",
                    firstProfile: profile,
                    secondID: partnerID,
                    secondProfile: partner,
                    preset: preset(for: .synastry),
                    targetDate: kind.needsTargetDate ? relationshipTargetDate : nil,
                    transitLocation: kind.supportsTransitLocation ? relationshipLocationOverride : nil,
                    perspective: perspective,
                    midpointAlgorithm: kind.supportsMidpointAlgorithm ? relationshipMidpointAlgorithmOverride : nil
                ),
                calculator: calculator
            )
            relationshipArtifacts[kind.rawValue] = artifact
            relationshipLoadStates[kind.rawValue] = .ready
        } catch {
            relationshipArtifacts.removeValue(forKey: kind.rawValue)
            relationshipLoadStates[kind.rawValue] = .failed(error.localizedDescription)
        }
    }

    private func invalidateRelationshipChart(_ kind: RelationshipChartKind) {
        relationshipArtifacts.removeValue(forKey: kind.rawValue)
        relationshipLoadStates[kind.rawValue] = .idle
        relationshipAIContent[kind.rawValue] = .empty
    }

    private func invalidateAllRelationshipCharts() {
        relationshipArtifacts.removeAll()
        relationshipLoadStates.removeAll()
        relationshipAIContent.removeAll()
    }

    func clearReports() {
        artifactStore.clearAll()
        savedReports = []
        aiContent = [:]
        relationshipAIContent = [:]
        generatingRelationships = []
    }

    func clearAskHistory() {
        AskHistoryStore.shared.removeAll()
    }

    func clearAICache() {
        artifactStore.clearAll()
        aiContent = [:]
        relationshipAIContent = [:]
        generatingRelationships = []
        reloadSavedReports()
    }

	func erasePersonalDataForAccountDeletion() async {
		isRestoringICloudBackup = true
		defer { isRestoringICloudBackup = false }
		try? await ICloudBackupStore.shared.delete()
		artifactStore.clearAll()
		snapshotCache.clear()
        advancedChartCache.clear()
		AskHistoryStore.shared.removeAll()
		PendingReportManager.shared.clearAll()
		for key in [
			"profile.v1", "people.v1", "language.v1", "appearance.v1", "font-size.v1",
			"synastry.partner.v1", "ai.network.consent.v1", "icloud.backup.enabled.v1",
			"onboarding.completed.v1", "charts.subject.v1"
		] {
			defaults.removeObject(forKey: key)
		}
		for kind in ChartKind.allCases {
			defaults.removeObject(forKey: "preset.\(kind.rawValue)")
		}
		profile = .sample
		savedPeople = []
		language = .english
		appearance = .dark
		fontSize = .standard
		presets = Dictionary(uniqueKeysWithValues: ChartKind.allCases.map { ($0, CalculationPreset.modern) })
		synastryPartnerID = nil
		aiConsentGranted = false
		iCloudBackupEnabled = true
		aiContent = [:]
        relationshipAIContent = [:]
		savedReports = []
		generatingCharts = []
        generatingRelationships = []
        relationshipArtifacts = [:]
        relationshipLoadStates = [:]
        relationshipLocationOverride = nil
        relationshipMidpointAlgorithmOverride = nil
        relationshipPerspective = .first
        selectedRelationshipChart = .composite
        advancedChartResults = [:]
        advancedChartLoadStates = [:]
        advancedChartTargetOverrides = [:]
        advancedChartCalculationFingerprints = [:]
		natal = nil
		transitReference = nil
		progressedReference = nil
		currentSky = nil
		transit = nil
		progressed = nil
		solarReturn = nil
		solarReturnReference = nil
		synastry = nil
		todaySignals = []
		todayContributions = []
		todayDashboardModel = nil
		transitCalendar = []
		transitContentPlan = nil
		chartEvents = .empty
		weeklyForecast = .empty
		todayEventsDayKey = nil
		persistPeople()
		await refresh()
		CommerceAccountDeletionState.clearPersonalEraseRequirement()
	}

    func clearGeneratedArtifacts(for chart: ChartKind) {
        artifactStore.remove(chartKind: chart)
        aiContent[chart] = .empty
        reloadSavedReports()
    }

    func clearGeneratedArtifactsForCurrentPerson() {
        artifactStore.remove(subjectHash: profileHashValue)
        aiContent = [:]
        relationshipAIContent = [:]
        reloadSavedReports()
    }

    func clearGeneratedArtifacts(for person: SavedPerson) {
        artifactStore.remove(subjectHash: profileHash(person.profile))
        aiContent[.synastry] = .empty
        relationshipAIContent = [:]
        invalidateAllRelationshipCharts()
        reloadSavedReports()
    }

    func deletePeople(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) {
            let deletedID = savedPeople[index].id.uuidString
            artifactStore.remove(subjectHash: profileHash(savedPeople[index].profile))
            savedPeople.remove(at: index)
            if synastryPartnerID == deletedID { synastryPartnerID = nil }
        }
        persistPeople()
        reloadSavedReports()
    }

    func reloadSavedReports() {
        savedReports = (artifactStore.loadAll().map { SavedReport(artifact: $0) } + artifactStore.loadPeriodReports())
            .sorted { $0.generatedAt > $1.generatedAt }
    }

    /// Local day key in the profile timezone, used to detect when Today's
    /// scanned events belong to an earlier local day.
    var currentLocalDayKey: String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        return String(calendar.startOfDay(for: Date()).timeIntervalSince1970)
    }

    private func nextTransitSignal(
        after now: Date,
        using engine: TodayEngine
    ) async throws -> DailySignal? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: profile.timezoneID) ?? .current
        for dayOffset in 1 ... 7 {
            guard let date = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            if let signal = try await engine.scan(containing: date, skyLimit: 0, transitLimit: 1)
                .first(where: { $0.source == .transit && ($0.eventDate ?? .distantPast) > now })
            {
                return signal
            }
        }
        return nil
    }

    /// Re-scans Today's local-day events when the stored signals are stale
    /// (app alive across local midnight, or an earlier scan failed). On
    /// failure the previous signals are kept so Today never flashes a
    /// spurious empty state; the next Today appearance retries.
    func refreshTodayEventsIfNeeded() async {
        guard todayEventsDayKey != currentLocalDayKey else { return }
        guard !refreshInFlight, !todayEventsRefreshInFlight else { return }
        guard let natalReference = todayReferenceForEvents else { return }
        todayEventsRefreshInFlight = true
        defer { todayEventsRefreshInFlight = false }
        do {
            let calculator = try calculatorInstance()
            let engine = TodayEngine(
                calculator: calculator,
                profile: profile,
                natal: natalReference,
                skyPreset: preset(for: .currentSky),
                transitPreset: preset(for: .transit),
                language: language,
                content: ContentProvider(area: .today, language: language)
            )
            let now = Date()
            let todayEvents = try await engine.scan(containing: now)
            let nextTransit: DailySignal? = if todayEvents.contains(where: {
                $0.source == .transit && ($0.eventDate ?? .distantPast) > now
            }) {
                nil
            } else {
                try await nextTransitSignal(after: now, using: engine)
            }
            guard !Task.isCancelled else { return }
            todaySignals = Array((todayEvents + [nextTransit].compactMap { $0 } + todayActiveSignals).prefix(18))
            todayEventsDayKey = currentLocalDayKey
            todayDashboardModel = makeTodayDashboard(
                contributions: todayContributions,
                signals: todaySignals,
                rules: TodayDashboardRules.load()
            )
        } catch {
            // Keep the previous signals; the next Today appearance retries.
        }
    }

    func refresh() async {
        refreshGeneration &+= 1
        let generation = refreshGeneration
        let refreshStartedAt = Date()
        clearChartFocus()
        guard !refreshInFlight else {
            refreshRequested = true
            return
        }
        refreshInFlight = true
        // A valid cache remains immediately usable while live calculations are
        // refreshed in the background. This prevents every launch or pull-to-
        // refresh from replacing the UI with a multi-second local spinner.
        isCalculating = natal == nil || currentSky == nil
        isEnriching = false
        refreshRequested = false
        errorMessage = nil
        if currentSky == nil {
            todayDashboardModel = nil
        }
        do {
            let calculator = try calculatorInstance()
            logRefreshTiming("calculator-ready", since: refreshStartedAt)
            let now = Date()
            let calculation = try await chartCalculationService.calculate(
                request: AppChartCalculationRequest(
                    subjectProfile: chartSubjectProfile,
                    ownerProfile: profile,
                    synastryPartnerProfile: synastryPartnerID.flatMap(profileForPersonID),
                    presets: presets,
                    now: now,
                    currentSkyTargetDate: currentSkyTargetDate,
                    transitTargetDate: transitTargetDate,
                    secondaryTargetDate: secondaryTargetDate,
                    solarReturnYear: solarReturnYear,
                    currentSkyUsesLiveDefault: currentSkyUsesLiveDefault,
                    transitUsesLiveDefault: transitUsesLiveDefault,
                    secondaryUsesLiveDefault: secondaryUsesLiveDefault,
                    currentSkyLocationOverride: currentSkyLocationOverride,
                    transitLocationOverride: transitLocationOverride,
                    solarReturnLocationOverride: solarReturnLocationOverride,
                    chartsUseOwner: true
                ),
                calculator: calculator
            )
            logRefreshTiming("base-snapshots-ready", since: refreshStartedAt)
            logRefreshTiming("synastry-ready", since: refreshStartedAt)
            let subjectProfile = calculation.subjectProfile
            let skyDate = calculation.skyDate
            let transitDate = calculation.transitDate
            let secondaryDate = calculation.secondaryDate
            let transitLocation = calculation.transitLocation
            let transitReferenceSnapshot = calculation.transitReference
            let skySnapshot = calculation.currentSky
            let transitMovingSnapshot = calculation.transit
            let progressedSnapshot = calculation.progressed
            let solarReturnSnapshot = calculation.solarReturn

            guard generation == refreshGeneration else {
                isCalculating = false
                isCalculatingSynastry = false
                isEnriching = false
                refreshInFlight = false
                if refreshRequested { await refresh() }
                return
            }

            // Every enrichment value below depends on this exact snapshot
            // generation. Invalidate the previous generation before publishing
            // the new snapshots so cards can never combine new wheels with old
            // events or calendars.
            transitCalendar = []
            transitContentPlan = nil
            chartEvents = .empty
            weeklyForecast = .empty

            natal = calculation.natal
            transitReference = calculation.transitReference
            progressedReference = calculation.progressedReference
            currentSky = calculation.currentSky
            transit = calculation.transit
            progressed = calculation.progressed
            solarReturn = calculation.solarReturn
            solarReturnReference = calculation.solarReturnReference
            solarReturnAspects = calculation.solarReturnAspects
            synastry = calculation.synastry
            isCalculatingSynastry = false
            transitAspects = calculation.transitAspects
            progressedAspects = calculation.progressedAspects

            // Today is always calculated for the actual current moment. Chart
            // exploration parameters must never rewrite the consumer homepage.
            let todayNatalSnapshot = calculation.todayNatal
            let todayTransitReferenceSnapshot = calculation.todayTransitReference
            let todayProgressedReferenceSnapshot = calculation.todayProgressedReference
            let todaySkySnapshot = calculation.todaySky
            let todayTransitSnapshot = calculation.todayTransit
            let todayTransitAspects = calculation.todayTransitAspects
            let todayProgressedAspects = calculation.todayProgressedAspects
            todayNatalForContent = todayNatalSnapshot
            todayReferenceForEvents = todayTransitReferenceSnapshot
            todaySkyForContent = todaySkySnapshot
            todayTransitForContent = todayTransitSnapshot
            todayTransitAspectsForContent = todayTransitAspects
            let dashboardRules = TodayDashboardRules.load()
            let todayContext = WeeklyDayContext(
                date: now,
                natal: todayNatalSnapshot,
                frames: [
                    "natal": WeeklySignalFrame(
                        sourceID: "natal",
                        aspects: todayNatalSnapshot.aspects,
                        reference: todayNatalSnapshot
                    ),
                    "current-sky": WeeklySignalFrame(
                        sourceID: "current-sky",
                        aspects: todaySkySnapshot.aspects,
                        reference: todayNatalSnapshot
                    ),
                    "transit": WeeklySignalFrame(
                        sourceID: "transit",
                        aspects: todayTransitAspects,
                        reference: todayTransitReferenceSnapshot
                    ),
                    "secondary": WeeklySignalFrame(
                        sourceID: "secondary",
                        aspects: todayProgressedAspects,
                        reference: todayProgressedReferenceSnapshot
                    ),
                ]
            )
            todayContributions = WeeklySignalRegistry.standard(rules: dashboardRules)
                .flatMap { $0.contributions(for: todayContext) }
            let activeSignals = enrichmentService.buildActiveSignals(
                sky: todaySkySnapshot,
                transits: todayTransitAspects,
                progressions: todayProgressedAspects,
                language: language
            )
            todayActiveSignals = activeSignals
            todaySignals = Array(activeSignals.prefix(5))
            todayDashboardModel = makeTodayDashboard(
                contributions: todayContributions,
                signals: todaySignals,
                rules: dashboardRules
            )
            saveSnapshotCache()
            logRefreshTiming("blocking-content-ready", since: refreshStartedAt)
            // Snapshot-driven screens are ready here. Event searches and the
            // seven-day aggregation are useful enrichment, but must not hold
            // the whole app behind the launch spinner.
            isCalculating = false
            isCalculatingSynastry = false
            isEnriching = true
            do {
                // Today must not wait behind the 90-day transit calendar,
                // weekly forecast, and all-chart event enrichment. Publish its
                // local-day events first; the heavier consumers continue below.
                let todayEngine = TodayEngine(
                    calculator: calculator,
                    profile: profile,
                    natal: todayTransitReferenceSnapshot,
                    skyPreset: preset(for: .currentSky),
                    transitPreset: preset(for: .transit),
                    language: language,
                    content: ContentProvider(area: .today, language: language)
                )
                let todayEvents = try await todayEngine.scan(containing: now)
                let nextTransit: DailySignal? = if todayEvents.contains(where: {
                    $0.source == .transit && ($0.eventDate ?? .distantPast) > now
                }) {
                    nil
                } else {
                    try await nextTransitSignal(after: now, using: todayEngine)
                }
                guard generation == refreshGeneration else {
                    throw CancellationError()
                }
                todaySignals = Array((todayEvents + [nextTransit].compactMap { $0 } + activeSignals).prefix(18))
                todayEventsDayKey = currentLocalDayKey
                todayDashboardModel = makeTodayDashboard(
                    contributions: todayContributions,
                    signals: todaySignals,
                    rules: dashboardRules
                )
                logRefreshTiming("today-events-ready", since: refreshStartedAt)

                let transitTimeZone = TimeZone(identifier: transitLocation.timezoneID) ?? .current
                let timelineRangeDays = TransitTimelineContract.maximumRangeDays
                let transitScopeID = TransitFactBundleBuilder.makeScopeID(
                    snapshot: transitMovingSnapshot,
                    natal: transitReferenceSnapshot,
                    crossAspects: transitAspects,
                    preset: preset(for: .transit).rawValue,
                    timeZoneIdentifier: transitTimeZone.identifier,
                    rangeDays: timelineRangeDays
                )
                let transitSamples = try await enrichmentService.buildTransitEphemerisSamples(
                    calculator: calculator,
                    startingAt: transitDate,
                    rangeDays: timelineRangeDays,
                    timeZone: transitTimeZone,
                    location: transitLocation.geographicLocation,
                    preset: preset(for: .transit)
                )
                let nextTransitCalendar = enrichmentService.buildTransitCalendar(
                    natal: transitReferenceSnapshot,
                    startingAt: transitDate,
                    rangeDays: timelineRangeDays,
                    scopeID: transitScopeID,
                    timeZone: transitTimeZone,
                    samples: transitSamples
                )
                logRefreshTiming("transit-calendar-ready", since: refreshStartedAt)
                let nextWeeklyForecast = try await enrichmentService.buildWeeklyForecast(
                    calculator: calculator,
                    profile: profile,
                    presets: presets,
                    language: language,
                    natal: todayNatalSnapshot,
                    transitReference: todayTransitReferenceSnapshot,
                    progressedReference: todayProgressedReferenceSnapshot,
                    startingAt: now
                )
                logRefreshTiming("weekly-forecast-ready", since: refreshStartedAt)
                let nextChartEvents = try await ChartEventBuilder.build(
                    calculator: calculator,
                    skyAnchor: skyDate,
                    transitAnchor: transitDate,
                    secondaryTargetDate: secondaryDate,
                    birthDate: subjectProfile.birthDateUTC,
                    location: subjectProfile.location,
                    skySnapshot: skySnapshot,
                    skyPreset: preset(for: .currentSky),
                    transitNatal: transitReferenceSnapshot,
                    transitPreset: preset(for: .transit),
                    transitRangeDays: timelineRangeDays,
                    transitSamples: transitSamples,
                    timeZone: transitTimeZone,
                    transitAspects: transitAspects,
                    progressedSnapshot: progressedSnapshot,
                    progressedAspects: progressedAspects,
                    solarReturnMoment: solarReturnSnapshot.utcDate
                )
                let nextTransitContentPlan = enrichmentService.makeTransitContentPlan(
                    snapshot: transitMovingSnapshot,
                    natal: transitReferenceSnapshot,
                    aspects: transitAspects,
                    events: nextChartEvents,
                    timeZone: transitTimeZone,
                    calendarDays: nextTransitCalendar,
                    preset: preset(for: .transit)
                )
                guard generation == refreshGeneration else {
                    throw CancellationError()
                }
                transitCalendar = nextTransitCalendar
                weeklyForecast = nextWeeklyForecast
                chartEvents = nextChartEvents
                transitContentPlan = nextTransitContentPlan
                saveSnapshotCache()
                logRefreshTiming("chart-events-ready", since: refreshStartedAt)
            } catch {
                #if DEBUG
                print("TIMING_ENRICHMENT_ERROR: \(error)")
                #endif
            }
            isEnriching = false
            logRefreshTiming("refresh-complete", since: refreshStartedAt)
        } catch {
            errorMessage = localized("app.error.local-chart-calculation", language: language)
        }
        isCalculating = false
        isCalculatingSynastry = false
        isEnriching = false
        refreshInFlight = false
        if refreshRequested {
            await refresh()
        }
    }

    private func makeTodayDashboard(
        contributions: [WeeklySignalContribution],
        signals: [DailySignal],
        rules: TodayDashboardRules
    ) -> TodayDashboardModel? {
        do {
            let dashboard = try TodayDashboardFactory.make(
                contributions: contributions,
                signals: signals,
                content: ContentProvider(area: .today, language: language),
                rules: rules,
                language: language,
                timeZone: TimeZone(identifier: profile.timezoneID) ?? .current
            )
            todayContentErrorMessage = nil
            return dashboard
        } catch let error as ConsumerContentError {
            todayContentErrorMessage = localized("today.error.content-unavailable", language: language)
            #if DEBUG
            print("TODAY_CONTENT_ERROR: \(error)")
            #endif
            return nil
        } catch {
            todayContentErrorMessage = localized("today.error.content-unavailable", language: language)
            #if DEBUG
            print("TODAY_CONTENT_ERROR: \(error)")
            #endif
            return nil
        }
    }

    private func logRefreshTiming(_ stage: String, since startedAt: Date) {
        #if DEBUG
        let elapsed = Date().timeIntervalSince(startedAt)
        print(String(format: "REFRESH_TIMING %.3fs %@", elapsed, stage))
        #endif
    }

    private func restoreSnapshotCache() {
        guard let cached = snapshotCache.load(),
              cached.schemaVersion == SnapshotCachePayload.currentSchemaVersion,
              cached.configurationFingerprint == snapshotCacheFingerprint(at: Date())
        else {
            return
        }
        natal = cached.natal
        transitReference = cached.transitReference
        progressedReference = cached.progressedReference
        currentSky = cached.currentSky
        transit = cached.transit
        progressed = cached.progressed
        solarReturn = cached.solarReturn
        solarReturnReference = cached.solarReturnReference
        solarReturnAspects = cached.solarReturnAspects
        synastry = cached.synastry
        transitAspects = cached.transitAspects
        progressedAspects = cached.progressedAspects
        transitCalendar = cached.transitCalendar
        chartEvents = cached.chartEvents
        transitContentPlan = enrichmentService.makeTransitContentPlan(
            snapshot: cached.transit,
            natal: cached.transitReference,
            aspects: cached.transitAspects,
            events: cached.chartEvents,
            timeZone: TimeZone(
                identifier: transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            ) ?? .current,
            calendarDays: cached.transitCalendar,
            preset: preset(for: .transit)
        )
    }

    private func saveSnapshotCache() {
        guard let natal,
              let transitReference,
              let progressedReference,
              let currentSky,
              let transit,
              let progressed,
              let solarReturn,
              let solarReturnReference
        else {
            return
        }
        snapshotCache.save(
            SnapshotCachePayload(
                schemaVersion: SnapshotCachePayload.currentSchemaVersion,
                configurationFingerprint: snapshotCacheFingerprint(at: Date()),
                savedAt: Date(),
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
                transitCalendar: transitCalendar,
                chartEvents: chartEvents
            )
        )
    }

    private func snapshotCacheFingerprint(at date: Date) -> String {
        let subject = chartSubjectProfile
        let defaultLocation = ChartLocationSelection(
            placeName: subject.placeName,
            timezoneID: subject.timezoneID,
            latitude: subject.latitude,
            longitude: subject.longitude
        )
        let skyLocation = currentSkyLocationOverride ?? defaultLocation
        let transitLocation = transitLocationOverride ?? defaultLocation
        let returnLocation = solarReturnLocationOverride ?? defaultLocation
        let presetValues = ChartKind.coreCases
            .map { "\($0.rawValue)=\(preset(for: $0).rawValue)" }
            .sorted()
            .joined(separator: ",")
        let partnerHash = synastryPartnerID
            .flatMap { id in savedPeople.first(where: { $0.id.uuidString == id }) }
            .map { profileHash($0.profile) } ?? "none"
        let raw = [
            "snapshot-cache-v\(SnapshotCachePayload.currentSchemaVersion)",
            profileHash(subject),
            presetValues,
            "partner=\(partnerHash)",
            "sky=\(currentSkyUsesLiveDefault ? bucket(date, format: "yyyy-MM-dd", timeZoneID: skyLocation.timezoneID) : minuteCacheValue(currentSkyTargetDate))",
            "sky-location=\(cacheLocationValue(skyLocation))",
            "transit=\(transitUsesLiveDefault ? bucket(date, format: "yyyy-MM-dd", timeZoneID: transitLocation.timezoneID) : minuteCacheValue(transitTargetDate))",
            "transit-location=\(cacheLocationValue(transitLocation))",
            "transit-range=\(transitRangeDays)",
            "secondary=\(secondaryUsesLiveDefault ? bucket(date, format: "yyyy-MM", timeZoneID: subject.timezoneID) : dayCacheValue(secondaryTargetDate, timeZoneID: subject.timezoneID))",
            "return=\(solarReturnYear)|\(cacheLocationValue(returnLocation))",
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    private func cacheLocationValue(_ location: ChartLocationSelection) -> String {
        [
            location.timezoneID,
            String(format: "%.6f", location.latitude),
            String(format: "%.6f", location.longitude),
        ].joined(separator: ",")
    }

    private func minuteCacheValue(_ date: Date) -> String {
        String(Int(floor(date.timeIntervalSince1970 / 60)))
    }

    private func dayCacheValue(_ date: Date, timeZoneID: String) -> String {
        bucket(date, format: "yyyy-MM-dd", timeZoneID: timeZoneID)
    }

    private func bucket(_ date: Date, format: String, timeZoneID: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateFormat = format
        return formatter.string(from: date)
    }

    func advancedChartLoadState(for chart: ChartKind) -> AdvancedChartLoadState {
        guard chart.isAdvancedChart else { return .idle }
        return advancedChartLoadStates[chart] ?? .idle
    }

    func ensureAdvancedChartCalculated(_ chart: ChartKind) async {
        guard chart.isAdvancedChart else { return }
        let context = chartContext(for: chart)
        let fingerprint = advancedChartFingerprint(for: chart, context: context)

        if advancedChartCalculationFingerprints[chart] == fingerprint,
           advancedChartResults[chart] != nil
        {
            advancedChartLoadStates[chart] = .ready
            refreshAIReportState(for: chart)
            return
        }
        if advancedChartCalculationFingerprints[chart] == fingerprint,
           advancedChartLoadStates[chart] == .loading
        {
            return
        }
        if let cached = advancedChartCache.load(chart: chart, fingerprint: fingerprint) {
            advancedChartCalculationFingerprints[chart] = fingerprint
            advancedChartResults[chart] = cached
            advancedChartLoadStates[chart] = .ready
            refreshAIReportState(for: chart)
            return
        }

        advancedChartCalculationFingerprints[chart] = fingerprint
        advancedChartLoadStates[chart] = .loading
        do {
            let calculator = try calculatorInstance()
            let result = try await advancedChartCalculationService.calculate(
                chart: chart,
                context: context,
                profile: chartSubjectProfile,
                calculator: calculator
            )
            guard advancedChartCalculationFingerprints[chart] == fingerprint else { return }
            let currentFingerprint = advancedChartFingerprint(
                for: chart,
                context: chartContext(for: chart)
            )
            guard currentFingerprint == fingerprint else { return }
            advancedChartResults[chart] = result
            advancedChartLoadStates[chart] = .ready
            advancedChartCache.save(chart: chart, fingerprint: fingerprint, result: result)
            refreshAIReportState(for: chart)
        } catch {
            guard advancedChartCalculationFingerprints[chart] == fingerprint else { return }
            advancedChartResults.removeValue(forKey: chart)
            advancedChartLoadStates[chart] = .failed(error.localizedDescription)
        }
    }

    private func invalidateAdvancedChart(_ chart: ChartKind) {
        guard chart.isAdvancedChart else { return }
        advancedChartResults.removeValue(forKey: chart)
        advancedChartLoadStates[chart] = .idle
        advancedChartCalculationFingerprints.removeValue(forKey: chart)
    }

    private func invalidateAllAdvancedCharts() {
        advancedChartResults.removeAll()
        advancedChartLoadStates.removeAll()
        advancedChartCalculationFingerprints.removeAll()
    }

    private func advancedChartFingerprint(
        for chart: ChartKind,
        context: ChartContext
    ) -> String {
        let subject = chartSubjectProfile
        let targetValue: String = switch context.target {
        case let .tertiary(targetDate, usesLiveDefault):
            "tertiary=\(usesLiveDefault ? "live" : "selected")|\(dayCacheValue(targetDate, timeZoneID: subject.timezoneID))"
        case let .lunarReturn(targetDate, location, usesLiveDefault):
            "lunar-return=\(usesLiveDefault ? "live" : "selected")|\(dayCacheValue(targetDate, timeZoneID: location.timezoneID))|\(cacheLocationValue(location))"
        case let .solarArc(targetDate, usesLiveDefault):
            "solar-arc=\(usesLiveDefault ? "live" : "selected")|\(dayCacheValue(targetDate, timeZoneID: subject.timezoneID))"
        case let .relocation(location):
            "relocation=\(cacheLocationValue(location))"
        case .twelfthHarmonic:
            "harmonic=12"
        case .thirteenthHarmonic:
            "harmonic=13"
        default:
            "unsupported"
        }
        let raw = [
            "advanced-chart-cache-v1",
            "technique-version=1",
            chart.rawValue,
            context.primaryPersonID,
            context.preset.rawValue,
            targetValue,
        ].joined(separator: "|")
        return SHA256Digest.hash(Data(raw.utf8)).hex
    }

    func snapshot(for chart: ChartKind) -> ChartSnapshot? {
        if focusedChart == chart {
            return focusedSnapshot
        }
        return switch chart {
        case .natal: natal
        case .currentSky: currentSky
        case .transit: transit
        case .secondary: progressed
        case .solarReturn: solarReturn
        case .synastry: synastry?.first
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            advancedChartResults[chart]?.snapshot
        }
    }

    func comparisonAspects(for chart: ChartKind) -> [ChartAspect] {
        if focusedChart == chart {
            return focusedAspects
        }
        return switch chart {
        case .transit: transitAspects
        case .secondary: progressedAspects
        case .solarReturn: solarReturnAspects
        case .synastry: synastry?.crossAspects ?? []
        case .natal, .currentSky: snapshot(for: chart)?.aspects ?? []
        case .tertiary, .lunarReturn, .solarArc, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            advancedChartResults[chart]?.comparisonAspects ?? []
        }
    }

    func referenceSnapshot(for chart: ChartKind) -> ChartSnapshot? {
        switch chart {
        case .transit: transitReference
        case .secondary: progressedReference
        case .solarReturn: solarReturnReference
        case .synastry: synastry?.second
        case .natal, .currentSky, .relocation: nil
        case .tertiary, .lunarReturn, .solarArc, .twelfthHarmonic, .thirteenthHarmonic:
            advancedChartResults[chart]?.reference
        }
    }

    func insightCards(for chart: ChartKind) -> InsightCardLoadState {
        guard chart.supportsInsightCards else { return .loaded([]) }
        do {
            let catalogResult: Result<CopyCatalogProvider, Error>
            if let cached = copyCatalogProviders[language] {
                catalogResult = cached
            } else {
                catalogResult = Result { try CopyCatalogProvider(language: language) }
                copyCatalogProviders[language] = catalogResult
            }
            let cardSnapshot = snapshot(for: chart)
            let cardNatal = chart.usesReferenceWheel ? referenceSnapshot(for: chart) : natal
            let cardAspects = comparisonAspects(for: chart)
            let isFocusedTransit = focusedChart == .transit && chart == .transit
            let cardEvents = focusedChart == chart ? .empty : chartEvents
            let cardTimeZoneID = switch chart {
            case .currentSky:
                currentSkyLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            case .transit:
                transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            case .solarReturn:
                solarReturnLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            case .natal, .secondary, .synastry, .tertiary, .lunarReturn, .solarArc,
                 .relocation, .twelfthHarmonic, .thirteenthHarmonic:
                chartSubjectProfile.timezoneID
            }
            let cardTimeZone = TimeZone(identifier: cardTimeZoneID) ?? .current
            let cardTransitCalendar = isFocusedTransit ? [] : transitCalendar
            let plannedTransit = chart == .transit
                ? enrichmentService.makeTransitContentPlan(
                    snapshot: cardSnapshot,
                    natal: cardNatal,
                    aspects: cardAspects,
                    events: cardEvents,
                    timeZone: cardTimeZone,
                    calendarDays: cardTransitCalendar,
                    preset: preset(for: .transit)
                )
                : nil
            let cards = try InsightFactory.make(
                chart: chart,
                snapshot: cardSnapshot,
                natal: cardNatal,
                aspects: cardAspects,
                content: nil,
                copyCatalog: try catalogResult.get(),
                language: language,
                transitCalendar: cardTransitCalendar,
                transitRangeDays: transitRangeDays,
                transitContentPlan: plannedTransit,
                synastryComparison: chart == .synastry ? synastry : nil,
                synastryFirstName: chart == .synastry ? profile.name : nil,
                synastrySecondName: chart == .synastry ? synastryPartnerID.flatMap(profileForPersonID)?.name : nil,
                preset: preset(for: chart).rawValue,
                events: cardEvents,
                timeZone: cardTimeZone
            )
            return .loaded(cards)
        } catch {
            #if DEBUG
            print("INSIGHT_ERROR \(chart.rawValue): \(error)")
            #endif
            #if DEBUG
            return .unavailable(String(describing: error))
            #else
            return .unavailable(
                localized("app.interpretation-content-is-incomplete-for-this-chart", language: language)
            )
            #endif
        }
    }

    func todayCardText(_ cardID: String) -> CardTextModel? {
        guard let sky = todaySkyForContent ?? currentSky,
              let transit = todayTransitForContent ?? self.transit,
              let natal = todayNatalForContent ?? self.natal
        else { return nil }
        let result: Result<CopyCatalogProvider, Error>
        if let cached = copyCatalogProviders[language] {
            result = cached
        } else {
            result = Result { try CopyCatalogProvider(language: language) }
            copyCatalogProviders[language] = result
        }
        guard let matcher = try? result.get() else { return nil }
       return matcher.todayText(
           cardID: cardID,
           sky: sky,
           transit: transit,
           natal: natal,
            transitAspects: todayTransitAspectsForContent.isEmpty ? transitAspects : todayTransitAspectsForContent,
            preset: todayCardPreset(cardID)
        )
    }

    func todayTransitContext(for signal: DailySignal) -> (domain: TodayLifeDomain, theme: String)? {
        guard let aspect = todayTransitAspect(for: signal),
              let natal = todayNatalForContent ?? self.natal,
              let body = CelestialBody(rawValue: aspect.firstID)
        else { return nil }
        let house = natal.house(containing: aspect.secondLongitude)
        let rules = TodayDashboardRules.load()
        let domain = TodayLifeDomain.allCases.first { rules.houses(for: $0).contains(house) }
            ?? .energy
        return (domain, ConsumerCopy.bodyTheme(body, language: language))
    }

    func todayTransitAspect(for signal: DailySignal) -> ChartAspect? {
        guard signal.source == .transit else { return nil }
        return todayTransitAspectsForContent.first {
            signal.id == "transit-\($0.id)" || signal.id.contains("-\($0.id)-")
        }
    }

    func todayTransitWindow(for signal: DailySignal) -> ChartEventData.TransitWindow? {
        guard let aspect = todayTransitAspect(for: signal),
              let first = CelestialBody(rawValue: aspect.firstID),
              let second = CelestialBody(rawValue: aspect.secondID)
        else { return nil }
        return chartEvents.transitWindows.first {
            $0.first == first && $0.second == second && $0.kind == aspect.kind
        }
    }

    private func todayCardPreset(_ cardID: String) -> String {
        switch cardID {
        case "current-chapter", "active-today", "coming-next":
            return preset(for: .transit).rawValue
        default:
            return preset(for: .currentSky).rawValue
        }
    }

    func selectChart(_ chart: ChartKind) {
        clearChartFocus()
        selectedChart = chart
        if chart.isAdvancedChart {
            Task { await ensureAdvancedChartCalculated(chart) }
        }
    }

    func requestChartParameterEditing(_ chart: ChartKind) {
        selectChart(chart)
        chartParameterEditRequest = chart
    }

    func consumeChartParameterEditRequest() {
        chartParameterEditRequest = nil
    }

    func chartContext(for chart: ChartKind) -> ChartContext {
        let subject = chart == .synastry ? profile : chartSubjectProfile
        let defaultLocation = chartLocation(for: subject)
        let target: ChartTarget = switch chart {
        case .natal:
            .natal
        case .currentSky:
            .currentSky(
                instant: currentSkyUsesLiveDefault ? Date() : currentSkyTargetDate,
                location: currentSkyLocationOverride ?? defaultLocation,
                usesLiveDefault: currentSkyUsesLiveDefault
            )
        case .transit:
            .transit(
                instant: transitUsesLiveDefault ? Date() : transitTargetDate,
                location: transitLocationOverride ?? defaultLocation,
                rangeDays: transitRangeDays,
                usesLiveDefault: transitUsesLiveDefault
            )
        case .secondary:
            .secondary(
                targetDate: secondaryUsesLiveDefault ? Date() : secondaryTargetDate,
                usesLiveDefault: secondaryUsesLiveDefault
            )
        case .solarReturn:
            .solarReturn(year: solarReturnYear, location: solarReturnLocationOverride ?? defaultLocation)
        case .synastry:
            .synastry
        case .tertiary:
            advancedChartTargetOverrides[chart] ?? .tertiary(targetDate: Date(), usesLiveDefault: true)
        case .lunarReturn:
            advancedChartTargetOverrides[chart]
                ?? .lunarReturn(targetDate: Date(), location: defaultLocation, usesLiveDefault: true)
        case .solarArc:
            advancedChartTargetOverrides[chart] ?? .solarArc(targetDate: Date(), usesLiveDefault: true)
        case .relocation:
            advancedChartTargetOverrides[chart] ?? .relocation(location: defaultLocation)
        case .twelfthHarmonic:
            .twelfthHarmonic
        case .thirteenthHarmonic:
            .thirteenthHarmonic
        }
        return ChartContext(
            chartKind: chart,
            primaryPersonID: chart == .currentSky ? "none" : profileHash(subject),
            comparisonPersonID: chart == .synastry ? subjectHashes(for: chart).dropFirst().first : nil,
            preset: preset(for: chart),
            locale: language,
            target: target
        )
    }

    private func chartLocation(for profile: UserProfile) -> ChartLocationSelection {
        ChartLocationSelection(
            placeName: profile.placeName,
            timezoneID: profile.timezoneID,
            latitude: profile.latitude,
            longitude: profile.longitude
        )
    }

    func setTargetDate(_ date: Date, for chart: ChartKind) {
        clearChartFocus()
        switch chart {
        case .currentSky:
            currentSkyTargetDate = date
            currentSkyUsesLiveDefault = false
        case .transit:
            transitTargetDate = date
            transitUsesLiveDefault = false
        case .secondary:
            secondaryTargetDate = date
            secondaryUsesLiveDefault = false
        case .solarReturn:
            solarReturnYear = Calendar.current.component(.year, from: date)
        case .tertiary:
            advancedChartTargetOverrides[chart] = .tertiary(targetDate: date, usesLiveDefault: false)
        case .lunarReturn:
            let location: ChartLocationSelection
            if case let .lunarReturn(_, savedLocation, _) = advancedChartTargetOverrides[chart] {
                location = savedLocation
            } else {
                location = chartLocation(for: chartSubjectProfile)
            }
            advancedChartTargetOverrides[chart] = .lunarReturn(
                targetDate: date,
                location: location,
                usesLiveDefault: false
            )
        case .solarArc:
            advancedChartTargetOverrides[chart] = .solarArc(targetDate: date, usesLiveDefault: false)
        case .natal, .synastry, .relocation, .twelfthHarmonic, .thirteenthHarmonic:
            return
        }
        if chart.isAdvancedChart {
            invalidateAdvancedChart(chart)
            if selectedChart == chart {
                Task { await ensureAdvancedChartCalculated(chart) }
            }
        } else {
            Task { await refresh() }
        }
    }

    func setReferenceLocation(_ selection: LocationSelection, for chart: ChartKind) {
        let value = ChartLocationSelection(
            placeName: selection.name,
            timezoneID: selection.timezoneID,
            latitude: selection.latitude,
            longitude: selection.longitude
        )
        switch chart {
        case .currentSky:
            currentSkyLocationOverride = value
        case .transit:
            transitLocationOverride = value
        case .solarReturn:
            solarReturnLocationOverride = value
        case .lunarReturn:
            let targetDate: Date
            let usesLiveDefault: Bool
            if case let .lunarReturn(savedDate, _, savedUsesLiveDefault) = advancedChartTargetOverrides[chart] {
                targetDate = savedDate
                usesLiveDefault = savedUsesLiveDefault
            } else {
                targetDate = Date()
                usesLiveDefault = true
            }
            advancedChartTargetOverrides[chart] = .lunarReturn(
                targetDate: targetDate,
                location: value,
                usesLiveDefault: usesLiveDefault
            )
        case .relocation:
            advancedChartTargetOverrides[chart] = .relocation(location: value)
        case .natal, .secondary, .synastry, .tertiary, .solarArc, .twelfthHarmonic, .thirteenthHarmonic:
            return
        }
        if chart.isAdvancedChart {
            invalidateAdvancedChart(chart)
            if selectedChart == chart {
                Task { await ensureAdvancedChartCalculated(chart) }
            }
        } else {
            Task { await refresh() }
        }
    }

    func setTransitRangeDays(_ days: Int) {
        transitRangeDays = TransitTimelineContract.rangeDays.contains(days)
            ? days
            : TransitTimelineContract.defaultRangeDays
        Task { await refresh() }
    }

    func resetTarget(for chart: ChartKind) {
        switch chart {
        case .currentSky:
            currentSkyUsesLiveDefault = true
            currentSkyTargetDate = Date()
            currentSkyLocationOverride = nil
        case .transit:
            transitUsesLiveDefault = true
            transitTargetDate = Date()
            transitLocationOverride = nil
            transitRangeDays = TransitTimelineContract.defaultRangeDays
        case .secondary:
            secondaryUsesLiveDefault = true
            secondaryTargetDate = Date()
        case .solarReturn:
            solarReturnYear = Calendar.current.component(.year, from: Date())
            solarReturnLocationOverride = nil
        case .tertiary, .lunarReturn, .solarArc, .relocation:
            advancedChartTargetOverrides.removeValue(forKey: chart)
        case .twelfthHarmonic, .thirteenthHarmonic, .natal, .synastry:
            return
        }
        if chart.isAdvancedChart {
            invalidateAdvancedChart(chart)
            if selectedChart == chart {
                Task { await ensureAdvancedChartCalculated(chart) }
            }
        } else {
            Task { await refresh() }
        }
    }

    func openSignal(_ signal: DailySignal) {
        let chart: ChartKind
        switch signal.source {
        case .sky: chart = .currentSky
        case .transit: chart = .transit
        case .secondary: chart = .secondary
        }
        selectedChart = chart

        guard let date = signal.eventDate else {
            clearChartFocus()
            return
        }

        focusedChart = chart
        focusedChartDate = date
        focusedSnapshot = nil
        focusedAspects = []
        isCalculatingFocus = true
        Task { await calculateFocusedChart(chart, at: date) }
    }

    func clearChartFocus() {
        focusedChart = nil
        focusedChartDate = nil
        focusedSnapshot = nil
        focusedAspects = []
        isCalculatingFocus = false
    }

    func calculateHorarySnapshot(
        at date: Date,
        location: GeographicLocation
    ) async throws -> ChartSnapshot {
        let calculator = try calculatorInstance()
        return try await calculator.calculateSnapshot(
            NatalInput(utcDate: date, location: location),
            configuration: .horary
        )
    }

    func calculateHoraryJudgment(
        snapshot: ChartSnapshot,
        targetHouse: Int,
        targetRuler: CelestialBody? = nil,
        relatedHouses: [Int] = []
    ) async throws -> HoraryAnalysis {
        let calculator = try calculatorInstance()
        return try await HoraryEngine.judgedAnalysis(
            snapshot: snapshot,
            targetHouse: targetHouse,
            targetRuler: targetRuler,
            relatedHouses: relatedHouses,
            calculator: calculator
        )
    }

    func calculateHoraryChoices(
        snapshot: ChartSnapshot,
        candidates: [HoraryChoiceCandidate],
        mode: HoraryChoiceSignificatorMode
    ) async throws -> [HoraryChoiceResult] {
        let calculator = try calculatorInstance()
        return try await HoraryEngine.judgedChoices(
            snapshot: snapshot,
            candidates: candidates,
            mode: mode,
            calculator: calculator
        )
    }

    func searchElectionTiming(
        _ request: ElectionTimingRequest,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> [ElectionTimingCandidate] {
        let calculator = try calculatorInstance()
        return try await ElectionTimingEngine(calculator: calculator)
            .search(request, progress: progress)
    }

    private func calculateFocusedChart(_ chart: ChartKind, at date: Date) async {
        do {
            let calculator = try calculatorInstance()
            let subject = chartSubjectProfile
            let natalSnapshot: ChartSnapshot
            if let reference = referenceSnapshot(for: chart) {
                natalSnapshot = reference
            } else {
                natalSnapshot = try await calculator.calculateSnapshot(
                    NatalInput(utcDate: subject.birthDateUTC, location: subject.location),
                    preset: preset(for: chart)
                )
            }

            let movingDate: Date
            if chart == .secondary {
                movingDate = SwissEphemerisCalculator.secondaryProgressedDate(
                    birthDate: subject.birthDateUTC,
                    targetDate: date
                )
            } else {
                movingDate = date
            }
            let movingLocation = chart == .transit
                ? transitLocationOverride?.geographicLocation ?? subject.location
                : subject.location
            let snapshot = try await calculator.calculateSnapshot(
                NatalInput(utcDate: movingDate, location: movingLocation),
                preset: preset(for: chart),
                aspectOrbDegrees: chart == .secondary ? 3 : 6
            )
            let aspects: [ChartAspect]
            if chart.isComparison {
                aspects = SwissEphemerisCalculator.compare(
                    moving: snapshot,
                    reference: natalSnapshot,
                    orbDegrees: chart == .secondary ? 2 : ChartEventBuilder.transitAspectOrbDegrees
                )
            } else {
                aspects = snapshot.aspects
            }

            guard focusedChart == chart, focusedChartDate == date else { return }
            focusedSnapshot = snapshot
            focusedAspects = aspects
        } catch {
            guard focusedChart == chart, focusedChartDate == date else { return }
            errorMessage = localized("app.error.selected-event-chart-calculation", language: language)
        }
        if focusedChart == chart, focusedChartDate == date {
            isCalculatingFocus = false
        }
    }

    private func calculatorInstance() throws -> SwissEphemerisCalculator {
        if let calculator { return calculator }
        let candidates = [
            Bundle.main.url(forResource: "ephe", withExtension: nil),
            Bundle.main.resourceURL?.appendingPathComponent("ephe"),
        ].compactMap { $0 }
        guard let directory = candidates.first(where: {
            FileManager.default.fileExists(atPath: $0.path)
        }) else {
            throw AppModelError.missingEphemeris
        }
        let created = try SwissEphemerisCalculator(ephemerisDirectory: directory)
        calculator = created
        return created
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: "profile.v1")
        }
		scheduleICloudBackup()
    }

    private func persistPeople() {
        if let data = try? JSONEncoder().encode(savedPeople) {
            defaults.set(data, forKey: "people.v1")
        }
		scheduleICloudBackup()
    }

	func saveICloudBackup() async {
		guard iCloudBackupEnabled else { return }
		let envelope = ICloudBackupEnvelope(version: 1, updatedAt: Date(), profile: profile, people: savedPeople, language: language, appearance: appearance, fontSize: fontSize, presets: presets, reports: artifactStore.loadAll(), periodReports: artifactStore.loadPeriodReports())
		do { try await ICloudBackupStore.shared.save(envelope); iCloudBackupStatus = localized("icloud.saved", language: language) }
		catch { iCloudBackupStatus = localized("icloud.unavailable", language: language) }
	}

	func restoreICloudBackup() async {
		do {
			guard let backup = try await ICloudBackupStore.shared.load() else { iCloudBackupStatus = localized("icloud.no-backup", language: language); return }
			isRestoringICloudBackup = true
			defer { isRestoringICloudBackup = false }
			profile = backup.profile; savedPeople = backup.people; language = backup.language; appearance = backup.appearance; fontSize = backup.fontSize; presets = backup.presets
			backup.reports.forEach { _ = artifactStore.save($0) }
			(backup.periodReports ?? []).forEach { _ = artifactStore.savePeriodReport($0) }
			persistPeople(); reloadSavedReports(); iCloudBackupStatus = localized("icloud.restored", language: language); await refresh()
		} catch { iCloudBackupStatus = localized("icloud.unavailable", language: language) }
	}

	func scheduleICloudBackup() {
		guard iCloudBackupEnabled, !isRestoringICloudBackup else { return }
		Task { await saveICloudBackup() }
	}

    // MARK: - AI generation (LLM interpretation + reports)

    func grantAIConsent() {
        aiConsentGranted = true
        defaults.set(true, forKey: "ai.network.consent.v1")
    }

    func revokeAIConsent() {
        aiConsentGranted = false
        defaults.set(false, forKey: "ai.network.consent.v1")
    }

    func aiReport(for chart: ChartKind) -> AIReport? {
        aiContent[chart]?.report
    }

    func currentSavedReport(for chart: ChartKind) -> SavedReport? {
        let scope = "chart.\(chart.contentPrefix)"
        if let key = aiContent[chart]?.cacheKey,
           !key.isEmpty,
           let exact = savedReports.first(where: { $0.id == key })
        {
            return exact
        }
        // The report library must remain able to open the latest locally saved
        // report even when the current chart parameters now produce a different
        // semantic fingerprint. Regeneration will use the current parameters.
        return savedReports.first { $0.scope == scope }
    }

    func aiReportStatus(for chart: ChartKind) -> AIReportGenerationStatus {
        if generatingCharts.contains(chart) { return .generating }
        if PendingReportManager.shared.hasPendingChartReport(chartPrefix: chart.contentPrefix) { return .generating }
        return aiContent[chart]?.status ?? .idle
    }

    func currentSavedReport(for relationshipKind: RelationshipChartKind) -> SavedReport? {
        let prefix = relationshipKind.reportScope
        if let key = relationshipAIContent[relationshipKind.rawValue]?.cacheKey,
           !key.isEmpty,
           let exact = savedReports.first(where: { $0.id == key })
        {
            return exact
        }
        if let report = savedReports.first(where: { $0.scope == prefix }) { return report }
        if relationshipKind.rawValue == RelationshipChartKind.synastryA.rawValue {
            return savedReports.first(where: { $0.scope == "chart.synastry" })
        }
        return nil
    }

    func aiReportStatus(for relationshipKind: RelationshipChartKind) -> AIReportGenerationStatus {
        let raw = relationshipKind.rawValue
        let prefix = relationshipKind.reportScope
        if generatingRelationships.contains(raw) { return .generating }
        if PendingReportManager.shared.hasPendingChartReport(chartPrefix: prefix) { return .generating }
        if currentSavedReport(for: relationshipKind) != nil, relationshipAIContent[raw]?.status == nil {
            return .ready
        }
        return relationshipAIContent[raw]?.status ?? .idle
    }

    func refreshAIReportStates() {
        for chart in ChartKind.allCases {
            refreshAIReportState(for: chart)
        }
        for kind in RelationshipChartKind.allCases {
            refreshAIReportState(for: kind)
        }
        reloadSavedReports()
    }

    private func refreshAIReportState(for kind: RelationshipChartKind) {
        guard relationshipSnapshot(for: kind) != nil else { return }
        let raw = kind.rawValue
        guard !generatingRelationships.contains(raw) else { return }
        guard !PendingReportManager.shared.hasPendingChartReport(chartPrefix: kind.reportScope) else { return }
        guard let context = try? relationshipAIReportRequestContext(for: kind) else { return }
        if let artifact = artifactStore.load(key: context.key) {
            applyRelationshipArtifact(artifact, kind: kind)
        } else if relationshipAIContent[raw]?.cacheKey != context.key {
            relationshipAIContent[raw] = .empty
        }
    }

    private func refreshAIReportState(for chart: ChartKind) {
        guard snapshot(for: chart) != nil else { return }
        guard !generatingCharts.contains(chart) else { return }
        guard !PendingReportManager.shared.hasPendingChartReport(chartPrefix: chart.contentPrefix) else { return }
        guard let context = try? aiReportRequestContext(for: chart) else { return }
        if let artifact = artifactStore.load(key: context.key) {
            applyArtifact(artifact, chart: chart)
        } else if aiContent[chart]?.cacheKey != context.key {
            aiContent[chart] = .empty
        }
    }

    func generateAIReport(
        for chart: ChartKind,
        forceRegenerate: Bool = false,
        relationship: PersonRelationship? = nil,
        preset: CalculationPreset? = nil
    ) async {
        if let preset, preset != self.preset(for: chart) {
            guard CalculationPreset.consumerCases.contains(preset) else { return }
            presets[chart] = preset
            defaults.set(preset.rawValue, forKey: "preset.\(chart.rawValue)")
            if chart.isAdvancedChart {
                invalidateAdvancedChart(chart)
            } else {
                await refresh()
            }
        }
        if chart.isAdvancedChart {
            await ensureAdvancedChartCalculated(chart)
        }
        guard snapshot(for: chart) != nil else { return }
        guard !generatingCharts.contains(chart) else { return }
        guard !PendingReportManager.shared.hasPendingChartReport(chartPrefix: chart.contentPrefix) else { return }

        guard let context = try? aiReportRequestContext(for: chart, relationship: relationship) else { return }
        if !forceRegenerate, let artifact = artifactStore.load(key: context.key) {
            applyArtifact(artifact, chart: chart)
            return
        }
       if !forceRegenerate,
          let existing = aiContent[chart],
          existing.cacheKey == context.key,
          existing.report != nil
       {
           return
       }
       guard aiConsentGranted, isOnline else { return }
		if CommerceStore.shared.account != nil, CommerceStore.shared.totalCredits == 0 {
			CommerceStore.shared.showsCredits = true
			return
		}

        let updatedKey = context.key
        await MainActor.run {
            generatingCharts.insert(chart)
            var content = aiContent[chart] ?? .empty
            content.cacheKey = updatedKey
            content.status = .generating
            aiContent[chart] = content
        }
        await performAIGeneration(
            chart: chart,
            key: updatedKey,
            params: context.params,
            facts: context.facts,
            factsHash: context.factsHash,
            requestLocale: context.locale,
            forceRegenerate: forceRegenerate
        )
   }

    func generateAIReport(
        for relationshipKind: RelationshipChartKind,
        forceRegenerate: Bool = false
    ) async {
        await ensureRelationshipChartCalculated(relationshipKind)
        guard relationshipArtifact(for: relationshipKind) != nil else { return }
        let raw = relationshipKind.rawValue
        guard !generatingRelationships.contains(raw) else { return }
        guard !PendingReportManager.shared.hasPendingChartReport(chartPrefix: relationshipKind.reportScope) else { return }
        guard let context = try? relationshipAIReportRequestContext(for: relationshipKind) else { return }
        if !forceRegenerate, let artifact = artifactStore.load(key: context.key) {
            applyRelationshipArtifact(artifact, kind: relationshipKind)
            return
        }
        guard aiConsentGranted, isOnline else { return }
        if CommerceStore.shared.account != nil, CommerceStore.shared.totalCredits == 0 {
            CommerceStore.shared.showsCredits = true
            return
        }
        generatingRelationships.insert(raw)
        var content = relationshipAIContent[raw] ?? .empty
        content.cacheKey = context.key
        content.status = .generating
        relationshipAIContent[raw] = content
        await performRelationshipAIGeneration(
            kind: relationshipKind,
            key: context.key,
            params: context.params,
            facts: context.facts,
            factsHash: context.factsHash,
            requestLocale: context.locale,
            forceRegenerate: forceRegenerate
        )
    }

    private func performRelationshipAIGeneration(
        kind: RelationshipChartKind,
        key: String,
        params: [String: String],
        facts: [String: Any],
        factsHash: String,
        requestLocale: String,
        forceRegenerate: Bool
    ) async {
        let hashes = relationshipSubjectHashes()
        let body = aiReportService.relationshipRequestBody(
            kind: kind,
            preset: preset(for: .synastry),
            primarySubjectHash: hashes.first ?? "none",
            params: params,
            facts: facts,
            semanticFingerprint: key,
            factsHash: factsHash,
            locale: requestLocale,
            userID: CommerceStore.shared.userID.uuidString.lowercased(),
            forceRegenerate: forceRegenerate
        )
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body),
              let requestID = body["requestID"] as? String
        else {
            generatingRelationships.remove(kind.rawValue)
            return
        }
        let item = PendingGeneration(
            requestID: requestID,
            reportID: key,
            kind: "chart",
            chartPrefix: kind.reportScope,
            periodScope: nil,
            params: params,
            subjectHashes: hashes,
            preset: preset(for: .synastry).rawValue,
            locale: requestLocale,
            factsHash: factsHash,
            createdAt: Date()
        )
        let requestLanguage = AppLanguage(rawValue: requestLocale) ?? language
        PendingReportManager.shared.track(
            item,
            request: AIGenerateRequest(bodyData: bodyData, language: requestLanguage),
            onSaved: { [weak self] saved in
                Task { @MainActor in
                    self?.generatingRelationships.remove(kind.rawValue)
                    if let artifact = saved as? GeneratedChartArtifact {
                        self?.applyRelationshipArtifact(artifact, kind: kind)
                    } else {
                        self?.reloadSavedReports()
                    }
                }
            },
            onFailed: { [weak self] message in
                Task { @MainActor in
                    self?.generatingRelationships.remove(kind.rawValue)
                    var content = self?.relationshipAIContent[kind.rawValue] ?? .empty
                    content.status = .failed(message)
                    self?.relationshipAIContent[kind.rawValue] = content
                }
            }
        )
    }

    private func applyRelationshipArtifact(_ artifact: GeneratedChartArtifact, kind: RelationshipChartKind) {
        var content = relationshipAIContent[kind.rawValue] ?? .empty
        content.cacheKey = artifact.semanticFingerprint
        content.report = AIReport(
            title: artifact.response.report.title,
            subtitle: artifact.response.report.subtitle,
            sections: artifact.response.report.sections
        )
        content.status = .ready
        relationshipAIContent[kind.rawValue] = content
        reloadSavedReports()
    }

    private func relationshipAIReportRequestContext(
        for kind: RelationshipChartKind
    ) throws -> (params: [String: String], facts: [String: Any], factsHash: String, key: String, locale: String) {
        guard let artifact = relationshipArtifact(for: kind),
              let partnerID = synastryPartnerID,
              let partner = profileForPersonID(partnerID)
        else { throw AppModelError.missingSnapshot }
        let locale = language.reportRequestLanguage.rawValue
        let params = relationshipAIParams(for: kind)
        let facts = AIFactsBuilder.relationshipDocument(
            artifact: artifact,
            firstName: profile.name,
            secondName: partner.name,
            preset: preset(for: .synastry),
            params: params,
            locale: locale,
            relationship: synastryPartnerRelationship
        )
        let factsData = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
        let factsHash = SHA256Digest.hash(factsData).hex
        let identityFactsHash = try AIArtifactIdentity.factsIdentityHash(facts)
        let key = aiReportService.relationshipSemanticFingerprint(
            kind: kind,
            preset: preset(for: .synastry),
            subjectHashes: relationshipSubjectHashes(),
            params: params,
            factsHash: identityFactsHash
        )
        return (params, facts, factsHash, key, locale)
    }

    private func relationshipAIParams(for kind: RelationshipChartKind) -> [String: String] {
        var params: [String: String] = [
            "relationshipKind": kind.rawValue,
            "partnerHash": relationshipSubjectHashes().dropFirst().first ?? "",
        ]
        if kind.needsTargetDate {
            params["targetDate"] = ISO8601DateFormatter().string(from: relationshipTargetDate)
        }
        if kind.supportsTransitLocation, let location = relationshipLocationOverride {
            params["placeName"] = location.placeName
            params["timezoneID"] = location.timezoneID
            params["latitude"] = String(location.latitude)
            params["longitude"] = String(location.longitude)
        }
        if kind.supportsMidpointAlgorithm, let algorithm = relationshipMidpointAlgorithmOverride {
            params["midpointAlgorithm"] = algorithm.rawValue
        }
        switch kind {
        case .synastryA, .marksA:
            params["perspective"] = RelationshipPerspective.first.rawValue
        case .synastryB, .marksB:
            params["perspective"] = RelationshipPerspective.second.rawValue
        case .marksSecondary, .marksTertiary:
            params["perspective"] = relationshipPerspective.rawValue
        default:
            break
        }
        return params
    }

    private func relationshipSubjectHashes() -> [String] {
        var values = [profileHash(profile)]
        if let partnerID = synastryPartnerID, let partner = profileForPersonID(partnerID) {
            values.append(profileHash(partner))
        }
        return values
    }

   func regenerateAIArtifact(for chart: ChartKind) {
        Task { await generateAIReport(for: chart, forceRegenerate: true) }
   }

    private func performAIGeneration(
        chart: ChartKind,
        key: String,
        params: [String: String],
        facts: [String: Any],
        factsHash: String,
        requestLocale: String,
        forceRegenerate: Bool
    ) async {
        let body = aiReportService.chartRequestBody(
            chart: chart,
            preset: preset(for: chart),
            primarySubjectHash: subjectHashes(for: chart).first ?? "none",
            params: params,
            facts: facts,
            semanticFingerprint: key,
            factsHash: factsHash,
            locale: requestLocale,
			userID: CommerceStore.shared.userID.uuidString.lowercased(),
            forceRegenerate: forceRegenerate
        )
        guard let bodyData = try? JSONSerialization.data(withJSONObject: body, options: []),
              let requestID = body["requestID"] as? String
        else {
            generatingCharts.remove(chart)
            return
        }
        let item = PendingGeneration(
            requestID: requestID,
            reportID: key,
            kind: "chart",
            chartPrefix: chart.contentPrefix,
            periodScope: nil,
            params: params,
            subjectHashes: subjectHashes(for: chart),
            preset: preset(for: chart).rawValue,
            locale: requestLocale,
            factsHash: factsHash,
            createdAt: Date()
        )
        let requestLanguage = AppLanguage(rawValue: requestLocale) ?? language
        PendingReportManager.shared.track(
            item,
            request: AIGenerateRequest(bodyData: bodyData, language: requestLanguage),
            onSaved: { [weak self] _ in
                Task { @MainActor in
                    self?.generatingCharts.remove(chart)
                }
            },
            onFailed: { [weak self] message in
                Task { @MainActor in
                    self?.generatingCharts.remove(chart)
                    var content = self?.aiContent[chart] ?? .empty
                    content.status = .failed(message)
                    self?.aiContent[chart] = content
                }
            }
        )
    }

    func applySavedArtifact(_ artifact: GeneratedChartArtifact, chart: ChartKind) {
        applyArtifact(artifact, chart: chart)
    }

    private func applyArtifact(_ artifact: GeneratedChartArtifact, chart: ChartKind) {
        let response = artifact.response
        var content = aiContent[chart] ?? .empty
        content.cacheKey = artifact.semanticFingerprint
        content.report = AIReport(title: response.report.title, subtitle: response.report.subtitle, sections: response.report.sections)
        content.status = .ready
        aiContent[chart] = content
        reloadSavedReports()
    }

    private func aiReportRequestContext(
        for chart: ChartKind,
        relationship: PersonRelationship? = nil
    ) throws -> (
        params: [String: String], facts: [String: Any], factsHash: String, key: String, locale: String
    ) {
        let requestLocale = language.reportRequestLanguage.rawValue
        let effectiveRelationship = chart == .synastry
            ? relationship ?? synastryPartnerRelationship
            : nil
        let params = aiParams(for: chart, relationship: effectiveRelationship)
        let facts = try buildAIFacts(chart: chart, relationship: effectiveRelationship, params: params)
        let factsData = try JSONSerialization.data(withJSONObject: facts, options: [.sortedKeys])
        let factsHash = SHA256Digest.hash(factsData).hex
        let identityFactsHash = try AIArtifactIdentity.factsIdentityHash(facts)
        let key = semanticFingerprint(chart: chart, params: params, factsHash: identityFactsHash)
        return (params, facts, factsHash, key, requestLocale)
    }

    private func buildAIFacts(
        chart: ChartKind,
        relationship: PersonRelationship? = nil,
        params: [String: String]
    ) throws -> [String: Any] {
        guard let snapshot = snapshot(for: chart) else {
            throw AppModelError.missingSnapshot
        }
        let reference = referenceSnapshot(for: chart)
        let comparison = comparisonAspects(for: chart)
        let partner: (name: String, chart: ChartSnapshot)?
        if chart == .synastry {
            if let partnerSnapshot = synastry?.second {
                let name = synastryPartnerID.flatMap(profileForPersonID)?.name ?? "Partner"
                partner = (name, partnerSnapshot)
            } else {
                partner = nil
            }
        } else {
            partner = nil
        }
        let aiEvents: ChartEventData = chart == .transit ? .empty : chartEvents
        var transitBundle: TransitFactBundle?
        if chart == .transit {
            let timeZone = TimeZone(
                identifier: transitLocationOverride?.timezoneID ?? chartSubjectProfile.timezoneID
            ) ?? .current
            transitBundle = enrichmentService.makeTransitFactBundle(
                snapshot: snapshot,
                natal: reference,
                aspects: comparison,
                events: .empty,
                timeZone: timeZone,
                calendarDays: [],
                rangeDays: 1,
                preset: preset(for: .transit)
            )
        }
        let techniqueMetadata = chart.isAdvancedChart
            ? advancedChartResults[chart]?.techniqueMetadata
            : nil
        if chart.isAdvancedChart, techniqueMetadata == nil {
            throw AppModelError.missingTechniqueMetadata
        }
        let output = aiReportService.buildFacts(
            AppAIChartFactsInput(
                chart: chart,
                snapshot: snapshot,
                reference: reference,
                comparisonAspects: comparison,
                techniqueMetadata: techniqueMetadata,
                preset: preset(for: chart),
                personName: chart == .synastry ? profile.name : chartSubjectProfile.name,
                partnerName: partner?.name,
                partnerChart: partner?.chart,
                classicalSynastryAssessment: chart == .synastry ? synastry?.classicalAssessment : nil,
               events: aiEvents,
               params: params,
               locale: language.reportRequestLanguage.rawValue,
                transitBundle: transitBundle,
                relationship: chart == .synastry ? relationship : nil
           )
        )
        if let plan = output.transitPlan { transitContentPlan = plan }
        return output.document
    }

    private var profileHashValue: String {
        aiReportService.profileHash(profile)
    }

    private var synastryPartnerRelationship: PersonRelationship? {
        guard let partnerID = synastryPartnerID else { return nil }
        return savedPeople.first(where: { $0.id.uuidString == partnerID })?.relationship
    }

    private func aiParams(for chart: ChartKind, relationship: PersonRelationship? = nil) -> [String: String] {
        aiReportService.parameters(
            for: chartContext(for: chart).target,
            subjectTimeZoneID: chartSubjectProfile.timezoneID,
            subjectHashes: subjectHashes(for: chart),
            relationship: relationship
        )
    }

    private func semanticFingerprint(chart: ChartKind, params: [String: String], factsHash: String) -> String {
        aiReportService.semanticFingerprint(
            chart: chart,
            preset: preset(for: chart),
            target: chartContext(for: chart).target,
            subjectHashes: subjectHashes(for: chart),
            params: params,
            factsHash: factsHash
        )
    }

    private func subjectHashes(for chart: ChartKind) -> [String] {
        guard chart != .currentSky else { return [] }
        var hashes = [profileHash(chart == .synastry ? profile : chartSubjectProfile)]
        if chart == .synastry,
           let partnerID = synastryPartnerID,
           let partner = profileForPersonID(partnerID)
        {
            hashes.append(profileHash(partner))
        }
        return hashes
    }

    private func profileHash(_ value: UserProfile) -> String {
        aiReportService.profileHash(value)
    }

    // MARK: - Report library

    private func startNetworkMonitoring() {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        monitor.start(queue: DispatchQueue(label: "ai-network-monitor"))
        networkMonitor = monitor
    }


}

enum AppModelError: LocalizedError {
    case missingEphemeris
    case missingSnapshot
    case missingTechniqueMetadata

    var errorDescription: String? {
        switch self {
        case .missingEphemeris:
            "The bundled Swiss Ephemeris data could not be found."
        case .missingSnapshot:
            "The chart has not been calculated yet."
        case .missingTechniqueMetadata:
            "The advanced chart technique metadata is unavailable."
        }
    }
}

enum SHA256Digest {
    static func hash(_ data: Data) -> Data {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(data.count), &digest)
        }
        return Data(digest)
    }
}

extension Data {
    var hex: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
func aspectTitle(
    _ aspect: ChartAspect,
    prefix: String = "",
    language: AppLanguage = .english
) -> String {
    ConsumerCopy.connectionTitle(aspect, language: language)
}

func formatOrb(_ value: Double) -> String {
    String(format: "%.2f°", value)
}

func tone(_ kind: AspectKind) -> InsightTone {
    if kind.supportive { return .supportive }
    if kind.challenging { return .challenging }
    return .transition
}

func phaseLabel(_ phase: AspectPhase, language: AppLanguage) -> String {
    ConsumerCopy.timing(phase, language: language)
}
