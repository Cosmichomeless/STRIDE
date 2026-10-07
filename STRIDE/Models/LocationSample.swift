import Foundation

/// A single raw location reading, decoupled from CoreLocation so the filtering,
/// calculation and persistence layers can be tested with plain values.
struct LocationSample: Sendable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double
    var altitude: Double
    /// Radius of uncertainty in meters. Negative means the fix is invalid.
    var horizontalAccuracy: Double
    /// Instantaneous speed in m/s. Negative means unknown.
    var speed: Double
    var timestamp: Date
}
