import Foundation

/// Boundary between `Location/` and `Tracking/`. The tracking layer only knows this
/// protocol, so it can be driven by deterministic fakes in tests.
@MainActor
protocol LocationProviding: AnyObject {
    var authorization: LocationAuthorization { get }
    func gpsStatus(now: Date) -> GPSStatus
    /// Raw, unfiltered samples in arrival order, with the original timestamps.
    /// Meant for a single consumer for the lifetime of the app.
    var samples: AsyncStream<LocationSample> { get }
    /// Emits the new value every time the authorization changes.
    var authorizationChanges: AsyncStream<LocationAuthorization> { get }

    func requestAuthorization()
    func startUpdates()
    func stopUpdates()
    /// Lets updates continue while the app is in the background or the screen is locked.
    /// Enabled only while a run is in progress; otherwise the app should stop with the foreground.
    func setBackgroundTracking(_ enabled: Bool)
}
