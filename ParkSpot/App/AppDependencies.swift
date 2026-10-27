import Foundation
import SwiftData

/// Everything the view models reach the outside world through. Built once at launch; tests swap in fakes.
@MainActor struct AppDependencies {
    let location: LocationProviding
    let camera: CameraAuthorizing
    let photos: PhotoStoring
    let repository: SpotRepository
    let geocoder: Geocoding
    let maps: MapsOpening
    let now: () -> Date

    static func live(container: ModelContainer) -> AppDependencies {
        let photos = PhotoStore.live()
        return AppDependencies(location: LocationService(),
                               camera: CameraAccess(),
                               photos: photos,
                               repository: SpotRepository(context: container.mainContext, photos: photos),
                               geocoder: GeocodingService(),
                               maps: MapsLauncher(),
                               now: { Date() })
    }
}
