import Foundation

enum Geodesy {
    /// Mean Earth radius in meters.
    static let earthRadius = 6_371_000.0

    /// Great-circle distance in meters (haversine). Pure and deterministic, so it is
    /// testable without CoreLocation. Error vs. the ellipsoid is ~0.3 %, far below GPS noise.
    static func distance(from a: LocationSample, to b: LocationSample) -> Double {
        let lat1 = a.latitude * .pi / 180
        let lat2 = b.latitude * .pi / 180
        let dLat = lat2 - lat1
        let dLon = (b.longitude - a.longitude) * .pi / 180
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }
}
