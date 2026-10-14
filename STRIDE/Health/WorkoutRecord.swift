import Foundation

/// A finished run as Health stores it: plain values, so building it needs no HealthKit.
struct WorkoutRecord: Sendable, Equatable {
    var start: Date
    var end: Date
    /// Meters.
    var distance: Double
    /// Accepted GPS samples in chronological order.
    var route: [LocationSample]
    /// Stretches the run was paused, so Health's duration matches the time actually run.
    var pauses: [DateInterval]

    /// `nil` unless the run is finished and has covered some distance: an empty workout is noise in Health.
    init?(run: RunRecord, points: [TrackPoint]) {
        guard run.status == .finished, let finishedAt = run.finishedAt, run.distance > 0, finishedAt > run.startedAt else {
            return nil
        }
        start = run.startedAt
        end = finishedAt
        distance = run.distance
        route = points.map(\.sample)
        pauses = Self.pauses(in: points, within: DateInterval(start: run.startedAt, end: finishedAt))
    }

    /// Pauses are not stored on their own, but a new segment starts after each one (or after an
    /// interruption, which the app also treats as a pause): the gap between the last point of a segment
    /// and the first of the next is the paused time, within a few seconds of what the timer excluded.
    static func pauses(in points: [TrackPoint], within interval: DateInterval) -> [DateInterval] {
        var result: [DateInterval] = []
        for (previous, next) in zip(points, points.dropFirst()) where next.startsSegment {
            let gap = DateInterval(start: previous.sample.timestamp, end: next.sample.timestamp)
            guard next.sample.timestamp > previous.sample.timestamp,
                  gap.start >= interval.start, gap.end <= interval.end else { continue }
            result.append(gap)
        }
        return result
    }
}
