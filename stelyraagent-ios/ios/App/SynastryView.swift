import AstroCore
import SwiftUI

private struct AskOptionDraft: Identifiable, Equatable {
    let id: UUID
    var label: String
    var primaryHouse: Int?
    var additionalHouses: Set<Int>

    init(
        id: UUID = UUID(),
        label: String = "",
        primaryHouse: Int? = nil,
        additionalHouses: Set<Int> = []
    ) {
        self.id = id
        self.label = label
        self.primaryHouse = primaryHouse
        self.additionalHouses = additionalHouses
    }
}

private enum TimingRangeSelection: String, CaseIterable, Identifiable {
    case short
    case medium
    case long
    case custom

    var id: String { rawValue }
}

private struct AskResultCard: Identifiable {
    let id: String
    let icon: String
    let summary: String
    let detail: String
}

struct AskView: View {
    @EnvironmentObject private var model: AppModel
    @State private var mode: HoraryQuestionMode?
    @State private var question = ""
    @State private var primaryHouse: Int?
    @State private var relatedHouses: Set<Int> = []
    @State private var options = [AskOptionDraft(), AskOptionDraft()]
    @State private var sharedSamePrimary: Bool?
    @State private var sharedPrimaryHouse: Int?
    @State private var sharedRelatedHouses: Set<Int> = []
    @State private var timingPrecision: TimingPrecision = .day
    @State private var timingRange: TimingRangeSelection = .medium
    @State private var startDate = Date()
    @State private var customEndDate = Date().addingTimeInterval(30 * 86_400)
    @State private var chartDate = Date()
    @State private var location: LocationSelection?
    @State private var showsLocationPicker = false
    @State private var session: HorarySession?
    @State private var isCalculating = false
    @State private var progress = 0.0
    @State private var errorMessage: String?
    @State private var calculationTask: Task<Void, Never>?
    @State private var askHistory: [AskHistoryEntry] = []
    @State private var showAskHistory = false
    @State private var showLifeAreasHelp = false
    @FocusState private var focusedInputID: String?
    private let askHistoryStore = AskHistoryStore()

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    modeSelection
                    .padding(.horizontal, 18)
                    .padding(.top, 18)
                    .padding(.bottom, 34)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showsLocationPicker) {
                LocationSearchView(language: model.language) {
                    location = $0
                }
            }
            .sheet(isPresented: $showLifeAreasHelp) {
                ABCLifeAreasHelpView(language: model.language)
            }
            .onAppear {
                if location == nil {
                    location = profileLocation
                }
                askHistory = askHistoryStore.load()
            }
            .onChange(of: startDate) { _, _ in
                customEndDate = min(max(customEndDate, startDate), maximumEndDate)
            }
            .navigationDestination(
                isPresented: Binding(
                    get: { mode != nil },
                    set: { isPresented in
                        if !isPresented {
                            resetToModes()
                        }
                    }
                )
            ) {
                if let mode {
                    askFlow(mode)
                }
            }
            .navigationDestination(isPresented: $showAskHistory) {
                AskHistoryView(
                    entries: $askHistory,
                    language: model.language,
                    onOpen: { entry in
                        openHistoryEntry(entry)
                    },
                    onDelete: { entry in
                        askHistoryStore.remove(id: entry.id)
                    }
                )
            }
        }
        .onDisappear {
            calculationTask?.cancel()
        }
    }

    private func askFlow(_ mode: HoraryQuestionMode) -> some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                Group {
                    if let session {
                        resultView(session)
                    } else {
                        configurationView(mode)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 34)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(session == nil
            ? modeTitle(mode)
            : localized("ask.your-answer", language: model.language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var modeSelection: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 7) {
                Text(localized("ask.ask-the-chart", language: model.language))
                    .font(.footnote.weight(.bold))
                    .tracking(1.7)
                    .foregroundStyle(AppTheme.violet)
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(localized("ask.what-do-you-want-to-ask", language: model.language))
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 0)
                    VStack(spacing: 1) {
                        Text(localized("credits.one-credit", language: model.language))
                            .font(.caption.weight(.bold))
                        Text(localized("ask.limited-free", language: model.language))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(AppTheme.violet)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(AppTheme.violet.opacity(0.12), in: Capsule())
                    .fixedSize()
                }
                Text(localized("ask.choose-one-path-your-question-is-calculated-privately-on-this-device", language: model.language))
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            askModeCard(
                mode: .yesNo,
                icon: "questionmark.circle",
                title: localized("ask.will-it-happen", language: model.language),
                detail: localized("ask.ask-about-one-specific-outcome", language: model.language)
            )
            askModeCard(
                mode: .choice,
                icon: "arrow.triangle.branch",
                title: localized("ask.which-one", language: model.language),
                detail: localized("ask.compare-two-to-five-real-options", language: model.language)
            )
            askModeCard(
                mode: .timing,
                icon: "calendar.badge.clock",
                title: localized("ask.find-the-best-time", language: model.language),
                detail: localized("ask.search-by-day-week-or-month", language: model.language)
            )

            historySection
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showAskHistory = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(localized("ask.history", language: model.language))
                            .font(.headline)
                            .foregroundStyle(AppTheme.text)
                        Text(askHistory.isEmpty
                             ? localized("ask.no-saved-questions-yet", language: model.language)
                             : LocalizedFormatters.savedQuestions(askHistory.count, language: model.language))
                            .font(.caption)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, minHeight: 50, alignment: .leading)
                .contentShape(Rectangle())
                .cardSurface()
            }
            .buttonStyle(.plain)
            .accessibilityLabel(localized("ask.history", language: model.language))

        }
    }

    private func askModeCard(
        mode: HoraryQuestionMode,
        icon: String,
        title: String,
        detail: String
    ) -> some View {
        Button {
            select(mode)
        } label: {
            HStack(spacing: 15) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
                    .frame(width: 48, height: 48)
                    .background(AppTheme.violet.opacity(0.12), in: Circle())
                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.text)
                    Text(detail)
                        .font(AppTypography.summary)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
            .contentShape(Rectangle())
            .cardSurface()
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ask-mode-\(mode.rawValue)")
    }

    private func configurationView(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            ScreenTitle(
                eyebrow: localized("ask.ask-the-chart", language: model.language),
                title: modeTitle(mode),
                subtitle: modeSubtitle(mode)
            )

            switch mode {
            case .yesNo:
                yesNoFields
            case .choice:
                choiceFields
            case .timing:
                timingFields
            }

            locationAndTime(mode)

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.coral)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
            }

            if isCalculating {
                VStack(alignment: .leading, spacing: 10) {
                    ProgressView(value: mode == .timing ? progress : nil)
                        .tint(AppTheme.violet)
                    HStack {
                        Text(
                            mode == .timing
                                ? localized("ask.searching-the-selected-range", language: model.language)
                                : localized("ask.calculating-the-horary-chart", language: model.language)
                        )
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        Spacer()
                        Button(localized("location.cancel", language: model.language)) {
                            calculationTask?.cancel()
                        }
                        .font(AppTypography.label)
                    }
                }
                .cardSurface()
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(localized("ask.credit-cost", language: model.language))
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppTheme.muted)
                    Text(localized("ask.limited-free", language: model.language))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Button {
                    generate(mode)
                } label: {
                    Label(
                        mode == .timing
                            ? localized("ask.find-the-best-time.9e18bc9", language: model.language)
                            : localized("ask.ask-the-chart.22f1126", language: model.language),
                        systemImage: "sparkles"
                    )
                    .font(.headline)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, minHeight: 52)
                    .background(
                        canGenerate(mode) ? AppTheme.violet : AppTheme.muted.opacity(0.5),
                        in: RoundedRectangle(cornerRadius: 16)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canGenerate(mode))
            }
        }
    }

    private var yesNoFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            fieldTitle(localized("ask.your-question", language: model.language))
            TextField(
                localized("ask.for-example-will-this-application-move-forward", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(14)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15))

            LifeAreaPickerButton(
                title: localized("ask.select-life-areas", language: model.language),
                primary: $primaryHouse,
                related: $relatedHouses,
                language: model.language
            )
        }
        .cardSurface()
    }

    private var choiceFields: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                fieldTitle(localized("ask.name-each-option", language: model.language))
                Spacer()
                Button {
                    showLifeAreasHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(localized("ask.life-areas-help", language: model.language))
            }

            VStack(alignment: .leading, spacing: 11) {
                Text(localized("ask.shared-life-areas", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Text(localized("ask.do-all-options-belong-mainly-to-the-same-life-area", language: model.language))
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 9) {
                    sharedModeButton(true, title: localized("common.yes", language: model.language))
                    sharedModeButton(false, title: localized("common.no", language: model.language))
                }

                if sharedSamePrimary == true {
                    LifeAreaPickerButton(
                        title: localized("ask.shared-primary-area", language: model.language),
                        primary: $sharedPrimaryHouse,
                        related: $sharedRelatedHouses,
                        language: model.language
                    )
                } else if sharedSamePrimary == false {
                    AdditionalLifeAreaPickerButton(
                        title: localized("ask.shared-related-areas-optional", language: model.language),
                        selection: $sharedRelatedHouses,
                        excluding: [],
                        language: model.language
                    )
                }
            }
            .padding(13)
            .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))

            ForEach($options) { $option in
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(
                            localized("ask.option", language: model.language)
                                + " \(optionLetter(option.id))"
                        )
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                        Spacer()
                        if options.count > 2 {
                            Button {
                                options.removeAll { $0.id == option.id }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(AppTheme.coral)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    TextField(
                        localized("ask.what-is-this-option", language: model.language),
                        text: $option.label
                    )
                    .focused($focusedInputID, equals: option.id.uuidString)
                    .submitLabel(.done)
                    .onSubmit { focusedInputID = nil }
                    .textFieldStyle(.plain)
                    .padding(13)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))

                    if sharedSamePrimary == true {
                        AdditionalLifeAreaPickerButton(
                            title: localized("ask.additional-life-areas-optional", language: model.language),
                            selection: $option.additionalHouses,
                            excluding: Set([sharedPrimaryHouse].compactMap { $0 }).union(sharedRelatedHouses),
                            language: model.language
                        )
                    } else if sharedSamePrimary == false {
                        LifeAreaPickerButton(
                            title: localized("ask.select-life-areas", language: model.language),
                            primary: $option.primaryHouse,
                            related: $option.additionalHouses,
                            excluding: sharedRelatedHouses,
                            language: model.language
                        )
                    }
                }
                .padding(13)
                .background(AppTheme.background.opacity(0.45), in: RoundedRectangle(cornerRadius: 16))
            }

            if options.count < 3 {
                Button {
                    options.append(AskOptionDraft())
                } label: {
                    Label(
                        localized("ask.add-another-option", language: model.language),
                        systemImage: "plus.circle.fill"
                    )
                    .font(AppTypography.label)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppTheme.violet)
            }
        }
        .cardSurface()
    }

    private var timingFields: some View {
        VStack(alignment: .leading, spacing: 16) {
            fieldTitle(localized("ask.what-are-you-planning", language: model.language))
            TextField(
                localized("ask.optional-description", language: model.language),
                text: $question
            )
            .focused($focusedInputID, equals: "question")
            .submitLabel(.done)
            .onSubmit { focusedInputID = nil }
            .textFieldStyle(.plain)
            .padding(13)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))

            LifeAreaPickerButton(
                title: localized("ask.select-life-areas", language: model.language),
                primary: $primaryHouse,
                related: $relatedHouses,
                language: model.language
            )

            fieldTitle(localized("ask.precision", language: model.language))
            Picker(
                localized("ask.precision", language: model.language),
                selection: $timingPrecision
            ) {
                Text(localized("ask.day", language: model.language)).tag(TimingPrecision.day)
                Text(localized("ask.week", language: model.language)).tag(TimingPrecision.week)
                Text(localized("ask.month", language: model.language)).tag(TimingPrecision.month)
            }
            .pickerStyle(.segmented)
            .onChange(of: timingPrecision) { _, _ in
                timingRange = .medium
                customEndDate = defaultEndDate
            }

            fieldTitle(localized("ask.search-within", language: model.language))
            Picker(
                localized("ask.search-range", language: model.language),
                selection: $timingRange
            ) {
                ForEach(TimingRangeSelection.allCases) { range in
                    Text(rangeTitle(range)).tag(range)
                }
            }
            .pickerStyle(.navigationLink)

            if timingRange == .custom {
                DatePicker(
                    localized("ask.end-date", language: model.language),
                    selection: $customEndDate,
                    in: startDate ... maximumEndDate,
                    displayedComponents: [.date]
                )
            }
        }
        .cardSurface()
    }

    private func locationAndTime(_ mode: HoraryQuestionMode) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            fieldTitle(
                mode == .timing
                    ? localized("ask.search-starts", language: model.language)
                    : localized("ask.chart-moment", language: model.language)
            )
            DatePicker(
                "",
                selection: mode == .timing ? $startDate : $chartDate,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .frame(maxWidth: .infinity, alignment: .leading)

            fieldTitle(localized("ask.location", language: model.language))
            Button {
                showsLocationPicker = true
            } label: {
                HStack(spacing: 11) {
                    Image(systemName: "map.fill")
                        .foregroundStyle(AppTheme.violet)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(location?.name ?? localized("ask.choose-a-location", language: model.language))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        if let location {
                            Text(location.timezoneID)
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundStyle(AppTheme.violet)
                }
                .frame(minHeight: 50)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

        }
        .cardSurface()
    }

    private func resultView(_ session: HorarySession) -> some View {
        let overlay = overlay(for: session)
        return VStack(alignment: .leading, spacing: 18) {
            ScreenTitle(
                eyebrow: localized("ask.ask-the-chart", language: model.language),
                title: localized("ask.your-answer", language: model.language),
                subtitle: formattedSessionDate(session)
            )

            resultHero(session)

            ChartWheelView(
                snapshot: session.snapshot,
                reference: nil,
                comparisonAspects: [],
                language: model.language,
                horaryOverlay: overlay
            )
            .padding(10)
            .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

            if session.mode == .choice {
                choiceRanking(session.choices)
            } else if session.mode == .timing {
                timingRanking(session.timingCandidates)
            }

            resultCards(session)

            NavigationLink {
                HoraryProfessionalView(session: session, overlay: overlay, language: model.language)
            } label: {
                Label(
                    localized("ask.view-chart-analysis", language: model.language),
                    systemImage: "chart.xyaxis.line"
                )
                .font(.headline)
                .foregroundStyle(AppTheme.violet)
                .frame(maxWidth: .infinity, minHeight: 52)
                .background(AppTheme.violet.opacity(0.11), in: RoundedRectangle(cornerRadius: 16))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Text(
                session.mode == .timing
                    ? localized("ask.likelihood-and-suitability-describe-support-within-this-chart-model-they", language: model.language)
                    : localized("ask.support-note", language: model.language)
            )
            .font(AppTypography.supporting)
            .foregroundStyle(AppTheme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultHero(_ session: HorarySession) -> some View {
        let score = primaryScore(session)
        let label = primaryLabel(session)
        return HStack(spacing: 18) {
            ZStack {
                Circle()
                    .stroke(AppTheme.line, lineWidth: 10)
                Circle()
                    .trim(from: 0, to: score / 100)
                    .stroke(
                        scoreColor(score),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(Int(score.rounded()))%")
                        .font(.title2.bold().monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                    Text(session.mode == .timing
                        ? localized("ask.suitable", language: model.language)
                        : localized("ask.support", language: model.language))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 116, height: 116)

            VStack(alignment: .leading, spacing: 7) {
                Text(label)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                if !session.question.trimmed.isEmpty {
                    Text(session.question)
                        .font(AppTypography.summary)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
        }
        .cardSurface()
    }

    private func choiceRanking(_ choices: [HoraryChoiceResult]) -> some View {
        let close = choices.first?.isTiedForLead == true
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(localized("ask.option-ranking", language: model.language))
                    .font(.headline)
                    .foregroundStyle(AppTheme.text)
                Spacer()
                if close {
                    Text(localized("ask.close-call", language: model.language))
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.amber)
                }
            }
            ForEach(Array(choices.enumerated()), id: \.element.id) { index, item in
                VStack(spacing: 6) {
                    HStack {
                        Text(String(UnicodeScalar(65 + item.originalIndex)!))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.violet)
                            .frame(width: 24, height: 24)
                            .background(AppTheme.violet.opacity(0.12), in: Circle())
                        Text(item.label)
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        Spacer()
                        Text("\(Int(item.supportScore.rounded()))%")
                            .font(.headline.monospacedDigit())
                            .foregroundStyle(AppTheme.text)
                    }
                    ProgressView(value: item.supportScore, total: 100)
                        .tint(index == 0 ? AppTheme.violet : AppTheme.blue.opacity(0.6))
                }
                .padding(.vertical, 4)
            }
        }
        .cardSurface()
    }

    private func timingRanking(_ candidates: [ElectionTimingCandidate]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(localized("ask.best-timing", language: model.language))
                .font(.headline)
                .foregroundStyle(AppTheme.text)
            ForEach(Array(candidates.enumerated()), id: \.element.id) { index, candidate in
                HStack(spacing: 12) {
                    Image(systemName: index == 0 ? "star.fill" : "calendar")
                        .foregroundStyle(index == 0 ? AppTheme.amber : AppTheme.violet)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(formattedInterval(candidate))
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                        if timingPrecision != .day {
                            Text(
                                localized("ask.peak", language: model.language)
                                    + formattedDate(candidate.peakDate, includesTime: false)
                            )
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text("\(Int(candidate.score.rounded()))%")
                        .font(.headline.monospacedDigit())
                        .foregroundStyle(AppTheme.text)
                }
                .frame(minHeight: 48)
            }
        }
        .cardSurface()
    }

    private func resultCards(_ session: HorarySession) -> some View {
        let cards: [AskResultCard]
        do {
            cards = try AskContentComposer.cards(
                for: session,
                language: model.language
            )
        } catch {
            return AnyView(
                Label(
                    localized("ask.result-explanations-are-unavailable", language: model.language),
                    systemImage: "exclamationmark.triangle"
                )
                .font(AppTypography.summary)
                .foregroundStyle(AppTheme.coral)
                .frame(maxWidth: .infinity, alignment: .leading)
                .cardSurface()
            )
        }
        return AnyView(
            VStack(spacing: 12) {
                ForEach(cards) { card in
                    DisclosureGroup {
                        Text(card.detail)
                            .font(AppTypography.body)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 8)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: card.icon)
                                .font(.title3)
                                .foregroundStyle(AppTheme.violet)
                                .frame(width: 28)
                            Text(card.summary)
                                .font(AppTypography.summary)
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .tint(AppTheme.violet)
                    .cardSurface()
                }
            }
        )
    }

    private func fieldTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.label)
            .foregroundStyle(AppTheme.text)
    }

    private func generate(_ mode: HoraryQuestionMode) {
        guard let location else { return }
        calculationTask?.cancel()
        isCalculating = true
        progress = 0
        errorMessage = nil
        let requestLocation = GeographicLocation(
            latitudeDegrees: location.latitude,
            longitudeDegrees: location.longitude
        )
        calculationTask = Task {
            do {
                let newSession: HorarySession
                switch mode {
                case .yesNo:
                    guard let primaryHouse else { return }
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: try await model.calculateHoraryJudgment(
                            snapshot: snapshot,
                            targetHouse: primaryHouse,
                            relatedHouses: Array(relatedHouses).sorted()
                        ),
                        choices: [],
                        timingCandidates: []
                    )
                case .choice:
                    let moment = chartDate
                    let snapshot = try await model.calculateHorarySnapshot(
                        at: moment,
                        location: requestLocation
                    )
                    let candidates = options.enumerated().compactMap { index, option -> HoraryChoiceCandidate? in
                        guard let house = effectivePrimaryHouse(for: option) else { return nil }
                        return HoraryChoiceCandidate(
                            id: option.id,
                            label: option.label.trimmed,
                            house: house,
                            relatedHouses: Array(effectiveRelatedHouses(for: option)).sorted(),
                            originalIndex: index
                        )
                    }
                    let choiceMode: HoraryChoiceSignificatorMode = if let sharedPrimaryHouse,
                                                                     sharedSamePrimary == true {
                        .sharedPrimary(house: sharedPrimaryHouse)
                    } else {
                        .independentPrimary
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: "",
                        createdAt: moment,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: snapshot,
                        analysis: nil,
                        choices: try await model.calculateHoraryChoices(
                            snapshot: snapshot,
                            candidates: candidates,
                            mode: choiceMode
                        ),
                        timingCandidates: []
                    )
                case .timing:
                    guard let primaryHouse else { return }
                    guard let timeZone = TimeZone(identifier: location.timezoneID) else {
                        throw AskViewError.invalidTimeZone
                    }
                    let request = ElectionTimingRequest(
                        targetHouse: primaryHouse,
                        relatedHouses: Array(relatedHouses).sorted(),
                        startDate: startDate,
                        endDate: selectedEndDate,
                        location: requestLocation,
                        timeZone: timeZone,
                        calendarIdentifier: .gregorian,
                        precision: timingPrecision
                    )
                    let candidates = try await model.searchElectionTiming(request) { value in
                        Task { @MainActor in
                            progress = value
                        }
                    }
                    guard let first = candidates.first else {
                        throw ElectionTimingError.noCandidates
                    }
                    newSession = HorarySession(
                        mode: mode,
                        question: question.trimmed,
                        createdAt: startDate,
                        locationName: location.name,
                        timezoneID: location.timezoneID,
                        snapshot: first.snapshot,
                        analysis: first.analysis,
                        choices: [],
                        timingCandidates: candidates
                    )
                }
                try Task.checkCancellation()
                await MainActor.run {
                    session = newSession
                    isCalculating = false
                    progress = 1
                    askHistoryStore.append(historyEntry(from: newSession))
                    askHistory = askHistoryStore.load()
                }
            } catch is CancellationError {
                await MainActor.run {
                    isCalculating = false
                    progress = 0
                }
            } catch {
                await MainActor.run {
                    errorMessage = localized("ask.the-chart-could-not-be-calculated-check-the-time-and-location-then-try-a", language: model.language)
                    isCalculating = false
                }
            }
        }
    }

    private func select(_ selectedMode: HoraryQuestionMode) {
        mode = selectedMode
        focusedInputID = nil
        chartDate = Date()
        startDate = Date()
        customEndDate = defaultEndDate
        session = nil
        errorMessage = nil
    }

    private func resetToModes() {
        calculationTask?.cancel()
        calculationTask = nil
        mode = nil
        session = nil
        focusedInputID = nil
        question = ""
        primaryHouse = nil
        relatedHouses = []
        options = [AskOptionDraft(), AskOptionDraft()]
        sharedSamePrimary = nil
        sharedPrimaryHouse = nil
        sharedRelatedHouses = []
        timingPrecision = .day
        timingRange = .medium
        startDate = Date()
        chartDate = Date()
        customEndDate = defaultEndDate
        isCalculating = false
        progress = 0
        errorMessage = nil
    }

    private func canGenerate(_ mode: HoraryQuestionMode) -> Bool {
        guard location != nil else { return false }
        switch mode {
        case .yesNo:
            return !question.trimmed.isEmpty && primaryHouse != nil
        case .choice:
            return options.count >= 2
                && sharedSamePrimary != nil
                && options.allSatisfy {
                    !$0.label.trimmed.isEmpty && effectivePrimaryHouse(for: $0) != nil
                }
        case .timing:
            return primaryHouse != nil && selectedEndDate > startDate
        }
    }

    private func optionLetter(_ id: UUID) -> String {
        guard let index = options.firstIndex(where: { $0.id == id }) else { return "" }
        return String(UnicodeScalar(65 + index)!)
    }

    private func effectivePrimaryHouse(for option: AskOptionDraft) -> Int? {
        sharedSamePrimary == true ? sharedPrimaryHouse : option.primaryHouse
    }

    private func effectiveRelatedHouses(for option: AskOptionDraft) -> Set<Int> {
        guard let primary = effectivePrimaryHouse(for: option) else { return [] }
        return sharedRelatedHouses
            .union(option.additionalHouses)
            .subtracting([primary])
    }

    private func sharedModeButton(_ value: Bool, title: String) -> some View {
        let selected = sharedSamePrimary == value
        return Button {
            sharedSamePrimary = value
            if value {
                for index in options.indices {
                    options[index].primaryHouse = nil
                }
            } else {
                sharedPrimaryHouse = nil
            }
        } label: {
            Text(title)
                .font(AppTypography.label)
                .foregroundStyle(selected ? Color.white : AppTheme.text)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected ? AppTheme.violet : AppTheme.panelRaised,
                    in: RoundedRectangle(cornerRadius: 12)
                )
        }
        .buttonStyle(.plain)
    }

    private func historyEntry(from session: HorarySession) -> AskHistoryEntry {
        let title: String
        let text: String
        switch session.mode {
        case .yesNo:
            title = session.analysis.map { judgmentLabel($0) } ?? localized("ask.result", language: model.language)
            text = session.analysis.map { "\(Int($0.score.rounded()))% " + localized("ask.support", language: model.language) } ?? ""
        case .choice:
            if let first = session.choices.first {
                title = first.isTiedForLead
                    ? localized("ask.no-clear-option", language: model.language)
                    : first.label
                text = "\(Int(first.supportScore.rounded()))% " + localized("ask.support", language: model.language)
            } else {
                title = localized("ask.result", language: model.language)
                text = ""
            }
        case .timing:
            title = session.timingCandidates.first.map { formatDateRange($0.interval) } ?? localized("ask.result", language: model.language)
            text = localized("ask.recommended-window", language: model.language)
        }
        return AskHistoryEntry(
            id: session.snapshot.utcDate.timeIntervalSince1970.description + session.question,
            mode: session.mode.rawValue,
            question: session.question.isEmpty ? modeTitle(session.mode) : session.question,
            answerTitle: title,
            answerText: text,
            createdAt: session.createdAt,
            locationName: session.locationName,
            significators: [],
            session: session
        )
    }

    private func openHistoryEntry(_ entry: AskHistoryEntry) {
        guard let restoredSession = entry.session else { return }
        withTransaction(Transaction(animation: nil)) {
            session = restoredSession
            mode = restoredSession.mode
            showAskHistory = false
        }
    }

    private func formatDateRange(_ interval: DateInterval) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: interval.start)
    }

    private var profileLocation: LocationSelection {
        LocationSelection(
            name: model.profile.placeName,
            latitude: model.profile.latitude,
            longitude: model.profile.longitude,
            timezoneID: model.profile.timezoneID
        )
    }

    private var selectedEndDate: Date {
        if timingRange == .custom {
            return min(customEndDate, maximumEndDate)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        let component: Calendar.Component
        let value: Int
        switch timingPrecision {
        case .day:
            component = .day
            value = timingRange == .short ? 7 : timingRange == .medium ? 30 : 90
        case .week:
            component = .month
            value = timingRange == .short ? 1 : timingRange == .medium ? 3 : 6
        case .month:
            component = .month
            value = timingRange == .short ? 3 : timingRange == .medium ? 6 : 12
        }
        return calendar.date(byAdding: component, value: value, to: startDate)
            ?? startDate.addingTimeInterval(Double(value) * 30 * 86_400)
    }

    private var maximumEndDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        switch timingPrecision {
        case .day:
            return calendar.date(byAdding: .day, value: 90, to: startDate)
                ?? startDate.addingTimeInterval(90 * 86_400)
        case .week:
            return calendar.date(byAdding: .month, value: 6, to: startDate)
                ?? startDate.addingTimeInterval(184 * 86_400)
        case .month:
            return calendar.date(byAdding: .month, value: 12, to: startDate)
                ?? startDate.addingTimeInterval(366 * 86_400)
        }
    }

    private var defaultEndDate: Date {
        selectedEndDate
    }

    private func rangeTitle(_ range: TimingRangeSelection) -> String {
        if range == .custom {
            return localized("ask.custom", language: model.language)
        }
        let values: [Int]
        switch timingPrecision {
        case .day: values = [7, 30, 90]
        case .week: values = [1, 3, 6]
        case .month: values = [3, 6, 12]
        }
        let index = range == .short ? 0 : range == .medium ? 1 : 2
        let value = values[index]
        switch timingPrecision {
        case .day:
            return LocalizedFormatters.nextDays(value, language: model.language)
        case .week, .month:
            return LocalizedFormatters.nextMonths(value, language: model.language)
        }
    }

    private func modeTitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo: localized("ask.will-it-happen", language: model.language)
        case .choice: localized("ask.which-one", language: model.language)
        case .timing: localized("ask.find-the-best-time", language: model.language)
        }
    }

    private func modeSubtitle(_ mode: HoraryQuestionMode) -> String {
        switch mode {
        case .yesNo:
            localized("ask.keep-the-question-specific-and-choose-the-area-it-belongs-to", language: model.language)
        case .choice:
            localized("ask.name-the-real-options-and-choose-their-life-areas", language: model.language)
        case .timing:
            localized("ask.choose-what-matters-how-far-to-search-and-the-precision-you-need", language: model.language)
        }
    }

    private func primaryScore(_ session: HorarySession) -> Double {
        switch session.mode {
        case .yesNo: session.analysis?.score ?? 0
        case .choice: session.choices.first?.supportScore ?? 0
        case .timing: session.timingCandidates.first?.score ?? 0
        }
    }

    private func primaryLabel(_ session: HorarySession) -> String {
        switch session.mode {
        case .yesNo:
            guard let analysis = session.analysis else {
                return localized("ask.still-unclear", language: model.language)
            }
            return judgmentLabel(analysis)
        case .choice:
            guard let first = session.choices.first, !first.isTiedForLead else {
                return localized("ask.no-clear-option", language: model.language)
            }
            return first.label
        case .timing:
            guard let first = session.timingCandidates.first else {
                return localized("ask.no-timing-found", language: model.language)
            }
            return formattedInterval(first)
        }
    }

    private func scoreColor(_ score: Double) -> Color {
        if score >= 65 { return AppTheme.mint }
        if score >= 45 { return AppTheme.amber }
        return AppTheme.coral
    }

    private func judgmentLabel(_ analysis: HoraryAnalysis) -> String {
        switch analysis.judgment?.verdict {
        case .yes: localized("common.yes", language: model.language)
        case .no: localized("common.no", language: model.language)
        case .noClearJudgment, nil: localized("ask.no-clear-judgment", language: model.language)
        }
    }

    private func overlay(for session: HorarySession) -> HoraryOverlay {
        var houses: Set<Int> = [1]
        var labels: [CelestialBody: [String]] = [:]
        var aspects: Set<String> = []

        func append(_ label: String, for body: CelestialBody) {
            var values = labels[body, default: []]
            if !values.contains(label) { values.append(label) }
            labels[body] = values
        }

        switch session.mode {
        case .yesNo, .timing:
            if let analysis = session.analysis {
                houses.insert(analysis.targetHouse)
                append(localized("ask.you", language: model.language), for: analysis.querentRuler)
                append(
                    session.mode == .timing
                        ? localized("ask.goal", language: model.language)
                        : localized("ask.answer", language: model.language),
                    for: analysis.targetRuler
                )
                if let relationship = analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        case .choice:
            if let first = session.choices.first {
                append(localized("ask.you", language: model.language), for: first.analysis.querentRuler)
            }
            for choice in session.choices {
                houses.insert(choice.house)
                append(
                    "\(String(UnicodeScalar(65 + choice.originalIndex)!)) · \(choice.label)",
                    for: choice.ruler
                )
                if let relationship = choice.analysis.relationship {
                    aspects.insert(relationship.id)
                }
            }
        }
        return HoraryOverlay(
            highlightedHouses: houses,
            planetLabels: labels.mapValues { $0.joined(separator: " / ") },
            keyAspectIDs: aspects
        )
    }

    private func formattedSessionDate(_ session: HorarySession) -> String {
        "\(formattedDate(session.createdAt, includesTime: true)) · \(session.locationName)"
    }

    private func formattedDate(_ date: Date, includesTime: Bool) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: location?.timezoneID ?? "") ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = includesTime ? .short : .none
        return formatter.string(from: date)
    }

    private func formattedInterval(_ candidate: ElectionTimingCandidate) -> String {
        if timingPrecision == .day {
            return formattedDate(candidate.peakDate, includesTime: false)
        }
        let start = formattedDate(candidate.interval.start, includesTime: false)
        let end = formattedDate(
            candidate.interval.end.addingTimeInterval(-1),
            includesTime: false
        )
        return "\(start) – \(end)"
    }
}

