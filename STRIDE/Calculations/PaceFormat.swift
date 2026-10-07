import Foundation

enum PaceFormat {
    /// Slower than this (s/km) is shown as unknown: it is standing or walking, not a pace.
    static let slowest: TimeInterval = 3_600

    /// `m:ss` per kilometer, or `--` when the pace is unknown or meaningless.
    static func pace(_ secondsPerKilometer: TimeInterval?) -> String {
        guard let value = secondsPerKilometer, value.isFinite, value > 0, value < slowest else { return "--" }
        let total = Int(value.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

enum DistanceFormat {
    /// Kilometers with two decimals, e.g. `1.25`.
    static func kilometers(_ meters: Double) -> String {
        String(format: "%.2f", max(0, meters) / 1000)
    }
}
