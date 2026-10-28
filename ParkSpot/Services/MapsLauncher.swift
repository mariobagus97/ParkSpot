import CoreLocation
import MapKit
import UIKit

@MainActor protocol MapsOpening: AnyObject {
    func openWalkingDirections(to: Coordinate, name: String?)
}

/// Hands the walk to Maps. Google Maps when it is installed (Mario's preference), Apple Maps otherwise.
@MainActor final class MapsLauncher: MapsOpening {
    func openWalkingDirections(to coordinate: Coordinate, name: String?) {
        if let url = GoogleMapsLink.walking(to: coordinate), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
            return
        }

        let target = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: target))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}

/// The Google Maps URL that opens walking directions to a point.
///
/// Pure and separate so it can be tested without a device: the coordinates must always use a dot as the
/// decimal separator, whatever the phone's locale, or Google Maps reads "106,817400" as a separate number.
enum GoogleMapsLink {
    static let scheme = "comgooglemaps"

    static func walking(to coordinate: Coordinate) -> URL? {
        let pair = String(format: "%.6f,%.6f",
                          locale: Locale(identifier: "en_US_POSIX"),
                          coordinate.latitude,
                          coordinate.longitude)
        return URL(string: "\(scheme)://?daddr=\(pair)&directionsmode=walking")
    }
}