private struct LifeAreaPickerButton: View {
    let title: String
    @Binding var primary: Int?
    @Binding var related: Set<Int>
    var excluding: Set<Int> = []
    let language: AppLanguage
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                    Text(summary)
                        .font(AppTypography.supporting)
                        .foregroundStyle(primary == nil ? AppTheme.muted : AppTheme.violet)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("ask-life-area-picker")
        .sheet(isPresented: $isPresented) {
            LifeAreaPickerSheet(
                title: title,
                primary: $primary,
                related: $related,
                excluding: excluding,
                allowsPrimary: true,
                language: language
            )
        }
    }

    private var summary: String {
        guard let primary else {
            return localized("ask.select-life-areas", language: language)
        }
        let relatedNames = related.subtracting([primary]).sorted().map {
            askLifeAreaTitle($0, language: language)
        }
        if relatedNames.isEmpty {
            return askLifeAreaTitle(primary, language: language)
        }
        return askLifeAreaTitle(primary, language: language) + " · " + relatedNames.joined(separator: ", ")
    }
}

private struct AdditionalLifeAreaPickerButton: View {
    let title: String
    @Binding var selection: Set<Int>
    let excluding: Set<Int>
    let language: AppLanguage
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(AppTypography.label)
                        .foregroundStyle(AppTheme.text)
                    Text(summary)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(AppTheme.violet)
            }
            .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $isPresented) {
            LifeAreaPickerSheet(
                title: title,
                primary: .constant(nil),
                related: $selection,
                excluding: excluding,
                allowsPrimary: false,
                language: language
            )
        }
    }

    private var summary: String {
        let names = selection.subtracting(excluding).sorted().map {
            askLifeAreaTitle($0, language: language)
        }
        return names.isEmpty
            ? localized("common.none", language: language)
            : names.joined(separator: ", ")
    }
}

