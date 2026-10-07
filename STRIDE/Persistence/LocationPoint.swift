import Foundation
import SwiftData

/// An accepted (validated) GPS sample belonging to a run.
///
/// Points reference their run by `runId` instead of a SwiftData relationship on
/// purpose: a run can have thousands of points and a relationship array on `Run`
/// would load them whenever the run is fetched (for example in the history list).
/// The `runId, timestamp` index makes per-run, ordered fetches cheap.
@Model
final class LocationPoint {
    #Index<LocationPoint>([\.runId, \.timestamp])

    @Attribute(.unique) var id: UUID
    var runId: UUID
    var latitude: Double
    var longitude: Double
    var altitude: Double
    var horizontalAccuracy: Double
    var speed: Double
    var timestamp: Date
    /// True when this point starts a new segment (first point of the run, after a
    /// pause, or after a recovery gap). Distance is never measured *to* it from
    /// the previous point.
    var startsSegment: Bool

    init(id: UUID = UUID(), runId: UUID, sample: LocationSample, startsSegment: Bool = false) {
        self.id = id
        self.runId = runId
        self.latitude = sample.latitude
        self.longitude = sample.longitude
        self.altitude = sample.altitude
        self.horizontalAccuracy = sample.horizontalAccuracy
        self.speed = sample.speed
        self.timestamp = sample.timestamp
        self.startsSegment = startsSegment
    }

    var sample: LocationSample {
        LocationSample(
            latitude: latitude,
            longitude: longitude,
            altitude: altitude,
            horizontalAccuracy: horizontalAccuracy,
            speed: speed,
            timestamp: timestamp
        )
    }
}
