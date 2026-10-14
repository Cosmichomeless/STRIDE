import Foundation

/// Values as a screen reader should say them: words and units instead of `5:25` and `km`.
enum SpokenFormat {
    static func duration(_ seconds: TimeInterval, locale: Locale = .current) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        return Duration.seconds(whole).formatted(.units(allowed: [.hours, .minutes, .seconds], width: .wide).locale(locale))
    }

    static func distance(_ meters: Double, unit: DistanceUnit, locale: Locale = .current) -> String {
        let length: UnitLength = unit == .miles ? .miles : .kilometers
        let measurement = Measurement(value: (unit.value(fromMeters: max(0, meters)) * 100).rounded() / 100, unit: length)
        return measurement.formatted(.measurement(width: .wide, usage: .asProvided, numberFormatStyle: .number.precision(.fractionLength(0...2))).locale(locale))
    }

    /// e.g. "5 minutes, 25 seconds per kilometer", or "not available" while the pace is unknown.
    static func pace(_ secondsPerKilometer: TimeInterval?, unit: DistanceUnit, locale: Locale = .current) -> String {
        guard let value = secondsPerKilometer, value.isFinite, value > 0, value < PaceFormat.slowest else {
            return String(localized: LocalizedStringResource("Not available", locale: locale))
        }
        let perUnit = (value * unit.metersPerUnit / 1_000).rounded()
        let per = unit == .miles
            ? LocalizedStringResource("per mile", locale: locale)
            : LocalizedStringResource("per kilometer", locale: locale)
        return "\(duration(perUnit, locale: locale)) \(String(localized: per))"
    }
}
