import SwiftUI
import UIKit

enum AppTheme {
    static let background = adaptive(
        light: UIColor(red: 0.965, green: 0.972, blue: 0.992, alpha: 1),
        dark: UIColor(red: 0.027, green: 0.035, blue: 0.063, alpha: 1)
    )
    static let backgroundAccent = adaptive(
        light: UIColor(red: 0.91, green: 0.925, blue: 0.985, alpha: 1),
        dark: UIColor(red: 0.043, green: 0.055, blue: 0.094, alpha: 1)
    )
    static let panel = adaptive(
        light: UIColor(red: 0.992, green: 0.994, blue: 1, alpha: 1),
        dark: UIColor(red: 0.067, green: 0.086, blue: 0.133, alpha: 1)
    )
    static let panelRaised = adaptive(
        light: UIColor(red: 0.925, green: 0.936, blue: 0.975, alpha: 1),
        dark: UIColor(red: 0.09, green: 0.114, blue: 0.173, alpha: 1)
    )
    static let line = adaptive(
        light: UIColor(red: 0.16, green: 0.19, blue: 0.29, alpha: 0.12),
        dark: UIColor(white: 1, alpha: 0.085)
    )
    static let text = adaptive(
        light: UIColor(red: 0.09, green: 0.105, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.969, green: 0.973, blue: 0.988, alpha: 1)
    )
    static let muted = adaptive(
        light: UIColor(red: 0.37, green: 0.40, blue: 0.49, alpha: 1),
        dark: UIColor(red: 0.588, green: 0.624, blue: 0.706, alpha: 1)
    )
    static let violet = adaptive(
        light: UIColor(red: 0.42, green: 0.31, blue: 0.83, alpha: 1),
        dark: UIColor(red: 0.655, green: 0.537, blue: 1.0, alpha: 1)
    )
    static let blue = adaptive(
        light: UIColor(red: 0.27, green: 0.36, blue: 0.82, alpha: 1),
        dark: UIColor(red: 0.431, green: 0.533, blue: 1.0, alpha: 1)
    )
    static let mint = adaptive(
        light: UIColor(red: 0.12, green: 0.57, blue: 0.39, alpha: 1),
        dark: UIColor(red: 0.49, green: 0.867, blue: 0.722, alpha: 1)
    )
    static let amber = adaptive(
        light: UIColor(red: 0.72, green: 0.46, blue: 0.08, alpha: 1),
        dark: UIColor(red: 0.945, green: 0.792, blue: 0.482, alpha: 1)
    )
    static let coral = adaptive(
        light: UIColor(red: 0.78, green: 0.25, blue: 0.32, alpha: 1),
        dark: UIColor(red: 0.961, green: 0.604, blue: 0.671, alpha: 1)
    )
    static let moonLit = adaptive(
        light: UIColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 1),
        dark: UIColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 1)
    )
    static let moonShadow = adaptive(
        light: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1),
        dark: UIColor(red: 0.08, green: 0.10, blue: 0.16, alpha: 1)
    )

    static func tone(_ tone: InsightTone) -> Color {
        switch tone {
        case .supportive: mint
        case .challenging: coral
        case .transition: amber
        case .neutral: blue
        }
    }

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(
            uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark ? dark : light
            }
        )
    }
}

enum AppTypography {
    static let eyebrow = Font.footnote.weight(.bold)
    static let supporting = Font.footnote
    static let label = Font.subheadline.weight(.semibold)
    static let summary = Font.callout
    static let body = Font.body
    static let compactLabel = Font.caption.weight(.semibold)
    static let metadata = Font.caption
    static let factValue = Font.subheadline.weight(.semibold)

    /// Maps the prototype's point-size hierarchy onto Dynamic Type styles.
    /// Fixed `.system(size:)` fonts ignore the app's text-size preference.
    static func scaled(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base: Font = switch size {
        case ..<9.5: .caption2
        case ..<11.5: .caption
        case ..<12.5: .footnote
        case ..<14: .subheadline
        case ..<16: .callout
        case ..<18: .body
        case ..<20: .title3
        case ..<23: .title2
        case ..<28: .title
        default: .largeTitle
        }
        return base.weight(weight)
    }
}

struct CardSurface: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(16)
            .background(
                LinearGradient(
                    colors: [AppTheme.panelRaised, AppTheme.panel],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(AppTheme.line, lineWidth: 1)
            )
    }
}

extension View {
    func cardSurface() -> some View {
        modifier(CardSurface())
    }

    /// Makes custom bottom-sheet actions respond across their full visual
    /// surface. Without an explicit content shape, plain buttons inside a
    /// ScrollView can leave only the text itself reliably tappable.
    func drawerTapTarget(minHeight: CGFloat = 48) -> some View {
        frame(maxWidth: .infinity, minHeight: minHeight)
            .contentShape(Rectangle())
    }
}
