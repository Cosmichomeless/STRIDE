import Foundation

/// Text shown for a completed run, shared by the History rows and the Run details screen.
enum RunSummary {
    static func distance(_ run: RunRecord) -> String { DistanceFormat.kilometers(run.distance) + " km" }
    static func duration(_ run: RunRecord) -> String { DurationFormat.clock(run.accumulatedDuration) }
    static func pace(_ run: RunRecord) -> String { PaceFormat.pace(run.averagePace) + " /km" }

    /// One line for a list row, e.g. `5.20 km · 28:10 · 5:25 /km`.
    static func line(_ run: RunRecord) -> String {
        [distance(run), duration(run), pace(run)].joined(separator: " · ")
    }
}
