import CoreLocation

/// Every CoreLocation knob that trades accuracy for battery, in one place so it can
/// be compared and tuned (see docs/PERFORMANCE.md).
struct LocationConfiguration: Sendable, Equatable {
    var desiredAccuracy: CLLocationAccuracy = kCLLocationAccuracyBest
    /// Minimum movement (m) before a new update is delivered.
    var distanceFilter: CLLocationDistance = 5
    var activityType: CLActivityType = .fitness
    /// Left off: the system must not stop updates in the middle of a run.
    var pausesLocationUpdatesAutomatically = false

    /// Shows the system blue indicator while updates continue in the background. Kept on:
    /// it is how iOS tells the user (and us) that a run is still being recorded.
    var showsBackgroundLocationIndicator = true

    static let `default` = LocationConfiguration()

    func apply(to manager: CLLocationManager) {
        manager.desiredAccuracy = desiredAccuracy
        manager.distanceFilter = distanceFilter
        manager.activityType = activityType
        manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
    }

    /// Background updates need `location` in `UIBackgroundModes`; setting
    /// `allowsBackgroundLocationUpdates` without it raises an exception, so it is checked first.
    func applyBackground(_ enabled: Bool, to manager: CLLocationManager, bundleInfo: [String: Any]? = Bundle.main.infoDictionary) -> Bool {
        let allowed = enabled && Self.declaresBackgroundLocation(bundleInfo)
        manager.allowsBackgroundLocationUpdates = allowed
        manager.showsBackgroundLocationIndicator = allowed && showsBackgroundLocationIndicator
        return allowed
    }

    static func declaresBackgroundLocation(_ info: [String: Any]?) -> Bool {
        (info?["UIBackgroundModes"] as? [String])?.contains("location") ?? false
    }
}
