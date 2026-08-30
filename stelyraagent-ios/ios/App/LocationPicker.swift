@preconcurrency import CoreLocation
@preconcurrency import MapKit
import SwiftUI

struct LocationSelection: Equatable {
    let name: String
    let latitude: Double
    let longitude: Double
    let timezoneID: String
}

struct LocationSearchResult: Identifiable {
    enum Source {
        case apple(MKLocalSearchCompletion)
        case offline(OfflineLocation)
    }

    let id: String
    let title: String
    let subtitle: String
    let source: Source
}

@MainActor
final class LocationSearchService: NSObject, ObservableObject, @preconcurrency MKLocalSearchCompleterDelegate {
    @Published var query = "" {
        didSet {
            completer.queryFragment = query
            refreshOfflineResults()
        }
    }
    @Published private(set) var results: [LocationSearchResult] = []
    @Published private(set) var isResolving = false
    @Published private(set) var errorMessage: String?

    private let completer = MKLocalSearchCompleter()
    private let offlineStore = try? OfflineLocationStore()
    private var appleResults: [MKLocalSearchCompletion] = []
    private var offlineResults: [OfflineLocation] = []

    override init() {
        super.init()
        completer.resultTypes = [.address]
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        appleResults = completer.results
        publishResults()
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        if offlineResults.isEmpty {
            errorMessage = error.localizedDescription
        }
    }

    func resolve(_ result: LocationSearchResult) async -> LocationSelection? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        switch result.source {
        case let .offline(location):
            return selection(from: location)
        case let .apple(completion):
            if let location = await resolveApple(completion) {
                return location
            }
            errorMessage = localizedDescriptionForMissingPlace
            return nil
        }
    }

    private func resolveApple(_ completion: MKLocalSearchCompletion) async -> LocationSelection? {
        do {
            let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
            guard let item = response.mapItems.first else { return nil }
            let coordinate: CLLocationCoordinate2D
            if #available(iOS 26.0, *) {
                coordinate = item.location.coordinate
            } else {
                coordinate = item.placemark.coordinate
            }
            guard let timeZone = item.timeZone,
                  !(item.name ?? completion.title).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }
            return LocationSelection(
                name: item.name ?? completion.title,
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneID: timeZone.identifier
            )
        } catch {
            return nil
        }
    }

    func resolve(_ coordinate: CLLocationCoordinate2D) async -> LocationSelection? {
        isResolving = true
        errorMessage = nil
        defer { isResolving = false }
        do {
            let placemarks = try await CLGeocoder().reverseGeocodeLocation(
                CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            )
            let placemark = placemarks.first
            let parts = [
                placemark?.locality,
                placemark?.administrativeArea,
                placemark?.country,
            ]
            .compactMap { $0 }
            .reduce(into: [String]()) { result, value in
                if !result.contains(value) { result.append(value) }
            }
            guard !parts.isEmpty, let timeZone = placemark?.timeZone else {
                return offlineSelection(for: coordinate)
            }
            return LocationSelection(
                name: parts.joined(separator: ", "),
                latitude: coordinate.latitude,
                longitude: coordinate.longitude,
                timezoneID: timeZone.identifier
            )
        } catch {
            return offlineSelection(for: coordinate)
        }
    }

    private func refreshOfflineResults() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        offlineResults = trimmed.isEmpty ? [] : offlineStore?.search(trimmed, limit: 8) ?? []
        if !offlineResults.isEmpty { errorMessage = nil }
        if trimmed.isEmpty { appleResults = [] }
        publishResults()
    }

    private func publishResults() {
        var seen = Set<String>()
        var merged: [LocationSearchResult] = []
        // Keep Apple results first while reserving visible rows for the transparent
        // offline fallback when MapKit only returns irrelevant regional matches.
        for completion in appleResults.prefix(4) {
            let key = "\(completion.title)|\(completion.subtitle)".folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(key).inserted else { continue }
            merged.append(LocationSearchResult(
                id: "apple:\(key)",
                title: completion.title,
                subtitle: completion.subtitle,
                source: .apple(completion)
            ))
        }
        for location in offlineResults {
            let key = "\(location.name)|\(location.countryCode)".folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(key).inserted else { continue }
            merged.append(LocationSearchResult(
                id: "offline:\(location.id)",
                title: location.name,
                subtitle: "\(location.countryCode) · \(location.timezoneID)",
                source: .offline(location)
            ))
        }
        for completion in appleResults.dropFirst(4) {
            let key = "\(completion.title)|\(completion.subtitle)".folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            guard seen.insert(key).inserted else { continue }
            merged.append(LocationSearchResult(
                id: "apple:\(key)",
                title: completion.title,
                subtitle: completion.subtitle,
                source: .apple(completion)
            ))
        }
        results = Array(merged.prefix(8))
    }

    private func offlineSelection(for coordinate: CLLocationCoordinate2D) -> LocationSelection? {
        guard let location = offlineStore?.resolve(coordinate) else {
            errorMessage = localizedDescriptionForMissingPlace
            return nil
        }
        return selection(from: location)
    }

    private func selection(from location: OfflineLocation) -> LocationSelection {
        LocationSelection(
            name: [location.name, location.countryCode].joined(separator: ", "),
            latitude: location.latitude,
            longitude: location.longitude,
            timezoneID: location.timezoneID
        )
    }

    private var localizedDescriptionForMissingPlace: String {
        "The selected map location does not include a valid address and time zone."
    }
}