private struct LifeAreaPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var primary: Int?
    @Binding var related: Set<Int>
    let excluding: Set<Int>
    let allowsPrimary: Bool
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            List(1 ... 12, id: \.self) { house in
                let selected = primary == house || related.contains(house)
                let disabled = excluding.contains(house) && !selected
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .center, spacing: 12) {
                        Button { toggle(house) } label: {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(selected ? AppTheme.violet : AppTheme.muted)
                                .frame(width: 32, height: 44)
                        }
                        .buttonStyle(.plain)
                        .disabled(disabled)
                        .accessibilityIdentifier("ask-life-area-toggle-\(house)")

                        VStack(alignment: .leading, spacing: 3) {
                            Text(askLifeAreaTitle(house, language: language))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(disabled ? AppTheme.muted : AppTheme.text)
                            Text(askLifeAreaDescription(house, language: language))
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 4)
                        if allowsPrimary, primary == house {
                            Text(localized("ask.primary", language: language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 9)
                                .frame(minHeight: 32)
                                .background(AppTheme.violet, in: Capsule())
                        } else if allowsPrimary, related.contains(house) {
                            Text(localized("ask.related", language: language))
                                .font(.caption.weight(.bold))
                                .foregroundStyle(AppTheme.violet)
                        }
                    }

                    if allowsPrimary, related.contains(house) {
                        Button { makePrimary(house) } label: {
                            Label(
                                localized("ask.set-as-primary", language: language),
                                systemImage: "arrow.up.circle"
                            )
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppTheme.violet)
                            .frame(maxWidth: .infinity, minHeight: 36, alignment: .leading)
                            .padding(.leading, 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("ask-life-area-set-primary-\(house)")
                    }
                }
                .contentShape(Rectangle())
                .opacity(disabled ? 0.55 : 1)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: language)) { dismiss() }
                        .disabled(allowsPrimary && primary == nil && !related.isEmpty)
                }
            }
        }
    }

    private func toggle(_ house: Int) {
        guard !excluding.contains(house) || primary == house || related.contains(house) else { return }
        if primary == house {
            primary = nil
        } else if related.contains(house) {
            related.remove(house)
        } else if allowsPrimary, primary == nil, related.isEmpty {
            primary = house
        } else {
            related.insert(house)
        }
    }

    private func makePrimary(_ house: Int) {
        guard allowsPrimary else { return }
        if let previous = primary, previous != house {
            related.insert(previous)
        }
        related.remove(house)
        primary = house
    }
}

