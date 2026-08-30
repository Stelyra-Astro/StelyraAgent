import AstroCore
import SwiftUI

enum AstrologyWheelGeometry {
    /// ASC is fixed at the left edge. Increasing zodiac longitude proceeds
    /// from ASC toward the lower half of the screen, matching the conventional
    /// counter-clockwise house order in a screen coordinate system (positive Y
    /// points downward).
    static func point(
        center: CGPoint,
        radius: Double,
        longitude: Double,
        ascendantRotation: Double
    ) -> CGPoint {
        let angle = (180 - (longitude - ascendantRotation)) * .pi / 180
        return CGPoint(
            x: center.x + cos(angle) * radius,
            y: center.y + sin(angle) * radius
        )
    }
}

struct ChartWheelView: View {
    let snapshot: ChartSnapshot
    let reference: ChartSnapshot?
    let comparisonAspects: [ChartAspect]
    let language: AppLanguage
    let horaryOverlay: HoraryOverlay?
    @ScaledMetric(relativeTo: .caption) private var dynamicTextScale: CGFloat = 1

    init(
        snapshot: ChartSnapshot,
        reference: ChartSnapshot?,
        comparisonAspects: [ChartAspect],
        language: AppLanguage,
        horaryOverlay: HoraryOverlay? = nil
    ) {
        self.snapshot = snapshot
        self.reference = reference
        self.comparisonAspects = comparisonAspects
        self.language = language
        self.horaryOverlay = horaryOverlay
    }

    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) * 0.47
            let typographyScale = min(1.34, max(1, min(size.width, size.height) / 345)) * dynamicTextScale
            let rotation = reference?.angles.ascendantDegrees ?? snapshot.angles.ascendantDegrees

            drawCircle(context: &context, center: center, radius: radius, color: AppTheme.text.opacity(0.32))
            drawCircle(context: &context, center: center, radius: radius * 0.82, color: AppTheme.text.opacity(0.14))
            drawCircle(context: &context, center: center, radius: radius * 0.61, color: AppTheme.text.opacity(0.09))
            drawDegreeTicks(
                context: &context,
                center: center,
                radius: radius,
                rotation: rotation
            )

            for index in 0 ..< 12 {
                let boundary = Double(index * 30)
                let outer = point(center: center, radius: radius, longitude: boundary, rotation: rotation)
                let inner = point(center: center, radius: radius * 0.82, longitude: boundary, rotation: rotation)
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                context.stroke(path, with: .color(AppTheme.text.opacity(0.14)), lineWidth: 0.8)

                let labelPoint = point(
                    center: center,
                    radius: radius * 0.91,
                    longitude: boundary + 15,
                    rotation: rotation
                )
                context.draw(
                    Text(zodiacWheelLabel(index))
                        .font(
                            .system(
                                size: (language == .english ? 9.0 : 9.5) * typographyScale,
                                weight: .semibold
                            )
                        )
                        .foregroundStyle(AppTheme.muted),
                    at: labelPoint
                )
            }

            let houseSnapshot = reference ?? snapshot
            drawHighlightedHouses(
                horaryOverlay?.highlightedHouses ?? [],
                houses: houseSnapshot.houses,
                context: &context,
                center: center,
                innerRadius: radius * 0.61,
                outerRadius: radius * 0.82,
                rotation: rotation
            )
            for (index, house) in houseSnapshot.houses.enumerated() {
                let outer = point(center: center, radius: radius * 0.82, longitude: house.cuspDegrees, rotation: rotation)
                let inner = point(center: center, radius: radius * 0.61, longitude: house.cuspDegrees, rotation: rotation)
                var path = Path()
                path.move(to: inner)
                path.addLine(to: outer)
                context.stroke(
                    path,
                    with: .color(house.number == 1 || house.number == 10 ? AppTheme.violet.opacity(0.8) : AppTheme.text.opacity(0.12)),
                    lineWidth: house.number == 1 || house.number == 10 ? 1.6 : 0.7
                )

                let nextHouse = houseSnapshot.houses[(index + 1) % houseSnapshot.houses.count]
                let houseLongitude = circularMidpoint(
                    from: house.cuspDegrees,
                    to: nextHouse.cuspDegrees
                )
                context.draw(
                    Text("\(house.number)")
                        .font(.system(size: 9 * typographyScale, weight: .semibold))
                        .foregroundStyle(
                            horaryOverlay?.highlightedHouses.contains(house.number) == true
                                ? AppTheme.violet
                                : AppTheme.muted.opacity(0.78)
                        ),
                    at: point(
                        center: center,
                        radius: radius * 0.64,
                        longitude: houseLongitude,
                        rotation: rotation
                    )
                )
            }

            drawAxes(
                angles: houseSnapshot.angles,
                context: &context,
                center: center,
                radius: radius * 0.82,
                rotation: rotation,
                typographyScale: typographyScale
            )

            if let reference {
                drawComparisonAspectLines(
                    comparisonAspects,
                    context: &context,
                    center: center,
                    movingRadius: radius * 0.62,
                    referenceRadius: radius * 0.48,
                    rotation: rotation
                )
                drawPoints(
                    reference.points,
                    context: &context,
                    center: center,
                    radius: radius * 0.52,
                    rotation: rotation,
                    color: AppTheme.muted,
                    fontSize: 9 * typographyScale,
                    degreeFontSize: 8 * typographyScale,
                    showsDegrees: true,
                    labels: [:]
                )
                drawPoints(
                    snapshot.points,
                    context: &context,
                    center: center,
                    radius: radius * 0.70,
                    rotation: rotation,
                    color: AppTheme.violet,
                    fontSize: 9.5 * typographyScale,
                    degreeFontSize: 8 * typographyScale,
                    showsDegrees: true,
                    labels: [:]
                )
            } else {
                drawAspectLines(
                    snapshot.aspects,
                    context: &context,
                    center: center,
                    radius: radius * 0.57,
                    rotation: rotation,
                    keyAspectIDs: horaryOverlay?.keyAspectIDs ?? []
                )
                drawPoints(
                    snapshot.points,
                    context: &context,
                    center: center,
                    radius: radius * 0.70,
                    rotation: rotation,
                    color: AppTheme.text,
                    fontSize: 9.5 * typographyScale,
                    degreeFontSize: 8 * typographyScale,
                    showsDegrees: true,
                    labels: horaryOverlay?.planetLabels ?? [:]
                )
            }

            context.draw(
                Text(reference == nil ? "◎" : "◉")
                    .font(AppTypography.scaled(20, weight: .light))
                    .foregroundStyle(AppTheme.violet.opacity(0.7)),
                at: center
            )
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel(
            reference == nil
                ? localized("chart.astrology-wheel", language: language)
                : localized("chart.double-astrology-wheel", language: language)
        )
        .accessibilityIdentifier("astrology-wheel")
    }

    private func drawHighlightedHouses(
        _ highlighted: Set<Int>,
        houses: [ChartHouse],
        context: inout GraphicsContext,
        center: CGPoint,
        innerRadius: Double,
        outerRadius: Double,
        rotation: Double
    ) {
        guard !highlighted.isEmpty, houses.count == 12 else { return }
        for index in houses.indices where highlighted.contains(houses[index].number) {
            let start = houses[index].cuspDegrees
            var end = houses[(index + 1) % houses.count].cuspDegrees
            while end <= start { end += 360 }
            var path = Path()
            let steps = max(6, Int((end - start) / 2))
            path.move(to: point(center: center, radius: innerRadius, longitude: start, rotation: rotation))
            for step in 0 ... steps {
                let longitude = start + (end - start) * Double(step) / Double(steps)
                path.addLine(
                    to: point(
                        center: center,
                        radius: outerRadius,
                        longitude: longitude,
                        rotation: rotation
                    )
                )
            }
            for step in (0 ... steps).reversed() {
                let longitude = start + (end - start) * Double(step) / Double(steps)
                path.addLine(
                    to: point(
                        center: center,
                        radius: innerRadius,
                        longitude: longitude,
                        rotation: rotation
                    )
                )
            }
            path.closeSubpath()
            context.fill(path, with: .color(AppTheme.violet.opacity(0.11)))
        }
    }

    private func drawCircle(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        color: Color
    ) {
        let rect = CGRect(
            x: center.x - radius,
            y: center.y - radius,
            width: radius * 2,
            height: radius * 2
        )
        context.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 1)
    }

    private func drawDegreeTicks(
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double
    ) {
        for degree in 0 ..< 360 {
            let isTen = degree.isMultiple(of: 10)
            let isFive = degree.isMultiple(of: 5)
            let tickLength = isTen ? 7.0 : isFive ? 4.5 : 2.2
            let opacity = isTen ? 0.3 : isFive ? 0.18 : 0.09
            var tick = Path()
            tick.move(
                to: point(
                    center: center,
                    radius: radius - tickLength,
                    longitude: Double(degree),
                    rotation: rotation
                )
            )
            tick.addLine(
                to: point(
                    center: center,
                    radius: radius,
                    longitude: Double(degree),
                    rotation: rotation
                )
            )
            context.stroke(
                tick,
                with: .color(AppTheme.text.opacity(opacity)),
                lineWidth: isTen ? 0.75 : 0.45
            )
        }
    }

    private func drawAxes(
        angles: NatalAngles,
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double,
        typographyScale: Double
    ) {
        let axes: [(String, Double, Bool)] = [
            (localized("chart.rising", language: language), angles.ascendantDegrees, true),
            (localized("chart.setting", language: language), angles.ascendantDegrees + 180, false),
            (localized("chart.midheaven", language: language), angles.midheavenDegrees, true),
            (localized("chart.nadir", language: language), angles.midheavenDegrees + 180, false),
        ]
        for (label, longitude, emphasized) in axes {
            var path = Path()
            path.move(to: center)
            path.addLine(
                to: point(
                    center: center,
                    radius: radius,
                    longitude: longitude,
                    rotation: rotation
                )
            )
            context.stroke(
                path,
                with: .color(
                    emphasized
                        ? AppTheme.violet.opacity(0.48)
                        : AppTheme.text.opacity(0.13)
                ),
                lineWidth: emphasized ? 1.15 : 0.75
            )
            context.draw(
                Text(label)
                    .font(
                        .system(
                            size: (language == .english ? 8.2 : 8.6) * typographyScale,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(
                        emphasized
                            ? AppTheme.violet
                            : AppTheme.muted.opacity(0.76)
                    ),
                at: point(
                    center: center,
                    radius: radius * 0.92,
                    longitude: longitude,
                    rotation: rotation
                )
            )
        }
    }

    private func drawPoints(
        _ points: [ChartPoint],
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double,
        color: Color,
        fontSize: Double,
        degreeFontSize: Double,
        showsDegrees: Bool,
        labels: [CelestialBody: String]
    ) {
        let sorted = circularlySorted(points)
        let minimumSpacing = language == .english ? 17.0 : 15.0
        var adjusted: [(ChartPoint, Double)] = []
        for pointValue in sorted {
            var longitude = pointValue.longitudeDegrees
            if let first = adjusted.first?.1 {
                while longitude < first { longitude += 360 }
            }
            if let previous = adjusted.last?.1, longitude - previous < minimumSpacing {
                longitude = previous + minimumSpacing
            }
            adjusted.append((pointValue, longitude))
        }
        for (pointValue, longitude) in adjusted {
            let location = point(center: center, radius: radius, longitude: longitude, rotation: rotation)
            let anchor = point(
                center: center,
                radius: radius - 13,
                longitude: pointValue.longitudeDegrees,
                rotation: rotation
            )
            var leader = Path()
            leader.move(to: anchor)
            leader.addLine(
                to: point(
                    center: center,
                    radius: radius - 5,
                    longitude: longitude,
                    rotation: rotation
                )
            )
            context.stroke(leader, with: .color(color.opacity(0.28)), lineWidth: 0.55)
            let role = labels[pointValue.body].map { "\n\($0)" } ?? ""
            let label = Text(wheelBodyLabel(pointValue.body) + retrogradeLabel(pointValue))
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundColor(color)
                + Text(showsDegrees ? "\n\(Int(pointValue.degreeInSign))°" : "")
                .font(.system(size: degreeFontSize, weight: .medium))
                .foregroundColor(color.opacity(0.7))
                + Text(role)
                .font(.system(size: max(8, degreeFontSize), weight: .bold))
                .foregroundColor(AppTheme.violet)
            context.draw(
                label,
                at: location
            )
        }
    }

    private func zodiacWheelLabel(_ index: Int) -> String {
        let name = Zodiac.name(index: index, language: language)
        if language == .simplifiedChinese {
            return name.replacingOccurrences(of: "座", with: "")
        }
        return String(name.prefix(3))
    }

    private func wheelBodyLabel(_ body: CelestialBody) -> String {
        let name = bodyName(body, language: language)
        return language == .simplifiedChinese ? String(name.prefix(2)) : String(name.prefix(5))
    }

    private func retrogradeLabel(_ point: ChartPoint) -> String {
        guard point.retrograde else { return "" }
        return localized("chart.retrograde-marker", language: language)
    }

    private func circularMidpoint(from start: Double, to rawEnd: Double) -> Double {
        var end = rawEnd
        while end < start { end += 360 }
        return (start + (end - start) / 2).truncatingRemainder(dividingBy: 360)
    }

    private func circularlySorted(_ points: [ChartPoint]) -> [ChartPoint] {
        let sorted = points.sorted { $0.longitudeDegrees < $1.longitudeDegrees }
        guard sorted.count > 1 else { return sorted }
        var largestGap = -Double.infinity
        var startIndex = 0
        for index in sorted.indices {
            let nextIndex = (index + 1) % sorted.count
            let nextLongitude = nextIndex == 0
                ? sorted[nextIndex].longitudeDegrees + 360
                : sorted[nextIndex].longitudeDegrees
            let gap = nextLongitude - sorted[index].longitudeDegrees
            if gap > largestGap {
                largestGap = gap
                startIndex = nextIndex
            }
        }
        return Array(sorted[startIndex...]) + Array(sorted[..<startIndex])
    }

    private func drawAspectLines(
        _ aspects: [ChartAspect],
        context: inout GraphicsContext,
        center: CGPoint,
        radius: Double,
        rotation: Double,
        keyAspectIDs: Set<String>
    ) {
        for aspect in aspects.prefix(18) {
            let emphasized = keyAspectIDs.contains(aspect.id)
            var path = Path()
            path.move(to: point(center: center, radius: radius, longitude: aspect.firstLongitude, rotation: rotation))
            path.addLine(to: point(center: center, radius: radius, longitude: aspect.secondLongitude, rotation: rotation))
            context.stroke(
                path,
                with: .color(
                    AppTheme.tone(tone(aspect.kind))
                        .opacity(emphasized ? 0.92 : 0.18 + aspect.strength * 0.32)
                ),
                lineWidth: emphasized ? 2.4 : 0.5 + aspect.strength
            )
        }
    }

    private func drawComparisonAspectLines(
        _ aspects: [ChartAspect],
        context: inout GraphicsContext,
        center: CGPoint,
        movingRadius: Double,
        referenceRadius: Double,
        rotation: Double
    ) {
        for aspect in aspects.prefix(18) {
            var path = Path()
            path.move(
                to: point(
                    center: center,
                    radius: movingRadius,
                    longitude: aspect.firstLongitude,
                    rotation: rotation
                )
            )
            path.addLine(
                to: point(
                    center: center,
                    radius: referenceRadius,
                    longitude: aspect.secondLongitude,
                    rotation: rotation
                )
            )
            context.stroke(
                path,
                with: .color(AppTheme.tone(tone(aspect.kind)).opacity(0.25 + aspect.strength * 0.4)),
                lineWidth: 0.5 + aspect.strength
            )
        }
    }

    private func point(center: CGPoint, radius: Double, longitude: Double, rotation: Double) -> CGPoint {
        AstrologyWheelGeometry.point(
            center: center,
            radius: radius,
            longitude: longitude,
            ascendantRotation: rotation
        )
    }
}

struct AspectChartView: View {
    let aspects: [ChartAspect]
    let movingPoints: [ChartPoint]
    let referencePoints: [ChartPoint]
    let language: AppLanguage
    let comparison: Bool
    @ScaledMetric(relativeTo: .caption) private var matrixScale: CGFloat = 1

    var body: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text(
                        comparison
                            ? localized("chart.moving-natal", language: language)
                            : localized("chart.single-chart-aspects", language: language)
                    )
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppTheme.text)
                    Spacer()
                    Text(
                        comparison
                            ? localized("chart.rows-move", language: language)
                            : localized("chart.lower-triangle", language: language)
                    )
                    .font(.footnote)
                    .foregroundStyle(AppTheme.muted)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    aspectMatrix
                        .padding(.vertical, 2)
                }

                HStack(spacing: 12) {
                    legend(.supportive, label: localized("chart.flow", language: language))
                    legend(.challenging, label: localized("chart.tone.tension", language: language))
                    legend(.transition, label: localized("chart.change", language: language))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel(localized("chart.aspect-matrix", language: language))

            VStack(spacing: 0) {
                ForEach(aspects.prefix(12)) { aspect in
                    HStack(spacing: 12) {
                        Text(aspect.kind.symbol)
                            .font(.title3)
                            .foregroundStyle(AppTheme.tone(tone(aspect.kind)))
                            .frame(width: 26)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(displayTitle(aspect))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppTheme.text)
                            Text("\(localized("chart.orb", language: language)) \(formatOrb(aspect.orbDegrees)) · \(phaseLabel(aspect.phase, language: language))")
                                .font(.caption)
                                .foregroundStyle(AppTheme.muted)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 10)
                    if aspect.id != aspects.prefix(12).last?.id {
                        Divider().overlay(AppTheme.line)
                    }
                }
            }
        }
        .padding(16)
        .background(AppTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(AppTheme.line))
    }

    private var matrixColumns: [CelestialBody] {
        let points = comparison ? referencePoints : movingPoints
        return CelestialBody.allCases.filter { body in
            points.contains { $0.body == body }
        }
    }

    private var matrixRows: [CelestialBody] {
        let points = movingPoints
        return CelestialBody.allCases.filter { body in
            points.contains { $0.body == body }
        }
    }

    private var aspectMatrix: some View {
        let rows = matrixRows
        let columns = matrixColumns
        return VStack(spacing: 3) {
            HStack(spacing: 3) {
                matrixCorner
                ForEach(columns) { body in
                    Text(body.symbol)
                        .font(AppTypography.scaled(comparison ? 14 : 13, weight: .semibold))
                        .foregroundStyle(comparison ? AppTheme.muted : AppTheme.violet)
                        .frame(width: matrixCellSize, height: matrixCellSize)
                        .accessibilityLabel(bodyName(body, language: language))
                }
            }

            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, rowBody in
                HStack(spacing: 3) {
                    Text(rowBody.symbol)
                        .font(AppTypography.scaled(comparison ? 14 : 13, weight: .semibold))
                        .foregroundStyle(comparison ? AppTheme.violet : AppTheme.muted)
                        .frame(width: matrixCellSize, height: matrixCellSize)
                        .accessibilityLabel(bodyName(rowBody, language: language))

                    ForEach(Array(columns.enumerated()), id: \.element.id) { columnIndex, columnBody in
                        matrixCell(
                            row: rowBody,
                            column: columnBody,
                            rowIndex: rowIndex,
                            columnIndex: columnIndex
                        )
                    }
                }
            }
        }
    }

    private var matrixCorner: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.panelRaised.opacity(0.65))
            if comparison {
                Path { path in
                    path.move(to: CGPoint(x: 4, y: matrixCellSize - 4))
                    path.addLine(to: CGPoint(x: matrixCellSize - 4, y: 4))
                }
                .stroke(AppTheme.line, lineWidth: 1)
            }
        }
        .frame(width: matrixCellSize, height: matrixCellSize)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func matrixCell(
        row: CelestialBody,
        column: CelestialBody,
        rowIndex: Int,
        columnIndex: Int
    ) -> some View {
        if !comparison, columnIndex >= rowIndex {
            RoundedRectangle(cornerRadius: 5)
                .fill(
                    columnIndex == rowIndex
                        ? AppTheme.violet.opacity(0.09)
                        : Color.clear
                )
                .frame(width: matrixCellSize, height: matrixCellSize)
                .accessibilityHidden(true)
        } else if let aspect = matrixAspect(row: row, column: column) {
            Text(aspect.kind.symbol)
                .font(AppTypography.scaled(comparison ? 14 : 13, weight: .bold))
                .foregroundStyle(AppTheme.tone(tone(aspect.kind)))
                .frame(width: matrixCellSize, height: matrixCellSize)
                .background(
                    AppTheme.tone(tone(aspect.kind)).opacity(0.12 + aspect.strength * 0.13),
                    in: RoundedRectangle(cornerRadius: 5)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(
                            AppTheme.tone(tone(aspect.kind)).opacity(0.24),
                            lineWidth: 0.7
                        )
                )
                .accessibilityLabel(displayTitle(aspect))
                .accessibilityValue(
                    "\(localized("chart.orb", language: language)) \(formatOrb(aspect.orbDegrees)), \(phaseLabel(aspect.phase, language: language))"
                )
        } else {
            RoundedRectangle(cornerRadius: 5)
                .fill(AppTheme.panelRaised.opacity(0.42))
                .frame(width: matrixCellSize, height: matrixCellSize)
                .overlay(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(AppTheme.line, lineWidth: 0.6)
                )
                .accessibilityLabel(
                    localizedTemplate("dynamic.a9c7b4e126", substitutions: ["value1": String(describing: bodyName(row, language: language)), "value2": String(describing: bodyName(column, language: language))], language: language)
                )
        }
    }

    private func matrixAspect(
        row: CelestialBody,
        column: CelestialBody
    ) -> ChartAspect? {
        aspects.first { aspect in
            if comparison {
                return aspect.firstID == row.id && aspect.secondID == column.id
            }
            return (aspect.firstID == row.id && aspect.secondID == column.id)
                || (aspect.firstID == column.id && aspect.secondID == row.id)
        }
    }

    private var matrixCellSize: CGFloat {
        (comparison ? 34 : 28) * matrixScale
    }

    private func legend(_ tone: InsightTone, label: String) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(AppTheme.tone(tone))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.footnote)
                .foregroundStyle(AppTheme.muted)
        }
    }

    private func displayTitle(_ aspect: ChartAspect) -> String {
        guard comparison else { return aspectTitle(aspect, language: language) }
        let moving = CelestialBody(rawValue: aspect.firstID)
            .map { bodyName($0, language: language) } ?? aspect.firstID
        let natal = CelestialBody(rawValue: aspect.secondID)
            .map { bodyName($0, language: language) } ?? aspect.secondID
        return localizedTemplate("dynamic.c7aa5a5c6b", substitutions: ["value1": String(describing: moving), "value2": String(describing: aspect.kind.symbol), "value3": String(describing: natal)], language: language)
    }
}
