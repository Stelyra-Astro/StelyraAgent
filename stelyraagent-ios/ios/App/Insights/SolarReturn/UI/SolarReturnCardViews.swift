import SwiftUI

extension InsightVisualView {
    var yearOrbit: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(AppTheme.violet.opacity(0.35), lineWidth: 1).frame(width: 118, height: 118)
                Circle().stroke(AppTheme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 4])).frame(width: 88, height: 88)
                Circle().fill(AppTheme.violet.opacity(0.12)).frame(width: 40, height: 40)
                Text("☉").font(AppTypography.scaled(18, weight: .bold)).foregroundStyle(AppTheme.text)
                Text("↑").font(AppTypography.scaled(13, weight: .bold)).foregroundStyle(AppTheme.mint)
                    .offset(x: 0, y: -64)
                Text("♄").font(AppTypography.scaled(12, weight: .semibold)).foregroundStyle(AppTheme.amber)
                    .offset(x: 55, y: 26)
                Text("♃").font(AppTypography.scaled(12, weight: .semibold)).foregroundStyle(AppTheme.blue)
                    .offset(x: -52, y: 34)
            }
            .frame(width: 128, height: 128)
            HStack(spacing: 9) {
                ForEach(Array(facts.prefix(3).enumerated()), id: \.offset) { _, fact in
                    trioCell(label: fact.label, value: fact.value)
                }
            }
        }
    }

    // MARK: - Dual insight (prototype .dual-insight)

    var quarterTabs: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { index, fact in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fact.label)
                            .font(AppTypography.scaled(10, weight: .bold))
                            .foregroundStyle(index == 0 ? AppTheme.violet : AppTheme.muted)
                        Text(fact.value)
                            .font(AppTypography.scaled(10))
                            .foregroundStyle(AppTheme.muted)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(9)
                    .background(index == 0 ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 11))
                }
            }
            if let opening = facts.first, !opening.value.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text(opening.value)
                        .font(AppTypography.scaled(13, weight: .bold))
                        .foregroundStyle(AppTheme.text)
                    if let note = opening.note {
                        Text(note)
                            .font(AppTypography.scaled(11))
                            .foregroundStyle(AppTheme.muted)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 13))
            }
        }
    }

    func natalOverlay(firstLabel: String, firstValue: String, secondLabel: String, secondValue: String) -> some View {
        HStack(spacing: 8) {
            compareNode(label: firstLabel, value: firstValue, tone: .supportive)
            Text("↔").font(AppTypography.scaled(15, weight: .bold)).foregroundStyle(AppTheme.muted)
            compareNode(label: secondLabel, value: secondValue, tone: .challenging)
        }
    }

    func compareNode(label: String, value: String, tone: InsightTone) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(AppTypography.scaled(8.5, weight: .bold))
                .tracking(1.1)
                .foregroundStyle(AppTheme.tone(tone))
            Text(value)
                .font(AppTypography.scaled(11.5, weight: .semibold))
                .foregroundStyle(AppTheme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(AppTheme.tone(tone).opacity(0.08), in: RoundedRectangle(cornerRadius: 13))
    }
}
