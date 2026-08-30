import SwiftUI

enum TransitDetailDrawer: Identifiable {
    case planetPaths([TransitPlanetPathRow])
    case activeTransit(TransitActiveRow)

    var id: String {
        switch self {
        case .planetPaths: "planet-paths"
        case let .activeTransit(row): "active-\(row.id)"
        }
    }
}


extension InsightCardView {
    func storyRoleWeave(_ roleTexts: [CardRoleText], result: String?) -> some View {
        VStack(spacing: 8) {
            ForEach(Array(roleTexts.enumerated()), id: \.offset) { index, roleText in
                if index > 0 {
                    Image(systemName: "plus")
                        .font(AppTypography.scaled(11, weight: .bold))
                        .foregroundStyle(AppTheme.muted)
                }
                HStack(alignment: .top, spacing: 10) {
                    let presentation = storyRolePresentation(roleText.roleID)
                    Label(presentation.label, systemImage: presentation.systemImage)
                        .font(AppTypography.scaled(9, weight: .bold))
                        .foregroundStyle(AppTheme.tone(presentation.tone))
                        .accessibilityLabel(presentation.label)
                    Text(roleText.text)
                        .font(AppTypography.scaled(11.5, weight: .medium))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                }
                .padding(12)
                .background(
                    AppTheme.tone(storyRoleTone(roleText.roleID)).opacity(0.08),
                    in: RoundedRectangle(cornerRadius: 8)
                )
            }
            if let result, !result.isEmpty {
                Text(result)
                    .font(AppTypography.scaled(10.5))
                    .lineSpacing(3)
                    .foregroundStyle(AppTheme.text.opacity(0.95))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    func storyRoleLabel(_ roleID: String) -> String {
        storyRolePresentation(roleID).label
    }

    func storyRoleTone(_ roleID: String) -> InsightTone {
        storyRolePresentation(roleID).tone
    }

    private func storyRolePresentation(_ roleID: String) -> (label: String, tone: InsightTone, systemImage: String) {
        switch roleID {
        case TransitStorySignalRoleID.expanding.rawValue:
            (localized("insight.transit.expanding", language: language), .supportive, "arrow.up.right")
        case TransitStorySignalRoleID.structuring.rawValue:
            (localized("insight.transit.structuring", language: language), .transition, "square.3.layers.3d")
        case TransitStorySignalRoleID.disrupting.rawValue:
            (localized("insight.transit.disrupting", language: language), .challenging, "bolt")
        case TransitStorySignalRoleID.stabilizing.rawValue:
            (localized("insight.transit.stabilizing", language: language), .transition, "shield")
        case TransitStorySignalRoleID.supporting.rawValue:
            (localized("insight.transit.supporting", language: language), .supportive, "plus.circle")
        case ClassicalTransitSignalRoleID.beneficSupport.rawValue:
            (localized("insight.transit.support", language: language), .supportive, "plus.circle")
        case ClassicalTransitSignalRoleID.maleficPressure.rawValue:
            (localized("insight.transit.pressure", language: language), .challenging, "exclamationmark.triangle")
        case ClassicalTransitSignalRoleID.fortified.rawValue:
            (localized("insight.transit.fortified", language: language), .supportive, "shield.checkered")
        case ClassicalTransitSignalRoleID.impaired.rawValue:
            (localized("insight.transit.impaired", language: language), .challenging, "shield.slash")
        case ClassicalTransitSignalRoleID.received.rawValue:
            (localized("insight.transit.received", language: language), .transition, "arrow.left.arrow.right")
        default:
            (roleID.uppercased(), .neutral, "circle")
        }
    }
}

extension InsightVisualView {
    func activityGauge(value: Int, supportive: Int, adjustment: Int) -> some View {
        VStack(spacing: 10) {
            ZStack {
                Path { path in
                    path.addArc(center: CGPoint(x: 110, y: 78), radius: 62, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(AppTheme.panelRaised, lineWidth: 12)
                Path { path in
                    path.addArc(center: CGPoint(x: 110, y: 78), radius: 62, startAngle: .degrees(180), endAngle: .degrees(180 + 180 * Double(value) / 100), clockwise: false)
                }
                .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(180), anchor: .center)
                VStack(spacing: 2) {
                    Text("\(value)").font(AppTypography.scaled(22, weight: .bold).monospacedDigit()).foregroundStyle(AppTheme.text)
                    Text(localized("insight.transit.activity", language: language)).font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
                }
                .offset(y: 8)
            }
            .frame(height: 96)
            HStack(spacing: 12) {
                metric("\(supportive)", localized("insight.transit.push", language: language), .supportive)
                metric("\(adjustment)", localized("insight.transit.adjust", language: language), .challenging)
            }
        }
    }

    func transitOverview(intensity: Int, rhythm: [Double]) -> some View {
        VStack(spacing: 10) {
            metric("\(intensity)%", localized("insight.synastry.intensity.8edbde8", language: language), .transition)
            rhythmWave(rhythm)
        }
    }

    func rhythmWave(_ values: [Double]) -> some View {
        Canvas { context, size in
            guard values.count > 1 else { return }
            var path = Path()
            for index in values.indices {
                let x = size.width * CGFloat(index) / CGFloat(values.count - 1)
                let y = size.height * (1 - max(0, min(1, values[index])))
                index == 0 ? path.move(to: CGPoint(x: x, y: y)) : path.addLine(to: CGPoint(x: x, y: y))
            }
            context.stroke(path, with: .linearGradient(Gradient(colors: [AppTheme.blue, AppTheme.violet]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: 0)), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        }
        .frame(height: 54)
    }

    // MARK: - Gantt (prototype .gantt-row: head + track with bar/marker)

    func houseRadar(_ values: [Double]) -> some View {
        Canvas { context, size in
            let count = values.count
            guard count > 0 else { return }
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.4
            for level in 1 ... 3 {
                context.stroke(polygon(center: center, radius: radius * Double(level) / 3, count: count), with: .color(AppTheme.line), lineWidth: 0.8)
            }
            var data = Path()
            for index in 0 ..< count {
                let value = max(0, min(1, values[index]))
                let point = polygonPoint(center: center, radius: radius * value, index: index, count: count)
                index == 0 ? data.move(to: point) : data.addLine(to: point)
            }
            data.closeSubpath()
            context.fill(data, with: .color(AppTheme.violet.opacity(0.2)))
            context.stroke(data, with: .color(AppTheme.violet), lineWidth: 1.4)
        }
        .frame(height: 150)
        .overlay(alignment: .bottom) {
            HStack {
                ForEach(Array(values.enumerated()), id: \.offset) { index, _ in
                    Text("\(index + 1)")
                        .font(AppTypography.scaled(9).monospacedDigit())
                        .foregroundStyle(AppTheme.muted)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    // MARK: - 7-day calendar (prototype heat grid)

    func calendar(_ values: [Int]) -> some View {
        VStack(spacing: 9) {
            HStack(spacing: 6) {
                ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                    VStack(spacing: 3) {
                        Text(shortDay(index + 1)).font(AppTypography.scaled(9.5)).foregroundStyle(AppTheme.muted)
                        RoundedRectangle(cornerRadius: 6)
                            .fill(AppTheme.tone(value > 66 ? .challenging : value > 35 ? .transition : .neutral).opacity(0.16 + Double(value) / 100 * 0.7))
                            .frame(height: 46)
                            .overlay(
                                Text("\(value)")
                                    .font(AppTypography.scaled(10, weight: .bold).monospacedDigit())
                                    .foregroundStyle(AppTheme.text)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            Text(localized("insight.transit.this-weeks-intensity", language: language))
                .font(AppTypography.scaled(9.5))
                .foregroundStyle(AppTheme.muted)
        }
    }

    func shortDay(_ index: Int) -> String {
        let days = LocalizedFormatters.weekdayLabelsStartingMonday(language: language)
        return days[min(max(0, index - 1), 6)]
    }

    func transitPlanetPaths(_ rows: [TransitPlanetPathRow]) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(localized("insight.transit.transiting-houses-motion", language: language))
                        .font(AppTypography.scaled(14, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized("insight.transit.this-separates-planetary-location-from-aspect-interpretation", language: language))
                    .font(AppTypography.scaled(9.5))
                    .lineSpacing(2)
                    .foregroundStyle(AppTheme.muted)
                }
                Spacer(minLength: 8)
                Button {
                    transitDetailDrawer = .planetPaths(rows)
                } label: {
                    Text(localized("insight.transit.how-it-works", language: language))
                        .font(AppTypography.scaled(9.5, weight: .semibold))
                        .foregroundStyle(AppTheme.violet)
                        .frame(minHeight: 44, alignment: .topTrailing)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-planet-paths-how-it-works")
            }
            .padding(.bottom, 2)

            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(AppTheme.line)
                }
                HStack(spacing: 10) {
                    Text(row.symbol)
                        .font(AppTypography.scaled(17, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.background.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(row.title)
                            .font(AppTypography.scaled(11, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(row.detail)
                            .font(AppTypography.scaled(9))
                            .lineSpacing(2)
                            .foregroundStyle(AppTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 3) {
                        Text(transitPathStateLabel(row.state))
                            .font(AppTypography.scaled(9, weight: .medium))
                            .foregroundStyle(AppTheme.text.opacity(0.86))
                        Text(row.timing)
                            .font(AppTypography.scaled(9))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    .frame(minWidth: 52, alignment: .trailing)
                }
                .padding(.vertical, 11)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transit-path-\(row.id)")
            }
        }
    }

    func transitLifeAreas(_ rows: [TransitLifeAreaRow]) -> some View {
        let shown = showAllAreas ? rows : Array(rows.prefix(4))
        return VStack(spacing: 0) {
            Text(localized("insight.transit.activity-reflects-transiting-houses-activated-natal-planets-and-overlapp", language: language))
            .font(AppTypography.scaled(9.5))
            .lineSpacing(3)
            .foregroundStyle(AppTheme.muted)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(10)
            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
            .padding(.bottom, 12)

            ForEach(shown) { row in
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(row.title)
                            .font(AppTypography.scaled(10.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 8)
                        Text(transitTriggerSummary(row))
                            .font(AppTypography.scaled(9))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.background.opacity(0.78))
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0, min(1, row.progress)))
                        }
                    }
                    .frame(height: 8)
                }
                .padding(.bottom, 12)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("transit-life-area-\(row.id)")
            }

            if rows.count > 4 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { showAllAreas.toggle() }
                } label: {
                    Text(showAllAreas
                         ? localized("insight.transit.show-fewer-areas", language: language)
                         : LocalizedFormatters.viewAllAreas(rows.count, language: language))
                        .font(AppTypography.scaled(10, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-life-areas-toggle")
            }
        }
    }

    func transitActiveRows(_ rows: [TransitActiveRow]) -> some View {
        let filtered = transitFilter == nil ? rows : rows.filter { $0.category == transitFilter }
        let prioritized = filtered.sorted(by: transitActivePriority)
        let shown = showAllActiveTransits ? prioritized : Array(prioritized.prefix(5))
        return VStack(spacing: 0) {
            HStack(spacing: 6) {
                aspectFilterChip(nil, localized("insight.shared.all", language: language))
                aspectFilterChip("long-term", localized("insight.shared.long-term", language: language))
                aspectFilterChip("current", localized("insight.shared.current", language: language))
                aspectFilterChip("daily", localized("insight.shared.daily", language: language))
                Spacer(minLength: 0)
            }
            .padding(.bottom, 1)

            ForEach(Array(shown.enumerated()), id: \.element.id) { index, row in
                if index > 0 {
                    Divider().overlay(AppTheme.line)
                }
                Button {
                    transitDetailDrawer = .activeTransit(row)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Text(row.symbol)
                            .font(AppTypography.scaled(15, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .frame(width: 34, height: 34)
                            .background(AppTheme.violet.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 4) {
                            Text(row.title)
                                .font(AppTypography.scaled(11, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            if !row.detail.isEmpty {
                                Text(row.detail)
                                    .font(AppTypography.scaled(9))
                                    .lineSpacing(2)
                                    .foregroundStyle(AppTheme.muted)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(transitActiveStatusLabel(row.status))
                                .font(AppTypography.scaled(8.5, weight: .semibold))
                                .foregroundStyle(AppTheme.text.opacity(0.85))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppTheme.background.opacity(0.65), in: Capsule())
                                .overlay(Capsule().stroke(AppTheme.line, lineWidth: 1))
                            Text(row.technicalValue)
                                .font(AppTypography.scaled(8.5, weight: .medium))
                                .foregroundStyle(AppTheme.muted)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(AppTheme.background.opacity(0.45), in: Capsule())
                        }
                        .multilineTextAlignment(.trailing)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("transit-active-\(row.id)")
            }
            if prioritized.count > 5 {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showAllActiveTransits.toggle()
                    }
                } label: {
                    Text(showAllActiveTransits
                         ? localized("insight.transit.show-key-transits", language: language)
                         : localized("insight.transit.view-all-active-transits", language: language))
                        .font(AppTypography.scaled(10, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 8)
            }
        }
    }

    func transitActivePriority(_ lhs: TransitActiveRow, _ rhs: TransitActiveRow) -> Bool {
        let lhsRank = transitActiveStatusRank(lhs.status)
        let rhsRank = transitActiveStatusRank(rhs.status)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        let categoryOrder = ["long-term": 0, "current": 1, "daily": 2]
        let lhsCategory = categoryOrder[lhs.category] ?? 3
        let rhsCategory = categoryOrder[rhs.category] ?? 3
        if lhsCategory != rhsCategory { return lhsCategory < rhsCategory }
        return lhs.id < rhs.id
    }

    func transitActiveStatusRank(_ status: TransitActiveStatus) -> Int {
        switch status {
        case .exact: 0
        case .returning: 1
        case .applying: 2
        case .ingress: 3
        case .retrograde, .direct: 4
        case .separating: 5
        }
    }

    @ViewBuilder
    func transitDrawer(_ drawer: TransitDetailDrawer) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                switch drawer {
                case let .planetPaths(rows):
                    Text(localized("charts.planet-paths", language: language))
                        .font(AppTypography.scaled(23, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    Text(localized("insight.transit.this-module-shows-each-transiting-planets-sign-natal-house-direction-and", language: language))
                    .font(AppTypography.supporting)
                    .lineSpacing(4)
                    .foregroundStyle(AppTheme.muted)
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)],
                        spacing: 9
                    ) {
                        ForEach(rows.prefix(4)) { row in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(bodyName(row.body, language: language))
                                    .font(AppTypography.metadata)
                                    .foregroundStyle(AppTheme.muted)
                                Text(transitDrawerHouse(row.house))
                                    .font(AppTypography.scaled(12, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                        }
                    }
                    transitDrawerSection(
                        title: localized("insight.transit.why-separate-it", language: language),
                        body: localized("insight.transit.a-planet-can-matter-because-of-the-house-it-occupies-even-when-no-exact", language: language)
                    )
                    transitDrawerSection(
                        title: localized("insight.transit.difference-from-active-transits", language: language),
                        body: localized("insight.transit.planet-paths-shows-location-and-motion-active-transits-shows-exact-relat", language: language)
                    )
                case let .activeTransit(row):
                    Text(row.title)
                        .font(AppTypography.scaled(23, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                    if !row.detail.isEmpty {
                        Text(row.detail)
                            .font(AppTypography.supporting)
                            .lineSpacing(4)
                            .foregroundStyle(AppTheme.muted)
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                        ForEach(row.fields) { field in
                            VStack(alignment: .leading, spacing: 5) {
                                Text(field.label)
                                    .font(AppTypography.metadata)
                                    .foregroundStyle(AppTheme.muted)
                                Text(field.value)
                                    .font(AppTypography.scaled(12, weight: .semibold))
                                    .foregroundStyle(AppTheme.text)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
                            .padding(12)
                            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                        }
                    }
                    transitDrawerSection(
                        title: localized("insight.transit.technical-basis", language: language),
                        body: localized("insight.transit.timing-orb-house-and-motion-are-calculated-for-the-selected-chart-moment", language: language)
                    )
                }
                Button {
                    transitDetailDrawer = nil
                } label: {
                    Text(localized("charts.done", language: language))
                        .font(AppTypography.scaled(12, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(AppTheme.violet, in: RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 19)
            .padding(.top, 10)
            .padding(.bottom, 32)
        }
        .background(AppTheme.panel)
    }

    func transitDrawerSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Divider().overlay(AppTheme.line)
            Text(title)
                .font(AppTypography.label)
                .foregroundStyle(AppTheme.text)
                .padding(.top, 8)
            Text(body)
                .font(AppTypography.supporting)
                .lineSpacing(3)
                .foregroundStyle(AppTheme.muted)
        }
    }

    func transitDrawerHouse(_ house: Int) -> String {
        guard (1 ... 12).contains(house) else { return localized("insight.transit.unknown-house", language: language) }
        return localizedTemplate("dynamic.24d4dfe3ce", substitutions: ["value1": AstroTerms.house(house, language: language)], language: language)
    }

    func ordinalLabel(_ value: Int) -> String {
        let remainder = value % 100
        if (11 ... 13).contains(remainder) { return "\(value)th" }
        return switch value % 10 {
        case 1: "\(value)st"
        case 2: "\(value)nd"
        case 3: "\(value)rd"
        default: "\(value)th"
        }
    }

    func transitPathStateLabel(_ state: TransitPathState) -> String {
        switch state {
        case .direct: localized("insight.transit.direct", language: language)
        case .retrograde: localized("insight.transit.retrograde", language: language)
        case .next: localized("insight.shared.next", language: language)
        }
    }

    func transitActiveStatusLabel(_ status: TransitActiveStatus) -> String {
        switch status {
        case .applying: localized("insight.transit.applying", language: language)
        case .returning: localized("insight.transit.returning", language: language)
        case .ingress: localized("insight.transit.ingress", language: language)
        case .separating: localized("insight.transit.separating", language: language)
        case .exact: localized("insight.secondary.exact", language: language)
        case .retrograde: localized("insight.transit.retrograde", language: language)
        case .direct: localized("insight.transit.direct", language: language)
        }
    }

    func transitTriggerSummary(_ row: TransitLifeAreaRow) -> String {
        if row.triggerCount == 0 {
            return localizedTemplate("dynamic.a34989f3f0", substitutions: ["value1": String(describing: row.activity)], language: language)
        }
        let key = row.triggerCount == 1
            ? "insight.transit.trigger-summary.one"
            : "insight.transit.trigger-summary.other"
        return localizedTemplate(
            key,
            substitutions: [
                "activity": row.activity,
                "count": String(row.triggerCount),
            ],
            language: language
        )
    }

    func aspectFilterChip(_ category: String?, _ label: String) -> some View {
        let selected = transitFilter == category
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                transitFilter = category
                showAllActiveTransits = false
            }
        } label: {
            Text(label)
                .font(AppTypography.compactLabel)
                .foregroundStyle(selected ? Color.white : AppTheme.muted)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(selected ? AppTheme.violet : AppTheme.background.opacity(0.4), in: Capsule())
        }
        .buttonStyle(.plain)
    }

    func storyWeave(expanding: String, structuring: String, result: String) -> some View {
        VStack(spacing: 8) {
            storyThread(label: localized("insight.transit.expanding.5e50de8", language: language), value: expanding, tone: .supportive)
            Image(systemName: "plus").font(AppTypography.scaled(11, weight: .bold)).foregroundStyle(AppTheme.muted)
            storyThread(label: localized("insight.transit.structuring.b1a7c26", language: language), value: structuring, tone: .challenging)
            Text(result)
                .font(AppTypography.scaled(10.5))
                .lineSpacing(3)
                .foregroundStyle(AppTheme.text.opacity(0.95))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.violet.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
        }
    }

    func storyThread(label: String, value: String, tone: InsightTone) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(label).font(AppTypography.scaled(9, weight: .bold)).foregroundStyle(AppTheme.tone(tone))
            Text(value).font(AppTypography.scaled(11.5, weight: .medium)).foregroundStyle(AppTheme.text)
            Spacer()
        }
        .padding(12)
        .background(AppTheme.tone(tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }

    // MARK: - Cycle tabs (prototype .cycle-tabs)

    func cycleTabs(
        long: TransitCyclePresentation?,
        current: TransitCyclePresentation?,
        daily: TransitCyclePresentation?
    ) -> some View {
        let options = [
            (
                localized("insight.shared.long-term", language: language),
                localized("insight.transit.long-term-chapter", language: language),
                long,
                InsightTone.supportive
            ),
            (
                localized("insight.shared.current", language: language),
                localized("insight.transit.current-period", language: language),
                current,
                InsightTone.transition
            ),
            (
                localized("insight.shared.daily", language: language),
                localized("insight.transit.daily-movement", language: language),
                daily,
                InsightTone.neutral
            ),
        ]
        let selected = options[selectedCycleIndex]
        return VStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(options.indices, id: \.self) { index in
                    cycleTabChip(options[index].0, index: index)
                }
            }
            cycleRow(kicker: selected.1, presentation: selected.2, tone: selected.3)
        }
    }

    func cycleTabChip(_ label: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) { selectedCycleIndex = index }
        } label: {
            Text(label)
                .font(AppTypography.scaled(11, weight: .semibold))
                .foregroundStyle(selectedCycleIndex == index ? Color.white : AppTheme.muted)
                .frame(maxWidth: .infinity, minHeight: 34)
                .background(
                    selectedCycleIndex == index ? AppTheme.violet : AppTheme.background.opacity(0.4),
                    in: RoundedRectangle(cornerRadius: 8)
                )
        }
        .buttonStyle(.plain)
    }

    func cycleRow(
        kicker: String,
        presentation: TransitCyclePresentation?,
        tone: InsightTone
    ) -> some View {
        let copy = presentation.flatMap { item in
            text?.cycleTexts?.first(where: { $0.roleID == item.roleID })
        }
        return VStack(alignment: .leading, spacing: 7) {
            Text(kicker.uppercased())
                .font(AppTypography.scaled(9, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tone(tone))
            if let presentation {
                Text(copy?.headline ?? presentation.fallbackTitle)
                    .font(AppTypography.scaled(17, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let body = copy?.body, !body.isEmpty {
                    Text(body)
                        .font(AppTypography.scaled(10))
                        .lineSpacing(3)
                        .foregroundStyle(AppTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(presentation.tags.enumerated()), id: \.offset) { _, tag in
                        Text(tag)
                            .font(AppTypography.scaled(9, weight: .medium))
                            .foregroundStyle(AppTheme.text.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(AppTheme.background.opacity(0.65), in: RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
                .padding(.top, 2)
            } else {
                Text(localized("insight.transit.no-active-cycle-at-this-time-scale", language: language))
                    .font(AppTypography.scaled(10))
                    .foregroundStyle(AppTheme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Stage flow (prototype .stage-flow)

    struct TransitTimelineView: View {
        let entries: [TransitTimelineEntry]
        let calendarFacts: [TransitCalendarFact]
        let anchorDate: Date
        let timeZoneIdentifier: String
        let language: AppLanguage
        @State private var selectedDays: Int
        @State private var showCalendar = false
        @State private var displayedMonth: Date
        var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? .current }

        init(
            entries: [TransitTimelineEntry],
            calendarFacts: [TransitCalendarFact],
            anchorDate: Date,
            initialRangeDays: Int,
            timeZoneIdentifier: String,
            language: AppLanguage
        ) {
            self.entries = entries
            self.calendarFacts = calendarFacts
            self.anchorDate = anchorDate
            self.timeZoneIdentifier = timeZoneIdentifier
            self.language = language
            let normalizedRange = TransitTimelineContract.rangeDays.contains(initialRangeDays)
                ? initialRangeDays
                : TransitTimelineContract.defaultRangeDays
            _selectedDays = State(initialValue: normalizedRange)
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
            _displayedMonth = State(
                initialValue: calendar.date(
                    from: calendar.dateComponents([.year, .month], from: anchorDate)
                ) ?? anchorDate
            )
        }

        var axisStart: Date { anchorDate }
        var axisEnd: Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(byAdding: .day, value: selectedDays, to: anchorDate)
                ?? anchorDate.addingTimeInterval(Double(selectedDays) * 86_400)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 11) {
                HStack(spacing: 6) {
                    rangeButton(30, localized("charts.30-days", language: language))
                    rangeButton(7, localized("charts.7-days", language: language))
                    rangeButton(365, localized("charts.12-months", language: language))
                    Spacer()
                }
                HStack(spacing: 6) {
                    viewButton(false, localized("insight.transit.timeline", language: language))
                    viewButton(true, localized("insight.transit.calendar", language: language))
                    Spacer()
                }
                if showCalendar {
                    calendarGrid
                } else {
                    timelineRows
                }
            }
        }

        func rangeButton(_ days: Int, _ label: String) -> some View {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    selectedDays = days
                    displayedMonth = monthStart(anchorDate)
                }
            } label: {
                Text(label)
                    .font(AppTypography.scaled(10, weight: .semibold))
                    .foregroundStyle(selectedDays == days ? Color.white : AppTheme.muted)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(selectedDays == days ? AppTheme.violet : AppTheme.background.opacity(0.4), in: Capsule())
            }
            .buttonStyle(.plain)
        }

        func viewButton(_ calendar: Bool, _ label: String) -> some View {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { showCalendar = calendar }
            } label: {
                Text(label)
                    .font(AppTypography.scaled(10, weight: .semibold))
                    .foregroundStyle(showCalendar == calendar ? AppTheme.violet : AppTheme.muted)
                    .padding(.horizontal, 11)
                    .padding(.vertical, 6)
                    .background(AppTheme.background.opacity(0.4), in: Capsule())
                    .overlay(Capsule().stroke(showCalendar == calendar ? AppTheme.violet.opacity(0.5) : AppTheme.line, lineWidth: 1))
            }
            .buttonStyle(.plain)
        }

        var timelineRows: some View {
            let visible = entries.filter {
                ($0.end ?? $0.start) >= axisStart && $0.start <= axisEnd
            }
            if visible.isEmpty {
                return AnyView(
                    Text(localized("insight.transit.no-transits-enter-this-window", language: language))
                        .font(AppTypography.scaled(11))
                        .foregroundStyle(AppTheme.muted)
                        .padding(.vertical, 8)
                )
            }
            return AnyView(
                VStack(spacing: 11) {
                    markerLegend
                    ForEach(Array(visible.prefix(8)), id: \.id) { entry in
                        timelineRow(entry)
                    }
                }
            )
        }

        var markerLegend: some View {
            HStack(spacing: 4) {
                markerLegendItem(localized("insight.transit.start", language: language), color: AppTheme.blue)
                markerLegendItem(localized("insight.secondary.exact", language: language), color: AppTheme.violet)
                markerLegendItem(localized("insight.transit.return", language: language), color: AppTheme.amber)
                markerLegendItem(localized("insight.transit.end", language: language), color: AppTheme.muted)
            }
        }

        func markerLegendItem(_ label: String, color: Color) -> some View {
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 5, height: 5)
                Text(label).font(AppTypography.scaled(8.5, weight: .medium)).foregroundStyle(AppTheme.muted)
            }
            .frame(maxWidth: .infinity)
        }

        func timelineRow(_ entry: TransitTimelineEntry) -> some View {
            let total = max(1, axisEnd.timeIntervalSince(axisStart))
            let startRatio = ratio(entry.start, total: total)
            let endRatio = entry.end.map { ratio($0, total: total) }
            return VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(entryTitle(entry))
                        .font(AppTypography.scaled(11.5, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineLimit(2)
                    Spacer(minLength: 6)
                    Text(entryDateRange(entry))
                        .font(AppTypography.scaled(9.5))
                        .foregroundStyle(AppTheme.muted)
                        .multilineTextAlignment(.trailing)
                }
                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 5)
                        if let endRatio {
                            Capsule()
                                .fill(AppTheme.blue.opacity(0.5))
                                .frame(
                                    width: proxy.size.width * max(0.025, endRatio - startRatio),
                                    height: 5
                                )
                                .offset(x: proxy.size.width * startRatio)
                        }
                        timelineMarker(ratio: startRatio, color: AppTheme.blue, filled: true, width: proxy.size.width)
                        ForEach(Array(entry.exactDates.enumerated()), id: \.offset) { index, date in
                            timelineMarker(
                                ratio: ratio(date, total: total),
                                color: index == 0 ? AppTheme.violet : AppTheme.amber,
                                filled: index == 0,
                                width: proxy.size.width
                            )
                        }
                        if let endRatio {
                            timelineMarker(ratio: endRatio, color: AppTheme.muted, filled: false, width: proxy.size.width)
                        }
                    }
                }
                .frame(height: 11)
            }
        }

        func timelineMarker(ratio: Double, color: Color, filled: Bool, width: CGFloat) -> some View {
            Circle()
                .fill(filled ? color : AppTheme.panel)
                .overlay(Circle().stroke(color, lineWidth: 1.5))
                .frame(width: 9, height: 9)
                .offset(x: width * ratio - 4.5)
        }

        func ratio(_ date: Date, total: TimeInterval) -> Double {
            min(1, max(0, date.timeIntervalSince(axisStart) / total))
        }

        func entryTitle(_ entry: TransitTimelineEntry) -> String {
            let body = bodyName(entry.movingBody, language: language)
            switch entry.kind {
            case let .aspect(kind):
                let reference = entry.referenceBody.map { bodyName($0, language: language) } ?? ""
                return "\(body) \(kind.symbol) \(reference)"
            case let .houseResidence(house):
                return localizedTemplate("dynamic.d2a685052e", substitutions: ["value1": body, "value2": AstroTerms.house(house, language: language)], language: language)
            case let .signIngress(sign):
                return localizedTemplate("dynamic.4cbf796387", substitutions: ["value1": String(describing: body), "value2": String(describing: Zodiac.name(index: sign, language: language))], language: language)
            case .stationRetrograde:
                return localizedTemplate("dynamic.aa92844e1f", substitutions: ["value1": String(describing: body)], language: language)
            case .stationDirect:
                return localizedTemplate("dynamic.2772c7af82", substitutions: ["value1": String(describing: body)], language: language)
            }
        }

        func entryDateRange(_ entry: TransitTimelineEntry) -> String {
            guard let end = entry.end else {
                return entry.start.shortEventDate(language: language, timeZone: timeZone)
            }
            return entry.start.shortEventRange(to: end, language: language, timeZone: timeZone)
        }

        func ordinal(_ value: Int) -> String {
            let remainder = value % 100
            if (11 ... 13).contains(remainder) { return "\(value)th" }
            return switch value % 10 {
            case 1: "\(value)st"
            case 2: "\(value)nd"
            case 3: "\(value)rd"
            default: "\(value)th"
            }
        }

        var calendarGrid: some View {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let today = calendar.startOfDay(for: anchorDate)
            let first = monthStart(displayedMonth)
            let firstWeekday = calendar.component(.weekday, from: first)
            let daysInMonth = calendar.range(of: .day, in: .month, for: first)?.count ?? 30
            let leading = (firstWeekday + 5) % 7
            let weekdayLabels = LocalizedFormatters.weekdayLabelsStartingMonday(language: language)
            let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)
            let factsByDay = Dictionary(
                uniqueKeysWithValues: calendarFacts.map { (calendar.startOfDay(for: $0.date), $0) }
            )
            let eventKindsByDay = Dictionary(
                grouping: entries.flatMap { entry in
                    ([entry.start] + entry.exactDates + [entry.end].compactMap { $0 }).map {
                        (calendar.startOfDay(for: $0), entry.kind)
                    }
                },
                by: { $0.0 }
            ).mapValues { $0.map { $0.1 } }
            return VStack(spacing: 6) {
                HStack {
                    monthButton(systemName: "chevron.left", delta: -1, enabled: canMoveMonth(-1))
                    Spacer()
                    Text(displayedMonth.shortEventMonthYear(language: language, timeZone: timeZone))
                        .font(AppTypography.scaled(11, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                    Spacer()
                    monthButton(systemName: "chevron.right", delta: 1, enabled: canMoveMonth(1))
                }
                HStack(spacing: 5) {
                    ForEach(weekdayLabels, id: \.self) { label in
                        Text(label).font(AppTypography.scaled(9)).foregroundStyle(AppTheme.muted).frame(maxWidth: .infinity)
                    }
                }
                LazyVGrid(columns: columns, spacing: 5) {
                    ForEach(0 ..< leading, id: \.self) { _ in
                        Color.clear.frame(height: 30)
                    }
                    ForEach(1 ... daysInMonth, id: \.self) { day in
                        let date = calendar.date(byAdding: .day, value: day - 1, to: first) ?? today
                        let fact = factsByDay[date]
                        let kinds = eventKindsByDay[date] ?? []
                        let inRange = date >= today && date <= calendar.startOfDay(for: axisEnd)
                        VStack(spacing: 3) {
                            HStack(spacing: 2) {
                                Text("\(day)")
                                    .font(AppTypography.scaled(10, weight: fact == nil ? .medium : .bold))
                                if let fact, !fact.sourceFactIDs.isEmpty {
                                    Text("\(fact.sourceFactIDs.count)")
                                        .font(AppTypography.scaled(7.5, weight: .bold))
                                        .foregroundStyle(AppTheme.violet)
                                }
                            }
                            HStack(spacing: 2) {
                                ForEach(Array(calendarColors(for: kinds).prefix(3).enumerated()), id: \.offset) { _, color in
                                    Circle().fill(color).frame(width: 4, height: 4)
                                }
                            }
                            .frame(height: 4)
                        }
                            .foregroundStyle(inRange ? AppTheme.text : AppTheme.muted.opacity(0.45))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .background(
                                calendarCellBackground(score: inRange ? fact?.score : nil),
                                in: RoundedRectangle(cornerRadius: 7)
                            )
                    }
                }
            }
        }

        func monthStart(_ date: Date) -> Date {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        }

        func canMoveMonth(_ delta: Int) -> Bool {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            guard let target = calendar.date(byAdding: .month, value: delta, to: displayedMonth) else { return false }
            return monthStart(target) >= monthStart(anchorDate) && monthStart(target) <= monthStart(axisEnd)
        }

        func monthButton(systemName: String, delta: Int, enabled: Bool) -> some View {
            Button {
                var calendar = Calendar(identifier: .gregorian)
                calendar.timeZone = timeZone
                displayedMonth = calendar.date(byAdding: .month, value: delta, to: displayedMonth) ?? displayedMonth
            } label: {
                Image(systemName: systemName)
                    .font(AppTypography.scaled(11, weight: .semibold))
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            .foregroundStyle(enabled ? AppTheme.violet : AppTheme.muted.opacity(0.35))
            .disabled(!enabled)
        }

        func calendarCellBackground(score: Int?) -> Color {
            guard let score else { return AppTheme.background.opacity(0.4) }
            return AppTheme.violet.opacity(0.08 + 0.18 * min(1, Double(score) / 100))
        }

        func calendarColors(for kinds: [TransitTimelineEntryKind]) -> [Color] {
            var colors: [Color] = []
            if kinds.contains(where: { if case .aspect = $0 { true } else { false } }) {
                colors.append(AppTheme.violet)
            }
            if kinds.contains(where: {
                if case .houseResidence = $0 { return true }
                if case .signIngress = $0 { return true }
                return false
            }) {
                colors.append(AppTheme.blue)
            }
            if kinds.contains(where: { $0 == .stationRetrograde || $0 == .stationDirect }) {
                colors.append(AppTheme.amber)
            }
            return colors
        }
    }

    // MARK: - Bond orbit (prototype .bond-orbit)

    func polygon(center: CGPoint, radius: Double, count: Int) -> Path {
        var path = Path()
        for index in 0 ..< count {
            let point = polygonPoint(center: center, radius: radius, index: index, count: count)
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }

    func polygonPoint(center: CGPoint, radius: Double, index: Int, count: Int) -> CGPoint {
        let angle = Double(index) / Double(count) * 2 * Double.pi - Double.pi / 2
        return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
    }
}
