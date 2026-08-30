import SwiftUI

extension InsightVisualView {
    func bondOrbit(_ presentation: SynastryOverviewPresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                personOrb(name: presentation.firstName)
                bondLine
                personOrb(name: presentation.secondName)
            }
            .padding(.top, 5)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 6) {
                    ForEach(Array(presentation.dimensions.enumerated()), id: \.offset) { _, dimension in
                        dimensionTag(dimension)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        ForEach(Array(presentation.dimensions.prefix(2).enumerated()), id: \.offset) { _, dimension in
                            dimensionTag(dimension)
                        }
                    }
                    if presentation.dimensions.count > 2 {
                        dimensionTag(presentation.dimensions[2])
                    }
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(localizedTemplate("dynamic.0097683c1c", substitutions: ["value1": String(describing: presentation.firstName), "value2": String(describing: presentation.secondName)], language: language))
    }

    private func personOrb(name: String) -> some View {
        Text(synastryInitials(name))
            .font(AppTypography.scaled(18, weight: .heavy))
            .foregroundStyle(AppTheme.text)
            .minimumScaleFactor(0.72)
            .lineLimit(1)
            .frame(width: 68, height: 68)
            .background(AppTheme.panelRaised, in: Circle())
            .overlay(Circle().stroke(AppTheme.text.opacity(0.14), lineWidth: 1))
            .accessibilityLabel(name)
    }

    private var bondLine: some View {
        ZStack {
            LinearGradient(
                colors: [AppTheme.blue, AppTheme.violet],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 2)

            Image(systemName: "heart")
                .font(AppTypography.scaled(14, weight: .semibold))
                .foregroundStyle(AppTheme.violet)
                .frame(width: 32, height: 32)
                .background(AppTheme.panelRaised, in: Circle())
                .overlay(Circle().stroke(AppTheme.violet.opacity(0.3), lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func dimensionTag(_ dimension: SynastryOverviewDimension) -> some View {
        Text("\(dimensionLabel(dimension.id)): \(dimensionStateLabel(dimension.state))")
            .font(AppTypography.scaled(11, weight: .medium))
            .foregroundStyle(AppTheme.muted)
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(AppTheme.text.opacity(0.05), in: Capsule())
            .overlay(Capsule().stroke(AppTheme.text.opacity(0.085), lineWidth: 1))
    }

    private func dimensionLabel(_ id: SynastryOverviewDimensionID) -> String {
        switch id {
        case .communication: localized("insight.synastry.communication", language: language)
        case .emotionalPace: localized("insight.synastry.emotional-pace", language: language)
        case .chemistry: localized("insight.synastry.chemistry", language: language)
        }
    }

    private func dimensionStateLabel(_ state: SynastryOverviewDimensionState) -> String {
        switch state {
        case .strong: localized("insight.synastry.strong", language: language)
        case .steady: localized("insight.synastry.steady", language: language)
        case .active: localized("insight.synastry.active", language: language)
        case .mixed: localized("insight.synastry.mixed", language: language)
        case .different: localized("insight.synastry.different", language: language)
        case .quiet: localized("insight.synastry.quiet", language: language)
        }
    }

    private func synastryInitials(_ name: String) -> String {
        let parts = name.split(whereSeparator: \.isWhitespace)
        let initials = parts.prefix(2).compactMap(\.first).map(String.init).joined()
        return initials.isEmpty ? "•" : initials.uppercased()
    }

    // MARK: - Perspective tabs (prototype .perspective-tabs)

    func perspectiveTabs(_ presentation: SynastryPerspectivePresentation) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                perspectiveButton(name: presentation.pair.firstName, index: 0)
                perspectiveButton(name: presentation.pair.secondName, index: 1)
            }

            let role = selectedSynastryPerspective == 0 ? "personA" : "personB"
            VStack(alignment: .leading, spacing: 7) {
                if let headline = roleText("\(role).headline") {
                    Text(headline)
                        .font(AppTypography.scaled(17, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = roleText("\(role).body") {
                    Text(body)
                        .font(AppTypography.scaled(12.5))
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        }
    }

    private func perspectiveButton(name: String, index: Int) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { selectedSynastryPerspective = index }
        } label: {
            Text(localizedTemplate("dynamic.56daa0b4f7", substitutions: ["value1": String(describing: name)], language: language))
                .font(AppTypography.scaled(12, weight: .semibold))
                .foregroundStyle(selectedSynastryPerspective == index ? Color.white : AppTheme.muted)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(selectedSynastryPerspective == index ? AppTheme.violet.opacity(0.36) : AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selectedSynastryPerspective == index ? .isSelected : [])
    }

    // MARK: - Connection grid (prototype .connection-grid)

    func synastryConnectionGrid(_ kind: SynastryConnectionGridKind) -> some View {
        let roles = kind == .emotional ? ["flow", "difference"] : ["stability", "growth"]
        return VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                ForEach(roles, id: \.self) { role in
                    if let fact = facts.first(where: { $0.visualRole == role }) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gridRoleLabel(role))
                                .font(AppTypography.scaled(9.5, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(fact.label)
                                .font(AppTypography.scaled(13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(fact.value)
                                .font(AppTypography.metadata.monospacedDigit())
                                .foregroundStyle(AppTheme.muted)
                            if let body = roleText("\(role).body") {
                                Text(body)
                                    .font(AppTypography.scaled(11.5))
                                    .foregroundStyle(AppTheme.muted)
                                    .lineSpacing(2)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    } else {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(gridRoleLabel(role))
                                .font(AppTypography.scaled(9.5, weight: .bold))
                                .foregroundStyle(role == "difference" ? AppTheme.coral : AppTheme.mint)
                            Text(localized("insight.synastry.no-distinct-signal", language: language))
                                .font(AppTypography.scaled(13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                            Text(missingGridRoleExplanation(role))
                                .font(AppTypography.scaled(11.5))
                                .foregroundStyle(AppTheme.muted)
                                .lineSpacing(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 118, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
            }
        }
    }

    var synastryPathFlow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    VStack(spacing: 3) {
                        Text(communicationStepText(index))
                            .font(AppTypography.scaled(11.5, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                            .multilineTextAlignment(.center)
                        if let fact = facts[safe: index] {
                            Text(fact.value)
                                .font(AppTypography.metadata.monospacedDigit())
                                .foregroundStyle(AppTheme.muted)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 58)
                    .padding(.horizontal, 5)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppTheme.line, lineWidth: 1))
                    if index < 2 {
                        Image(systemName: "arrow.right")
                            .font(AppTypography.scaled(9, weight: .bold))
                            .foregroundStyle(AppTheme.violet)
                    }
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(AppTypography.scaled(12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.line, lineWidth: 1))
            }
        }
    }

    var synastryChemistry: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 9) {
                chemistryCell(role: "attraction", label: localized("insight.synastry.attraction", language: language), tone: AppTheme.mint)
                chemistryCell(role: "intensity", label: localized("insight.synastry.intensity", language: language), tone: AppTheme.coral)
            }
            if let body = text?.body {
                Text(body)
                    .font(AppTypography.scaled(12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(AppTheme.line, lineWidth: 1))
            }
        }
    }

    @ViewBuilder
    private func chemistryCell(role: String, label: String, tone: Color) -> some View {
        if let fact = facts.first(where: { $0.visualRole == role }) {
            VStack(spacing: 5) {
                Text(label).font(AppTypography.scaled(9.5, weight: .bold)).foregroundStyle(tone)
                Text(fact.label)
                    .font(AppTypography.scaled(13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
                Text(fact.value)
                    .font(AppTypography.metadata.monospacedDigit())
                    .foregroundStyle(AppTheme.muted)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(11)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(tone.opacity(0.22), lineWidth: 1))
        } else {
            VStack(spacing: 5) {
                Text(label)
                    .font(AppTypography.scaled(9.5, weight: .bold))
                    .foregroundStyle(tone)
                Text(localized("insight.synastry.no-distinct-signal", language: language))
                    .font(AppTypography.scaled(13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .padding(11)
            .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(AppTheme.line, lineWidth: 1))
        }
    }

    func synastryHouseOverlayRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.element.id) { index, fact in
                VStack(alignment: .leading, spacing: 5) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(fact.label)
                            .font(AppTypography.scaled(13, weight: .semibold))
                            .foregroundStyle(AppTheme.text)
                        Spacer(minLength: 8)
                        Text(fact.value)
                            .font(AppTypography.scaled(11, weight: .medium))
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                    }
                    synastryRelevanceBar(fact.progress ?? 0)
                }
                .padding(.vertical, 4)
                if index < min(facts.count, 4) - 1 {
                    Divider().overlay(AppTheme.line)
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(AppTypography.scaled(12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
        .accessibilityLabel(localizedTemplate("dynamic.64a1051533", substitutions: ["value1": String(describing: pair.firstName), "value2": String(describing: pair.secondName)], language: language))
    }

    func synastryInterAspectRows(_ pair: SynastryPairPresentation) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            ForEach(Array(facts.prefix(6).enumerated()), id: \.element.id) { index, fact in
                Button { synastryFactDrawer = fact } label: {
                    HStack(spacing: 10) {
                        Text(fact.symbol ?? "✦")
                            .font(AppTypography.scaled(14, weight: .semibold))
                            .foregroundStyle(AppTheme.tone(fact.emphasis))
                            .frame(width: 30, height: 30)
                            .background(AppTheme.tone(fact.emphasis).opacity(0.1), in: RoundedRectangle(cornerRadius: 9))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(fact.label)
                                .font(AppTypography.scaled(13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(fact.value)
                                .font(AppTypography.scaled(11))
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer(minLength: 8)
                        Text(technicalTag(fact.emphasis))
                            .font(AppTypography.scaled(9.5, weight: .semibold))
                            .foregroundStyle(AppTheme.muted)
                            .multilineTextAlignment(.trailing)
                            .lineLimit(1)
                            .minimumScaleFactor(0.76)
                    }
                    .padding(.vertical, 5)
                }
                .buttonStyle(.plain)
                if index < min(facts.count, 6) - 1 {
                    Divider().overlay(AppTheme.line)
                }
            }
            if let body = text?.body {
                Text(body)
                    .font(AppTypography.scaled(12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(3)
            }
        }
        .accessibilityLabel(localizedTemplate("dynamic.ca5d9a507f", substitutions: ["value1": String(describing: pair.firstName), "value2": String(describing: pair.secondName)], language: language))
    }

    private func gridRoleLabel(_ role: String) -> String {
        switch role {
        case "flow": localized("insight.synastry.what-flows", language: language)
        case "difference": localized("insight.synastry.what-differs", language: language)
        case "stability": localized("insight.synastry.stability", language: language)
        case "growth": localized("insight.synastry.growth", language: language)
        default: role.uppercased()
        }
    }

    private func synastryRelevanceBar(_ value: Double) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(AppTheme.background.opacity(0.8))
                LinearGradient(
                    colors: [AppTheme.blue, AppTheme.violet],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: proxy.size.width * min(max(value, 0), 1))
                .clipShape(Capsule())
            }
        }
        .frame(height: 8)
        .accessibilityValue(localizedTemplate("dynamic.57e8687897", substitutions: ["value1": String(describing: Int(value * 100))], language: language))
    }

    private func missingGridRoleExplanation(_ role: String) -> String {
        switch role {
        case "flow":
            localized("insight.synastry.no-separate-supportive-moon-contact-met-the-current-threshold", language: language)
        case "difference":
            localized("insight.synastry.no-separate-contrasting-moon-contact-met-the-current-threshold", language: language)
        case "stability":
            localized("insight.synastry.no-separate-saturn-contact-met-the-current-threshold", language: language)
        case "growth":
            localized("insight.synastry.no-separate-jupiter-contact-met-the-current-threshold", language: language)
        default:
            localized("insight.synastry.no-separate-qualifying-contact-was-found", language: language)
        }
    }

    private func communicationStepText(_ index: Int) -> String {
        return facts[safe: index]?.label ?? localized("insight.synastry.no-signal", language: language)
    }

    private func roleText(_ roleID: String) -> String? {
        text?.roleTexts?.first(where: { $0.roleID == roleID })?.text
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct SynastryFactDetailSheet: View {
    let fact: InsightFact
    let interpretation: String?
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                sheetHandle
                Text(fact.label)
                    .font(AppTypography.scaled(23, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(localized("insight.synastry.a-cross-chart-contact-showing-how-one-persons-planet-meets-the-other-per", language: language))
                .font(AppTypography.scaled(12.5))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    factTile(localized("insight.synastry.aspect", language: language), fact.label)
                    factTile(localized("insight.synastry.function", language: language), functionLabel)
                    factTile(localized("insight.synastry.orb-phase", language: language), fact.value)
                    factTile(localized("insight.synastry.direction", language: language), fact.category ?? "—")
                }
                .padding(.vertical, 16)

                if let technicalDetail = fact.technicalDetail, !technicalDetail.isEmpty {
                    sheetSection(
                        title: localized("insight.synastry.calculated-details", language: language),
                        body: technicalDetail
                    )
                    .padding(.bottom, 12)
                }

                if let explanation = fact.note ?? interpretation, !explanation.isEmpty {
                    sheetSection(
                        title: localized("insight.synastry.interpretation", language: language),
                        body: explanation
                    )
                }

                doneButton
                    .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var functionLabel: String {
        switch fact.emphasis {
        case .supportive: localized("insight.synastry.core-support", language: language)
        case .challenging: localized("insight.synastry.active-friction", language: language)
        case .transition: localized("insight.synastry.long-term-bond", language: language)
        case .neutral: localized("insight.synastry.supporting-context", language: language)
        }
    }

    private var sheetHandle: some View {
        Capsule()
            .fill(AppTheme.muted.opacity(0.55))
            .frame(width: 38, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.bottom, 18)
    }

    private func factTile(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(AppTypography.scaled(10))
                .foregroundStyle(AppTheme.muted)
            Text(value)
                .font(AppTypography.scaled(13, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
    }

    private func sheetSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.scaled(13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text(body)
                .font(AppTypography.scaled(12))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }

    private var doneButton: some View {
        Button {
            dismiss()
        } label: {
            Text(localized("charts.done", language: language))
                .font(AppTypography.scaled(13, weight: .bold))
                .foregroundStyle(Color.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 13)
                .background(
                    LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .drawerTapTarget(minHeight: 52)
        }
            .buttonStyle(.plain)
    }
}

struct SynastryCardDetailSheet: View {
    let card: InsightCardModel
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(AppTheme.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)

                Text(card.title)
                    .font(AppTypography.scaled(23, weight: .bold))
                    .tracking(-0.5)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(detailIntroduction)
                    .font(AppTypography.scaled(12.5))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    ForEach(Array(card.facts.prefix(4).enumerated()), id: \.element.id) { index, fact in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(detailFactLabel(fact, index: index))
                                .font(AppTypography.scaled(10))
                                .foregroundStyle(AppTheme.muted)
                            Text(fact.label)
                                .font(AppTypography.scaled(13, weight: .semibold))
                                .foregroundStyle(AppTheme.text)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, minHeight: 78, alignment: .topLeading)
                        .background(AppTheme.panelRaised, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
                    }
                }
                .padding(.vertical, 16)

                if let headline = card.text?.headline, !headline.isEmpty {
                    interpretationSection(title: headline, body: card.text?.body)
                } else if let body = card.text?.body, !body.isEmpty {
                    interpretationSection(
                        title: localized("insight.synastry.interpretation", language: language),
                        body: body
                    )
                }

                Button {
                    dismiss()
                } label: {
                    Text(localized("charts.done", language: language))
                        .font(AppTypography.scaled(13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(colors: [AppTheme.blue, AppTheme.violet], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var detailIntroduction: String {
        switch card.id {
        case "emotional-connection":
            localized("insight.synastry.moon-contacts-show-emotional-recognition-regulation-and-pacing", language: language)
        case "communication":
            localized("insight.synastry.mercury-contacts-describe-comprehension-pace-and-conflict-style", language: language)
        case "chemistry":
            localized("insight.synastry.venus-and-mars-contacts-describe-attraction-and-pursuit-other-major-cont", language: language)
        case "commitment":
            localized("insight.synastry.saturn-jupiter-and-angle-contacts-show-reliability-growth-and-structural", language: language)
        default:
            localized("insight.synastry.this-detail-uses-only-the-calculated-evidence-selected-for-this-card", language: language)
        }
    }

    private func detailFactLabel(_ fact: InsightFact, index: Int) -> String {
        if let role = fact.visualRole {
            switch role {
            case "flow": return localized("insight.current-sky.support", language: language)
            case "difference": return localized("insight.synastry.friction", language: language)
            case "attraction": return localized("insight.synastry.attraction.96f0c62", language: language)
            case "intensity": return localized("insight.synastry.intensity.8edbde8", language: language)
            case "stability": return localized("insight.synastry.stability.295101c", language: language)
            case "growth": return localized("insight.synastry.growth.7216182", language: language)
            default: break
            }
        }
        if card.id == "communication" {
            if fact.emphasis == .supportive { return localized("insight.current-sky.support", language: language) }
            if fact.emphasis == .challenging { return localized("insight.synastry.friction.1fd3acf", language: language) }
        }
        return localizedTemplate("dynamic.8b817d9a14", substitutions: ["value1": String(describing: index + 1)], language: language)
    }

    private func interpretationSection(title: String, body: String?) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.scaled(13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            if let body, !body.isEmpty {
                Text(body)
                    .font(AppTypography.scaled(12))
                    .foregroundStyle(AppTheme.muted)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .overlay(alignment: .top) { Rectangle().fill(AppTheme.line).frame(height: 1) }
    }
}

struct SynastryOverviewDetailSheet: View {
    let card: InsightCardModel
    let presentation: SynastryOverviewPresentation
    let language: AppLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                Capsule()
                    .fill(AppTheme.muted.opacity(0.55))
                    .frame(width: 38, height: 5)
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 18)

                Text(localized("insight.synastry.relationship-overview", language: language))
                    .font(AppTypography.scaled(23, weight: .bold))
                    .tracking(-0.55)
                    .foregroundStyle(AppTheme.text)
                    .padding(.bottom, 7)

                Text(localizedTemplate("dynamic.9c8150aeca", substitutions: ["value1": String(describing: presentation.firstName), "value2": String(describing: presentation.secondName)], language: language))
                .font(AppTypography.scaled(12.5))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible())], spacing: 9) {
                    overviewFact(
                        label: localized("insight.synastry.strongest-link", language: language),
                        fact: strongestSupport ?? card.facts.first
                    )
                    overviewFact(
                        label: localized("insight.synastry.primary-contrast", language: language),
                        fact: primaryContrast ?? card.facts.dropFirst().first
                    )
                }
                .padding(.vertical, 16)

                if let body = card.text?.body, !body.isEmpty {
                    detailSection(
                        title: localized("insight.synastry.main-pattern", language: language),
                        body: body
                    )
                }

                detailSection(
                    title: localized("insight.synastry.how-to-read-this", language: language),
                    body: localized("insight.synastry.this-overview-separates-relationship-functions-because-the-same-connecti", language: language)
                )

                Button {
                    dismiss()
                } label: {
                    Text(localized("charts.done", language: language))
                        .font(AppTypography.scaled(13, weight: .bold))
                        .foregroundStyle(Color.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            LinearGradient(
                                colors: [AppTheme.blue, AppTheme.violet],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .padding(.top, 18)
            }
            .padding(.top, 10)
            .padding(.horizontal, 19)
            .padding(.bottom, 33)
        }
        .background(AppTheme.panel.ignoresSafeArea())
    }

    private var strongestSupport: InsightFact? {
        card.facts.first { $0.emphasis == .supportive }
    }

    private var primaryContrast: InsightFact? {
        card.facts.first { $0.emphasis == .challenging }
    }

    @ViewBuilder
    private func overviewFact(label: String, fact: InsightFact?) -> some View {
        if let fact {
            VStack(alignment: .leading, spacing: 5) {
                Text(label)
                    .font(AppTypography.scaled(10))
                    .foregroundStyle(AppTheme.muted)
                Text(fact.label)
                    .font(AppTypography.scaled(13, weight: .semibold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
            .background(AppTheme.background.opacity(0.55), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        }
    }

    private func detailSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(AppTypography.scaled(13, weight: .bold))
                .foregroundStyle(AppTheme.text)
            Text(body)
                .font(AppTypography.scaled(12))
                .foregroundStyle(AppTheme.muted)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 13)
        .overlay(alignment: .top) {
            Rectangle().fill(AppTheme.line).frame(height: 1)
        }
    }
}
