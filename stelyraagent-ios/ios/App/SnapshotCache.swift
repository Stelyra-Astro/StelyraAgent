import AstroCore
import Foundation

struct SnapshotCachePayload: Codable {
    static let currentSchemaVersion = 4

    let schemaVersion: Int
    let configurationFingerprint: String
    let savedAt: Date
    let natal: ChartSnapshot
    let transitReference: ChartSnapshot
    let progressedReference: ChartSnapshot
    let currentSky: ChartSnapshot
    let transit: ChartSnapshot
    let progressed: ChartSnapshot
    let solarReturn: ChartSnapshot
    let solarReturnReference: ChartSnapshot
    let solarReturnAspects: [ChartAspect]
    let synastry: SynastryComparison?
    let transitAspects: [ChartAspect]
    let progressedAspects: [ChartAspect]
    let transitCalendar: [TransitCalendarDay]
    let chartEvents: ChartEventData
}

final class SnapshotCacheStore: @unchecked Sendable {
    private let url: URL

    init(url: URL? = nil) {
        let base = url ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        self.url = base.appendingPathComponent("CalculatedSnapshots-v1.json")
    }

    func load() -> SnapshotCachePayload? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SnapshotCachePayload.self, from: data)
    }

    func save(_ payload: SnapshotCachePayload) {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? data.write(
            to: url,
            options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
        )
    }

	func clear() {
		try? FileManager.default.removeItem(at: url)
	}
}
