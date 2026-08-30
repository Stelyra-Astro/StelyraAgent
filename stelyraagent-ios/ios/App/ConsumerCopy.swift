import AstroCore
import Foundation

enum ConsumerCopy {
    static func bodyTheme(_ body: CelestialBody?, language: AppLanguage) -> String {
        guard let body else {
            return localized("consumer.an-important-need", language: language)
        }
        return switch body {
        case .sun: localized("consumer.body-theme.sun", language: language)
        case .moon: localized("consumer.body-theme.moon", language: language)
        case .mercury: localized("consumer.body-theme.mercury", language: language)
        case .venus: localized("consumer.body-theme.venus", language: language)
        case .mars: localized("consumer.body-theme.mars", language: language)
        case .jupiter: localized("consumer.body-theme.jupiter", language: language)
        case .saturn: localized("consumer.body-theme.saturn", language: language)
        case .uranus: localized("consumer.body-theme.uranus", language: language)
        case .neptune: localized("consumer.body-theme.neptune", language: language)
        case .pluto: localized("consumer.body-theme.pluto", language: language)
        case .trueNode: localized("consumer.body-theme.true-node", language: language)
        case .lilith, .partOfFortune, .juno: localized("consumer.an-important-need", language: language)
        }
    }

    static func connectionTitle(_ aspect: ChartAspect, language: AppLanguage) -> String {
        let first = bodyName(CelestialBody(rawValue: aspect.firstID) ?? .sun, language: language)
        let second = bodyName(CelestialBody(rawValue: aspect.secondID) ?? .moon, language: language)
        if aspect.kind.supportive {
            return localizedTemplate("dynamic.030ed20d4e", substitutions: ["value1": String(describing: first), "value2": String(describing: second)], language: language)
        }
        if aspect.kind.challenging {
            return localizedTemplate("dynamic.b57a7b3fa7", substitutions: ["value1": String(describing: first), "value2": String(describing: second)], language: language)
        }
        return localizedTemplate("dynamic.909e84449b", substitutions: ["value1": String(describing: first), "value2": String(describing: second)], language: language)
    }

    static func connectionLabel(_ kind: AspectKind, language: AppLanguage) -> String {
        if kind.supportive {
            return localized("consumer.work-together-smoothly", language: language)
        }
        if kind.challenging {
            return localized("consumer.need-active-balancing", language: language)
        }
        return localized("consumer.become-active-together", language: language)
    }

    static func timing(_ phase: AspectPhase, language: AppLanguage) -> String {
        switch phase {
        case .applying:
            localized("consumer.the-influence-is-building", language: language)
        case .exact:
            localized("consumer.the-influence-is-clearest-now", language: language)
        case .separating:
            localized("consumer.the-influence-is-easing", language: language)
        }
    }

    static func intensity(_ strength: Double, language: AppLanguage) -> String {
        if strength >= 0.78 {
            return localized("consumer.very-noticeable", language: language)
        }
        if strength >= 0.52 {
            return localized("consumer.noticeable", language: language)
        }
        return localized("consumer.subtle-but-present", language: language)
    }

    static func lifeArea(_ house: Int?, language: AppLanguage) -> String {
        guard let house, (1 ... 12).contains(house) else {
            return localized("consumer.everyday-choices", language: language)
        }
        return switch house {
        case 1: localized("consumer.life-area.1", language: language)
        case 2: localized("consumer.life-area.2", language: language)
        case 3: localized("consumer.life-area.3", language: language)
        case 4: localized("consumer.life-area.4", language: language)
        case 5: localized("consumer.life-area.5", language: language)
        case 6: localized("consumer.life-area.6", language: language)
        case 7: localized("consumer.life-area.7", language: language)
        case 8: localized("consumer.life-area.8", language: language)
        case 9: localized("consumer.life-area.9", language: language)
        case 10: localized("consumer.life-area.10", language: language)
        case 11: localized("consumer.life-area.11", language: language)
        case 12: localized("consumer.life-area.12", language: language)
        default: localized("consumer.everyday-choices", language: language)
        }
    }

    static func style(signIndex: Int, language: AppLanguage) -> String {
        let index = max(0, min(11, signIndex))
        return switch index {
        case 0: localized("consumer.style.aries", language: language)
        case 1: localized("consumer.style.taurus", language: language)
        case 2: localized("consumer.style.gemini", language: language)
        case 3: localized("consumer.style.cancer", language: language)
        case 4: localized("consumer.style.leo", language: language)
        case 5: localized("consumer.style.virgo", language: language)
        case 6: localized("consumer.style.libra", language: language)
        case 7: localized("consumer.style.scorpio", language: language)
        case 8: localized("consumer.style.sagittarius", language: language)
        case 9: localized("consumer.style.capricorn", language: language)
        case 10: localized("consumer.style.aquarius", language: language)
        default: localized("consumer.style.pisces", language: language)
        }
    }

    static func motion(isRetrograde: Bool, language: AppLanguage) -> String {
        isRetrograde
            ? localized("consumer.a-review-and-adjust-period", language: language)
            : localized("consumer.moving-forward-steadily", language: language)
    }

    static func cycleStage(angle: Double, language: AppLanguage) -> String {
        switch angle {
        case 0 ..< 90:
            localized("consumer.a-beginning-and-building-stage", language: language)
        case 90 ..< 180:
            localized("consumer.an-active-development-stage", language: language)
        case 180 ..< 270:
            localized("consumer.a-visibility-and-review-stage", language: language)
        default:
            localized("consumer.a-completion-and-reset-stage", language: language)
        }
    }
}