private struct ABCLifeAreasHelpView: View {
    @Environment(\.dismiss) private var dismiss
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            ScrollView(.vertical, showsIndicators: false) {
                Text(attributedText)
                    .font(.body)
                    .foregroundStyle(AppTheme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
            }
            .background(ScreenBackground())
            .navigationTitle(localized("ask.life-areas-help", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: language)) { dismiss() }
                }
            }
        }
    }

    private var attributedText: AttributedString {
        let resource = "abc-life-areas-help-\(language.helpResourceCode)"
        guard let url = Bundle.main.url(forResource: resource, withExtension: "md"),
              let markdown = try? String(contentsOf: url, encoding: .utf8),
              let value = try? AttributedString(markdown: markdown)
        else {
            return AttributedString(localized("ask.help-unavailable", language: language))
        }
        return value
    }
}

private extension AppLanguage {
    var helpResourceCode: String {
        switch self {
        case .english: "en"
        case .simplifiedChinese: "zh-Hans"
        case .spanish: "es"
        case .french: "fr"
        case .turkish: "tr"
        case .german: "de"
        case .italian: "it"
        case .portugueseBrazil: "pt-BR"
        case .korean: "ko"
        }
    }
}

private func askLifeAreaTitle(_ house: Int, language: AppLanguage) -> String {
    let keys = [
        "ask.house-area.1", "ask.house-area.2", "ask.house-area.3", "ask.house-area.4",
        "ask.house-area.5", "ask.house-area.6", "ask.house-area.7", "ask.house-area.8",
        "ask.house-area.9", "ask.house-area.10", "ask.house-area.11", "ask.house-area.12",
    ]
    return localized(keys[min(12, max(1, house)) - 1], language: language)
}

