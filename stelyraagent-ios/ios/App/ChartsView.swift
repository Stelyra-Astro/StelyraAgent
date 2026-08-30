import AstroCore
import SwiftUI

private enum ChartsSpace: Equatable {
    case you
    case bonds
}

struct ChartsView: View {
    @EnvironmentObject private var model: AppModel
	@ObservedObject private var commerce = CommerceStore.shared
    @Binding var selectedTab: RootTab
   @State private var showLocationPicker = false
    @State private var selectedReport: SavedReport?
    @State private var generationChart: ChartKind?
    @State private var generationWillReplace = false
    @State private var pendingGeneration: PendingGeneration?
    @State private var generatingChart: ChartKind?
   @State private var showParameters = false
    @State private var showAllCharts = false
    @State private var showReports = false
    @State private var chartsSpace: ChartsSpace = .you

    private let youFixedShortcuts: [ChartKind] = [.natal, .transit, .secondary]
    private let bondsFixedShortcuts: [RelationshipChartKind] = [.composite, .synastryA, .compositeTransit]

private struct PendingGeneration: Identifiable {
    let id = UUID()
    let chart: ChartKind
    let force: Bool
}

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 18) {
                        let insightState = visibleInsightState
                        topBar
                        chartSelector

                        if chartsSpace == .bonds {
                            synastryPeopleSelector
                        }

                        if chartsSpace == .you,
                           model.focusedChart == model.selectedChart,
                           let date = model.focusedChartDate
                        {
                            eventTimeContext(date)
                        }

                        chartControlBar
                        if chartsSpace == .you, showsPremiumPreview {
                            premiumPreviewBanner
                        }
                        chartContent

                        if shouldShowInsightCards, !insightState.cards.isEmpty {
                            ForEach(Array(insightState.cards.enumerated()), id: \.element.id) { index, card in
                                insightCardRow(index: index, card: card)
                            }
                        } else if shouldShowInsightCards,
                                  let message = insightState.errorMessage,
                                  (chartsSpace == .bonds
                                    ? model.relationshipSnapshot(for: model.selectedRelationshipChart) != nil
                                    : model.snapshot(for: model.selectedChart) != nil)
                        {
                            Label(message, systemImage: "doc.text.magnifyingglass")
                                .font(.footnote)
                                .foregroundStyle(AppTheme.muted)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .cardSurface()
                        }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await model.refresh()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(
                isPresented: Binding(
                    get: { selectedReport != nil },
                    set: { if !$0 { selectedReport = nil } }
                )
            ) {
                if let report = selectedReport {
                    ReportReaderView(
                        report: report,
                        language: model.language,
                        onRegenerate: {
                            selectedReport = nil
                            if let chart = ChartKind.allCases.first(where: { report.scope == "chart.\($0.contentPrefix)" }) {
                                generationChart = chart
                                generationWillReplace = true
                            }
                        }
                    )
                }
            }
            .navigationDestination(isPresented: $showReports) {
                ReportsView(selectedTab: $selectedTab)
            }
            .sheet(item: $generationChart) { chart in
                ReportGenerationSheet(
                    chart: chart,
                    replacesExisting: generationWillReplace,
                    onGenerate: {
                        generationChart = nil
                        requestGeneration(for: chart, force: generationWillReplace)
                    },
                    onEdit: {
                        generationChart = nil
                        model.selectChart(chart)
                        showParameters = true
                    },
                    onCancel: {
                        generationChart = nil
                    }
                )
            }
            .sheet(item: $generatingChart) { chart in
                ReportGeneratingSheet(chart: chart, language: model.language) {
                    generatingChart = nil
                }
            }
            .alert(
                localized("ai.network-consent.chart-title", language: model.language),
                isPresented: Binding(
                    get: { pendingGeneration != nil },
                    set: { if !$0 { pendingGeneration = nil } }
                ),
                presenting: pendingGeneration
            ) { pending in
                Button(localized("charts.allow", language: model.language)) {
                    model.grantAIConsent()
                    Task {
                        await model.generateAIReport(
                            for: pending.chart,
                            forceRegenerate: pending.force
                        )
                        if let saved = model.currentSavedReport(for: pending.chart) {
                            await MainActor.run { selectedReport = saved }
                        }
                    }
                    pendingGeneration = nil
                }
                Button(localized("charts.not-now", language: model.language), role: .cancel) {
                    pendingGeneration = nil
                }
            } message: { _ in
                Text(localized("ai.network-consent.chart-message", language: model.language))
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .charts {
                    selectedReport = nil
                    generationChart = nil
                }
            }
            .onChange(of: model.chartParameterEditRequest) { _, chart in
                guard let chart else { return }
                model.selectChart(chart)
                showParameters = true
                model.consumeChartParameterEditRequest()
            }
            .sheet(isPresented: $showAllCharts) {
                allChartsSheet
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationSearchView(language: model.language) { selection in
                    if chartsSpace == .bonds {
                        model.setRelationshipLocation(selection)
                    } else {
                        model.setReferenceLocation(selection, for: model.selectedChart)
                    }
                    showLocationPicker = false
                }
            }
            .sheet(isPresented: $showParameters) {
                NavigationStack {
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            if chartsSpace == .bonds {
                                relationshipParameters
                                relationshipPresetSelector
                            } else {
                                chartParameters
                                presetSelector
                            }
                        }
                        .padding(18)
                    }
                    .background(ScreenBackground())
                    .navigationTitle(localized("charts.parameters.sheet-title", language: model.language))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(localized("charts.done", language: model.language)) {
                                showParameters = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func shouldLockCard(at index: Int) -> Bool {
        guard index > 0, !commerce.isPremium else { return false }
        if chartsSpace == .bonds {
            return true
        }
        return ![.natal, .currentSky].contains(model.selectedChart)
    }

    private var showsPremiumPreview: Bool {
        !commerce.isPremium && ![.natal, .currentSky].contains(model.selectedChart)
    }

    private var premiumPreviewBanner: some View {
        Button {
            commerce.showsPaywall = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .foregroundStyle(AppTheme.violet)
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("premium.preview-title", language: model.language))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized("premium.preview-message", language: model.language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cardSurface()
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func insightCardRow(index: Int, card: InsightCardModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if shouldLockCard(at: index) {
                cardSectionHeader(card)
                Button { commerce.showsPaywall = true } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                        LinearGradient(
                            colors: [AppTheme.violet.opacity(0.18), AppTheme.panel.opacity(0.5), AppTheme.blue.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 10) {
                            Image(systemName: "lock.fill").font(.title2).foregroundStyle(AppTheme.violet)
                            Text(localized("premium.explore", language: model.language)).font(.headline).foregroundStyle(AppTheme.text)
                            Text(localized("premium.locked-card-message", language: model.language)).font(.caption).foregroundStyle(AppTheme.muted)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.16)))
                }
                .buttonStyle(.plain)
                .accessibilityHint(localized("premium.see-full-picture", language: model.language))
            } else {
                cardSectionHeader(card)
                InsightCardView(
                    card: card,
                    language: model.language,
                    prototypeTransitStyle: isPlannedTransitCard(card.id),
                    externalHeaderStyle: true
                )
            }
        }
    }

    private func cardSectionHeader(_ card: InsightCardModel) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(cardSectionTitle(card))
                .font(AppTypography.scaled(20, weight: .bold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Text(cardSectionSubtitle(card))
                .font(AppTypography.scaled(12))
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
        .padding(.top, 7)
    }

    private func isPlannedTransitCard(_ cardID: String) -> Bool {
        model.selectedChart == .transit
            && TransitContentPlan.cardIDs.contains(cardID)
    }

    private func cardSectionTitle(_ card: InsightCardModel) -> String {
        isPlannedTransitCard(card.id) ? transitSectionTitle(card.id) : card.title
    }

    private func cardSectionSubtitle(_ card: InsightCardModel) -> String {
        if isPlannedTransitCard(card.id) {
            return transitSectionSubtitle(card.id)
        }
        if model.selectedChart == .synastry {
            switch card.id {
            case "relationship-overview":
                return localized("charts.how-two-charts-affect-each-other", language: model.language)
            case "perspectives":
                return localized("charts.two-directions-not-one-shared-score", language: model.language)
            case "emotional-connection":
                return localized("charts.moon-contacts-and-emotional-house-overlays", language: model.language)
            case "communication":
                return localized("charts.how-ideas-are-exchanged", language: model.language)
            case "chemistry":
                let key = model.preset(for: .synastry) == .classical
                    ? "charts.synastry.chemistry-subtitle.classical"
                    : "charts.synastry.chemistry-subtitle.modern"
                return localized(key, language: model.language)
            case "commitment":
                return localized("charts.saturn-jupiter-and-angle-contacts", language: model.language)
            case "house-overlays":
                return localized("charts.where-each-person-lands-in-the-others-life", language: model.language)
            case "key-inter-aspects":
                return localized("charts.sorted-by-relevance-not-positivity", language: model.language)
            default:
                break
            }
        }
        return cardKicker(card.id, language: model.language) ?? ""
    }

    private func transitSectionTitle(_ cardID: String) -> String {
        switch cardID {
        case "current-story": localized("charts.current-story", language: model.language)
        case "current-cycles": localized("charts.current-cycles", language: model.language)
        case "transit-timeline": localized("charts.transit-timeline", language: model.language)
        case "planet-paths": localized("charts.planet-paths", language: model.language)
        case "life-areas": localized("charts.life-areas", language: model.language)
        case "active-transits": localized("charts.active-transits", language: model.language)
        default: cardID
        }
    }

    private func transitSectionSubtitle(_ cardID: String) -> String {
        switch cardID {
        case "current-story": localized("charts.how-the-strongest-cycles-combine", language: model.language)
        case "current-cycles": localized("charts.one-theme-per-time-scale", language: model.language)
        case "transit-timeline": localized("charts.start-exact-return-end", language: model.language)
        case "planet-paths": localized("charts.where-the-current-planets-are-moving", language: model.language)
        case "life-areas": localized("charts.activity-not-fortune", language: model.language)
        case "active-transits": localized("charts.complete-filtered-list", language: model.language)
        default: ""
        }
    }

    private var topBar: some View {
        HStack(spacing: 9) {
            chartsSpaceButton(.you, title: localized("charts.space.you", language: model.language))
            chartsSpaceButton(.bonds, title: localized("charts.space.bonds", language: model.language))
            Spacer()
            Button {
                showReports = true
            } label: {
                Label(localized("charts.reports", language: model.language), systemImage: "doc.text.fill")
                    .font(AppTypography.scaled(11, weight: .semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppTheme.violet.opacity(0.1), in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("charts-reports-button")
        }
    }

    private func chartsSpaceButton(_ space: ChartsSpace, title: String) -> some View {
        let selected = chartsSpace == space
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                chartsSpace = space
                if space == .you {
                    if model.selectedChart == .synastry { model.selectChart(.natal) }
                } else {
                    model.selectRelationshipChart(model.selectedRelationshipChart)
                }
            }
        } label: {
            Text(title)
                .font(AppTypography.scaled(24, weight: .bold))
                .kerning(-0.6)
                .foregroundStyle(selected ? AppTheme.text : AppTheme.muted)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) {
                    Capsule()
                        .fill(selected ? AppTheme.violet : Color.clear)
                        .frame(height: 2)
                }
        }
        .buttonStyle(.plain)
    }

    private var shouldShowInsightCards: Bool {
        chartsSpace == .you || model.selectedRelationshipChart.isSynastry
    }

    private var visibleInsightState: InsightCardLoadState {
        if chartsSpace == .bonds {
            return model.selectedRelationshipChart.isSynastry
                ? model.insightCards(for: .synastry)
                : InsightCardLoadState(cards: [], errorMessage: nil)
        }
        return model.insightCards(for: model.selectedChart)
    }

    private var chartControlBar: some View {
        HStack(spacing: 10) {
            viewSelector
            Button { showParameters = true } label: {
                Label(localized("charts.parameters.button", language: model.language), systemImage: "slider.horizontal.3")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.violet.opacity(0.22)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("charts-parameters-button")
        }
    }

    private var synastryPeopleSelector: some View {
        HStack(spacing: 10) {
            Text(model.profile.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppTheme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(AppTheme.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line))

            Image(systemName: "heart.fill")
                .font(AppTypography.scaled(14, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .accessibilityHidden(true)

            if model.savedPeople.isEmpty {
                Button {
                    selectedTab = .profile
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "person.crop.circle.badge.plus")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Text(localized("charts.add-person-in-profile", language: model.language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppTheme.muted)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppTheme.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line))
                }
                .buttonStyle(.plain)
            } else {
                Menu {
                    ForEach(model.savedPeople) { person in
                        Button(person.profile.name) {
                            model.selectSynastryPartner(person.id.uuidString)
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(selectedSynastryPartnerName ?? localized("charts.select", language: model.language))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedSynastryPartnerName == nil ? AppTheme.muted : AppTheme.text)
                            .lineLimit(1)
                            .minimumScaleFactor(0.75)
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(AppTheme.violet)
                    }
                    .padding(.horizontal, 12)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .background(AppTheme.background.opacity(0.48), in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .cardSurface()
    }

    private var selectedSynastryPartnerName: String? {
        model.synastryPartnerID.flatMap(model.profileForPersonID)?.name
    }

    private var profileStrip: some View {
        HStack(spacing: 12) {
            Text(String(model.profile.name.prefix(1)).uppercased())
                .font(AppTypography.scaled(15, weight: .bold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 38, height: 38)
                .background(AppTheme.violet.opacity(0.12), in: Circle())
                .overlay(Circle().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
            VStack(alignment: .leading, spacing: 3) {
                Text(model.profile.name)
                    .font(AppTypography.scaled(15, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                Text(birthInfo)
                    .font(AppTypography.scaled(10))
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            TagChip(
                text: model.preset(for: model.selectedChart).title(language: model.language),
                tone: .neutral
            )
        }
        .padding(15)
        .cardSurface()
    }

    private var birthInfo: String {
        let subject = model.chartSubjectProfile
        let timeZone = TimeZone(identifier: subject.timezoneID) ?? .current
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = timeZone
        formatter.dateFormat = "MMM d, yyyy · HH:mm"
        let date = formatter.string(from: subject.birthDateUTC)
        return "\(date) · \(subject.placeName)"
    }

    private var chartSubtitle: String {
        switch model.selectedChart {
        case .natal:
            return "\(model.profile.name) · \(model.profile.placeName)"
        case .currentSky:
            return localized("charts.live-sky-at-the-saved-location", language: model.language)
        case .transit:
            return localized("charts.current-sky-compared-with-the-natal-chart", language: model.language)
        case .secondary:
            return localized("charts.day-for-a-year-secondary-progressions", language: model.language)
        case .solarReturn:
            return localized("charts.the-year-that-begins-at-your-next-solar-return", language: model.language)
        case .synastry:
            return localized("charts.how-two-natal-charts-meet", language: model.language)
        case .tertiary:
            return localized("charts.tertiary.subtitle", language: model.language)
        case .lunarReturn:
            return localized("charts.lunar-return.subtitle", language: model.language)
        case .solarArc:
            return localized("charts.solar-arc.subtitle", language: model.language)
        case .relocation:
            return localized("charts.relocation.subtitle", language: model.language)
        case .twelfthHarmonic:
            return localized("charts.twelfth-harmonic.subtitle", language: model.language)
        case .thirteenthHarmonic:
            return localized("charts.thirteenth-harmonic.subtitle", language: model.language)
        }
    }

    private var chartSelector: some View {
        HStack(spacing: 9) {
            if chartsSpace == .you {
                ForEach(youFixedShortcuts) { chart in
                    chartSelectorButton(chart)
                }
            } else {
                ForEach(bondsFixedShortcuts, id: \.rawValue) { kind in
                    relationshipSelectorButton(kind)
                }
            }

            Button { showAllCharts = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.grid.2x2")
                    Text(localized("charts.more", language: model.language))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isMoreSelectionActive ? Color.white : AppTheme.violet)
                .padding(.horizontal, 13)
                .padding(.vertical, 9)
                .background(isMoreSelectionActive ? AppTheme.violet.opacity(0.92) : AppTheme.violet.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(isMoreSelectionActive ? AppTheme.violet.opacity(0.7) : AppTheme.violet.opacity(0.22)))
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("charts-more-button")
        }
    }

    private var isMoreSelectionActive: Bool {
        if chartsSpace == .you {
            return !youFixedShortcuts.contains(model.selectedChart)
        }
        return !bondsFixedShortcuts.contains { isRelationshipShortcutSelected($0) }
    }

    private func isRelationshipShortcutSelected(_ shortcut: RelationshipChartKind) -> Bool {
        if shortcut == .synastryA && model.selectedRelationshipChart.isSynastry {
            return true
        }
        return model.selectedRelationshipChart == shortcut
    }

    private func relationshipSelectorButton(_ kind: RelationshipChartKind) -> some View {
        let selected = isRelationshipShortcutSelected(kind)
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { model.selectRelationshipChart(kind) }
        } label: {
            Text(kind.title(language: model.language))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppTheme.muted)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(selected ? AppTheme.violet.opacity(0.92) : AppTheme.panel, in: Capsule())
                .overlay(Capsule().stroke(selected ? AppTheme.violet.opacity(0.7) : AppTheme.line))
        }
        .buttonStyle(.plain)
    }

    private func chartSelectorButton(_ chart: ChartKind) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.selectChart(chart)
            }
        } label: {
            Text(chart.title(language: model.language))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(model.selectedChart == chart ? Color.white : AppTheme.muted)
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    model.selectedChart == chart ? AppTheme.violet.opacity(0.92) : AppTheme.panel,
                    in: Capsule()
                )
                .overlay(
                    Capsule().stroke(
                        model.selectedChart == chart ? AppTheme.violet.opacity(0.7) : AppTheme.line
                    )
                )
        }
        .buttonStyle(.plain)
    }

    private var allChartsSheet: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if chartsSpace == .you {
                        allChartsSection(
                            title: localized("charts.progressions-directions", language: model.language),
                            charts: ChartDefinitionRegistry.charts(in: .progressionsDirections).filter { $0 != .secondary }
                        )
                        allChartsSection(
                            title: localized("charts.returns", language: model.language),
                            charts: ChartDefinitionRegistry.charts(in: .returns)
                        )
                        allChartsSection(
                            title: localized("charts.derived-location", language: model.language),
                            charts: ChartDefinitionRegistry.charts(in: .derivedLocation)
                                .filter { $0 != .synastry && $0 != .transit && $0 != .natal && $0 != .currentSky }
                        )
                        allChartsSection(
                            title: localized("charts.other", language: model.language),
                            charts: [.currentSky]
                        )
                    } else {
                        relationshipChartsSection(
                            title: localized("relationship.group.composite", language: model.language),
                            kinds: [.compositeSecondary, .compositeTertiary, .compositeSecondaryCompare, .compositeTertiaryCompare]
                        )
                        relationshipChartsSection(
                            title: localized("relationship.group.davison", language: model.language),
                            kinds: [.davison, .davisonTransit, .davisonSecondary, .davisonTertiary]
                        )
                        relationshipChartsSection(
                            title: localized("relationship.group.marks", language: model.language),
                            kinds: [.marksA, .marksB, .marksSecondary, .marksTertiary]
                        )
                    }
                }
                .padding(18)
            }
            .background(ScreenBackground())
            .navigationTitle(chartsSpace == .you
                ? localized("charts.all-charts", language: model.language)
                : localized("relationship.more", language: model.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: model.language)) { showAllCharts = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func relationshipChartsSection(title: String, kinds: [RelationshipChartKind]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .textCase(.uppercase)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(kinds, id: \.rawValue) { kind in
                    let selected = model.selectedRelationshipChart.rawValue == kind.rawValue
                    Button {
                        model.selectRelationshipChart(kind)
                        showAllCharts = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: relationshipSystemImage(kind))
                                .foregroundStyle(selected ? Color.white : AppTheme.violet)
                                .frame(width: 22)
                            Text(relationshipMoreTitle(kind))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(selected ? Color.white : AppTheme.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(selected ? AppTheme.violet.opacity(0.92) : AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(selected ? AppTheme.violet.opacity(0.7) : AppTheme.line))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("relationship-more-\(kind.rawValue)")
                }
            }
        }
    }

    private func relationshipMoreTitle(_ kind: RelationshipChartKind) -> String {
        if kind.rawValue == RelationshipChartKind.synastryB.rawValue {
            return localized("relationship.synastry-reverse", language: model.language)
        }
        return kind.title(language: model.language)
    }

    private func relationshipSystemImage(_ kind: RelationshipChartKind) -> String {
        switch kind {
        case .synastryA, .synastryB: "person.2.fill"
        case .composite, .compositeTransit, .compositeSecondary, .compositeTertiary,
             .compositeSecondaryCompare, .compositeTertiaryCompare: "circle.grid.cross"
        case .davison, .davisonTransit, .davisonSecondary, .davisonTertiary: "mappin.and.ellipse"
        case .marksA, .marksB, .marksSecondary, .marksTertiary: "point.3.connected.trianglepath.dotted"
        }
    }

    private func allChartsSection(title: String, charts: [ChartKind]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
                .textCase(.uppercase)

            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(charts) { chart in
                    Button {
                        model.selectChart(chart)
                        showAllCharts = false
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: chartSystemImage(chart))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(model.selectedChart == chart ? Color.white : AppTheme.violet)
                                .frame(width: 22)
                            Text(chart.title(language: model.language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(model.selectedChart == chart ? Color.white : AppTheme.text)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 12)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                        .background(
                            model.selectedChart == chart ? AppTheme.violet.opacity(0.92) : AppTheme.panel,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(model.selectedChart == chart ? AppTheme.violet.opacity(0.7) : AppTheme.line)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("charts-all-\(chart.rawValue)")
                }
            }
        }
    }

    private func chartSystemImage(_ chart: ChartKind) -> String {
        chart.definition.systemImage
    }

    @ViewBuilder
    private var chartParameters: some View {
        switch model.selectedChart.definition.parameterPresentation {
        case .birthData:
            parameterSummary(
                title: localized("charts.birth-data", language: model.language),
                value: birthInfo,
                systemImage: "person.text.rectangle"
            )

        case .dateTimeLocation:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.parameters.back-to-now", language: model.language))
                DatePicker(
                    localized("charts.date-time", language: model.language),
                    selection: targetDateBinding(for: model.selectedChart)
                )
                .datePickerStyle(.compact)
                .environment(\.timeZone, parameterTimeZone(for: model.selectedChart))
                locationButton(model.currentSkyLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()

        case .transitWindow:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.use-current-defaults", language: model.language))
                DatePicker(
                    localized("charts.target-time", language: model.language),
                    selection: targetDateBinding(for: model.selectedChart)
                )
                .datePickerStyle(.compact)
                .environment(\.timeZone, parameterTimeZone(for: model.selectedChart))
                Picker(localized("charts.range", language: model.language), selection: transitRangeBinding) {
                    Text(localized("charts.30-days", language: model.language)).tag(30)
                    Text(localized("charts.7-days", language: model.language)).tag(7)
                    Text(localized("charts.12-months", language: model.language)).tag(365)
                }
                .pickerStyle(.segmented)
                locationButton(model.transitLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()

        case .targetDateBirthLocation:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.back-to-today", language: model.language))
                DatePicker(
                    localized("charts.target-date", language: model.language),
                    selection: targetDateParameterBinding(for: model.selectedChart),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                Text(localized("charts.uses-birth-location", language: model.language))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            .cardSurface()

        case .targetDateLocation:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.back-to-today", language: model.language))
                DatePicker(
                    localized("charts.target-date", language: model.language),
                    selection: advancedTargetDateBinding(for: model.selectedChart),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                .environment(\.timeZone, parameterTimeZone(for: model.selectedChart))
                locationButton(
                    advancedLocationName(for: model.selectedChart),
                    title: localized("charts.location", language: model.language)
                )
            }
            .cardSurface()

        case .targetDateDerivedNatal:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.back-to-today", language: model.language))
                DatePicker(
                    localized("charts.target-date", language: model.language),
                    selection: advancedTargetDateBinding(for: model.selectedChart),
                    displayedComponents: .date
                )
                .datePickerStyle(.compact)
                Text(localized("charts.derived-from-natal", language: model.language))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            .cardSurface()

        case .returnYearLocation:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.current-return-year", language: model.language))
                Stepper(value: solarYearBinding, in: 1900 ... 2200) {
                    parameterSummary(
                        title: localized("charts.return-year", language: model.language),
                        value: String(model.solarReturnYear),
                        systemImage: "calendar"
                    )
                }
                locationButton(model.solarReturnLocationOverride?.placeName ?? model.chartSubjectProfile.placeName)
            }
            .cardSurface()

        case .people:
            parameterSummary(
                title: localized("charts.people", language: model.language),
                value: localized("charts.choose-the-pair-on-the-synastry-page", language: model.language),
                systemImage: "person.2"
            )

        case .location:
            VStack(alignment: .leading, spacing: 10) {
                parameterHeader(resetTitle: localized("charts.use-birth-location", language: model.language))
                locationButton(
                    advancedLocationName(for: model.selectedChart),
                    title: localized("charts.location", language: model.language)
                )
            }
            .cardSurface()

        case .derivedNatal:
            parameterSummary(
                title: model.selectedChart.title(language: model.language),
                value: localized("charts.derived-from-natal", language: model.language),
                systemImage: model.selectedChart.definition.systemImage
            )
            .cardSurface()
        }
    }

    private func parameterTimeZone(for chart: ChartKind) -> TimeZone {
        let identifier = switch chart {
        case .currentSky:
            model.currentSkyLocationOverride?.timezoneID ?? model.chartSubjectProfile.timezoneID
        case .transit:
            model.transitLocationOverride?.timezoneID ?? model.chartSubjectProfile.timezoneID
        case .solarReturn:
            model.solarReturnLocationOverride?.timezoneID ?? model.chartSubjectProfile.timezoneID
        case .lunarReturn:
            if case let .lunarReturn(_, location, _) = model.chartContext(for: .lunarReturn).target {
                location.timezoneID
            } else {
                model.chartSubjectProfile.timezoneID
            }
        case .relocation:
            if case let .relocation(location) = model.chartContext(for: .relocation).target {
                location.timezoneID
            } else {
                model.chartSubjectProfile.timezoneID
            }
        case .natal, .secondary, .synastry, .tertiary, .solarArc,
             .twelfthHarmonic, .thirteenthHarmonic:
            model.chartSubjectProfile.timezoneID
        }
        return TimeZone(identifier: identifier) ?? .current
    }

    private func parameterHeader(resetTitle: String) -> some View {
        HStack {
            Text(localized("charts.chart-parameters", language: model.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Button(resetTitle) { model.resetTarget(for: model.selectedChart) }
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.violet)
        }
    }

    private func parameterSummary(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage).foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(AppTheme.text)
                Text(value).font(.footnote).foregroundStyle(AppTheme.muted).lineLimit(2)
            }
            Spacer()
        }
    }

    private func locationButton(
        _ placeName: String,
        title: String? = nil
    ) -> some View {
        Button { showLocationPicker = true } label: {
            parameterSummary(
                title: title ?? localized("charts.reference-location", language: model.language),
                value: placeName,
                systemImage: "mappin.and.ellipse"
            )
        }
        .buttonStyle(.plain)
    }

    private func targetDateBinding(for chart: ChartKind) -> Binding<Date> {
        Binding(
            get: {
                switch chart {
                case .currentSky: model.currentSkyUsesLiveDefault ? Date() : model.currentSkyTargetDate
                case .transit: model.transitUsesLiveDefault ? Date() : model.transitTargetDate
                case .secondary: model.secondaryUsesLiveDefault ? Date() : model.secondaryTargetDate
                default: Date()
                }
            },
            set: { model.setTargetDate($0, for: chart) }
        )
    }

    private func targetDateParameterBinding(for chart: ChartKind) -> Binding<Date> {
        chart.isAdvancedChart ? advancedTargetDateBinding(for: chart) : targetDateBinding(for: chart)
    }

    private func advancedTargetDateBinding(for chart: ChartKind) -> Binding<Date> {
        Binding(
            get: {
                switch model.chartContext(for: chart).target {
                case let .tertiary(targetDate, _): targetDate
                case let .lunarReturn(targetDate, _, _): targetDate
                case let .solarArc(targetDate, _): targetDate
                default: Date()
                }
            },
            set: { model.setTargetDate($0, for: chart) }
        )
    }

    private func advancedLocationName(for chart: ChartKind) -> String {
        switch model.chartContext(for: chart).target {
        case let .lunarReturn(_, location, _): location.placeName
        case let .relocation(location): location.placeName
        default: model.chartSubjectProfile.placeName
        }
    }

    private var transitRangeBinding: Binding<Int> {
        Binding(get: { model.transitRangeDays }, set: { model.setTransitRangeDays($0) })
    }

    private var solarYearBinding: Binding<Int> {
        Binding(
            get: { model.solarReturnYear },
            set: { year in
                var components = DateComponents()
                components.year = year
                components.month = 1
                components.day = 1
                model.setTargetDate(Calendar.current.date(from: components) ?? Date(), for: .solarReturn)
            }
        )
    }

    private var presetSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(localized("charts.preset", language: model.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            HStack(spacing: 8) {
                ForEach(CalculationPreset.consumerCases) { preset in
                    let selected = model.preset(for: model.selectedChart) == preset
                    Button {
                        model.setPreset(preset, for: model.selectedChart)
                    } label: {
                        VStack(spacing: 3) {
                            Text(preset.title(language: model.language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(selected ? Color.white : AppTheme.text)
                            Text(preset.subtitle(language: model.language))
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(selected ? Color.white.opacity(0.82) : AppTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selected ? AppTheme.violet.opacity(0.92) : AppTheme.panel,
                            in: RoundedRectangle(cornerRadius: 13)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 13)
                                .stroke(selected ? AppTheme.violet.opacity(0.65) : AppTheme.line)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var viewSelector: some View {
        HStack(spacing: 6) {
            modeButton(.wheel, icon: "circle.hexagongrid")
            modeButton(.aspects, icon: "square.grid.3x3")
        }
        .padding(4)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 14))
        .frame(maxWidth: .infinity)
    }

    private func modeButton(_ mode: ChartViewMode, icon: String) -> some View {
        let selected = model.viewMode == mode
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                model.viewMode = mode
            }
        } label: {
            Label(
                mode == .wheel
                    ? localized("charts.wheel", language: model.language)
                    : localized("charts.aspects", language: model.language),
                systemImage: icon
            )
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? Color.white : AppTheme.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(selected ? AppTheme.violet.opacity(0.92) : .clear, in: RoundedRectangle(cornerRadius: 11))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var chartContent: some View {
        if chartsSpace == .bonds {
            relationshipChartContent
        } else if model.selectedChart == .synastry, model.synastryPartnerID == nil {
            Label(
                localized("charts.choose-the-other-person-to-calculate-this-synastry-chart", language: model.language),
                systemImage: "person.2"
            )
            .font(.subheadline)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, minHeight: 180)
            .cardSurface()
        } else if model.selectedChart == .synastry, model.isCalculatingSynastry {
            HStack(spacing: 12) {
                ProgressView().tint(AppTheme.violet)
                Text(localized("charts.calculating-the-relationship-locally", language: model.language))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .cardSurface()
        } else if model.selectedChart.isAdvancedChart {
            switch model.advancedChartLoadState(for: model.selectedChart) {
            case .loading where model.snapshot(for: model.selectedChart) == nil:
                HStack(spacing: 12) {
                    ProgressView().tint(AppTheme.violet)
                    Text(localized("charts.calculating-advanced-chart-locally", language: model.language))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .cardSurface()
            case let .failed(message):
                VStack(spacing: 12) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.coral)
                    Button(localized("common.retry", language: model.language)) {
                        Task { await model.ensureAdvancedChartCalculated(model.selectedChart) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .cardSurface()
            case .idle where model.snapshot(for: model.selectedChart) == nil:
                HStack(spacing: 12) {
                    ProgressView().tint(AppTheme.violet)
                    Text(localized("charts.calculating-advanced-chart-locally", language: model.language))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .cardSurface()
                .task {
                    await model.ensureAdvancedChartCalculated(model.selectedChart)
                }
            case .idle, .loading, .ready:
                chartResultContent
            }
        } else if (model.isCalculating || model.isCalculatingFocus),
                  model.snapshot(for: model.selectedChart) == nil
        {
            HStack(spacing: 12) {
                ProgressView().tint(AppTheme.violet)
                Text(localized("charts.calculating-chart-locally", language: model.language))
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, minHeight: 210)
            .cardSurface()
        } else if model.snapshot(for: model.selectedChart) != nil {
            chartResultContent
        } else if let message = model.errorMessage {
            Label(message, systemImage: "exclamationmark.triangle")
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity, minHeight: 180)
                .cardSurface()
        }
    }

    @ViewBuilder
    private var chartResultContent: some View {
        if let snapshot = model.snapshot(for: model.selectedChart) {
            if model.viewMode == .wheel {
                ChartWheelView(
                    snapshot: snapshot,
                    reference: model.referenceSnapshot(for: model.selectedChart),
                    comparisonAspects: model.selectedChart.usesReferenceWheel
                        ? model.comparisonAspects(for: model.selectedChart)
                        : [],
                    language: model.language
                )
                .padding(12)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
            } else {
                AspectChartView(
                    aspects: model.comparisonAspects(for: model.selectedChart),
                    movingPoints: snapshot.points,
                    referencePoints: model.selectedChart.usesReferenceAspects
                        ? model.referenceSnapshot(for: model.selectedChart)?.points ?? []
                        : [],
                    language: model.language,
                    comparison: model.selectedChart.usesReferenceAspects
                )
            }
        }
    }

    @ViewBuilder
    private var relationshipChartContent: some View {
        let kind = model.selectedRelationshipChart
        if model.synastryPartnerID == nil {
            Label(localized("relationship.choose-person", language: model.language), systemImage: "person.2")
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 180)
                .cardSurface()
        } else {
            switch model.relationshipLoadState(for: kind) {
            case .loading:
                HStack(spacing: 12) {
                    ProgressView().tint(AppTheme.violet)
                    Text(localized("charts.calculating-the-relationship-locally", language: model.language))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .cardSurface()
            case let .failed(message):
                VStack(spacing: 12) {
                    Label(message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(AppTheme.coral)
                    Button(localized("common.retry", language: model.language)) {
                        Task { await model.ensureRelationshipChartCalculated(kind) }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, minHeight: 180)
                .cardSurface()
            case .idle:
                HStack(spacing: 12) {
                    ProgressView().tint(AppTheme.violet)
                    Text(localized("charts.calculating-the-relationship-locally", language: model.language))
                        .foregroundStyle(AppTheme.muted)
                }
                .frame(maxWidth: .infinity, minHeight: 210)
                .cardSurface()
                .task { await model.ensureRelationshipChartCalculated(kind) }
            case .ready:
                relationshipResultContent(kind)
            }
        }
    }

    @ViewBuilder
    private func relationshipResultContent(_ kind: RelationshipChartKind) -> some View {
        if let artifact = model.relationshipArtifact(for: kind) {
            if model.viewMode == .wheel {
                ChartWheelView(
                    snapshot: artifact.snapshot,
                    reference: artifact.reference,
                    comparisonAspects: artifact.reference == nil ? [] : artifact.comparisonAspects,
                    language: model.language
                )
                .padding(12)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))
            } else {
                AspectChartView(
                    aspects: artifact.reference == nil ? artifact.snapshot.aspects : artifact.comparisonAspects,
                    movingPoints: artifact.snapshot.points,
                    referencePoints: artifact.reference?.points ?? [],
                    language: model.language,
                    comparison: artifact.reference != nil
                )
            }
            relationshipTechniqueSummary(artifact)
        }
    }

    private func relationshipTechniqueSummary(_ artifact: RelationshipChartArtifact) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(artifact.kind.title(language: model.language), systemImage: relationshipSystemImage(artifact.kind))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                Text(model.preset(for: .synastry).title(language: model.language))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            if !artifact.kind.isSynastry {
                Text(localized("relationship.calculated-only", language: model.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
            }
            if let date = artifact.metadata.targetDate {
                Text(formattedEventDate(date))
                    .font(.caption2)
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .cardSurface()
    }

    @ViewBuilder
    private var relationshipParameters: some View {
        let kind = model.selectedRelationshipChart
        VStack(alignment: .leading, spacing: 12) {
            Text(kind.title(language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            if kind.isSynastry {
                Picker(
                    localized("relationship.synastry-direction", language: model.language),
                    selection: Binding(
                        get: { model.selectedRelationshipChart.rawValue },
                        set: { value in
                            if value == RelationshipChartKind.synastryA.rawValue {
                                model.selectRelationshipChart(.synastryA)
                            } else if value == RelationshipChartKind.synastryB.rawValue {
                                model.selectRelationshipChart(.synastryB)
                            }
                        }
                    )
                ) {
                    Text("\(model.profile.name) → \(selectedSynastryPartnerName ?? localized("charts.select", language: model.language))")
                        .tag(RelationshipChartKind.synastryA.rawValue)
                    Text("\(selectedSynastryPartnerName ?? localized("charts.select", language: model.language)) → \(model.profile.name)")
                        .tag(RelationshipChartKind.synastryB.rawValue)
                }
                .pickerStyle(.segmented)
            }
            if kind.needsTargetDate {
                DatePicker(
                    localized("charts.date-time", language: model.language),
                    selection: Binding(
                        get: { model.relationshipTargetDate },
                        set: { model.setRelationshipTargetDate($0) }
                    )
                )
                .datePickerStyle(.compact)
            }
            if kind.supportsTransitLocation {
                Button { showLocationPicker = true } label: {
                    Label(
                        model.relationshipLocationOverride?.placeName ?? localized("relationship.default-location", language: model.language),
                        systemImage: "location"
                    )
                }
                .buttonStyle(.bordered)
            }
            if kind.supportsMidpointAlgorithm {
                Picker(
                    localized("relationship.midpoint-algorithm", language: model.language),
                    selection: Binding(
                        get: { model.relationshipMidpointAlgorithmOverride?.rawValue ?? "default" },
                        set: { value in
                            model.setRelationshipMidpointAlgorithm(
                                value == "default" ? nil : RelationshipMidpointAlgorithm(rawValue: value)
                            )
                        }
                    )
                ) {
                    Text(localized("relationship.algorithm-default", language: model.language)).tag("default")
                    Text(localized("relationship.algorithm-average", language: model.language)).tag(RelationshipMidpointAlgorithm.average.rawValue)
                    Text(localized("relationship.algorithm-shortest", language: model.language)).tag(RelationshipMidpointAlgorithm.shortestDistance.rawValue)
                }
                .pickerStyle(.segmented)
            }
            if kind.rawValue == RelationshipChartKind.marksSecondary.rawValue ||
               kind.rawValue == RelationshipChartKind.marksTertiary.rawValue {
                Picker(
                    localized("relationship.perspective", language: model.language),
                    selection: Binding(
                        get: { model.relationshipPerspective.rawValue },
                        set: { value in
                            if let perspective = RelationshipPerspective(rawValue: value) {
                                model.setRelationshipPerspective(perspective)
                            }
                        }
                    )
                ) {
                    Text(model.profile.name).tag(RelationshipPerspective.first.rawValue)
                    Text(selectedSynastryPartnerName ?? localized("charts.select", language: model.language)).tag(RelationshipPerspective.second.rawValue)
                }
                .pickerStyle(.segmented)
            }
        }
        .cardSurface()
    }

    private var relationshipPresetSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(localized("charts.preset", language: model.language))
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.muted)
            Picker(
                localized("charts.preset", language: model.language),
                selection: Binding(
                    get: { model.preset(for: .synastry).rawValue },
                    set: { value in
                        if let preset = CalculationPreset(rawValue: value), CalculationPreset.consumerCases.contains(preset) {
                            model.setPreset(preset, for: .synastry)
                            Task { await model.ensureRelationshipChartCalculated(model.selectedRelationshipChart) }
                        }
                    }
                )
            ) {
                ForEach(CalculationPreset.consumerCases, id: \.rawValue) { preset in
                    Text(preset.title(language: model.language)).tag(preset.rawValue)
                }
            }
            .pickerStyle(.segmented)
        }
        .cardSurface()
    }

    private func eventTimeContext(_ date: Date) -> some View {
        HStack(spacing: 11) {
            Image(systemName: "clock.arrow.circlepath")
                .foregroundStyle(AppTheme.violet)
            VStack(alignment: .leading, spacing: 3) {
                Text(localized("charts.event-time-chart", language: model.language))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Text(formattedEventDate(date))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
            }
            Spacer()
            Button(localized("charts.event.back-to-now", language: model.language)) {
                model.clearChartFocus()
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(AppTheme.violet)
        }
        .cardSurface()
    }

   private func formattedEventDate(_ date: Date) -> String {
       let formatter = DateFormatter()
       formatter.locale = Locale(identifier: model.language.rawValue)
       formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
       formatter.dateStyle = .medium
       formatter.timeStyle = .short
      return formatter.string(from: date)
  }

   private func requestGeneration(
        for chart: ChartKind,
        force: Bool
    ) {
        guard model.aiConsentGranted else {
            pendingGeneration = PendingGeneration(
                chart: chart,
                force: force
            )
            return
        }
        Task {
            await model.generateAIReport(
                for: chart,
                forceRegenerate: force
            )
            if let saved = model.currentSavedReport(for: chart) {
                await MainActor.run { selectedReport = saved }
            }
        }
    }
}

private struct ReportGeneratingSheet: View {
    let chart: ChartKind
    let language: AppLanguage
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Capsule().fill(AppTheme.muted.opacity(0.45)).frame(width: 42, height: 5)
                ProgressView().controlSize(.large).tint(AppTheme.violet)
                Text(localized("reports.generating", language: language)).font(.title2.bold()).foregroundStyle(AppTheme.text)
                Text(chart.title(language: language)).font(.headline).foregroundStyle(AppTheme.violet)
                Text(localized("reports.this-may-take-a-little-while-you-can-leave-this-page-and-come-back-later", language: language))
                    .font(.subheadline).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
                Text(localized("reports.no-regenerate-while-generating", language: language))
                    .font(.caption).foregroundStyle(AppTheme.muted).multilineTextAlignment(.center)
                Button(action: onDone) {
                    Text(localized("common.done", language: language))
                        .font(.headline)
                        .foregroundStyle(Color.white)
                        .drawerTapTarget(minHeight: 52)
                }
                    .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 16)).buttonStyle(.plain)
            }
            .padding(22)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ScreenBackground())
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.hidden)
    }
}