@MainActor
final class CurrentLocationService: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
    @Published private(set) var isLocating = false
    @Published private(set) var coordinate: LocationCoordinate?
    @Published private(set) var errorMessage: String?

    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func request() {
        errorMessage = nil
        switch manager.authorizationStatus {
        case .notDetermined:
            isLocating = true
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            isLocating = true
            manager.requestLocation()
        case .denied, .restricted:
            errorMessage = "Location access is disabled in Settings."
        @unknown default:
            errorMessage = "Location is currently unavailable."
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways
            || manager.authorizationStatus == .authorizedWhenInUse
        {
            manager.requestLocation()
        } else if manager.authorizationStatus == .denied
            || manager.authorizationStatus == .restricted
        {
            isLocating = false
            errorMessage = "Location access is disabled in Settings."
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        isLocating = false
        guard let location = locations.last else { return }
        coordinate = LocationCoordinate(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        isLocating = false
        errorMessage = error.localizedDescription
    }
}

struct LocationCoordinate: Equatable {
    let latitude: Double
    let longitude: Double
}

struct LocationSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = LocationSearchService()
    @StateObject private var currentLocation = CurrentLocationService()
    @State private var camera: MapCameraPosition = .automatic
    @State private var selection: LocationSelection?
    let language: AppLanguage
    let onSelect: (LocationSelection) -> Void

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MapReader { proxy in
                    Map(position: $camera) {
                        UserAnnotation()
                        if let selection {
                            Marker(
                                selection.name,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: selection.latitude,
                                    longitude: selection.longitude
                                )
                            )
                            .tint(AppTheme.violet)
                        }
                    }
                    .mapControls {
                        MapCompass()
                        MapScaleView()
                        MapUserLocationButton()
                    }
                    .onTapGesture { point in
                        guard let coordinate = proxy.convert(point, from: .local) else { return }
                        Task {
                            selection = await service.resolve(coordinate)
                        }
                    }
                }
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 8) {
                    HStack(spacing: 9) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(AppTheme.muted)
                        TextField(
                            localized("location.search-a-city-or-address", language: language),
                            text: $service.query
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        if service.isResolving {
                            ProgressView().controlSize(.small)
                        }
                    }
                    .padding(.horizontal, 13)
                    .frame(height: 46)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))

                    if !service.query.isEmpty, !service.results.isEmpty {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 0) {
                                ForEach(service.results.prefix(6)) { result in
                                    Button {
                                        Task {
                                            if let resolved = await service.resolve(result) {
                                                select(resolved)
                                                service.query = ""
                                            }
                                        }
                                    } label: {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(result.title)
                                                .font(.subheadline.weight(.semibold))
                                                .foregroundStyle(AppTheme.text)
                                            if !result.subtitle.isEmpty {
                                                Text(result.subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(AppTheme.muted)
                                            }
                                        }
                                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
                                        .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    Divider().overlay(AppTheme.line)
                                }
                            }
                        }
                        .frame(maxHeight: 300)
                        .padding(.horizontal, 13)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    }

                    if let selection {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "mappin.circle.fill")
                                .foregroundStyle(AppTheme.violet)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(selection.name)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(AppTheme.text)
                                Text(selection.timezoneID)
                                    .font(.caption)
                                    .foregroundStyle(AppTheme.muted)
                            }
                            Spacer()
                        }
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 15))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 8)

                VStack {
                    Spacer()
                    HStack {
                        Button {
                            currentLocation.request()
                        } label: {
                            Label(
                                localized("location.my-location", language: language),
                                systemImage: "location.fill"
                            )
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 13)
                            .frame(height: 44)
                            .background(.regularMaterial, in: Capsule())
                        }
                        .buttonStyle(.plain)
                        Spacer()
                        Text(localized("location.tap-the-map-to-choose", language: language))
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppTheme.muted)
                            .padding(.horizontal, 13)
                            .frame(height: 44)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .padding(14)
                }

                if service.errorMessage != nil || currentLocation.errorMessage != nil {
                    Text(localized("location.unavailable-error", language: language))
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .padding(.top, 340)
                }
            }
            .navigationTitle(localized("location.choose-location", language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localized("location.cancel", language: language)) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localized("charts.done", language: language)) {
                        if let selection {
                            onSelect(selection)
                            dismiss()
                        }
                    }
                    .disabled(selection == nil)
                }
            }
            .onAppear {
                currentLocation.request()
            }
            .onChange(of: currentLocation.coordinate) { _, location in
                guard let location else { return }
                Task {
                    let coordinate = CLLocationCoordinate2D(
                        latitude: location.latitude,
                        longitude: location.longitude
                    )
                    selection = await service.resolve(coordinate)
                    if let selection {
                        select(selection)
                    }
                }
            }
        }
    }

    private func select(_ location: LocationSelection) {
        selection = location
        camera = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(
                    latitude: location.latitude,
                    longitude: location.longitude
                ),
                span: MKCoordinateSpan(latitudeDelta: 0.35, longitudeDelta: 0.35)
            )
        )
    }
}
