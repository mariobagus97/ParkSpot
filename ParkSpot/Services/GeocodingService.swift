import CoreLocation
import MapKit

struct PlaceParts: Sendable {
    var name: String?
    var thoroughfare: String?
    var locality: String?
}

enum PlaceName {
    /// The first non-blank of name, thoroughfare, locality.
    static func from(_ parts: PlaceParts) -> String? {
        [parts.name, parts.thoroughfare, parts.locality]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

@MainActor protocol Geocoding: AnyObject {
    func placeName(for: Coordinate) async -> String?
}

/// Apple reverse geocoding. Any failure, or a place with no usable name, gives nil.
@MainActor final class GeocodingService: Geocoding {
    func placeName(for coordinate: Coordinate) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let parts: PlaceParts?
        if #available(iOS 26, *) {
            parts = await Self.parts(reverseGeocoding: location)
        } else {
            parts = await Self.legacyParts(reverseGeocoding: location)
        }
        return parts.flatMap(PlaceName.from)
    }

    @available(iOS 26, *)
    private static func parts(reverseGeocoding location: CLLocation) async -> PlaceParts? {
        guard let request = MKReverseGeocodingRequest(location: location),
              let item = try? await request.mapItems.first else { return nil }
        return PlaceParts(name: item.name,
                          thoroughfare: item.address?.shortAddress,
                          locality: item.addressRepresentations?.cityName)
    }

    /// `CLGeocoder` is deprecated from iOS 26; it stays for iOS 17 to 25.
    private static func legacyParts(reverseGeocoding location: CLLocation) async -> PlaceParts? {
        guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return nil }
        return PlaceParts(name: placemark.name, thoroughfare: placemark.thoroughfare, locality: placemark.locality)
    }
}
