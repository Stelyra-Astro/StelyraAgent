import SwiftUI

extension InsightVisualView {
    var gantt: some View {
        VStack(spacing: 12) {
            ForEach(Array(facts.prefix(4).enumerated()), id: \.offset) { _, fact in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(fact.label).font(AppTypography.scaled(12, weight: .semibold)).foregroundStyle(AppTheme.text)
                        Spacer()
                        if let note = fact.note {
                            Text(note).font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
                        }
                    }
                    GeometryReader { proxy in
                        ZStack(alignment: .leading) {
                            Capsule().fill(AppTheme.line.opacity(0.6)).frame(height: 6)
                            Capsule()
                                .fill(LinearGradient(colors: [AppTheme.blue.opacity(0.8), AppTheme.violet], startPoint: .leading, endPoint: .trailing))
                                .frame(width: proxy.size.width * max(0.12, min(0.88, fact.progress ?? 0.5)), height: 6)
                            // Main exact point (white + violet ring)
                            Circle()
                                .fill(Color.white)
                                .overlay(Circle().stroke(AppTheme.violet, lineWidth: 2.5))
                                .frame(width: 9, height: 9)
                                .offset(x: proxy.size.width * max(0.12, min(0.88, fact.progress ?? 0.5)) - 4.5)
                            // Repeating exact points (dark + violet ring)
                            ForEach(Array((fact.markers ?? []).enumerated()), id: \.offset) { _, marker in
                                if marker != (fact.progress ?? 0.5) {
                                    Circle()
                                        .fill(AppTheme.panel)
                                        .overlay(Circle().stroke(AppTheme.violet, lineWidth: 2))
                                        .frame(width: 7, height: 7)
                                        .offset(x: proxy.size.width * max(0.12, min(0.88, marker)) - 3.5)
                                }
                            }
                        }
                    }
                    .frame(height: 10)
                }
            }
        }
    }

    func progressedStage(phase: Double, moonProgress: Double, sunProgress: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().fill(AppTheme.panel).overlay(Circle().stroke(AppTheme.line))
                Circle().trim(from: 0, to: max(0.01, phase / 360))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text(progressedPhaseName(phase)).font(AppTypography.scaled(12, weight: .bold)).foregroundStyle(AppTheme.text)
                    Text("\(Int(phase))°").font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
                }
            }
            .frame(width: 108, height: 108)
            progressTrack(label: localized("insight.natal.moon", language: language), value: moonProgress, tone: .transition)
            progressTrack(label: localized("insight.natal.sun", language: language), value: sunProgress, tone: .supportive)
        }
    }

    func progressTrack(label: String, value: Double, tone: InsightTone) -> some View {
        HStack(spacing: 9) {
            Text(label).font(AppTypography.scaled(11, weight: .semibold)).foregroundStyle(AppTheme.muted).frame(width: 44, alignment: .leading)
            ProgressView(value: max(0, min(1, value))).tint(AppTheme.tone(tone))
            Text("\(Int(value * 30))°/30").font(AppTypography.scaled(10).monospacedDigit()).foregroundStyle(AppTheme.muted).frame(width: 52, alignment: .trailing)
        }
    }

    func progressedPhaseName(_ angle: Double) -> String {
        switch angle {
        case 0 ..< 90: localized("insight.secondary.new-phase", language: language)
        case 90 ..< 180: localized("insight.secondary.building-phase", language: language)
        case 180 ..< 270: localized("insight.secondary.review-phase", language: language)
        default: localized("insight.secondary.integration-phase", language: language)
        }
    }

    // MARK: - Signature trio / placements / aspects

    func moonProgressRing(progress: Double) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle().stroke(AppTheme.line.opacity(0.7), lineWidth: 2)
                Circle()
                    .trim(from: 0, to: max(0.02, min(1, progress)))
                    .stroke(AppTheme.violet, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("☽").font(AppTypography.scaled(24, weight: .semibold)).foregroundStyle(AppTheme.text)
            }
            .frame(width: 88, height: 88)
            factGrid(columns: 3)
        }
    }

    // MARK: - Compare strip (prototype .compare-strip)

    func compareStrip(natal: String, progressed: String) -> some View {
        HStack(spacing: 8) {
            VStack(spacing: 4) {
                Text(localized("insight.secondary.natal", language: language)).font(AppTypography.scaled(9, weight: .bold)).foregroundStyle(AppTheme.muted)
                Text(natal).font(AppTypography.scaled(11.5, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
            Image(systemName: "arrow.right").font(AppTypography.scaled(11)).foregroundStyle(AppTheme.muted)
            VStack(spacing: 4) {
                Text(localized("insight.secondary.now", language: language)).font(AppTypography.scaled(9, weight: .bold)).foregroundStyle(AppTheme.muted)
                Text(progressed).font(AppTypography.scaled(11.5, weight: .semibold)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
            .background(AppTheme.violet.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - Story weave (prototype .story-weave)

    func stageFlow(old: String, transition: String, emerging: String) -> some View {
        HStack(spacing: 6) {
            stageNode(label: localized("insight.secondary.old", language: language), value: old, active: false)
            Image(systemName: "arrow.right").font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("insight.secondary.transition", language: language), value: transition, active: true)
            Image(systemName: "arrow.right").font(AppTypography.scaled(10)).foregroundStyle(AppTheme.muted)
            stageNode(label: localized("insight.secondary.emerging", language: language), value: emerging, active: false)
        }
    }

    func stageNode(label: String, value: String, active: Bool) -> some View {
        VStack(spacing: 4) {
            Text(label).font(AppTypography.scaled(8.5, weight: .bold)).foregroundStyle(active ? AppTheme.violet : AppTheme.muted)
            Text(value).font(AppTypography.scaled(10, weight: .medium)).foregroundStyle(AppTheme.text).multilineTextAlignment(.center)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity)
        .padding(9)
        .background(active ? AppTheme.violet.opacity(0.12) : AppTheme.background.opacity(0.4), in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Solar return orbit with lines (prototype .year-orbit)
}