private func askLifeAreaDescription(_ house: Int, language: AppLanguage) -> String {
    let keys = [
        "ask.house-area-description.1", "ask.house-area-description.2",
        "ask.house-area-description.3", "ask.house-area-description.4",
        "ask.house-area-description.5", "ask.house-area-description.6",
        "ask.house-area-description.7", "ask.house-area-description.8",
        "ask.house-area-description.9", "ask.house-area-description.10",
        "ask.house-area-description.11", "ask.house-area-description.12",
    ]
    return localized(keys[min(12, max(1, house)) - 1], language: language)
}

private enum AskViewError: Error {
    case invalidTimeZone
}

private enum AskContentComposer {
    static func cards(
        for session: HorarySession,
        language: AppLanguage
    ) throws -> [AskResultCard] {
        let content = ContentProvider(area: .ask, language: language)
        switch session.mode {
        case .yesNo:
            guard let analysis = session.analysis else { return [] }
            let verdict = analysis.judgment?.verdict ?? .noClearJudgment
            let verdictKey: String = switch verdict {
            case .yes: "ask.judgment.yes"
            case .no: "ask.judgment.no"
            case .noClearJudgment: "ask.judgment.no-clear"
            }
            return try [
                card(
                    id: "answer",
                    icon: "checkmark.seal",
                    copy: content.requiredCopy(
                        key: verdictKey,
                        variables: ["score": "\(Int(analysis.score.rounded()))"]
                    )
                ),
                relationshipCard(analysis, content: content),
                moonCard(analysis, content: content),
                obstacleCard(analysis, content: content),
            ]
        case .choice:
            guard let first = session.choices.first else { return [] }
            return try [
                card(
                    id: "choice-result",
                    icon: "list.number",
                    copy: content.requiredCopy(
                        key: first.isTiedForLead ? "ask.choice.no-clear" : "ask.choice.leading",
                        variables: [
                            "option": first.label,
                            "score": "\(Int(first.supportScore.rounded()))",
                        ]
                    )
                ),
                relationshipCard(first.analysis, content: content),
                moonCard(first.analysis, content: content),
                obstacleCard(first.analysis, content: content),
            ]
        case .timing:
            guard let first = session.timingCandidates.first else { return [] }
            return try [
                card(
                    id: "timing-result",
                    icon: "calendar.badge.checkmark",
                    copy: content.requiredCopy(
                        key: "ask.timing.best",
                        variables: ["score": "\(Int(first.score.rounded()))"]
                    )
                ),
                relationshipCard(first.analysis, content: content),
                moonCard(first.analysis, content: content),
                obstacleCard(first.analysis, content: content),
            ]
        }
    }

