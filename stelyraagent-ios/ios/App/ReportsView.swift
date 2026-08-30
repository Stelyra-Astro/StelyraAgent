import SwiftUI
import AstroCore

private enum ReportSpace: Equatable {
    case you
    case bonds
}

struct ReportsView: View {
   let initialChart: ChartKind?
   @Binding var selectedTab: RootTab
   @EnvironmentObject private var model: AppModel
   @ObservedObject private var pendingReports = PendingReportManager.shared
   @State private var selectedReport: SavedReport?
   @State private var showConsent = false
   @State private var pendingChart: ChartKind?
   @State private var pendingRelationship: RelationshipChartKind?
   @State private var pendingForceRegenerate = false
   @State private var hasHandledInitialChart = false
    @State private var generationSheetChart: ChartKind?
    @State private var generationSheetRelationship: RelationshipChartKind?
    @State private var generationWillReplace = false
    @State private var reportSpace: ReportSpace = .you

    init(initialChart: ChartKind? = nil, selectedTab: Binding<RootTab>) {
        self.initialChart = initialChart
        _selectedTab = selectedTab
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 18) {
                    reportsHeader

                    Text(localized("reports.richer-calculated-details", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .cardSurface()

                    sectionTitle(
                        localized("reports.chart-reports", language: model.language),
                        sub: localized("reports.generated-only-when-you-ask", language: model.language)
                    )
                    if reportSpace == .you {
                        ForEach(orderedCharts) { chart in
                            chartReportRow(chart)
                        }
                    } else {
                        ForEach(relationshipReportTargets, id: \.rawValue) { kind in
                            relationshipReportRow(kind)
                        }
                    }

                }
                .padding(.horizontal, 17)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .alert(localized("ai.network-consent.title", language: model.language), isPresented: $showConsent) {
            Button(localized("charts.allow", language: model.language)) {
                model.grantAIConsent()
                if let chart = pendingChart {
                    Task {
                        await model.generateAIReport(
                            for: chart,
                            forceRegenerate: pendingForceRegenerate
                        )
                    }
                } else if let relationship = pendingRelationship {
                    Task {
                        await model.generateAIReport(
                            for: relationship,
                            forceRegenerate: pendingForceRegenerate
                        )
                    }
                }
                pendingChart = nil
                pendingRelationship = nil
                pendingForceRegenerate = false
            }
            Button(localized("charts.not-now", language: model.language), role: .cancel) {
                pendingChart = nil
                pendingRelationship = nil
                pendingForceRegenerate = false
            }
        } message: {
            Text(localized("ai.network-consent.chart-message", language: model.language))
        }
       .task {
           model.refreshAIReportStates()
           if initialChart == .synastry { reportSpace = .bonds }
           if !hasHandledInitialChart, let initialChart, let saved = model.currentSavedReport(for: initialChart) {
               selectedReport = saved
               hasHandledInitialChart = true
           }
       }
        .sheet(item: $generationSheetChart) { chart in
            ReportGenerationSheet(
                chart: chart,
                replacesExisting: generationWillReplace,
                onGenerate: {
                    generationSheetChart = nil
                    requestChartGeneration(chart, force: generationWillReplace)
                },
                onEdit: {
                    generationSheetChart = nil
                    model.requestChartParameterEditing(chart)
                    selectedTab = .charts
                },
                onCancel: {
                    generationSheetChart = nil
                }
            )
        }
        .sheet(item: $generationSheetRelationship) { kind in
            RelationshipReportGenerationSheet(
                kind: kind,
                replacesExisting: generationWillReplace,
                onGenerate: {
                    generationSheetRelationship = nil
                    requestRelationshipGeneration(kind, force: generationWillReplace)
                },
                onCancel: { generationSheetRelationship = nil }
            )
        }
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
                    onRegenerate: regenerationAction(for: report)
                )
            }
        }
    }

    private var orderedCharts: [ChartKind] {
        let youCharts = ChartKind.allCases.filter { $0 != .synastry }
        guard let initialChart, initialChart != .synastry else { return youCharts }
        return [initialChart] + youCharts.filter { $0 != initialChart }
    }

    private var relationshipReportTargets: [RelationshipChartKind] {
        [
            .composite, .synastryA, .compositeTransit,
            .synastryB, .compositeSecondary, .compositeTertiary,
            .compositeSecondaryCompare, .compositeTertiaryCompare,
            .davison, .davisonTransit, .davisonSecondary, .davisonTertiary,
            .marksA, .marksB, .marksSecondary, .marksTertiary,
        ]
    }

    private var reportsHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(localized("reports.library", language: model.language))
                .font(.footnote.weight(.bold))
                .tracking(1.7)
                .foregroundStyle(AppTheme.violet)
            HStack(alignment: .center, spacing: 12) {
                Text(localized("charts.reports", language: model.language))
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                Spacer()
                reportSpaceSelector
            }
            Text(localized("reports.generated-once-kept-permanently", language: model.language))
                .font(.subheadline)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private var reportSpaceSelector: some View {
        HStack(spacing: 4) {
            reportSpaceButton(.you, title: localized("charts.space.you", language: model.language))
            reportSpaceButton(.bonds, title: localized("charts.space.bonds", language: model.language))
        }
        .padding(3)
        .background(AppTheme.panel, in: Capsule())
    }

    private func reportSpaceButton(_ space: ReportSpace, title: String) -> some View {
        let selected = reportSpace == space
        return Button { reportSpace = space } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? Color.white : AppTheme.muted)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(selected ? AppTheme.violet : Color.clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func sectionTitle(_ title: String, sub: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.title3.weight(.bold)).foregroundStyle(AppTheme.text)
            Text(sub).font(.caption).foregroundStyle(AppTheme.muted)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private func chartReportRow(_ chart: ChartKind) -> some View {
        let hasSnapshot = model.snapshot(for: chart) != nil
        let saved = model.currentSavedReport(for: chart)
        let status = model.aiReportStatus(for: chart)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(savedReportScopeSymbol("chart.\(chart.contentPrefix)"))
                    .font(.title2)
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(savedReportScopeTitle("chart.\(chart.contentPrefix)", language: model.language))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(chartStatusText(status, hasSnapshot: hasSnapshot, savedAt: saved?.generatedAt))
                        .font(.caption)
                        .foregroundStyle(chartStatusColor(status, hasSnapshot: hasSnapshot))
                }
                Spacer()
            }

            if case .generating = status {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small).tint(AppTheme.violet)
                    Text(localized("reports.this-may-take-a-little-while-you-can-leave-this-page-and-come-back-later", language: model.language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.muted)
                }
            }

            if case let .failed(message) = status {
                Text(message)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.coral)
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 10) {
                    reportActions(chart: chart, saved: saved, status: status, hasSnapshot: hasSnapshot)
                }
                VStack(alignment: .leading, spacing: 10) {
                    reportActions(chart: chart, saved: saved, status: status, hasSnapshot: hasSnapshot)
                }
            }
        }
        .cardSurface()
        .overlay {
            if initialChart == chart {
                RoundedRectangle(cornerRadius: 18)
                    .stroke(AppTheme.violet.opacity(0.35), lineWidth: 1)
            }
        }
        .opacity(hasSnapshot ? 1 : 0.65)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("report-chart-\(chart.contentPrefix)")
    }

    @ViewBuilder
    private func reportActions(
        chart: ChartKind,
        saved: SavedReport?,
        status: AIReportGenerationStatus,
        hasSnapshot: Bool
    ) -> some View {
        if let saved {
            Button(localized("reports.view-report", language: model.language)) {
                selectedReport = saved
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.violet)

            Button(localized("reports.regenerate", language: model.language)) {
                openGenerationSheet(for: chart, replacing: true)
            }
            .buttonStyle(.bordered)
            .tint(AppTheme.violet)
            .disabled(status == .generating || !hasSnapshot || !model.isOnline)
        } else {
            Button(localized("reports.generate-report", language: model.language)) {
                openGenerationSheet(for: chart, replacing: false)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppTheme.violet)
            .disabled(status == .generating || !hasSnapshot || !model.isOnline)
        }
    }

    @ViewBuilder
    private func relationshipReportRow(_ kind: RelationshipChartKind) -> some View {
        let hasSnapshot = model.relationshipSnapshot(for: kind) != nil
        let saved = model.currentSavedReport(for: kind)
        let status = model.aiReportStatus(for: kind)

        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text(savedReportScopeSymbol(kind.reportScope))
                    .font(.title2)
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 40, height: 40)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(relationshipReportTitle(kind))
                        .font(.headline)
                        .foregroundStyle(AppTheme.text)
                    Text(chartStatusText(status, hasSnapshot: hasSnapshot, savedAt: saved?.generatedAt))
                        .font(.caption)
                        .foregroundStyle(chartStatusColor(status, hasSnapshot: hasSnapshot))
                }
                Spacer()
            }
            if case .generating = status {
                HStack(spacing: 9) {
                    ProgressView().controlSize(.small).tint(AppTheme.violet)
                    Text(localized("reports.this-may-take-a-little-while-you-can-leave-this-page-and-come-back-later", language: model.language))
                        .font(.caption)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            if case let .failed(message) = status {
                Text(message).font(.caption2).foregroundStyle(AppTheme.coral)
            }
            if !hasSnapshot {
                Button(localized("reports.calculate-this-chart-first", language: model.language)) {
                    Task { await model.ensureRelationshipChartCalculated(kind) }
                }
                .buttonStyle(.bordered)
                .tint(AppTheme.violet)
                .disabled(model.synastryPartnerID == nil)
            } else if let saved {
                HStack(spacing: 10) {
                    Button(localized("reports.view-report", language: model.language)) { selectedReport = saved }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.violet)
                    Button(localized("reports.regenerate", language: model.language)) {
                        openGenerationSheet(for: kind, replacing: true)
                    }
                    .buttonStyle(.bordered)
                    .tint(AppTheme.violet)
                    .disabled(status == .generating || !model.isOnline)
                }
            } else {
                Button(localized("reports.generate-report", language: model.language)) {
                    openGenerationSheet(for: kind, replacing: false)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.violet)
                .disabled(status == .generating || !model.isOnline)
            }
        }
        .cardSurface()
        .opacity(model.synastryPartnerID == nil ? 0.65 : 1)
        .accessibilityIdentifier("report-relationship-\(kind.rawValue)")
    }

    private func relationshipReportTitle(_ kind: RelationshipChartKind) -> String {
        if kind == .synastryB {
            return localized("relationship.synastry-reverse", language: model.language)
        }
        return kind.title(language: model.language)
    }

    private func chartStatusText(
        _ status: AIReportGenerationStatus,
        hasSnapshot: Bool,
        savedAt: Date?
    ) -> String {
        guard hasSnapshot else {
            return localized("reports.calculate-this-chart-first", language: model.language)
        }
        switch status {
        case .idle:
            if let savedAt { return savedTimestamp(savedAt) }
            return localized("reports.ready-to-generate", language: model.language)
        case .generating:
            return localized("reports.generating", language: model.language)
        case .ready:
            if let savedAt { return savedTimestamp(savedAt) }
            return localized("reports.ready-to-generate", language: model.language)
        case .failed:
            return savedAt != nil
                ? localized("reports.regeneration-failed-your-saved-report-is-unchanged", language: model.language)
                : localized("reports.generation-failed-you-can-try-again", language: model.language)
        }
    }

    private func savedTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func chartStatusColor(_ status: AIReportGenerationStatus, hasSnapshot: Bool) -> Color {
        guard hasSnapshot else { return AppTheme.muted }
        return switch status {
        case .ready: AppTheme.mint
        case .failed: AppTheme.coral
        case .generating: AppTheme.violet
        case .idle: AppTheme.muted
        }
    }

   private func requestChartGeneration(
       _ chart: ChartKind,
       force: Bool
   ) {
       guard model.aiConsentGranted else {
           pendingChart = chart
           pendingForceRegenerate = force
           showConsent = true
           return
       }
       Task {
           await model.generateAIReport(
               for: chart,
               forceRegenerate: force
           )
       }
   }

    private func requestRelationshipGeneration(_ kind: RelationshipChartKind, force: Bool) {
        guard model.aiConsentGranted else {
            pendingRelationship = kind
            pendingForceRegenerate = force
            showConsent = true
            return
        }
        Task { await model.generateAIReport(for: kind, forceRegenerate: force) }
    }

    private func openGenerationSheet(for chart: ChartKind, replacing: Bool) {
        generationWillReplace = replacing
        generationSheetChart = chart
    }

    private func openGenerationSheet(for kind: RelationshipChartKind, replacing: Bool) {
        generationWillReplace = replacing
        generationSheetRelationship = kind
    }

    private func regenerationAction(for report: SavedReport) -> (() -> Void)? {
        if let chart = ChartKind.allCases.first(where: {
            report.scope == "chart.\($0.contentPrefix)" && model.currentSavedReport(for: $0)?.id == report.id
        }) {
            return {
                selectedReport = nil
                openGenerationSheet(for: chart, replacing: true)
            }
        }
        if let kind = RelationshipChartKind.allCases.first(where: {
            report.scope == $0.reportScope && model.currentSavedReport(for: $0)?.id == report.id
        }) {
            return {
                selectedReport = nil
                openGenerationSheet(for: kind, replacing: true)
            }
        }
        return nil
    }

}

