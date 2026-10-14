import Foundation

/// How distances and paces are shown. Runs are always stored in meters and seconds per kilometer;
/// the unit only changes what the user reads.
enum DistanceUnit: String, CaseIterable, Sendable, Identifiable {
    case kilometers
    case miles

    var id: String { rawValue }

    var metersPerUnit: Double {
        switch self {
        case .kilometers: 1_000
        case .miles: 1_609.344
        }
    }

    /// Symbol shown next to a distance, e.g. `km`.
    var distanceSymbol: String {
        switch self {
        case .kilometers: "km"
        case .miles: "mi"
        }
    }

    /// Suffix of a pace, e.g. `/km`.
    var paceSuffix: String { "/" + distanceSymbol }

    var name: LocalizedStringResource {
        switch self {
        case .kilometers: "Kilometers"
        case .miles: "Miles"
        }
    }

    /// Miles in the United States and the United Kingdom, kilometers everywhere else.
    static func `default`(for locale: Locale) -> DistanceUnit {
        switch locale.measurementSystem {
        case .us, .uk: .miles
        default: .kilometers
        }
    }

    func value(fromMeters meters: Double) -> Double { meters / metersPerUnit }
}
