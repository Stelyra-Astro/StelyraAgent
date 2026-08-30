import AstroCore
import Foundation

struct ICloudBackupEnvelope: Codable {
    let version: Int
    let updatedAt: Date
    let profile: UserProfile
    let people: [SavedPerson]
    let language: AppLanguage
    let appearance: AppAppearance
    let fontSize: AppFontSize
    let presets: [ChartKind: CalculationPreset]
    let reports: [GeneratedChartArtifact]
    let periodReports: [SavedReport]?
}

actor ICloudBackupStore {
    static let shared = ICloudBackupStore()
    private let coordinator = NSFileCoordinator(filePresenter: nil)

    func save(_ value: ICloudBackupEnvelope) throws {
        guard let url = backupURL(create: true) else { throw CocoaError(.fileNoSuchFile) }
        let data = try JSONEncoder.cloud.encode(value)
        var coordinationError: NSError?
        var writeError: Error?
        coordinator.coordinate(writingItemAt: url, options: .forReplacing, error: &coordinationError) { target in
            do { try data.write(to: target, options: [.atomic, .completeFileProtection]) } catch { writeError = error }
        }
        if let error = coordinationError ?? writeError as NSError? { throw error }
    }

    func load() throws -> ICloudBackupEnvelope? {
        guard let url = backupURL(create: false), FileManager.default.fileExists(atPath: url.path) else { return nil }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        coordinator.coordinate(readingItemAt: url, options: [], error: &coordinationError) { target in result = Result { try Data(contentsOf: target) } }
        if let coordinationError { throw coordinationError }
        return try result.map { try JSONDecoder.cloud.decode(ICloudBackupEnvelope.self, from: $0.get()) }
    }

	func delete() throws {
		guard let url = backupURL(create: false), FileManager.default.fileExists(atPath: url.path) else { return }
		var coordinationError: NSError?
		var deleteError: Error?
		coordinator.coordinate(writingItemAt: url, options: .forDeleting, error: &coordinationError) { target in
			do { try FileManager.default.removeItem(at: target) } catch { deleteError = error }
		}
		if let error = coordinationError ?? deleteError as NSError? { throw error }
	}

    func isAvailable() -> Bool { FileManager.default.url(forUbiquityContainerIdentifier: nil) != nil }

    private func backupURL(create: Bool) -> URL? {
        guard let root = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let directory = root.appendingPathComponent("Documents/StelyraAgent", isDirectory: true)
        if create { try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true) }
        return directory.appendingPathComponent("personal-data-v1.json")
    }
}

private extension JSONEncoder {
    static var cloud: JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; value.outputFormatting = [.sortedKeys]; return value }
}
private extension JSONDecoder {
    static var cloud: JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
}
