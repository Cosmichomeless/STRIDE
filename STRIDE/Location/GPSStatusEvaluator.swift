import Foundation

/// Pure function of the current inputs, so every status is unit-testable.
struct GPSStatusEvaluator: Sendable {
    /// Horizontal accuracy (m) up to which a fix is considered good.
    var goodAccuracy: Double = 20
    /// A fix older than this (s) means the signal was lost.
    var lostAfter: TimeInterval = 10

    /// - Parameter lastValidSample: the latest sample with a non-negative accuracy, if any.
    func status(
        authorization: LocationAuthorization,
        servicesEnabled: Bool,
        lastValidSample: LocationSample?,
        now: Date
    ) -> GPSStatus {
        guard servicesEnabled, authorization.canTrack else { return .unavailable }
        guard let sample = lastValidSample else { return .acquiring }
        if now.timeIntervalSince(sample.timestamp) > lostAfter { return .lost }
        return sample.horizontalAccuracy <= goodAccuracy ? .good : .weak
    }
}
