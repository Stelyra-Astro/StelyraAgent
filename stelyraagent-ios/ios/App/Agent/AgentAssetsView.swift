import AstroCore
import SwiftUI

struct AgentAssetsView: View {
    @ObservedObject var store: AgentChartAssetStore
    let conversationID: UUID?
    let language: AppLanguage

    var body: some View {
        NavigationStack {
            Group {
                if let conversationID {
                    let assets = store.assets(for: conversationID)
                    if assets.isEmpty {
                        ContentUnavailableView(
                            "No charts yet",
                            systemImage: "circle.hexagongrid",
                            description: Text("Charts calculated by StelyraAgent will appear here.")
                        )
                    } else {
                        List(assets) { asset in
                            NavigationLink {
                                AgentChartDetailView(store: store, asset: asset, language: language)
                            } label: {
                                assetRow(asset)
                            }
                        }
                    }
                } else {
                    ContentUnavailableView("No conversation", systemImage: "bubble.left.and.bubble.right")
                }
            }
            .navigationTitle("Assets")
        }
    }

    private func assetRow(_ asset: ConversationChartAsset) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(displayTitle(asset.chartKind)).font(.headline)
            Text(asset.displaySubjects.joined(separator: " + ")).font(.subheadline)
            if let location = asset.locationSummary { Text(location).font(.caption).foregroundStyle(.secondary) }
            if let time = asset.timeSummary { Text(time).font(.caption).foregroundStyle(.secondary) }
            if let resolution = asset.resolution { Text(resolution).font(.caption2).foregroundStyle(.tertiary) }
        }
        .padding(.vertical, 4)
    }

    private func displayTitle(_ capability: String) -> String {
        agentChartDisplayTitle(capability)
    }
}

struct AgentChartDetailView: View {
    @ObservedObject var store: AgentChartAssetStore
    let asset: ConversationChartAsset
    let language: AppLanguage

    private var payload: AgentComputedChartPayload? { store.computedPayload(for: asset) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                subjectCard
                if let payload {
                    wheelSection(payload)
                    positionsSection(payload)
                    aspectsSection(payload)
                    housesSection(payload)
                    calculationDetails(payload)
                } else {
                    ContentUnavailableView(
                        "Chart data unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text("The local physical artifact for this chart could not be decoded.")
                    )
                }
            }
            .padding(16)
        }
        .navigationTitle(agentChartDisplayTitle(asset.chartKind))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var subjectCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(agentChartDisplayTitle(asset.chartKind)).font(.title2.weight(.bold))
            Text(asset.displaySubjects.joined(separator: " + ")).font(.headline)
            if let time = asset.timeSummary { Label(time, systemImage: "calendar") }
            if let location = asset.locationSummary { Label(location, systemImage: "mappin.and.ellipse") }
            if let resolution = asset.resolution { Label(resolution, systemImage: "scope") }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    @ViewBuilder
    private func wheelSection(_ payload: AgentComputedChartPayload) -> some View {
        chartSection("Wheel") {
            if !payload.relationshipArtifacts.isEmpty {
                ForEach(Array(payload.relationshipArtifacts.enumerated()), id: \.offset) { _, artifact in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(artifact.kind.title(language: language)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                        ChartWheelView(
                            snapshot: artifact.snapshot,
                            reference: artifact.reference,
                            comparisonAspects: artifact.reference == nil ? [] : artifact.comparisonAspects,
                            language: language
                        )
                        .frame(height: 350)
                    }
                }
            } else if let snapshot = payload.snapshots.last {
                ChartWheelView(
                    snapshot: snapshot,
                    reference: payload.snapshots.count > 1 ? payload.snapshots.first : nil,
                    comparisonAspects: payload.comparisonAspects,
                    language: language
                )
                .frame(height: 350)
            } else {
                Text("No wheel data is available.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func positionsSection(_ payload: AgentComputedChartPayload) -> some View {
        chartSection("Positions") {
            if let snapshot = payload.snapshots.last {
                ForEach(Array(snapshot.points.enumerated()), id: \.offset) { _, point in
                    HStack(alignment: .firstTextBaseline) {
                        Text(point.body.rawValue.capitalized).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(signName(point.signIndex)) · \(format(point.degreeInSign))° · H\(snapshot.house(containing: point.longitudeDegrees))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Divider()
                }
            } else {
                Text("No position data is available.").foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func aspectsSection(_ payload: AgentComputedChartPayload) -> some View {
        chartSection("Aspects") {
            let aspects = payload.comparisonAspects.isEmpty
                ? (payload.snapshots.last?.aspects ?? [])
                : payload.comparisonAspects
            if aspects.isEmpty {
                Text("No aspects were retained for this chart.").foregroundStyle(.secondary)
            } else {
                ForEach(Array(aspects.sorted { $0.strength > $1.strength }.enumerated()), id: \.offset) { _, aspect in
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(aspect.firstID) · \(aspect.kind.rawValue) · \(aspect.secondID)")
                                .font(.subheadline.weight(.semibold))
                            Text(aspect.phase.rawValue.capitalized).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("orb \(format(aspect.orbDegrees))°").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Divider()
                }
            }
        }
    }

    @ViewBuilder
    private func housesSection(_ payload: AgentComputedChartPayload) -> some View {
        chartSection("Houses") {
            if let snapshot = payload.snapshots.last {
                ForEach(Array(snapshot.houses.enumerated()), id: \.offset) { _, house in
                    HStack {
                        Text("House \(house.number)").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text("\(format(house.cuspDegrees))°").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Divider()
                }
            } else {
                Text("No house data is available.").foregroundStyle(.secondary)
            }
        }
    }

    private func calculationDetails(_ payload: AgentComputedChartPayload) -> some View {
        chartSection("Calculation details") {
            detailRow("Capability", payload.capability)
            detailRow("Fingerprint", asset.semanticFingerprint)
            detailRow("Subjects", asset.subjectRefs.joined(separator: ", "))
            if let time = asset.timeSummary { detailRow("Target time", time) }
            if let location = asset.locationSummary { detailRow("Location", location) }
            if let resolution = asset.resolution { detailRow("Resolution", resolution) }
            if let physical = store.physicalArtifact(semanticFingerprint: asset.semanticFingerprint) {
                detailRow("Schema", String(physical.schemaVersion))
                detailRow("Calculation schema", String(physical.calculationSchemaVersion))
            }
        }
    }

    private func chartSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(.headline)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18))
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text(title).foregroundStyle(.secondary)
            Spacer(minLength: 16)
            Text(value).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
        .font(.caption)
    }

    private func signName(_ index: Int) -> String {
        let signs = ["Aries", "Taurus", "Gemini", "Cancer", "Leo", "Virgo", "Libra", "Scorpio", "Sagittarius", "Capricorn", "Aquarius", "Pisces"]
        guard signs.indices.contains(index) else { return "—" }
        return signs[index]
    }

    private func format(_ value: Double) -> String { String(format: "%.2f", value) }
}

private func agentChartDisplayTitle(_ capability: String) -> String {
    switch capability {
    case "you.natal": "Natal"
    case "you.transit": "Transit"
    case "you.secondary": "Secondary"
    case "relationship.synastry": "Synastry"
    case "relationship.composite": "Composite"
    case "relationship.composite_transit": "Relationship Transit"
    default: capability
    }
}