struct ReportReaderView: View {
    let report: SavedReport
    let language: AppLanguage
    let onRegenerate: (() -> Void)?
    @State private var sectionIndex = 0

    init(report: SavedReport, language: AppLanguage, onRegenerate: (() -> Void)? = nil) {
        self.report = report
        self.language = language
        self.onRegenerate = onRegenerate
    }

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                ScrollViewReader { proxy in
                    LazyVStack(alignment: .leading, spacing: 16) {
                            // Cover
                            VStack(alignment: .leading, spacing: 8) {
                                Text(savedReportScopeTitle(report.scope, language: language).uppercased())
                                    .font(.caption.weight(.bold))
                                    .tracking(1.4)
                                    .foregroundStyle(AppTheme.violet)
                                Text(report.report.title)
                                    .font(.largeTitle.weight(.bold))
                                    .foregroundStyle(AppTheme.text)
                                Text(report.report.subtitle)
                                    .font(.subheadline)
                                    .foregroundStyle(AppTheme.muted)
                                HStack {
                                    Text("\(savedReportScopeTitle(report.scope, language: language)) · \(report.generatedAt.shortEventDate(language: language))")
                                        .font(.caption)
                                        .foregroundStyle(AppTheme.muted)
                                }
                                .padding(.top, 6)
                            }
                            .id(-1)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                            .cardSurface()

                            // Contents (RR-02): numbered rows that jump to each section
                            VStack(alignment: .leading, spacing: 10) {
                                Text(localized("reports.contents", language: language))
                                    .font(.headline)
                                    .foregroundStyle(AppTheme.text)
                                ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                                    Button {
                                        sectionIndex = index
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            proxy.scrollTo(index, anchor: .top)
                                        }
                                    } label: {
                                        HStack {
                                            Text("\(index + 1) · \(section.title)")
                                                .font(.footnote.weight(.medium))
                                                .foregroundStyle(index == sectionIndex ? AppTheme.violet : AppTheme.text)
                                        }
                                        .contentShape(Rectangle())
                                        .padding(.vertical, 2)
                                    }
                                    .buttonStyle(.plain)
                                    Divider().overlay(AppTheme.line.opacity(0.5))
                                }
                            }
                            .padding(16)
                            .cardSurface()

