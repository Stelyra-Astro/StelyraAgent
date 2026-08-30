import CoreLocation
import XCTest
@testable import StelyraAgent

@MainActor
final class OfflineLocationStoreTests: XCTestCase {
    func testSearchFindsParisWithExactTimezone() throws {
        let store = try OfflineLocationStore()

        let result = try XCTUnwrap(store.search("Paris", limit: 6).first {
            $0.timezoneID == "Europe/Paris"
        })

        XCTAssertEqual(result.countryCode, "FR")
        XCTAssertEqual(result.name, "Paris")
    }

    func testMapPointFallsBackToNearestRealCityAndItsTimezone() throws {
        let store = try OfflineLocationStore()
        let coordinate = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

        let result = try XCTUnwrap(store.resolve(coordinate))

        XCTAssertLessThan(
            CLLocation(latitude: result.latitude, longitude: result.longitude)
                .distance(from: CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)),
            2_000
        )
        XCTAssertEqual(result.timezoneID, "Europe/Paris")
        XCTAssertTrue(result.name.contains("Paris"))
    }

    func testOceanPointDoesNotGuessTimezone() throws {
        let store = try OfflineLocationStore()

        XCTAssertNil(store.resolve(CLLocationCoordinate2D(latitude: 0, longitude: -140)))
    }

    func testSearchServicePublishesOfflineParisInTheExistingResultList() {
        let service = LocationSearchService()

        service.query = "Paris"

        XCTAssertTrue(service.results.prefix(6).contains {
            $0.title == "Paris" && $0.subtitle.contains("Europe/Paris")
        })
    }

    func testSearchServiceResolvesParisFromAMapTap() async throws {
        let service = LocationSearchService()
        let tapped = CLLocationCoordinate2D(latitude: 48.8566, longitude: 2.3522)

        let resolved = await service.resolve(tapped)
        let selection = try XCTUnwrap(resolved)

        XCTAssertEqual(selection.timezoneID, "Europe/Paris")
        XCTAssertLessThan(
            CLLocation(latitude: selection.latitude, longitude: selection.longitude)
                .distance(from: CLLocation(latitude: tapped.latitude, longitude: tapped.longitude)),
            2_000
        )
    }
}
