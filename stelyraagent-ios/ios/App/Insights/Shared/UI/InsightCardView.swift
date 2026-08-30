import SwiftUI

// MARK: - Card container (prototype .card surface)

struct InsightCardView: View {
    let card: InsightCardModel
    let language: AppLanguage
    var prototypeTransitStyle = false
    var externalHeaderStyle = false
    @State private var showsSynastryOverviewDetail = false
    @State private var showsSynastryCardDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !externalHeaderStyle,
               (!isPrototypeTransitCard || card.id == "current-story"),
               let kicker = cardKicker(card.id, language: language),
               !kicker.isEmpty
            {
                Text(kicker.uppercased())
                    .font(AppTypography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.violet)
            }
            if !externalHeaderStyle {
                Text(card.title.isEmpty ? card.summary : card.title)
                    .font(AppTypography.scaled(18, weight: .bold))
                    .foregroundStyle(AppTheme.text)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let presentation = synastryOverviewPresentation {
                Text("\(presentation.firstName) + \(presentation.secondName)".uppercased())
                    .font(AppTypography.eyebrow)
                    .tracking(1.2)
                    .foregroundStyle(AppTheme.violet)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(
                        localizedTemplate(
                            "insight.synastry.people-accessibility",
                            substitutions: [
                                "firstName": presentation.firstName,
                                "secondName": presentation.secondName,
                            ],
                            language: language
                        )
                    )
            }

            if showsGenericCopy, let text = card.text {
                if let headline = text.headline, !headline.isEmpty, headline != card.title {
                    Text(headline)
                        .font(AppTypography.scaled(heroHeadline ? 21 : 16, weight: .semibold))
                        .foregroundStyle(AppTheme.text)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let body = text.body, !body.isEmpty, body != text.headline {
                    Text(body)
                        .font(heroHeadline ? AppTypography.supporting.weight(.medium) : AppTypography.summary)
                        .foregroundStyle(heroHeadline ? AppTheme.muted : AppTheme.text.opacity(0.95))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if card.id != "current-story",
                   let secondary = text.secondaryBody,
                   !secondary.isEmpty
                {
                    Text(secondary)
                        .font(AppTypography.supporting)
                        .foregroundStyle(AppTheme.muted)
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if showsGenericCopy,
                      !card.facts.isEmpty,
                      !card.summary.isEmpty,
                      card.summary != card.title
            {
                Text(card.summary)
                    .font(AppTypography.summary.weight(.medium))
                    .foregroundStyle(AppTheme.text.opacity(0.95))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if card.id == "current-story",
               let roleTexts = card.text?.roleTexts,
               !roleTexts.isEmpty
            {
                storyRoleWeave(roleTexts, result: card.text?.secondaryBody)
            } else {
                InsightVisualView(visual: card.visual, facts: card.facts, text: card.text, language: language)
            }
        }
        .padding(16)
        .background(
            LinearGradient(colors: [AppTheme.panelRaised, AppTheme.panel], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 22, style: .continuous)
        )
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line, lineWidth: 1))
        .contentShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("insight-card-\(card.id)")
        .accessibilityAddTraits(hasDetailAction ? .isButton : [])
        .accessibilityAction {
            showDetailIfAvailable()
        }
        .onTapGesture {
            showDetailIfAvailable()
        }
        .sheet(isPresented: $showsSynastryOverviewDetail) {
            if let presentation = synastryOverviewPresentation {
                SynastryOverviewDetailSheet(
                    card: card,
                    presentation: presentation,
                    language: language
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.panel)
            }
        }
        .sheet(isPresented: $showsSynastryCardDetail) {
            SynastryCardDetailSheet(card: card, language: language)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.hidden)
                .presentationBackground(AppTheme.panel)
        }
    }

    private var isPrototypeTransitCard: Bool {
        prototypeTransitStyle && TransitContentPlan.cardIDs.contains(card.id)
    }

    private var showsGenericCopy: Bool {
        (!isPrototypeTransitCard || card.id == "current-story")
            && !synastryStructuredCardIDs.contains(card.id)
    }

    private var heroHeadline: Bool {
        card.id == "current-story" || card.id == "relationship-overview"
    }

    private var synastryOverviewPresentation: SynastryOverviewPresentation? {
        guard card.id == "relationship-overview",
              case let .bondOrbit(presentation) = card.visual
        else { return nil }
        return presentation
    }

    private var synastryStructuredCardIDs: Set<String> {
        ["perspectives", "emotional-connection", "communication", "chemistry", "commitment", "house-overlays", "key-inter-aspects"]
    }

    private var synastryDetailCardIDs: Set<String> {
        ["emotional-connection", "communication", "chemistry", "commitment"]
    }

    private var hasDetailAction: Bool {
        synastryOverviewPresentation != nil || synastryDetailCardIDs.contains(card.id)
    }

    private func showDetailIfAvailable() {
        if synastryOverviewPresentation != nil {
            showsSynastryOverviewDetail = true
        } else if synastryDetailCardIDs.contains(card.id) {
            showsSynastryCardDetail = true
        }
    }

}

func cardKicker(_ id: String, language: AppLanguage) -> String? {
    switch id {
    case "sky-overview": return localized("card.sky-overview.eyebrow", language: language)
    case "moon-now": return localized("insight.shared.moon-now", language: language)
    case "aspect-pattern": return localized("insight.shared.aspect-pattern", language: language)
    case "planetary-motion": return localized("insight.shared.planetary-motion", language: language)
    case "sign-changes": return localized("insight.shared.sign-changes", language: language)
    case "element-climate": return localized("insight.shared.element-climate", language: language)
    case "upcoming-7-days": return localized("insight.shared.upcoming-7-days", language: language)
    case "natal-interpretation": return localized("insight.shared.core-personality", language: language)
    case "emotional-needs": return localized("insight.shared.emotional-needs", language: language)
    case "love-connection": return localized("insight.shared.love-connection", language: language)
    case "career-direction": return localized("insight.shared.public-direction", language: language)
    case "strengths-growth": return localized("insight.shared.your-edges", language: language)
    case "element-balance": return localized("insight.shared.temperament", language: language)
    case "house-emphasis": return localized("insight.shared.concentration", language: language)
    case "chart-signature": return localized("insight.shared.signature", language: language)
    case "planet-placements": return localized("insight.shared.placements", language: language)
    case "key-aspects": return localized("insight.shared.key-aspects", language: language)
    case "current-story": return localized("insight.shared.the-big-picture", language: language)
    case "current-cycles": return localized("insight.shared.cycles", language: language)
    case "transit-timeline": return localized("insight.shared.timeline", language: language)
    case "planet-paths": return localized("insight.shared.planet-paths", language: language)
    case "life-areas": return localized("insight.shared.life-areas", language: language)
    case "active-transits": return localized("insight.shared.active-transits", language: language)
    case "developmental-chapter": return localized("insight.shared.current-development", language: language)
    case "progressed-moon": return localized("insight.shared.progressed-moon", language: language)
    case "identity-development": return localized("insight.shared.identity", language: language)
    case "turning-points": return localized("insight.shared.turning-points", language: language)
    case "areas-maturing": return localized("insight.shared.maturing", language: language)
    case "timeline": return localized("insight.shared.24-month-timeline", language: language)
    case "year-theme": return localized("insight.shared.year-theme", language: language)
    case "year-anchors": return localized("insight.shared.year-anchors", language: language)
    case "priority-areas": return localized("insight.shared.priority-areas", language: language)
    case "year-dynamics": return localized("insight.shared.year-dynamics", language: language)
    case "year-timeline": return localized("insight.shared.year-timeline", language: language)
    case "natal-overlay": return localized("insight.shared.natal-overlay", language: language)
    case "year-aspects": return localized("insight.shared.year-aspects", language: language)
    case "relationship-overview": return localized("insight.shared.the-bond", language: language)
    case "perspectives": return localized("insight.shared.perspectives", language: language)
    case "emotional-connection": return localized("insight.shared.emotional-connection", language: language)
    case "communication": return localized("insight.shared.communication", language: language)
    case "chemistry": return localized("insight.shared.chemistry", language: language)
    case "commitment": return localized("insight.shared.commitment", language: language)
    case "house-overlays": return localized("insight.shared.house-overlays", language: language)
    case "key-inter-aspects": return localized("insight.shared.key-inter-aspects", language: language)
    default: return nil
    }
}
