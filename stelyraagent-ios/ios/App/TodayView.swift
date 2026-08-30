import AstroCore
import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var model: AppModel
    @Binding var selectedTab: RootTab
    @State private var showReports = false
    @State private var selectedDetail: TodayDetail?

    var body: some View {
        NavigationStack {
            ZStack {
                ScreenBackground()
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        topBar
                        dateLine

                        if model.currentSky == nil {
                            loadingCard
                        } else {
                            if let message = model.todayContentErrorMessage {
                                Label(message, systemImage: "doc.text.magnifyingglass")
                                    .font(AppTypography.scaled(12))
                                    .foregroundStyle(AppTheme.muted)
                                    .padding(14)
                                    .cardSurface()
                                    .padding(.bottom, 12)
                            }
                            transitsSection
                            moonSection
                            timelineSection
                            upcomingSection
                            retrogradesSection
                        }

                        if let message = model.errorMessage {
                            Label(message, systemImage: "exclamationmark.triangle")
                                .font(AppTypography.scaled(12))
                                .foregroundStyle(AppTheme.coral)
                                .padding(14)
                                .cardSurface()
                        }
                    }
                    .padding(.horizontal, 17)
                    .padding(.top, 8)
                    .padding(.bottom, 30)
                }
                .refreshable {
                    await model.refresh()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(isPresented: $showReports) {
                ReportsView(selectedTab: $selectedTab)
            }
            .onChange(of: selectedTab) { _, newTab in
                if newTab != .today {
                    showReports = false
                }
            }
            .task {
                await model.refreshTodayEventsIfNeeded()
            }
            .sheet(item: $selectedDetail) { detail in
                todayDetailSheet(detail)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(34)
            }
        }
    }

    // MARK: - Top bar / date line (prototype .topbar / .date-line)

    private var topBar: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(localized("brand.stelyraagent", language: model.language))
                    .font(AppTypography.scaled(10, weight: .bold))
                    .tracking(1.8)
                    .foregroundStyle(AppTheme.muted)
                Text(localized("navigation.today", language: model.language))
                    .font(AppTypography.scaled(30, weight: .bold))
                    .kerning(-1.2)
                    .foregroundStyle(AppTheme.text)
            }
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
        }
        .padding(.top, 6)
    }

    private var dateLine: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(formattedDate(Date()))
                .lineLimit(1)
            HStack(alignment: .top, spacing: 6) {
                HStack(alignment: .top, spacing: 3) {
                    Text(model.profile.name)
                        .fixedSize(horizontal: false, vertical: true)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .padding(.top, 2)
                }
                Text("·")
                Text(model.profile.placeName)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .font(AppTypography.scaled(13))
        .foregroundStyle(AppTheme.muted)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 2)
        .padding(.bottom, 17)
    }

    // MARK: - Your Transits (prototype chapter hero + transit stack)

    private var transitsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(
                localized("today.current-chapter", language: model.language),
                link: localized("today.view-all", language: model.language),
                topPadding: 0
            ) {
                selectedTab = .charts
                model.selectChart(.transit)
            }
            chapterHero
            VStack(spacing: 12) {
                if let signal = activeTodaySignal {
                    transitRow(signal, kind: .active)
                }
                if let signal = comingNextSignal {
                    transitRow(signal, kind: .coming)
                } else {
                    comingNextEmptyState
                }
            }
            .padding(.top, 11)
        }
    }

    private var activeTodaySignal: DailySignal? {
        let calendar = Calendar.current
        return model.todaySignals
            .filter { signal in
                guard signal.source == .transit else { return false }
                guard let date = signal.eventDate else { return signal.category == .activeNow }
                return calendar.isDateInToday(date) || signal.category == .activeNow
            }
            .sorted { ($0.eventDate ?? .distantPast) < ($1.eventDate ?? .distantPast) }
            .first
    }

    private var comingNextSignal: DailySignal? {
        let now = Date()
        return model.todaySignals
            .filter { signal in
                guard signal.source == .transit else { return false }
                guard signal.id != activeTodaySignal?.id, let date = signal.eventDate else { return false }
                return date > now
            }
            .sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
            .first
    }

    private var comingNextEmptyState: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "calendar.badge.checkmark")
                .font(AppTypography.scaled(18, weight: .semibold))
                .foregroundStyle(AppTheme.mint)
                .frame(width: 38, height: 38)
                .background(AppTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 7) {
                InsightBadge(
                    text: localized("today.coming-next", language: model.language),
                    tone: .good
                )
                Text(localized("today.no-upcoming-personal-transit", language: model.language))
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .cardSurface()
    }

    private var chapterHero: some View {
        let window = longChapterWindow
        let house = window.map { natalHouse(for: $0.firstLongitude) } ?? 0
        let area = ConsumerCopy.lifeArea(house, language: model.language)
        let copy = model.todayCardText("current-chapter")
        let title = copy?.headline
            ?? localized("today.content-unavailable", language: model.language)
        let summaryText = copy?.body
            ?? localized("today.the-required-reviewed-content-is-missing", language: model.language)
        return VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 10) {
                    chapterTitle(title)
                    Spacer(minLength: 0)
                    chapterBadge
                }
                VStack(alignment: .leading, spacing: 8) {
                    chapterBadge
                    chapterTitle(title)
                }
            }
            Text(summaryText)
                .font(AppTypography.scaled(12))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.muted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 8)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    TagChip(text: area, tone: .neutral)
                        .fixedSize(horizontal: true, vertical: false)
                    if let window {
                        TagChip(text: chapterTimingText(window, now: Date()), tone: .neutral)
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                VStack(alignment: .leading, spacing: 6) {
                    TagChip(text: area, tone: .neutral)
                    if let window {
                        TagChip(text: chapterTimingText(window, now: Date()), tone: .neutral)
                    }
                }
            }
            .padding(.top, 10)
            chapterLine(window)
        }
        .padding(16)
        .cardSurface()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("today-current-chapter-card")
    }

    private func chapterTitle(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.scaled(22, weight: .bold))
            .kerning(-0.5)
            .foregroundStyle(AppTheme.text)
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
    }

    private var chapterBadge: some View {
        InsightBadge(
            text: localized("insight.shared.long-term", language: model.language),
            tone: .purple
        )
        .padding(.top, 2)
    }

    /// The longest active slow-planet transit window, used as the current chapter.
    private var longChapterWindow: ChartEventData.TransitWindow? {
        let windows = model.chartEvents.transitWindows
        guard !windows.isEmpty else { return nil }
        let slow: Set<CelestialBody> = [.saturn, .uranus, .neptune, .pluto]
        let now = Date()
        let active = windows.filter { $0.start <= now && $0.end >= now }
        guard !active.isEmpty else { return nil }
        let slowWindows = active.filter { slow.contains($0.first) }
        let pool = slowWindows.isEmpty ? active : slowWindows
        return pool.max {
            $0.end.timeIntervalSince($0.start) < $1.end.timeIntervalSince($1.start)
        }
    }

    private func chapterTimingText(_ window: ChartEventData.TransitWindow, now: Date) -> String {
        if let occurrence = window.upcomingExactOccurrence(after: now) {
            let date = chapterDate(occurrence.date)
            return occurrence.isReturn
                ? LocalizedFormatters.exactAgain(date, language: model.language)
                : LocalizedFormatters.exact(date, language: model.language)
        }
        return localizedTemplate(
            "dynamic.7f1e2d8a22",
            substitutions: ["value1": chapterDate(window.end)],
            language: model.language
        )
    }

    private func chapterLine(_ window: ChartEventData.TransitWindow?) -> some View {
        let now = Date()
        let start = window?.start ?? now.addingTimeInterval(-7 * 86_400)
        let end = window?.end ?? now.addingTimeInterval(7 * 86_400)
        let total = max(1, end.timeIntervalSince(start))
        let progress = min(1, max(0, now.timeIntervalSince(start) / total))
        return HStack(spacing: 8) {
            Text(chapterDate(start))
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                        .frame(width: proxy.size.width * progress, height: 6)
                    Circle()
                        .fill(Color.white)
                        .overlay(Circle().stroke(AppTheme.violet, lineWidth: 3))
                        .frame(width: 10, height: 10)
                        .offset(x: proxy.size.width * progress - 5)
                }
            }
            .frame(height: 10)
            Text(chapterDate(end))
        }
        .font(AppTypography.scaled(9, weight: .medium))
        .foregroundStyle(AppTheme.muted)
        .padding(.top, 14)
    }

    private enum TransitRowKind {
        case active
        case coming

        var badgeTone: InsightBadgeTone { self == .active ? .warm : .good }
    }

    private enum TodayDetail: Identifiable {
        case transit(DailySignal, TransitRowKind)
        case moon

        var id: String {
            switch self {
            case let .transit(signal, kind): "transit-\(signal.id)-\(kind == .active ? "active" : "coming")"
            case .moon: "moon"
            }
        }
    }

    private func transitRow(_ signal: DailySignal, kind: TransitRowKind) -> some View {
        let badge = localized(
            kind == .active ? "today.active-today" : "today.coming-next",
            language: model.language
        )
        return Button {
            selectedDetail = .transit(signal, kind)
        } label: {
            HStack(alignment: .top, spacing: 12) {
            Text(signal.source.symbol)
                .font(AppTypography.scaled(18, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 38, height: 38)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.violet.opacity(0.2), lineWidth: 1))
            VStack(alignment: .leading, spacing: 0) {
                InsightBadge(
                    text: badge,
                    tone: kind.badgeTone
                )
                Text(signal.title)
                    .font(AppTypography.scaled(14, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .padding(.top, 7)
                Text(signal.subtitle)
                    .font(AppTypography.supporting)
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 3)
                let metadata = transitMetadata(signal, kind: kind)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 6) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { _, text in
                            TagChip(text: text, tone: .neutral)
                        }
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(metadata.enumerated()), id: \.offset) { _, text in
                            TagChip(text: text, tone: .neutral)
                        }
                    }
                }
                .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("›")
                .font(AppTypography.scaled(20))
                .foregroundStyle(AppTheme.muted)
                .padding(.top, 6)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .cardSurface()
    }

    private func transitMetadata(_ signal: DailySignal, kind: TransitRowKind) -> [String] {
        var labels: [String] = []
        if kind == .active {
            labels.append(
                signal.eventDate.map {
                    "\(localized("today.peaks", language: model.language)) \(timeOf($0))"
                } ?? localized("today.ongoing", language: model.language)
            )
        } else if let eventDate = signal.eventDate {
            labels.append(
                localizedTemplate(
                    "today.starts-value",
                    substitutions: ["value": nearDate(eventDate)],
                    language: model.language
                )
            )
            if let peakDate = signal.peakDate,
               abs(peakDate.timeIntervalSince(eventDate)) >= 60 * 60
            {
                labels.append(
                    localizedTemplate(
                        "today.strongest-value",
                        substitutions: ["value": shortDate(peakDate)],
                        language: model.language
                    )
                )
            }
        }
        if labels.count < 2, let context = model.todayTransitContext(for: signal) {
            labels.append("\(shortDomainTitle(context.domain)) · \(context.theme)")
        }
        return Array(labels.prefix(2))
    }

    private func nearDate(_ date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        let days = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: Date()),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        guard (0 ... 6).contains(days) else { return shortDate(date) }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEE")
        return formatter.string(from: date)
    }

    private func shortDomainTitle(_ domain: TodayLifeDomain) -> String {
        switch domain {
        case .love:
            localized("today.domain-chip.love", language: model.language)
        case .work:
            localized("today.domain-chip.work", language: model.language)
        case .money:
            localized("today.domain-chip.money", language: model.language)
        case .energy:
            localized("today.domain-chip.energy", language: model.language)
        }
    }

    // MARK: - Moon Today (prototype .moon-card)

    private var moonSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("today.moon-today", language: model.language), sub: localized("today.changes-quickly", language: model.language))
            if let moon = model.currentSky?.point(.moon) {
                let copy = model.todayCardText("moon-today")
                let house = model.natal?.house(containing: moon.longitudeDegrees) ?? 0
                Button {
                    selectedDetail = .moon
                } label: {
                    HStack(spacing: 15) {
                        LunarPhaseDisk(phaseAngle: moonPhaseAngle, size: 86)
                        VStack(alignment: .leading, spacing: 0) {
                        Text("\(Int((illumination * 100).rounded()))% \(localized("insight.current-sky.illuminated", language: model.language))")
                            .font(AppTypography.scaled(10, weight: .semibold))
                            .foregroundStyle(AppTheme.violet)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(AppTheme.violet.opacity(0.12), in: Capsule())
                            .overlay(Capsule().stroke(AppTheme.violet.opacity(0.22), lineWidth: 1))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text("\(localized("today.moon-in", language: model.language)) \(Zodiac.name(index: moon.signIndex, language: model.language))")
                            .font(AppTypography.scaled(17, weight: .bold))
                            .foregroundStyle(AppTheme.text)
                            .padding(.top, 7)
                        Text("\(moonPhaseName) · \(localized("today.moving-through-your", language: model.language)) \(ConsumerCopy.lifeArea(house, language: model.language))")
                            .font(AppTypography.supporting)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                        if let interpretation = copy?.body {
                            Text(interpretation)
                                .font(AppTypography.supporting)
                                .lineSpacing(2)
                                .foregroundStyle(AppTheme.text.opacity(0.86))
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 6)
                        }
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                                Capsule()
                                    .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: proxy.size.width * CGFloat(moon.degreeInSign / 30), height: 6)
                            }
                        }
                        .frame(height: 6)
                        .padding(.top, 9)
                        HStack {
                            Text(Zodiac.position(moon, language: model.language))
                            Spacer()
                            Text("\(Zodiac.name(index: (moon.signIndex + 1) % 12, language: model.language)) · \(nextSignIn(moon))")
                        }
                        .font(AppTypography.scaled(9, weight: .medium))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.top, 6)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(17)
                .cardSurface()
            }
        }
    }

    private var moonPhaseAngle: Double {
        guard let sky = model.currentSky,
              let sun = sky.point(.sun), let moon = sky.point(.moon)
        else { return 0 }
        return LunarPhaseGeometry.elongation(
            sunLongitude: sun.longitudeDegrees,
            moonLongitude: moon.longitudeDegrees
        )
    }

    private var illumination: Double {
        LunarPhaseGeometry.illuminationFraction(elongation: moonPhaseAngle)
    }

    private var moonPhaseName: String {
        switch moonPhaseAngle {
        case 0 ..< 22.5, 337.5 ..< 360: localized("insight.current-sky.new-moon", language: model.language)
        case 22.5 ..< 67.5: localized("today.waxing-crescent", language: model.language)
        case 67.5 ..< 112.5: localized("today.first-quarter", language: model.language)
        case 112.5 ..< 157.5: localized("today.waxing-gibbous", language: model.language)
        case 157.5 ..< 202.5: localized("insight.current-sky.full-moon", language: model.language)
        case 202.5 ..< 247.5: localized("today.waning-gibbous", language: model.language)
        case 247.5 ..< 292.5: localized("today.last-quarter", language: model.language)
        default: localized("today.waning-crescent", language: model.language)
        }
    }

    private func nextSignIn(_ moon: ChartPoint) -> String {
        guard let ingress = model.chartEvents.skyIngresses
            .filter({ $0.body == .moon && $0.date > Date() })
            .min(by: { $0.date < $1.date })
        else { return "—" }
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: ingress.date, relativeTo: Date())
    }

    // MARK: - Today Timeline (prototype .time-event + now-line)

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("today.today-timeline", language: model.language), sub: localized("today.local-time", language: model.language))
            let events = timelineEvents
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(events.enumerated()), id: \.offset) { index, signal in
                    timeEvent(signal, index: index, total: events.count)
                }
                if events.isEmpty {
                    if model.todayEventsDayKey == model.currentLocalDayKey {
                        Text(localized("today.no-exact-events-today-a-quieter-day", language: model.language))
                            .font(AppTypography.scaled(12))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.vertical, 10)
                    } else {
                        HStack(spacing: 8) {
                            ProgressView().controlSize(.small).tint(AppTheme.muted)
                            Text(localized("today.updating-events", language: model.language))
                                .font(AppTypography.scaled(12))
                                .foregroundStyle(AppTheme.muted)
                        }
                        .padding(.vertical, 10)
                    }
                }
            }
            .padding(16)
            .cardSurface()
        }
    }

    private var timelineEvents: [DailySignal] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        let today = model.todaySignals
            .filter { signal in
                guard signal.source == .sky, let date = signal.eventDate else { return false }
                return calendar.isDate(date, inSameDayAs: Date())
            }
            .sorted { ($0.eventDate ?? .distantFuture) < ($1.eventDate ?? .distantFuture) }
        let major = today.filter { $0.strength >= 90 }
        return Array((major.isEmpty ? today : major).prefix(3))
    }

    private func timeEvent(_ signal: DailySignal, index: Int, total: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(timeOf(signal.eventDate))
                .font(AppTypography.scaled(10.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(AppTheme.muted)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .frame(minWidth: 64, alignment: .leading)
                .layoutPriority(1)
            VStack(spacing: 0) {
                let isPast = signal.eventDate.map { $0 < Date() } ?? false
                Circle()
                    .fill(isPast ? AppTheme.violet : Color.clear)
                    .overlay(Circle().stroke(AppTheme.violet, lineWidth: isPast ? 0 : 1.6))
                    .frame(width: 8, height: 8)
                if index < total - 1 {
                    Rectangle().fill(AppTheme.line).frame(width: 1.5, height: 26)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(AppTypography.scaled(13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.bottom, 6)
    }

    // MARK: - Upcoming Sky Events (prototype .event-card)

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(localized("today.upcoming-sky-events", language: model.language), sub: localized("today.next-7-days", language: model.language))
            VStack(spacing: 12) {
                if let interpretation = model.todayCardText("upcoming-sky-events")?.body {
                    Text(interpretation)
                        .font(AppTypography.supporting)
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 2)
                }
                ForEach(Array(upcomingSkyRows.prefix(3).enumerated()), id: \.element.id) { _, event in
                    Button {
                        selectedTab = .charts
                        model.selectChart(.currentSky)
                        model.setTargetDate(event.date, for: .currentSky)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(spacing: 0) {
                                Text(monthAbbreviation(event.date)).font(AppTypography.scaled(9, weight: .semibold)).foregroundStyle(AppTheme.muted)
                                Text(dayNumber(event.date)).font(AppTypography.scaled(16, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                            }
                            .frame(width: 40)
                            Text(event.title)
                                .font(AppTypography.scaled(12.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Spacer(minLength: 4)
                            Text(event.subtitle)
                                .font(AppTypography.scaled(10))
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.75)
                                .truncationMode(.tail)
                        }
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .cardSurface()
                    }
                    .buttonStyle(.plain)
                }
                if upcomingSkyRows.isEmpty {
                    Text(localized("today.no-calculated-sky-events-in-the-next-seven-days", language: model.language))
                        .font(.footnote)
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .cardSurface()
                }
            }
            .padding(.top, 11)
        }
    }

    private var upcomingSkyRows: [(id: String, date: Date, title: String, subtitle: String)] {
        let ingressRows = model.chartEvents.skyIngresses.map { event in
            (
                id: "ingress-\(event.body.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: "\(bodyName(event.body, language: model.language)) → \(Zodiac.name(index: event.signIndex, language: model.language))",
                subtitle: localized("today.sign-change", language: model.language)
            )
        }
        let exactRows = model.chartEvents.skyExactEvents.map { event in
            (
                id: "exact-\(event.first.rawValue)-\(event.second.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: "\(bodyName(event.first, language: model.language)) · \(bodyName(event.second, language: model.language))",
                subtitle: aspectKindName(event.kind, language: model.language)
            )
        }
        let stationRows = model.chartEvents.skyStations.map { event in
            (
                id: "station-\(event.body.rawValue)-\(event.date.timeIntervalSince1970)",
                date: event.date,
                title: bodyName(event.body, language: model.language),
                subtitle: event.retrogradeAfter
                    ? localized("today.stations-retrograde", language: model.language)
                    : localized("today.stations-direct", language: model.language)
            )
        }
        let horizon = Date().addingTimeInterval(7 * 86_400)
        return (ingressRows + exactRows + stationRows)
            .filter { $0.date >= Date() && $0.date <= horizon }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Retrogrades (prototype .retro-card)

    private var retrogradesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHead(
                localized("today.retrogrades", language: model.language),
                link: localized("common.details", language: model.language)
            ) {
                selectedTab = .charts
                model.selectChart(.currentSky)
            }
            let retrogrades = model.currentSky?.points.filter(\.retrograde) ?? []
            VStack(alignment: .leading, spacing: 0) {
                if let interpretation = model.todayCardText("retrogrades")?.body {
                    Text(interpretation)
                        .font(AppTypography.supporting)
                        .lineSpacing(2)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.bottom, 10)
                }
                HStack {
                    Text(LocalizedFormatters.retrogradePlanets(retrogrades.count, language: model.language))
                        .font(AppTypography.scaled(13, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    TagChip(text: localized("today.review-window", language: model.language), tone: .neutral)
                }
                .padding(.bottom, 6)
                ForEach(retrogrades, id: \.body) { point in
                    HStack(spacing: 10) {
                        Text(point.body.symbol)
                            .font(AppTypography.scaled(15, weight: .semibold))
                            .foregroundStyle(AppTheme.coral)
                            .frame(width: 30, height: 30)
                            .background(AppTheme.coral.opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(bodyName(point.body, language: model.language))
                                .font(AppTypography.scaled(12.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(Zodiac.name(index: point.signIndex, language: model.language)) · \(localized("today.reviewing", language: model.language))")
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        TagChip(text: stationDeadline(for: point.body), tone: .neutral)
                    }
                    .padding(.vertical, 8)
                    Divider().overlay(AppTheme.line.opacity(0.6))
                }
                if retrogrades.isEmpty {
                    Text(localized("today.no-planets-are-in-review-right-now", language: model.language))
                        .font(AppTypography.scaled(12))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 8)
                }
            }
            .padding(16)
            .cardSurface()
        }
    }

    private func stationDeadline(for body: CelestialBody) -> String {
        guard let station = model.chartEvents.skyStations.first(where: {
            $0.body == body && !$0.retrogradeAfter
        }) else {
            return localized("today.reviewing.status", language: model.language)
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        let start = calendar.startOfDay(for: Date())
        let end = calendar.startOfDay(for: station.date)
        let days = max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
        if days == 0 {
            return localized("today.retrograde-direct-today", language: model.language)
        }
        if days <= 7 {
            return localizedTemplate(
                "today.retrograde-direct-in-days",
                substitutions: ["days": String(days)],
                language: model.language
            )
        }
        return localizedTemplate(
            "today.retrograde-ends",
            substitutions: ["date": shortDate(station.date)],
            language: model.language
        )
    }

    // MARK: - Today detail drawers

    private struct TodayDetailFact: Identifiable {
        let label: String
        let value: String
        var id: String { label }
    }

    private struct TodayDetailSection: Identifiable {
        let title: String
        let body: String
        var id: String { title }
    }

    @ViewBuilder
    private func todayDetailSheet(_ detail: TodayDetail) -> some View {
        switch detail {
        case let .transit(signal, kind):
            transitDetailSheet(signal, kind: kind)
        case .moon:
            moonDetailSheet
        }
    }

    private func transitDetailSheet(_ signal: DailySignal, kind: TransitRowKind) -> some View {
        let aspect = model.todayTransitAspect(for: signal)
        let window = model.todayTransitWindow(for: signal)
        var facts: [TodayDetailFact] = []
        if let aspect,
           let moving = CelestialBody(rawValue: aspect.firstID),
           let natalBody = CelestialBody(rawValue: aspect.secondID)
        {
            facts.append(
                TodayDetailFact(
                    label: localized("today.transit", language: model.language),
                    value: "\(bodyName(moving, language: model.language)) \(aspectKindName(aspect.kind, language: model.language)) \(localized("insight.secondary.natal", language: model.language)) \(bodyName(natalBody, language: model.language))"
                )
            )
        }
        if kind == .active {
            if let peak = window?.exact ?? signal.peakDate ?? signal.eventDate {
                facts.append(TodayDetailFact(label: localized("today.peak", language: model.language), value: detailDate(peak, includesTime: true)))
            }
            if let aspect {
                facts.append(TodayDetailFact(label: localized("today.stage", language: model.language), value: transitPhaseText(aspect.phase)))
                facts.append(TodayDetailFact(label: localized("today.orb", language: model.language), value: String(format: "%.2f°", aspect.orbDegrees)))
            }
        } else {
            if let start = window?.start ?? signal.eventDate {
                facts.append(TodayDetailFact(label: localized("today.starts", language: model.language), value: detailDate(start)))
            }
            if let exact = window?.exact ?? signal.peakDate {
                facts.append(TodayDetailFact(label: localized("today.exact", language: model.language), value: detailDate(exact)))
            }
            if let end = window?.end {
                facts.append(TodayDetailFact(label: localized("today.ends", language: model.language), value: detailDate(end)))
            }
        }
        let reviewed = model.todayCardText(kind == .active ? "active-today" : "coming-next")
        var sections = [
            TodayDetailSection(
                title: localized("today.interpretation", language: model.language),
                body: signal.subtitle
            ),
        ]
        if let additional = reviewed?.secondaryBody, !additional.isEmpty, additional != signal.subtitle {
            sections.append(
                TodayDetailSection(
                    title: localized("today.additional-context", language: model.language),
                    body: additional
                )
            )
        }
        return detailSheet(
            title: signal.title,
            subtitle: localized(
                kind == .active ? "today.active-detail-summary" : "today.coming-detail-summary",
                language: model.language
            ),
            facts: facts,
            sections: sections
        )
    }

    private var moonDetailSheet: some View {
        let moon = model.currentSky?.point(.moon)
        let house = moon.map { model.natal?.house(containing: $0.longitudeDegrees) ?? 0 } ?? 0
        let copy = model.todayCardText("moon-today")
        let facts = [
            TodayDetailFact(
                label: localized("today.sign", language: model.language),
                value: moon.map { Zodiac.position($0, language: model.language) } ?? "—"
            ),
            TodayDetailFact(label: localized("today.phase", language: model.language), value: moonPhaseName),
            TodayDetailFact(label: localized("today.illumination", language: model.language), value: "\(Int((illumination * 100).rounded()))%"),
            TodayDetailFact(
                label: localized("today.personal-house", language: model.language),
                value: (1 ... 12).contains(house) ? AstroTerms.house(house, language: model.language) : "—"
            ),
        ]
        var sections: [TodayDetailSection] = []
        if let moon {
            sections.append(
                TodayDetailSection(
                    title: localized("today.public-sky", language: model.language),
                    body: "\(Zodiac.name(index: (moon.signIndex + 1) % 12, language: model.language)) · \(nextSignIn(moon))"
                )
            )
        }
        if let personal = copy?.body, !personal.isEmpty {
            sections.append(
                TodayDetailSection(
                    title: localized("today.personal-layer", language: model.language),
                    body: personal
                )
            )
        }
        return detailSheet(
            title: localized("today.moon-today", language: model.language),
            subtitle: localized("today.moon-detail-summary", language: model.language),
            facts: facts,
            sections: sections
        )
    }

    private func detailSheet(
        title: String,
        subtitle: String,
        facts: [TodayDetailFact],
        sections: [TodayDetailSection]
    ) -> some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(AppTypography.scaled(24, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                Text(subtitle)
                    .font(AppTypography.summary)
                    .foregroundStyle(AppTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 11) {
                    ForEach(facts) { fact in
                        VStack(alignment: .leading, spacing: 7) {
                            Text(fact.label)
                                .font(AppTypography.supporting)
                                .foregroundStyle(AppTheme.muted)
                            Text(fact.value)
                                .font(AppTypography.label)
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                        .padding(14)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(AppTheme.line, lineWidth: 1))
                    }
                }

                ForEach(sections) { section in
                    VStack(alignment: .leading, spacing: 7) {
                        Divider().overlay(AppTheme.line)
                        Text(section.title)
                            .font(AppTypography.label)
                            .foregroundStyle(AppTheme.text)
                            .padding(.top, 9)
                        Text(section.body)
                            .font(AppTypography.supporting)
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 8)
            .padding(.bottom, 96)
        }
        .background(AppTheme.panel)
        .safeAreaInset(edge: .bottom) {
            Button(localized("common.done", language: model.language)) {
                selectedDetail = nil
            }
            .font(AppTypography.scaled(17, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                LinearGradient(colors: [AppTheme.violet, AppTheme.blue], startPoint: .leading, endPoint: .trailing),
                in: RoundedRectangle(cornerRadius: 17)
            )
            .padding(.horizontal, 22)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
    }

    private func transitPhaseText(_ phase: AspectPhase) -> String {
        switch phase {
        case .applying: localized("insight.transit.applying", language: model.language)
        case .exact: localized("today.exact", language: model.language)
        case .separating: localized("insight.transit.separating", language: model.language)
        }
    }

    private func detailDate(_ date: Date, includesTime: Bool = false) -> String {
        let formatter = DateFormatter()
        formatter.locale = model.language.locale
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.dateStyle = .medium
        formatter.timeStyle = includesTime ? .short : .none
        return formatter.string(from: date)
    }

    // MARK: - Shared

    private var loadingCard: some View {
        HStack(spacing: 12) {
            ProgressView().tint(AppTheme.violet)
            Text(localized("today.calculating-locally", language: model.language))
                .font(AppTypography.summary)
                .foregroundStyle(AppTheme.muted)
        }
        .frame(maxWidth: .infinity, minHeight: 160)
        .cardSurface()
    }

    private func sectionHead(
        _ title: String,
        sub: String? = nil,
        link: String? = nil,
        topPadding: CGFloat = 25,
        action: (() -> Void)? = nil
    ) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title).font(AppTypography.scaled(18, weight: .bold)).kerning(-0.3).foregroundStyle(AppTheme.text)
            Spacer(minLength: 12)
            if let sub {
                Text(sub)
                    .font(AppTypography.supporting)
                    .foregroundStyle(AppTheme.muted)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            if let link {
                if let action {
                    Button(link, action: action)
                        .font(AppTypography.scaled(11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .buttonStyle(.plain)
                } else {
                    Text(link).font(AppTypography.scaled(11.5, weight: .semibold)).foregroundStyle(AppTheme.violet)
                }
            }
        }
        .padding(.top, topPadding)
        .padding(.bottom, 11)
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("EEEE, MMM d")
        return formatter.string(from: date)
    }

    private var weekWindowLabel: String {
        let start = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: Date()) ?? Date()
        let timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        return "\(LocalizedFormatters.shortDate(start, language: model.language, timeZone: timeZone)) – \(LocalizedFormatters.shortDate(end, language: model.language, timeZone: timeZone))"
    }

    private func natalHouse(for longitude: Double) -> Int {
        model.natal?.house(containing: longitude) ?? 0
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        formatter.setLocalizedDateFormatFromTemplate("MMM d")
        return formatter.string(from: date)
    }

    private func chapterDate(_ date: Date) -> String {
        LocalizedFormatters.shortDateWithYear(
            date,
            language: model.language,
            timeZone: TimeZone(identifier: model.profile.timezoneID) ?? .current
        )
    }

    private func timeOf(_ date: Date?) -> String {
        guard let date else { return "—" }
        let timeZone = TimeZone(identifier: model.profile.timezoneID) ?? .current
        return LocalizedFormatters.time(date, language: model.language, timeZone: timeZone)
    }

    private func monthAbbreviation(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateFormat = "MMM"
        return formatter.string(from: date)
    }

    private func dayNumber(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: model.language.rawValue)
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    private func todaySourceTitle(_ source: DailySignal.Source) -> String {
        switch source {
        case .sky: localized("today.source.current-sky", language: model.language)
        case .transit: localized("today.personal-timing", language: model.language)
        case .secondary: localized("today.long-term-shift", language: model.language)
        }
    }
}

/// A projected lunar disk. The dark and bright regions are two sides of the
/// same Moon; the terminator is derived from the Sun–Moon elongation.
struct LunarPhaseDisk: View {
    let phaseAngle: Double
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().fill(AppTheme.moonShadow)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [AppTheme.moonShadow.opacity(0.82), AppTheme.moonShadow],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.75
                    )
                )
            LunarIlluminatedShape(phaseAngle: phaseAngle)
                .fill(
                    RadialGradient(
                        colors: [AppTheme.moonLit, AppTheme.moonLit.opacity(0.78)],
                        center: .topLeading,
                        startRadius: 2,
                        endRadius: size * 0.72
                    )
                )
            Circle().stroke(AppTheme.violet.opacity(0.30), lineWidth: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: AppTheme.moonLit.opacity(0.13), radius: 12)
        .accessibilityHidden(true)
    }
}

struct LunarIlluminatedShape: Shape {
    let phaseAngle: Double

    func path(in rect: CGRect) -> Path {
        let angle = normalizedAngle * .pi / 180
        let illumination = LunarPhaseGeometry.illuminationFraction(elongation: normalizedAngle)
        if illumination <= 0.000_01 { return Path() }
        if illumination >= 0.999_99 { return Path(ellipseIn: rect) }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let waxing = normalizedAngle < 180
        let boundaryScale = cos(angle) * (waxing ? 1 : -1)
        let steps = 96
        var path = Path()

        for step in 0 ... steps {
            let y = -radius + (2 * radius * CGFloat(step) / CGFloat(steps))
            let halfWidth = sqrt(max(0, radius * radius - y * y))
            let x = boundaryScale * halfWidth
            let point = CGPoint(x: center.x + x, y: center.y + y)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }

        for step in stride(from: steps, through: 0, by: -1) {
            let y = -radius + (2 * radius * CGFloat(step) / CGFloat(steps))
            let halfWidth = sqrt(max(0, radius * radius - y * y))
            let limbX = waxing ? halfWidth : -halfWidth
            path.addLine(to: CGPoint(x: center.x + limbX, y: center.y + y))
        }
        path.closeSubpath()
        return path
    }

    private var normalizedAngle: Double {
        let value = phaseAngle.truncatingRemainder(dividingBy: 360)
        return value >= 0 ? value : value + 360
    }
}

extension DailySignal.Source {
    var symbol: String {
        switch self {
        case .sky: "◉"
        case .transit: "◎"
        case .secondary: "◐"
        }
    }
}
