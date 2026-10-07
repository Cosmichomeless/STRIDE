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

    static let `default` = LocationConfiguration()

    func apply(to manager: CLLocationManager) {
        manager.desiredAccuracy = desiredAccuracy
        manager.distanceFilter = distanceFilter
        manager.activityType = activityType
        manager.pausesLocationUpdatesAutomatically = pausesLocationUpdatesAutomatically
    }
}
