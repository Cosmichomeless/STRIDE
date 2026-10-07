import Foundation

/// A coordinate as plain values, so route geometry stays testable without MapKit.
struct RouteCoordinate: Sendable, Equatable, Hashable {
    var latitude: Double
    var longitude: Double
}

/// Center and extent of the area a route covers, in degrees.
struct RouteRegion: Sendable, Equatable {
    var center: RouteCoordinate
    var latitudeSpan: Double
    var longitudeSpan: Double
}

/// The accepted points of a run grouped in continuous segments. A segment break (first point,
/// after a pause, after a gap) is never drawn as a line, mirroring how distance is computed.
struct Route: Sendable, Equatable {
    private(set) var segments: [[RouteCoordinate]] = []

    /// Smallest span used for framing, so a run that barely moved does not zoom to the street-corner level.
    static let minimumSpan = 0.002
    /// Extra room around the route when framing, as a factor of its extent.
    static let framingPadding = 1.3

    init() {}

    init(points: [TrackPoint]) {
        for point in points { add(point.sample, startsSegment: point.startsSegment) }
    }

    var pointCount: Int { segments.reduce(0) { $0 + $1.count } }
    var isEmpty: Bool { segments.isEmpty }
    var first: RouteCoordinate? { segments.first?.first }
    var last: RouteCoordinate? { segments.last?.last }

    mutating func add(_ sample: LocationSample, startsSegment: Bool) {
        let coordinate = RouteCoordinate(latitude: sample.latitude, longitude: sample.longitude)
        if startsSegment || segments.isEmpty {
            segments.append([coordinate])
        } else {
            segments[segments.count - 1].append(coordinate)
        }
    }

    /// The region that fits the whole route with some padding, or `nil` for an empty route.
    var framing: RouteRegion? {
        var minLat = Double.infinity, maxLat = -Double.infinity
        var minLon = Double.infinity, maxLon = -Double.infinity
        for coordinate in segments.joined() {
            minLat = min(minLat, coordinate.latitude); maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude); maxLon = max(maxLon, coordinate.longitude)
        }
        guard minLat <= maxLat else { return nil }
        return RouteRegion(
            center: RouteCoordinate(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2),
            latitudeSpan: max((maxLat - minLat) * Self.framingPadding, Self.minimumSpan),
            longitudeSpan: max((maxLon - minLon) * Self.framingPadding, Self.minimumSpan)
        )
    }
}
