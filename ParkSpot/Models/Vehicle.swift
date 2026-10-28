import Foundation

/// What was parked. People who own more than one vehicle forget which one they took, so every spot remembers it.
enum Vehicle: String, CaseIterable, Sendable {
    case car
    case motorbike
    case bike

    /// The copy key for the vehicle's name.
    var key: String {
        switch self {
        case .car: "vehicle_car"
        case .motorbike: "vehicle_motorbike"
        case .bike: "vehicle_bike"
        }
    }

    /// The localized name, for VoiceOver labels and places that build a sentence.
    var name: String { String(localized: String.LocalizationValue(key)) }

    /// A stored value, defaulting to a car when the field is missing (spots saved before vehicles existed).
    init(stored: String?) {
        self = stored.flatMap(Vehicle.init(rawValue:)) ?? .car
    }
}
