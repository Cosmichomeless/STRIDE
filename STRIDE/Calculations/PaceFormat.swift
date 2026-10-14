import Foundation

enum PaceFormat {
    /// Slower than this (s/km) is shown as unknown: it is standing or walking, not a pace.
    static let slowest: TimeInterval = 3_600

    /// `m:ss` per kilometer or per mile, or `--` when the pace is unknown or meaningless.
    /// `secondsPerKilometer` is how pace is stored and computed; the unit only converts it for display.
    static func pace(_ secondsPerKilometer: TimeInterval?, unit: DistanceUnit = .kilometers) -> String {
        guard let value = secondsPerKilometer, value.isFinite, value > 0, value < slowest else { return "--" }
        let total = Int((value * unit.metersPerUnit / 1_000).rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Pace as text with its unit, e.g. `5:25 /km`.
    static func paceWithUnit(_ secondsPerKilometer: TimeInterval?, unit: DistanceUnit = .kilometers) -> String {
        pace(secondsPerKilometer, unit: unit) + " " + unit.paceSuffix
    }
}

enum DistanceFormat {
    /// Kilometers with two decimals, e.g. `1.25`.
    static func kilometers(_ meters: Double, locale: Locale = .current) -> String {
        distance(meters, unit: .kilometers, locale: locale)
    }

    /// Distance in `unit` with two decimals and the decimal separator of `locale`, e.g. `1.25` or `1,25`.
    static func distance(_ meters: Double, unit: DistanceUnit, locale: Locale = .current) -> String {
        String(format: "%.2f", locale: locale, unit.value(fromMeters: max(0, meters)))
    }

    /// Distance with its symbol, e.g. `5.20 km`.
    static func distanceWithUnit(_ meters: Double, unit: DistanceUnit, locale: Locale = .current) -> String {
        distance(meters, unit: unit, locale: locale) + " " + unit.distanceSymbol
    }

    /// A goal distance with the decimals it needs, e.g. `5 km` or `2.5 mi`.
    static func goal(_ meters: Double, unit: DistanceUnit, locale: Locale = .current) -> String {
        let value = unit.value(fromMeters: meters)
        let text = value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
        return text + " " + unit.distanceSymbol
    }
}
