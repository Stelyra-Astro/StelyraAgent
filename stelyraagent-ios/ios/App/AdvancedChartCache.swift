import Foundation

struct AdvancedChartCacheEntry: Codable, Equatable {
    static let currentSchemaVersion = 1

    let schemaVersion: Int
    let chart: ChartKind
    let fingerprint: String
    let savedAt: Date
    let result: ChartDisplayResult
}

private struct AdvancedChartCachePayload: Codable {
    let entries: [AdvancedChartCacheEntry]
}

final class AdvancedChartCacheStore: @unchecked Sendable {
    private let url: URL
    private let maxEntriesPerChart: Int

    init(url: URL? = nil, maxEntriesPerChart: Int = 3) {
        let base = url ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.url = base.appendingPathComponent("CalculatedAdvancedCharts-v1.json")
        self.maxEntriesPerChart = max(1, maxEntriesPerChart)
    }

    func load(chart: ChartKind, fingerprint: String) -> ChartDisplayResult? {
        loadEntries().first {
            $0.schemaVersion == AdvancedChartCacheEntry.currentSchemaVersion
                && $0.chart == chart
                && $0.fingerprint == fingerprint
        }?.result
    }

    func save(chart: ChartKind, fingerprint: String, result: ChartDisplayResult) {
        var entries = loadEntries().filter {
            !($0.chart == chart && $0.fingerprint == fingerprint)
        }
        entries.append(
            AdvancedChartCacheEntry(
                schemaVersion: AdvancedChartCacheEntry.currentSchemaVersion,
                chart: chart,
                fingerprint: fingerprint,
                savedAt: Date(),
                result: result
            )
        )

        let grouped = Dictionary(grouping: entries, by: \.chart)
        let trimmed = grouped.values.flatMap { group in
            group.sorted { $0.savedAt > $1.savedAt }.prefix(maxEntriesPerChart)
        }
        persist(Array(trimmed))
    }

    func remove(chart: ChartKind) {
        persist(loadEntries().filter { $0.chart != chart })
    }

    func clear() {
        try? FileManager.default.removeItem(at: url)
    }

    private func loadEntries() -> [AdvancedChartCacheEntry] {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(AdvancedChartCachePayload.self, from: data)
        else {
            return []
        }
        return payload.entries.filter {
            $0.schemaVersion == AdvancedChartCacheEntry.currentSchemaVersion
        }
    }

    private func persist(_ entries: [AdvancedChartCacheEntry]) {
        if entries.isEmpty {
            try? FileManager.default.removeItem(at: url)
            return
        }
        guard let data = try? JSONEncoder().encode(AdvancedChartCachePayload(entries: entries)) else {
            return
        }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }
}
