import CoreLocation
import MapKit

@MainActor protocol MapsOpening: AnyObject {
    func openWalkingDirections(to: Coordinate, name: String?)
}

/// Hands the walk to Apple Maps.
@MainActor final class MapsLauncher: MapsOpening {
    func openWalkingDirections(to coordinate: Coordinate, name: String?) {
        let target = CLLocationCoordinate2D(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let item = MKMapItem(placemark: MKPlacemark(coordinate: target))
        item.name = name
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking])
    }
}
