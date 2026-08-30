import SwiftUI

struct InsightVisualView: View {
    let visual: InsightVisual
    let facts: [InsightFact]
    let text: CardTextModel?
    let language: AppLanguage
    @State var showAllAreas = false
    @State var showAllActiveTransits = false
    @State var transitFilter: String? = nil
    @State var selectedCycleIndex = 0
    @State var transitDetailDrawer: TransitDetailDrawer?
    @State var selectedSynastryPerspective = 0
    @State var synastryFactDrawer: InsightFact?

    var body: some View {
        Group {
            if facts.isEmpty {
                emptyState
            } else {
                switch visual {
            case .natalCore: orbitCircle
            case .rankedThemes: rankedThemes
            case let .strengthOrbit(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .blindSpot: factGrid(columns: 2)
            case .growthPath: pathFlow(title: localized("insight.shared.growth-path", language: language))
            case let .skyOverview(phase, activity, cycles): skyOverview(phase: phase, activity: activity, cycles: cycles)
            case .themeCards: themeCards
            case .needsCard: needsCard
            case .eventTimeline: eventList
            case .dateEvents: dateEventList
            case let .structureMap(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .domainBars(values): domainBars(values)
            case .observation: factRows
            case .evolution: evolution
            case .planetTable: planetTable
            case let .activityGauge(value, supportive, adjustment):
                activityGauge(value: value, supportive: supportive, adjustment: adjustment)
            case let .transitOverview(intensity, rhythm):
                transitOverview(intensity: intensity, rhythm: rhythm)
            case .gantt: gantt
            case let .transitTimeline(entries, calendar, anchorDate, initialRangeDays, timeZoneIdentifier):
                TransitTimelineView(
                    entries: entries,
                    calendarFacts: calendar,
                    anchorDate: anchorDate,
                    initialRangeDays: initialRangeDays,
                    timeZoneIdentifier: timeZoneIdentifier,
                    language: language
                )
            case let .balanceRing(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case let .houseRadar(values): houseRadar(values)
            case .actionGuidance: factRows
            case .arcTimeline: factRows
            case .doubleRing: placementRows
            case let .calendar(values): calendar(values)
            case let .progressedStage(phase, moonProgress, sunProgress):
                progressedStage(phase: phase, moonProgress: moonProgress, sunProgress: sunProgress)
            case let .progressedThemes(supportive, challenging, neutral):
                ringMetric(supportive: supportive, challenging: challenging, neutral: neutral)
            case .turningTimeline: factRows
            case .comparison: factRows
            case let .signatureTrio(ruler, dominant, orientation):
                metricTrio(ruler: ruler, dominant: dominant, orientation: orientation)
            case .placementList: placementRows
            case .aspectList: aspectRows
            case let .storyWeave(expanding, structuring, result): storyWeave(expanding: expanding, structuring: structuring, result: result)
            case let .cycleTabs(long, current, daily): cycleTabs(long: long, current: current, daily: daily)
            case let .transitPlanetPaths(rows): transitPlanetPaths(rows)
            case let .transitLifeAreas(rows): transitLifeAreas(rows)
            case let .transitActiveRows(rows): transitActiveRows(rows)
            case .positionRows: positionRows
            case .areaRows: areaRows
            case let .phaseDial(phase, illumination): phaseDial(phase: phase, illumination: illumination)
            case .motionList: positionRows
            case .elementRows: elementRows
            case let .stageFlow(old, transition, emerging):
                stageFlow(old: old, transition: transition, emerging: emerging)
            case let .moonProgress(progress): moonProgressRing(progress: progress)
            case let .identityCompare(natal, progressed):
                compareStrip(natal: natal, progressed: progressed)
            case .turningRows: factRows
            case .yearOrbit: yearOrbit
            case .anchorGrid: factGrid(columns: 2)
            case let .dualInsight(opening, demand, openingLabel, demandLabel): dualInsight(opening: opening, demand: demand, openingLabel: openingLabel, demandLabel: demandLabel)
            case let .edgeDual(opening, demand): edgeDual(opening: opening, demand: demand)
            case .quarterTabs: quarterTabs
            case .overlayCompare: compareStrip(natal: localized("insight.secondary.natal", language: language), progressed: localized("insight.shared.this-year", language: language))
            case let .natalOverlay(firstLabel, firstValue, secondLabel, secondValue):
                natalOverlay(firstLabel: firstLabel, firstValue: firstValue, secondLabel: secondLabel, secondValue: secondValue)
            case let .bondOrbit(presentation): bondOrbit(presentation)
            case let .perspectiveTabs(presentation): perspectiveTabs(presentation)
            case .connectionGrid: connectionGrid
            case .pathFlow: pathFlow(title: localized("insight.shared.how-it-flows", language: language))
            case let .synastryConnectionGrid(kind): synastryConnectionGrid(kind)
            case .synastryPathFlow: synastryPathFlow
            case .synastryChemistry: synastryChemistry
            case let .synastryHouseOverlayRows(pair): synastryHouseOverlayRows(pair)
            case let .synastryInterAspectRows(pair): synastryInterAspectRows(pair)
                }
            }
        }
        .sheet(item: $transitDetailDrawer) { drawer in
            transitDrawer(drawer)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(AppTheme.panel)
        }
        .sheet(item: $synastryFactDrawer) { fact in
            SynastryFactDetailSheet(fact: fact, interpretation: fact.note ?? text?.body, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.panel)
        }
    }


    var emptyState: some View {
        Label(
            localized("insight.shared.not-enough-calculated-facts-for-this-card", language: language),
            systemImage: "circle.dashed"
        )
        .font(AppTypography.supporting.weight(.medium))
        .foregroundStyle(AppTheme.muted)
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(12)
        .background(AppTheme.background.opacity(0.35), in: RoundedRectangle(cornerRadius: 14))
    }

    func factGrid(columns: Int) -> some View {
        let grid = Array(repeating: GridItem(.flexible(), spacing: 10), count: max(1, columns))
        return LazyVGrid(columns: grid, spacing: 10) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 5) {
                        if let symbol = fact.symbol {
                            Text(symbol).font(AppTypography.scaled(12, weight: .bold)).foregroundStyle(AppTheme.tone(fact.emphasis))
                        }
                        Text(fact.label)
                            .font(AppTypography.compactLabel)
                            .foregroundStyle(AppTheme.muted)
                    }
                    Text(fact.value)
                        .font(AppTypography.factValue)
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let progress = fact.progress {
                        ProgressView(value: max(0, min(1, progress)))
                            .tint(AppTheme.tone(fact.emphasis))
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    var factRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(alignment: .top, spacing: 10) {
                    if let symbol = fact.symbol {
                        Text(symbol)
                            .font(AppTypography.scaled(13, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 26, height: 26)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(AppTypography.compactLabel).foregroundStyle(AppTheme.muted)
                        Text(fact.value).font(AppTypography.factValue).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    if let progress = fact.progress {
                        Text("\(Int(progress * 100))%")
                            .font(AppTypography.compactLabel.monospacedDigit())
                            .foregroundStyle(AppTheme.muted)
                    }
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func ringMetric(supportive: Int, challenging: Int, neutral: Int) -> some View {
        let total = max(1, supportive + challenging + neutral)
        let support = Double(supportive) / Double(total)
        let challenge = Double(challenging) / Double(total)
        return HStack(spacing: 16) {
            ZStack {
                Circle().stroke(AppTheme.panelRaised, lineWidth: 12)
                Circle().trim(from: 0, to: support)
                    .stroke(AppTheme.mint, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Circle().trim(from: support, to: support + challenge)
                    .stroke(AppTheme.coral, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(total)").font(AppTypography.scaled(20, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("insight.shared.contacts", language: language)).font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 92, height: 92)
            VStack(alignment: .leading, spacing: 8) {
                metric("\(supportive)", localized("insight.current-sky.support", language: language), .supportive)
                metric("\(challenging)", localized("insight.current-sky.pressure", language: language), .challenging)
                metric("\(neutral)", localized("insight.shared.neutral", language: language), .transition)
            }
            .frame(maxWidth: .infinity)
        }
    }

    func metric(_ value: String, _ title: String, _ tone: InsightTone) -> some View {
        HStack {
            Text(value).font(AppTypography.scaled(15, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.tone(tone))
            Text(title).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
            Spacer()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(AppTheme.tone(tone).opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
    }

    func trioCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(AppTypography.metadata)
                .foregroundStyle(AppTheme.muted)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value).font(AppTypography.factValue).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // prototype .position-row: glyph + title + desc + state chip

    var positionRows: some View {
        VStack(spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "✦")
                        .font(AppTypography.scaled(15, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(width: 34, height: 34)
                        .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(AppTypography.scaled(12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(fact.value).font(AppTypography.compactLabel).foregroundStyle(AppTheme.text)
                    }
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    var aspectRows: some View {
        let hasCategories = facts.contains { $0.category != nil }
        let filtered = transitFilter == nil ? facts : facts.filter { $0.category == transitFilter }
        return VStack(spacing: 9) {
            if hasCategories {
                HStack(spacing: 6) {
                    aspectFilterChip(nil, localized("insight.shared.all", language: language))
                    aspectFilterChip("long-term", localized("insight.shared.long-term", language: language))
                    aspectFilterChip("current", localized("insight.shared.current", language: language))
                    aspectFilterChip("daily", localized("insight.shared.daily", language: language))
                    Spacer()
                }
            }
            ForEach(Array(filtered.prefix(6).enumerated()), id: \.offset) { _, fact in
                HStack(spacing: 10) {
                    Text(fact.symbol ?? "⌗")
                        .font(AppTypography.scaled(13, weight: .semibold))
                        .foregroundStyle(AppTheme.tone(fact.emphasis))
                        .frame(width: 26, height: 26)
                        .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label).font(AppTypography.scaled(12.5, weight: .semibold)).foregroundStyle(AppTheme.text)
                        if let note = fact.note {
                            Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
                        }
                    }
                    Spacer()
                    Text(technicalTag(fact.emphasis)).font(AppTypography.compactLabel)
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.trailing)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(AppTheme.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
                }
                .padding(11)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    // MARK: - Area / element rows (prototype .area-row with % bar)

    var areaRows: some View {
        let shown = showAllAreas ? Array(facts.prefix(12)) : Array(facts.prefix(4))
        return VStack(spacing: 11) {
            ForEach(Array(shown.enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Text(fact.label).font(AppTypography.scaled(12, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        Text(fact.value).font(AppTypography.scaled(10, weight: .semibold)).foregroundStyle(AppTheme.muted)
                    }
                    if let progress = fact.progress {
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.line.opacity(0.6))
                                Capsule()
                                    .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.85), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * max(0.02, min(1, progress)))
                            }
                        }
                        .frame(height: 6)
                    }
                }
            }
            if facts.count > 4 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllAreas.toggle()
                    }
                } label: {
                    Text(showAllAreas
                         ? localized("insight.shared.show-fewer-areas", language: language)
                         : LocalizedFormatters.viewAllAreas(facts.count, language: language))
                        .font(AppTypography.scaled(11, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
            }
            Text(localized("insight.shared.activity-reflects-the-current-signals-not-a-fortune-score", language: language))
                .font(AppTypography.supporting)
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 2)
        }
    }

    var elementRows: some View {
        VStack(spacing: 11) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                HStack(spacing: 9) {
                    Text(["🜁", "🜃", "🜂", "🜄"][index])
                        .font(AppTypography.scaled(13, weight: .bold))
                        .foregroundStyle([AppTheme.blue, AppTheme.mint, AppTheme.coral, AppTheme.violet][index])
                        .frame(width: 16)
                    Text(fact.label).font(AppTypography.scaled(12, weight: .semibold)).foregroundStyle(AppTheme.text).frame(width: 44, alignment: .leading)
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6))
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.85), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0.02, min(1, fact.progress ?? 0)))
                        }
                    }
                    .frame(height: 6)
                    Text(fact.value).font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted).frame(width: 44, alignment: .trailing)
                }
            }
            if facts.count > 4 {
                HStack(spacing: 6) {
                    ForEach(Array(facts.dropFirst(4).prefix(3).enumerated()), id: \.offset) { _, fact in
                        Text("\(fact.label)：\(fact.value)")
                            .font(AppTypography.metadata.weight(.medium))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.violet.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.violet.opacity(0.25), lineWidth: 1))
                            .foregroundStyle(AppTheme.text.opacity(0.9))
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Moon dial (prototype .progress-moon)

    func dualInsight(opening: String, demand: String, openingLabel: String, demandLabel: String) -> some View {
        HStack(spacing: 9) {
            VStack(spacing: 5) {
                Text(openingLabel)
                    .font(AppTypography.compactLabel)
                    .foregroundStyle(AppTheme.mint)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(opening).font(AppTypography.label).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.mint.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
            VStack(spacing: 5) {
                Text(demandLabel)
                    .font(AppTypography.compactLabel)
                    .foregroundStyle(AppTheme.coral)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(demand).font(AppTypography.label).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(11)
            .background(AppTheme.coral.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    var connectionGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 4) {
                    Text(fact.label).font(AppTypography.compactLabel).foregroundStyle(AppTheme.muted)
                    Text(fact.value).font(AppTypography.factValue).foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if let note = fact.note {
                        Text(note).font(AppTypography.supporting).foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(11)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    func pathFlow(title: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(AppTypography.supporting.weight(.semibold)).foregroundStyle(AppTheme.muted)
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { index, fact in
                    VStack(spacing: 4) {
                        Text(fact.symbol ?? "\(index + 1)")
                            .font(AppTypography.scaled(13, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.12), in: Circle())
                        Text(fact.label).font(AppTypography.metadata.weight(.medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    if index < min(3, facts.count) - 1 {
                        Image(systemName: "arrow.right").font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
                    }
                }
            }
        }
        .padding(12)
        .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
    }

    func technicalTag(_ tone: InsightTone) -> String {
        switch tone {
        case .supportive: localized("insight.shared.supportive-pattern", language: language)
        case .challenging: localized("insight.shared.core-tension", language: language)
        case .transition, .neutral: localized("insight.shared.relational-pattern", language: language)
        }
    }
}
