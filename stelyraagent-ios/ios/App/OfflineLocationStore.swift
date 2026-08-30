import CoreLocation
import Foundation
import SQLite3

struct OfflineLocation: Equatable, Identifiable {
    let id: Int64
    let name: String
    let asciiName: String
    let countryCode: String
    let admin1Code: String
    let latitude: Double
    let longitude: Double
    let population: Int
    let timezoneID: String
}

enum OfflineLocationStoreError: Error {
    case missingDatabase
    case openFailed(String)
    case queryFailed(String)
}

private final class OfflineLocationBundleToken: NSObject {}

final class OfflineLocationStore: @unchecked Sendable {
    private var database: OpaquePointer?

    init(databaseURL: URL? = nil) throws {
        let url = databaseURL ?? Bundle(for: OfflineLocationBundleToken.self).url(
            forResource: "OfflineLocations",
            withExtension: "sqlite3"
        )
        guard let url else { throw OfflineLocationStoreError.missingDatabase }
        var connection: OpaquePointer?
        let result = sqlite3_open_v2(
            url.path,
            &connection,
            SQLITE_OPEN_READONLY | SQLITE_OPEN_NOMUTEX,
            nil
        )
        guard result == SQLITE_OK, let connection else {
            let message = connection.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let connection { sqlite3_close(connection) }
            throw OfflineLocationStoreError.openFailed(message)
        }
        database = connection
    }

    deinit {
        if let database { sqlite3_close(database) }
    }

    func search(_ rawQuery: String, limit: Int) -> [OfflineLocation] {
        let tokens = rawQuery
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { !$0.isEmpty }
        guard !tokens.isEmpty, limit > 0 else { return [] }
        let match = tokens
            .map { "\"\($0.replacingOccurrences(of: "\"", with: "\"\""))\"*" }
            .joined(separator: " AND ")
        let sql = """
            SELECT p.id, p.name, p.ascii_name, p.country_code, p.admin1_code,
                   p.latitude, p.longitude, p.population, t.identifier
            FROM place_search s
            JOIN places p ON p.id = s.rowid
            JOIN timezones t ON t.id = p.timezone_index
            WHERE place_search MATCH ?
            ORDER BY p.population DESC, p.id
            LIMIT ?
            """
        return (try? rows(sql: sql) { statement in
            bind(match, to: 1, in: statement)
            sqlite3_bind_int(statement, 2, Int32(min(limit, 50)))
        }) ?? []
    }

    func resolve(_ coordinate: CLLocationCoordinate2D) -> OfflineLocation? {
        guard CLLocationCoordinate2DIsValid(coordinate) else { return nil }
        let latitudeRadius = 1.5
        let longitudeRadius = min(
            180,
            latitudeRadius / max(0.1, cos(coordinate.latitude * .pi / 180))
        )
        let minimumLongitude = coordinate.longitude - longitudeRadius
        let maximumLongitude = coordinate.longitude + longitudeRadius
        let longitudeClause: String
        let longitudeBindings: [Double]
        if minimumLongitude < -180 {
            longitudeClause = "(p.longitude >= ? OR p.longitude <= ?)"
            longitudeBindings = [minimumLongitude + 360, maximumLongitude]
        } else if maximumLongitude > 180 {
            longitudeClause = "(p.longitude >= ? OR p.longitude <= ?)"
            longitudeBindings = [minimumLongitude, maximumLongitude - 360]
        } else {
            longitudeClause = "p.longitude BETWEEN ? AND ?"
            longitudeBindings = [minimumLongitude, maximumLongitude]
        }
        let sql = """
            SELECT p.id, p.name, p.ascii_name, p.country_code, p.admin1_code,
                   p.latitude, p.longitude, p.population, t.identifier
            FROM places p
            JOIN timezones t ON t.id = p.timezone_index
            WHERE p.latitude BETWEEN ? AND ? AND \(longitudeClause)
            ORDER BY ((p.latitude - ?) * (p.latitude - ?))
                   + ((p.longitude - ?) * (p.longitude - ?)) ASC,
                     p.population DESC
            LIMIT 32
            """
        guard let candidates = try? rows(sql: sql, bind: { statement in
            sqlite3_bind_double(statement, 1, coordinate.latitude - latitudeRadius)
            sqlite3_bind_double(statement, 2, coordinate.latitude + latitudeRadius)
            sqlite3_bind_double(statement, 3, longitudeBindings[0])
            sqlite3_bind_double(statement, 4, longitudeBindings[1])
            sqlite3_bind_double(statement, 5, coordinate.latitude)
            sqlite3_bind_double(statement, 6, coordinate.latitude)
            sqlite3_bind_double(statement, 7, coordinate.longitude)
            sqlite3_bind_double(statement, 8, coordinate.longitude)
        }) else { return nil }

        let tappedLocation = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        return candidates
            .map { candidate in
                let distance = tappedLocation.distance(from: CLLocation(
                    latitude: candidate.latitude,
                    longitude: candidate.longitude
                ))
                return (candidate, distance)
            }
            .filter { $0.1 <= 150_000 }
            .min {
                if abs($0.1 - $1.1) > 1 { return $0.1 < $1.1 }
                return $0.0.population > $1.0.population
            }?
            .0
    }

    private func rows(
        sql: String,
        bind: (OpaquePointer) -> Void
    ) throws -> [OfflineLocation] {
        guard let database else { return [] }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK,
              let statement
        else {
            throw OfflineLocationStoreError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        defer { sqlite3_finalize(statement) }
        bind(statement)
        var output: [OfflineLocation] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            output.append(OfflineLocation(
                id: sqlite3_column_int64(statement, 0),
                name: text(at: 1, in: statement),
                asciiName: text(at: 2, in: statement),
                countryCode: text(at: 3, in: statement),
                admin1Code: text(at: 4, in: statement),
                latitude: sqlite3_column_double(statement, 5),
                longitude: sqlite3_column_double(statement, 6),
                population: Int(sqlite3_column_int64(statement, 7)),
                timezoneID: text(at: 8, in: statement)
            ))
        }
        let result = sqlite3_errcode(database)
        guard result == SQLITE_OK || result == SQLITE_DONE else {
            throw OfflineLocationStoreError.queryFailed(String(cString: sqlite3_errmsg(database)))
        }
        return output
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) {
        sqlite3_bind_text(statement, index, value, -1, unsafeBitCast(-1, to: sqlite3_destructor_type.self))
    }

    private func text(at index: Int32, in statement: OpaquePointer) -> String {
        guard let value = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: value)
    }
}
