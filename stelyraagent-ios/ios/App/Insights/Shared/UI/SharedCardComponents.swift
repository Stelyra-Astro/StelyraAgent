import SwiftUI

// MARK: - Shared prototype primitives

private struct Kicker: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppTypography.eyebrow)
            .tracking(1.6)
            .foregroundStyle(AppTheme.violet)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
    }
}

enum InsightBadgeTone {
    case purple
    case warm
    case good
}

struct InsightBadge: View {
    let text: String
    var tone: InsightBadgeTone = .purple

    var body: some View {
        Text(text)
            .font(AppTypography.compactLabel)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
    }

    private var foreground: Color {
        switch tone {
        case .purple: AppTheme.violet
        case .warm: AppTheme.amber
        case .good: AppTheme.mint
        }
    }

    private var background: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.13)
        case .warm: AppTheme.amber.opacity(0.11)
        case .good: AppTheme.mint.opacity(0.11)
        }
    }

    private var border: Color {
        switch tone {
        case .purple: AppTheme.violet.opacity(0.22)
        case .warm: AppTheme.amber.opacity(0.18)
        case .good: AppTheme.mint.opacity(0.18)
        }
    }
}

struct TagChip: View {
    let text: String
    var tone: InsightTone = .neutral
    var body: some View {
        Text(text)
            .font(AppTypography.metadata.weight(.medium))
            .lineLimit(1)
            .truncationMode(.tail)
            .minimumScaleFactor(0.78)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(background, in: Capsule())
            .overlay(Capsule().stroke(border, lineWidth: 1))
            .foregroundStyle(foreground)
    }

    private var foreground: Color {
        tone == .neutral ? AppTheme.text.opacity(0.82) : AppTheme.tone(tone)
    }

    private var background: Color {
        tone == .neutral ? AppTheme.text.opacity(0.05) : AppTheme.tone(tone).opacity(0.1)
    }

    private var border: Color {
        tone == .neutral ? AppTheme.line : AppTheme.tone(tone).opacity(0.25)
    }
}

private struct SectionSub: View {
    let text: String
    var body: some View {
        Text(text)
            .font(AppTypography.supporting)
            .foregroundStyle(AppTheme.muted)
    }
}

// MARK: - Visual renderer
