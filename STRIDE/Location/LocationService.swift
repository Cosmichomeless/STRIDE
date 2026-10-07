import CoreLocation
import Observation

/// Owns `CLLocationManager`: authorization and GPS status.
/// (The sample stream is added in the next change.)
@MainActor
@Observable
final class LocationService: NSObject {
    private(set) var authorization: LocationAuthorization
    private(set) var servicesEnabled = true
    private(set) var lastValidSample: LocationSample?

    private let manager: CLLocationManager
    private let evaluator: GPSStatusEvaluator

    /// Current GPS status. Reads `now` from the caller so views can re-evaluate on a tick.
    func gpsStatus(now: Date = .now) -> GPSStatus {
        evaluator.status(
            authorization: authorization,
            servicesEnabled: servicesEnabled,
            lastValidSample: lastValidSample,
            now: now
        )
    }

    init(evaluator: GPSStatusEvaluator = GPSStatusEvaluator()) {
        let manager = CLLocationManager()
        self.manager = manager
        self.evaluator = evaluator
        self.authorization = LocationAuthorization(manager.authorizationStatus)
        super.init()
        manager.delegate = self
        refreshServicesEnabled()
    }

    /// Shows the system prompt only when the user has not decided yet.
    func requestAuthorization() {
        guard authorization.canRequest else { return }
        manager.requestWhenInUseAuthorization()
    }

    private func refreshServicesEnabled() {
        // `locationServicesEnabled()` can block, so it must not run on the main thread.
        Task.detached {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in self?.servicesEnabled = enabled }
        }
    }

    fileprivate func authorizationDidChange(to status: CLAuthorizationStatus) {
        authorization = LocationAuthorization(status)
        refreshServicesEnabled()
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.authorizationDidChange(to: status) }
    }
}