    private static func relationshipCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let key: String
        if let perfection = analysis.judgment?.perfection {
            if perfection.status == .completes, perfection.primaryPath?.kind == .translation {
                key = "ask.connection.translation"
            } else if perfection.status == .completes, perfection.primaryPath?.kind == .collection {
                key = "ask.connection.collection"
            } else if perfection.status == .prevented {
                key = "ask.connection.prevented"
            } else if perfection.status == .delayed {
                key = "ask.connection.delayed"
            } else if let relationship = analysis.relationship {
                if relationship.phase == .separating {
                    key = "ask.connection.separating"
                } else if relationship.kind.supportive || relationship.kind == .conjunction {
                    key = "ask.connection.supportive"
                } else {
                    key = "ask.connection.challenging"
                }
            } else {
                key = "ask.connection.none"
            }
        } else if let relationship = analysis.relationship {
            if relationship.phase == .separating {
                key = "ask.connection.separating"
            } else if relationship.kind.supportive || relationship.kind == .conjunction {
                key = "ask.connection.supportive"
            } else {
                key = "ask.connection.challenging"
            }
        } else {
            key = "ask.connection.none"
        }
        return card(
            id: "connection",
            icon: "link",
            copy: try content.requiredCopy(key: key)
        )
    }

    private static func moonCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        card(
            id: "moon",
            icon: "moon.stars",
            copy: try content.requiredCopy(
                key: analysis.moon.isVoidOfCourse
                    ? "ask.moon.void"
                    : "ask.moon.next"
            )
        )
    }

    private static func obstacleCard(
        _ analysis: HoraryAnalysis,
        content: ContentProvider
    ) throws -> AskResultCard {
        let hasInterruption = !(analysis.judgment?.perfection.interruptions.isEmpty ?? true)
        let hasConditionRisk = analysis.querent.conditions.contains(.combust)
            || analysis.querent.conditions.contains(.retrograde)
            || analysis.target.conditions.contains(.combust)
            || analysis.target.conditions.contains(.retrograde)
        return card(
            id: "obstacle",
            icon: hasInterruption || hasConditionRisk ? "exclamationmark.triangle" : "shield.checkered",
            copy: try content.requiredCopy(
                key: hasInterruption || hasConditionRisk ? "ask.risk.present" : "ask.risk.limited"
            )
        )
    }

    private static func card(
        id: String,
        icon: String,
        copy: (summary: String, detail: String)
    ) -> AskResultCard {
        AskResultCard(
            id: id,
            icon: icon,
            summary: copy.summary,
            detail: copy.detail
        )
    }
}

