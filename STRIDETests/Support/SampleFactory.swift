import Foundation
@testable import STRIDE

/// Builds samples on a straight line north from a fixed origin, so distances are exact.
struct SampleFactory {
    let t0 = Date(timeIntervalSince1970: 100_000)
    /// Meters per degree of latitude for the haversine radius used in `Geodesy`.
    let metersPerDegree = Geodesy.earthRadius * .pi / 180

    /// A sample `meters` north of the origin, `seconds` after `t0`.
    func sample(meters: Double = 0, at seconds: TimeInterval = 0, accuracy: Double = 5, speed: Double = -1) -> LocationSample {
        LocationSample(
            latitude: 40 + meters / metersPerDegree, longitude: -3, altitude: 0,
            horizontalAccuracy: accuracy, speed: speed, timestamp: t0.addingTimeInterval(seconds)
        )
    }

    func now(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }
}
