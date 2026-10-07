import Foundation

/// Distance and pace of a run, computed from **validated** samples only.
///
/// Incremental on purpose: every accepted sample is folded in once, in O(1), and the
/// same type is rebuilt after a relaunch by replaying the persisted points
/// (`startsSegment` marks where a pause or a gap broke the track).
///
/// Behavior at the edges (also documented in `docs/METRICS.md`):
/// - A sample that starts a segment adds no distance: nothing is accumulated across a pause
///   or a recovery gap.
/// - Average pace needs `minDistanceForAverage`, otherwise it is unknown (`nil`) instead of absurd.
/// - Current pace looks only at the last `window` seconds of the current segment. It is `nil`
///   when the window is too short or too still, and when the last sample is older than `staleAfter`
///   (sparse GPS or standing still). It never extrapolates.
struct RunMetrics: Sendable, Equatable {
    struct Configuration: Sendable, Equatable {
        /// Span of the rolling window for the current pace (s).
        var window: TimeInterval = 20
        /// Minimum time covered by the window to give a current pace (s).
        var minWindowDuration: TimeInterval = 5
        /// Minimum distance covered by the window to give a current pace (m). Below it, movement is jitter.
        var minWindowDistance: Double = 5
        /// Current pace is unknown if the last sample is older than this (s).
        var staleAfter: TimeInterval = 10
        /// Minimum total distance to give an average pace (m).
        var minDistanceForAverage: Double = 10
    }

    private struct Mark: Sendable, Equatable {
        var timestamp: Date
        var odometer: Double
    }

    let configuration: Configuration
    /// Total distance in meters.
    private(set) var distance: Double = 0
    private var lastSample: LocationSample?
    private var marks: [Mark] = []

    init(configuration: Configuration = Configuration()) {
        self.configuration = configuration
    }

    /// Folds an accepted sample into the totals.
    mutating func add(_ sample: LocationSample, startsSegment: Bool) {
        if let previous = lastSample, !startsSegment {
            distance += Geodesy.distance(from: previous, to: sample)
        } else {
            marks.removeAll()
        }
        lastSample = sample
        marks.append(Mark(timestamp: sample.timestamp, odometer: distance))
        let cutoff = sample.timestamp.addingTimeInterval(-configuration.window)
        marks.removeAll { $0.timestamp < cutoff }
    }

    /// Seconds per kilometer over the whole run, from moving (active) time. `nil` while unknown.
    func averagePace(elapsed: TimeInterval) -> TimeInterval? {
        guard distance >= configuration.minDistanceForAverage, elapsed > 0 else { return nil }
        return elapsed / (distance / 1000)
    }

    /// Seconds per kilometer over the last `window` seconds. `nil` while unknown.
    func currentPace(at now: Date) -> TimeInterval? {
        guard let first = marks.first, let last = marks.last, first != last else { return nil }
        guard now.timeIntervalSince(last.timestamp) <= configuration.staleAfter else { return nil }
        let duration = last.timestamp.timeIntervalSince(first.timestamp)
        let covered = last.odometer - first.odometer
        guard duration >= configuration.minWindowDuration, covered >= configuration.minWindowDistance else { return nil }
        return duration / (covered / 1000)
    }
}
