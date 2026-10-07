import CoreLocation
import Observation

/// Owns `CLLocationManager`: authorization, GPS status and the stream of raw samples.
@MainActor
@Observable
final class LocationService: NSObject, LocationProviding {
    private(set) var authorization: LocationAuthorization
    private(set) var servicesEnabled = true
    private(set) var lastValidSample: LocationSample?
    private(set) var isUpdating = false

    @ObservationIgnored nonisolated let samples: AsyncStream<LocationSample>
    @ObservationIgnored nonisolated let authorizationChanges: AsyncStream<LocationAuthorization>
    @ObservationIgnored private nonisolated let sampleContinuation: AsyncStream<LocationSample>.Continuation
    @ObservationIgnored private nonisolated let authorizationContinuation: AsyncStream<LocationAuthorization>.Continuation

    private let manager: CLLocationManager
    private let evaluator: GPSStatusEvaluator

    /// Current GPS status. Takes `now` so views can re-evaluate on a tick.
    func gpsStatus(now: Date = .now) -> GPSStatus {
        evaluator.status(
            authorization: authorization,
            servicesEnabled: servicesEnabled,
            lastValidSample: lastValidSample,
            now: now
        )
    }

    init(
        manager: CLLocationManager = CLLocationManager(),
        configuration: LocationConfiguration = .default,
        evaluator: GPSStatusEvaluator = GPSStatusEvaluator()
    ) {
        self.manager = manager
        self.evaluator = evaluator
        self.authorization = LocationAuthorization(manager.authorizationStatus)
        // Newest wins: if the consumer is slow, stale positions are worthless.
        (samples, sampleContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(256))
        (authorizationChanges, authorizationContinuation) = AsyncStream.makeStream(bufferingPolicy: .bufferingNewest(8))
        super.init()
        configuration.apply(to: manager)
        manager.delegate = self
        refreshServicesEnabled()
    }

    /// Shows the system prompt only when the user has not decided yet.
    func requestAuthorization() {
        guard authorization.canRequest else { return }
        manager.requestWhenInUseAuthorization()
    }

    /// Idempotent. Does nothing without permission.
    func startUpdates() {
        guard authorization.canTrack, !isUpdating else { return }
        manager.startUpdatingLocation()
        isUpdating = true
    }

    func stopUpdates() {
        guard isUpdating else { return }
        manager.stopUpdatingLocation()
        isUpdating = false
    }

    private func refreshServicesEnabled() {
        // `locationServicesEnabled()` can block, so it must not run on the main thread.
        Task.detached {
            let enabled = CLLocationManager.locationServicesEnabled()
            await MainActor.run { [weak self] in self?.servicesEnabled = enabled }
        }
    }

    fileprivate func authorizationDidChange(to status: CLAuthorizationStatus) {
        let new = LocationAuthorization(status)
        guard new != authorization else { return }
        authorization = new
        if !new.canTrack { isUpdating = false } // the system stops delivering updates
        authorizationContinuation.yield(new)
        refreshServicesEnabled()
    }

    fileprivate func record(_ samples: [LocationSample]) {
        if let latest = samples.last(where: { $0.horizontalAccuracy >= 0 }) {
            lastValidSample = latest
        }
    }
}

extension LocationService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor [weak self] in self?.authorizationDidChange(to: status) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let received = locations.map(LocationSample.init)
        // Yield directly (not through a Task) so arrival order is preserved.
        for sample in received { sampleContinuation.yield(sample) }
        Task { @MainActor [weak self] in self?.record(received) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: any Error) {
        // `kCLErrorLocationUnknown` is transient; CoreLocation keeps trying. Nothing to do:
        // the GPS status degrades to `lost` on its own when no samples arrive.
    }
}
