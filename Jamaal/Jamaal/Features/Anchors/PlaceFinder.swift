//
//  PlaceFinder.swift
//  Jamaal
//

import CoreLocation
import Foundation

/// Where the app finds a place: the device's location (when-in-use permission, asked only now) or a city search.
@MainActor
protocol PlaceFinding {
    /// The device's place, or `nil` when permission is denied or it can't be found.
    func current() async -> FoundPlace?
    /// Whether the device's place can be read without asking (permission already given).
    var canReadQuietly: Bool { get }
    /// Cities matching `query`; empty when offline.
    func search(_ query: String) async -> [FoundPlace]
}

@MainActor
final class SystemPlaceFinder: NSObject, PlaceFinding, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var waiting: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var canReadQuietly: Bool { [.authorizedWhenInUse, .authorizedAlways].contains(manager.authorizationStatus) }

    func current() async -> FoundPlace? {
        switch manager.authorizationStatus {
        case .denied, .restricted: return nil
        default: break
        }
        guard let location = await requestLocation() else { return nil }
        return await place(for: location)
    }

    func search(_ query: String) async -> [FoundPlace] {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count >= 2 else { return [] }
        let marks = (try? await CLGeocoder().geocodeAddressString(text)) ?? []
        return marks.compactMap(Self.found)
    }

    private func requestLocation() async -> CLLocation? {
        await withCheckedContinuation { continuation in
            waiting = continuation
            if manager.authorizationStatus == .notDetermined { manager.requestWhenInUseAuthorization() } else { manager.requestLocation() }
        }
    }

    private func place(for location: CLLocation) async -> FoundPlace? {
        let marks = (try? await CLGeocoder().reverseGeocodeLocation(location)) ?? []
        if let found = marks.compactMap(Self.found).first { return found }
        return FoundPlace(name: "Your location", region: "", countryCode: Locale.current.region?.identifier,
                          latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
    }

    private static func found(_ mark: CLPlacemark) -> FoundPlace? {
        guard let coordinate = mark.location?.coordinate, let name = mark.locality ?? mark.name else { return nil }
        let region = [mark.administrativeArea, mark.country].compactMap { $0 }.filter { $0 != name }.joined(separator: ", ")
        return FoundPlace(name: name, region: region, countryCode: mark.isoCountryCode,
                          latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    // MARK: CLLocationManagerDelegate

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            switch status {
            case .authorizedWhenInUse, .authorizedAlways: if waiting != nil { self.manager.requestLocation() }
            case .denied, .restricted: finish(nil)
            default: break
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let latest = locations.last
        Task { @MainActor in finish(latest) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        Task { @MainActor in finish(nil) }
    }

    private func finish(_ location: CLLocation?) {
        waiting?.resume(returning: location)
        waiting = nil
    }
}

#if DEBUG
/// `-JamaalFakePlaces`: Leicester for "use my location" and a fixed set of cities for search, so UI tests don't depend
/// on the simulator's location or a network.
@MainActor
struct FakePlaceFinder: PlaceFinding {
    static let leicester = FoundPlace(name: "Leicester", region: "England, United Kingdom", countryCode: "GB", latitude: 52.6369, longitude: -1.1398)
    private static let all = [
        leicester,
        FoundPlace(name: "Leicester", region: "Massachusetts, United States", countryCode: "US", latitude: 42.2457, longitude: -71.9076),
        FoundPlace(name: "Leichlingen", region: "North Rhine-Westphalia, Germany", countryCode: "DE", latitude: 51.1065, longitude: 7.0078),
    ]
    var canReadQuietly: Bool { false }
    func current() async -> FoundPlace? { Self.leicester }
    func search(_ query: String) async -> [FoundPlace] {
        let text = query.lowercased()
        return text.count < 2 ? [] : Self.all.filter { $0.name.lowercased().hasPrefix(text) }
    }
}
#endif

enum PlaceFinders {
    @MainActor static func make() -> any PlaceFinding {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-JamaalFakePlaces") { return FakePlaceFinder() }
        #endif
        return SystemPlaceFinder()
    }
}
