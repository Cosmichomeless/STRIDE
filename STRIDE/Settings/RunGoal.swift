import Foundation

/// A target for a run: a distance or a time. Progress is computed from the same distance and
/// active time the run already tracks.
enum RunGoal: Equatable, Sendable {
    case distance(meters: Double)
    case time(seconds: TimeInterval)

    struct Progress: Equatable, Sendable {
        /// 0...1, never above 1 so a progress bar stays inside its track.
        let fraction: Double
        let isReached: Bool
    }

    func progress(distance: Double, elapsed: TimeInterval) -> Progress {
        let target: Double
        let done: Double
        switch self {
        case .distance(let meters): (target, done) = (meters, distance)
        case .time(let seconds): (target, done) = (seconds, elapsed)
        }
        guard target > 0 else { return Progress(fraction: 0, isReached: false) }
        let raw = max(0, done) / target
        return Progress(fraction: min(raw, 1), isReached: raw >= 1)
    }
}

extension RunGoal {
    /// The target alone, e.g. `5 km` or `30 min`.
    func targetText(unit: DistanceUnit, locale: Locale = .current) -> String {
        switch self {
        case .distance(let meters): DistanceFormat.goal(meters, unit: unit, locale: locale)
        case .time(let seconds): DurationFormat.goal(seconds, locale: locale)
        }
    }

    /// Progress and target, e.g. `2.10 / 5 km` or `12:05 / 30:00`.
    func progressText(distance: Double, elapsed: TimeInterval, unit: DistanceUnit, locale: Locale = .current) -> String {
        switch self {
        case .distance(let meters):
            "\(DistanceFormat.distance(distance, unit: unit, locale: locale)) / \(DistanceFormat.goal(meters, unit: unit, locale: locale))"
        case .time(let seconds):
            "\(DurationFormat.clock(elapsed)) / \(DurationFormat.clock(seconds))"
        }
    }
}
