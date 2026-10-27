import Foundation

enum SpotFilter: CaseIterable, Sendable {
    case all, malls, streets

    var key: String {
        switch self {
        case .all: "all"
        case .malls: "malls"
        case .streets: "streets"
        }
    }

    /// Keeps the spots of this kind, then those whose place name or note contains `query`
    /// (ignoring case and diacritics). An empty query keeps them all.
    func apply(to spots: [ParkingSpot], query: String) -> [ParkingSpot] {
        let ofKind = spots.filter { spot in
            switch self {
            case .all: true
            case .malls: spot.kind == .mall
            case .streets: spot.kind == .street
            }
        }
        guard !query.isEmpty else { return ofKind }
        return ofKind.filter { spot in
            spot.placeName?.localizedStandardContains(query) == true || spot.note?.localizedStandardContains(query) == true
        }
    }
}
