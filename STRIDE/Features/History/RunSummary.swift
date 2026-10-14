import Foundation

/// Text shown for a completed run, shared by the History rows and the Run details screen.
enum RunSummary {
    static func distance(_ run: RunRecord, unit: DistanceUnit = .kilometers, locale: Locale = .current) -> String {
        DistanceFormat.distanceWithUnit(run.distance, unit: unit, locale: locale)
    }
    static func duration(_ run: RunRecord) -> String { DurationFormat.clock(run.accumulatedDuration) }
    static func pace(_ run: RunRecord, unit: DistanceUnit = .kilometers) -> String {
        PaceFormat.paceWithUnit(run.averagePace, unit: unit)
    }

    /// One line for a list row, e.g. `5.20 km · 28:10 · 5:25 /km`.
    static func line(_ run: RunRecord, unit: DistanceUnit = .kilometers, locale: Locale = .current) -> String {
        [distance(run, unit: unit, locale: locale), duration(run), pace(run, unit: unit)].joined(separator: " · ")
    }

    /// The same line for a screen reader.
    static func spokenLine(_ run: RunRecord, unit: DistanceUnit = .kilometers, locale: Locale = .current) -> String {
        [
            SpokenFormat.distance(run.distance, unit: unit, locale: locale),
            SpokenFormat.duration(run.accumulatedDuration, locale: locale),
            SpokenFormat.pace(run.averagePace, unit: unit, locale: locale),
        ].joined(separator: ", ")
    }
}