                            // Sections
                            ForEach(Array(report.report.sections.enumerated()), id: \.offset) { index, section in
                                sectionCard(index: index, section: section)
                                    .id(index)
                            }
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 30)
                }
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            if onRegenerate != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localized("reports.regenerate", language: language)) {
                        onRegenerate?()
                    }
                    .foregroundStyle(AppTheme.violet)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
    }

    private func sectionCard(index: Int, section: AIReportSection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%02d · %@", index + 1, section.title.uppercased()))
                .font(.caption.weight(.bold))
                .tracking(1.2)
                .foregroundStyle(AppTheme.violet)
            Text(section.body)
                .font(.body)
                .foregroundStyle(AppTheme.text)
                .lineSpacing(5)
            if let callout = section.callout, !callout.isEmpty {
                Text(callout)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppTheme.violet)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.violet.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(16)
        .cardSurface()
    }
}

// MARK: - Report generation sheet

struct ReportGenerationSheet: View {
    let chart: ChartKind
    let replacesExisting: Bool
    let onGenerate: () -> Void
    let onEdit: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(localized("reports.generate-report", language: model.language))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)

                    Text(replacesExisting
                         ? localized("reports.current-information-will-replace", language: model.language)
                         : localized("reports.current-information-confirmation", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 0) {
                        ForEach(Array(contextRows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Divider().overlay(AppTheme.line) }
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(row.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                                    .frame(width: 86, alignment: .leading)
                                Text(row.value)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .cardSurface()

                    ReportCreditSummary(language: model.language)

                    HStack(spacing: 12) {
                        Button {
                            onEdit()
                        } label: {
                            Text(localized("reports.edit", language: model.language))
                                .drawerTapTarget(minHeight: 52)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppTheme.muted)

                        Button {
                            if commerce.totalCredits > 0 {
                                onGenerate()
                            } else {
                                onCancel()
                                DispatchQueue.main.async { commerce.showsCredits = true }
                            }
                        } label: {
                            Text(commerce.totalCredits > 0
                                 ? localized("reports.generate", language: model.language)
                                 : localized("credits.buy", language: model.language))
                                .drawerTapTarget(minHeight: 52)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(AppTheme.violet)
                    }
                }
                .padding(17)
                .padding(.top, 8)
            }
            .background(AppTheme.background)
            .toolbar(.visible, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(localized("reports.generate-report", language: model.language))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("location.cancel", language: model.language)) { onCancel() }
                }
            }
        }
    }

    private var contextRows: [(label: String, value: String)] {
        var rows: [(String, String)] = [
            (localized("reports.chart", language: model.language), chart.title(language: model.language))
        ]
        if chart == .synastry {
            if let people = model.synastryReportPeople {
                rows.append((localized("charts.people", language: model.language), "\(people.first) ↔ \(people.second)"))
            }
        } else if chart != .currentSky {
            rows.append((localized("charts.person", language: model.language), model.chartSubjectProfile.name))
        }
        switch model.chartContext(for: chart).target {
        case .natal:
            rows.append((localized("charts.date-time", language: model.language), formatted(model.chartSubjectProfile.birthDateUTC, timeZoneID: model.chartSubjectProfile.timezoneID)))
            rows.append((localized("charts.reference-location", language: model.language), model.chartSubjectProfile.placeName))
        case let .currentSky(instant, location, _):
            rows.append((localized("charts.date-time", language: model.language), formatted(instant, timeZoneID: location.timezoneID)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case let .transit(instant, location, rangeDays, _):
            rows.append((localized("charts.target-time", language: model.language), formatted(instant, timeZoneID: location.timezoneID)))
            rows.append((localized("charts.range", language: model.language), rangeLabel(rangeDays)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case let .secondary(targetDate, _):
            rows.append((localized("charts.target-date", language: model.language), formatted(targetDate, timeZoneID: model.chartSubjectProfile.timezoneID, dateOnly: true)))
        case let .solarReturn(year, location):
            rows.append((localized("charts.return-year", language: model.language), String(year)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case .synastry:
            break
        case let .tertiary(targetDate, _), let .solarArc(targetDate, _):
            rows.append((localized("charts.target-date", language: model.language), formatted(targetDate, timeZoneID: model.chartSubjectProfile.timezoneID)))
        case let .lunarReturn(targetDate, location, _):
            rows.append((localized("charts.target-date", language: model.language), formatted(targetDate, timeZoneID: location.timezoneID)))
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case let .relocation(location):
            rows.append((localized("charts.reference-location", language: model.language), location.placeName))
        case .twelfthHarmonic, .thirteenthHarmonic:
            break
        }
        rows.append((localized("reports.preset", language: model.language), model.preset(for: chart).title(language: model.language)))
        return rows
    }

    private func formatted(_ date: Date, timeZoneID: String, dateOnly: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: timeZoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = dateOnly ? .none : .short
        return formatter.string(from: date)
    }

    private func rangeLabel(_ days: Int) -> String {
        switch days {
        case 7: localized("charts.7-days", language: model.language)
        case 365: localized("charts.12-months", language: model.language)
        default: localized("charts.30-days", language: model.language)
        }
    }
}

struct RelationshipReportGenerationSheet: View {
    let kind: RelationshipChartKind
    let replacesExisting: Bool
    let onGenerate: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject private var model: AppModel
    @ObservedObject private var commerce = CommerceStore.shared

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    Text(localized("reports.generate-report", language: model.language))
                        .font(.title2.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(replacesExisting
                         ? localized("reports.current-information-will-replace", language: model.language)
                         : localized("reports.current-information-confirmation", language: model.language))
                        .font(.subheadline)
                        .foregroundStyle(AppTheme.muted)
                    VStack(spacing: 0) {
                        ForEach(Array(contextRows.enumerated()), id: \.offset) { index, row in
                            if index > 0 { Divider().overlay(AppTheme.line) }
                            HStack(alignment: .firstTextBaseline, spacing: 14) {
                                Text(row.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppTheme.muted)
                                    .frame(width: 86, alignment: .leading)
                                Text(row.value)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(AppTheme.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.vertical, 12)
                        }
                    }
                    .padding(.horizontal, 16)
                    .cardSurface()

                    ReportCreditSummary(language: model.language)

                    Button {
                        if commerce.totalCredits > 0 {
                            onGenerate()
                        } else {
                            onCancel()
                            DispatchQueue.main.async { commerce.showsCredits = true }
                        }
                    } label: {
                        Text(commerce.totalCredits > 0
                             ? localized("reports.generate", language: model.language)
                             : localized("credits.buy", language: model.language))
                            .frame(maxWidth: .infinity)
                            .drawerTapTarget(minHeight: 52)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(AppTheme.violet)
                }
                .padding(17)
                .padding(.top, 8)
            }
            .background(AppTheme.background)
            .navigationTitle(localized("reports.generate-report", language: model.language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("location.cancel", language: model.language)) { onCancel() }
                }
            }
        }
    }

    private var relationshipReportDisplayTitle: String {
        if kind == .synastryB {
            return localized("relationship.synastry-reverse", language: model.language)
        }
        return kind.title(language: model.language)
    }

    private var contextRows: [(label: String, value: String)] {
        var rows: [(String, String)] = [
            (localized("reports.chart", language: model.language), relationshipReportDisplayTitle)
        ]
        if let people = model.synastryReportPeople {
            rows.append((localized("charts.people", language: model.language), "\(people.first) ↔ \(people.second)"))
        }
        if kind.needsTargetDate {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: model.language.rawValue)
            formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
            formatter.dateStyle = .medium
            formatter.timeStyle = .short
            rows.append((localized("charts.target-date", language: model.language), formatter.string(from: model.relationshipTargetDate)))
        }
        if kind.supportsTransitLocation {
            rows.append((
                localized("charts.reference-location", language: model.language),
                model.relationshipLocationOverride?.placeName
                    ?? localized("relationship.default-location", language: model.language)
            ))
        }
        if kind.supportsMidpointAlgorithm, let algorithm = model.relationshipMidpointAlgorithmOverride {
            rows.append((localized("relationship.midpoint-algorithm", language: model.language), algorithm.rawValue))
        }
        rows.append((localized("reports.preset", language: model.language), model.preset(for: .synastry).title(language: model.language)))
        return rows
    }
}

private struct ReportCreditSummary: View {
    @ObservedObject private var commerce = CommerceStore.shared
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(localized("credits.balance", language: language), systemImage: "sparkles")
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Text(String(commerce.totalCredits))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(AppTheme.text)
            }
            HStack {
                Text(localized("credits.report-cost", language: language))
                    .foregroundStyle(AppTheme.muted)
                Spacer()
                Text(localized("credits.one-credit", language: language))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            if commerce.totalCredits > 0 {
                Text(localizedTemplate(
                    "credits.after-generation",
                    substitutions: ["count": String(max(0, commerce.totalCredits - 1))],
                    language: language
                ))
                .font(.caption)
                .foregroundStyle(AppTheme.muted)
            } else {
                Text(localized("credits.none-available", language: language))
                    .font(.caption)
                    .foregroundStyle(AppTheme.coral)
            }
        }
        .cardSurface()
    }
}