private struct HoraryProfessionalView: View {
    let session: HorarySession
    let overlay: HoraryOverlay
    let language: AppLanguage

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                ChartWheelView(
                    snapshot: session.snapshot,
                    reference: nil,
                    comparisonAspects: [],
                    language: language,
                    horaryOverlay: overlay
                )
                .padding(10)
                .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 24))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(AppTheme.line))

                AspectChartView(
                    aspects: HoraryEngine.validTraditionalAspects(in: session.snapshot),
                    movingPoints: session.snapshot.points,
                    referencePoints: [],
                    language: language,
                    comparison: false
                )

                ForEach(Array(analyses.enumerated()), id: \.offset) { _, analysis in
                    analysisBlock(analysis)
                }
            }
            .padding(18)
        }
        .background(ScreenBackground())
        .navigationTitle(localized("ask.chart-analysis", language: language))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var analyses: [HoraryAnalysis] {
        if session.mode == .choice {
            return session.choices.map(\.analysis)
        }
        return [session.analysis].compactMap { $0 }
    }

    private func analysisBlock(_ analysis: HoraryAnalysis) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(
                localizedTemplate("dynamic.d9e7f60cb4", substitutions: ["value1": String(describing: analysis.targetHouse)], language: language)
            )
            .font(.headline)
            .foregroundStyle(AppTheme.text)

            professionalRow(
                localized("ask.querent-ruler", language: language),
                bodyName(analysis.querentRuler, language: language)
            )
            professionalRow(
                localized("ask.target-ruler", language: language),
                bodyName(analysis.targetRuler, language: language)
            )
            if let judgment = analysis.judgment {
                professionalRow(
                    localized("ask.judgment", language: language),
                    judgmentLabel(judgment.verdict)
                )
                professionalRow(
                    localized("ask.perfection", language: language),
                    perfectionLabel(judgment.perfection)
                )
            }
            professionalRow(
                localized("ask.connection", language: language),
                analysis.relationship.map {
                    "\(aspectKindName($0.kind, language: language)) · \(phaseLabel($0.phase, language: language)) · \(formatOrb($0.orbDegrees))"
                } ?? localized("ask.no-major-aspect-in-orb", language: language)
            )
            professionalRow(
                localized("ask.reception", language: language),
                receptionLabel(analysis)
            )
            professionalRow(
                localized("insight.natal.moon", language: language),
                analysis.moon.isVoidOfCourse
                    ? localized("ask.void-of-course", language: language)
                    : nextMoonAspect(analysis)
            )

            Divider().overlay(AppTheme.line)
            ForEach(analysis.components) { component in
                HStack {
                    Text(componentLabel(component.id))
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                    Spacer()
                    Text(String(format: "%+.1f", component.value))
                        .font(AppTypography.label.monospacedDigit())
                        .foregroundStyle(component.value < 0 ? AppTheme.coral : AppTheme.mint)
                }
            }
            HStack {
                Text(localized(analysis.judgment == nil ? "ask.total" : "ask.support", language: language))
                    .font(.headline)
                Spacer()
                Text("\(Int(analysis.score.rounded()))")
                    .font(.title3.bold().monospacedDigit())
            }
            .foregroundStyle(AppTheme.text)
        }
        .cardSurface()
    }

    private func professionalRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title)
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
            Spacer()
            Text(value)
                .font(AppTypography.label)
                .foregroundStyle(AppTheme.text)
                .multilineTextAlignment(.trailing)
        }
    }

    private func receptionLabel(_ analysis: HoraryAnalysis) -> String {
        if analysis.receptionFromQuerent.isPresent, analysis.receptionFromTarget.isPresent {
            return localized("ask.mutual-reception", language: language)
        }
        if analysis.receptionFromQuerent.isPresent || analysis.receptionFromTarget.isPresent {
            return localized("ask.one-way-reception", language: language)
        }
        return localized("ask.no-major-reception", language: language)
    }

    private func judgmentLabel(_ verdict: HoraryJudgmentVerdict) -> String {
        switch verdict {
        case .yes: localized("common.yes", language: language)
        case .no: localized("common.no", language: language)
        case .noClearJudgment: localized("ask.no-clear-judgment", language: language)
        }
    }

    private func perfectionLabel(_ assessment: HoraryPerfectionAssessment) -> String {
        if let path = assessment.primaryPath, assessment.status == .completes {
            let distance = " · " + formatOrb(path.distanceDegrees)
            let mediator = path.mediator.map { " · " + bodyName($0, language: language) } ?? ""
            switch path.kind {
            case .direct:
                return localized("ask.perfection.direct", language: language) + distance
            case .translation:
                return localized("ask.perfection.translation", language: language) + mediator + distance
            case .collection:
                return localized("ask.perfection.collection", language: language) + mediator + distance
            }
        }
        switch assessment.status {
        case .prevented: return localized("ask.perfection.prevented", language: language)
        case .delayed: return localized("ask.perfection.delayed", language: language)
        case .none, .ambiguous: return localized("ask.perfection.none", language: language)
        case .completes: return localized("ask.perfection.direct", language: language)
        }
    }

    private func nextMoonAspect(_ analysis: HoraryAnalysis) -> String {
        guard let aspect = analysis.moon.nextAspect else {
            return localized("ask.no-next-major-aspect", language: language)
        }
        let target = CelestialBody(rawValue: aspect.secondID)
            .map { bodyName($0, language: language) } ?? aspect.secondID
        let hours = analysis.moon.hoursUntilNextAspect.map { Int($0.rounded()) }
        return "\(aspectKindName(aspect.kind, language: language)) \(target)"
            + (hours.map { LocalizedFormatters.hoursDuration($0, language: language) } ?? "")
    }

    private func componentLabel(_ id: String) -> String {
        switch id {
        case "significator-relationship": localized("ask.fact.significator-relationship", language: language)
        case "reception": localized("ask.reception", language: language)
        case "moon", "moon-condition": localized("ask.fact.moon-condition", language: language)
        case "strength": localized("ask.fact.planet-strength", language: language)
        case "obstruction": localized("ask.fact.obstructions", language: language)
        case "target-strength": localized("ask.fact.target-ruler-strength", language: language)
        case "ascendant-strength": localized("ask.fact.ascendant-ruler", language: language)
        case "benefic-support": localized("ask.fact.benefic-support", language: language)
        case "applying-connection": localized("ask.fact.applying-connection", language: language)
        case "risk": localized("ask.fact.risk", language: language)
        default: id
        }
    }
}

struct AskHistoryView: View {
    @Binding var entries: [AskHistoryEntry]
    let language: AppLanguage
    let onOpen: (AskHistoryEntry) -> Void
    let onDelete: (AskHistoryEntry) -> Void
    @State private var pendingDelete: AskHistoryEntry?

    var body: some View {
        ZStack {
            ScreenBackground()
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ScreenTitle(
                        eyebrow: localized("ask.ask-history", language: language),
                        title: localized("ask.history", language: language),
                        subtitle: localized("ask.local-results-only", language: language)
                    )
                    if entries.isEmpty {
                        Text(localized("ask.no-questions-yet", language: language))
                            .font(.footnote)
                            .foregroundStyle(AppTheme.muted)
                            .cardSurface()
                    } else {
                        ForEach(entries) { entry in
                            HStack(spacing: 8) {
                                if entry.session != nil {
                                    Button {
                                        onOpen(entry)
                                    } label: {
                                        historySummary(entry, showsDisclosure: true)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("ask-history-entry-\(entry.id)")
                                } else {
                                    historySummary(entry, showsDisclosure: false)
                                }

                                Button(role: .destructive) {
                                    pendingDelete = entry
                                } label: {
                                    Image(systemName: "trash")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(AppTheme.coral)
                                .accessibilityLabel(localized("profile.delete", language: language))
                            }
                            .padding(13)
                            .cardSurface()
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 18)
                .padding(.bottom, 30)
            }
        }
        .toolbar(.visible, for: .navigationBar)
        .navigationTitle(localized("ask.history", language: language))
        .navigationBarTitleDisplayMode(.inline)
        .alert(
            localized("ask.delete-history-title", language: language),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            presenting: pendingDelete
        ) { entry in
            Button(localized("profile.delete", language: language), role: .destructive) {
                onDelete(entry)
                entries.removeAll { $0.id == entry.id }
                pendingDelete = nil
            }
            Button(localized("location.cancel", language: language), role: .cancel) {
                pendingDelete = nil
            }
        } message: { _ in
            Text(localized("ask.delete-history-message", language: language))
        }
    }

    private func historySummary(_ entry: AskHistoryEntry, showsDisclosure: Bool) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                Text(entry.question)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppTheme.text)
                Text(entry.answerTitle)
                    .font(.subheadline)
                    .foregroundStyle(AppTheme.muted)
                Text(shortDate(entry.createdAt))
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted.opacity(0.8))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .contentShape(Rectangle())
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
