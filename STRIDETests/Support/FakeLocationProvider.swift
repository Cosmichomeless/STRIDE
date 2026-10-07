import Foundation
@testable import STRIDE

/// Deterministic stand-in for `LocationService`.
@MainActor
final class FakeLocationProvider: LocationProviding {
    private(set) var authorization: LocationAuthorization
    let samples: AsyncStream<LocationSample>
    let authorizationChanges: AsyncStream<LocationAuthorization>
    private let sampleContinuation: AsyncStream<LocationSample>.Continuation
    private let authorizationContinuation: AsyncStream<LocationAuthorization>.Continuation
    private(set) var isUpdating = false
    private(set) var startCount = 0

    init(authorization: LocationAuthorization = .whenInUse) {
        self.authorization = authorization
        (samples, sampleContinuation) = AsyncStream.makeStream()
        (authorizationChanges, authorizationContinuation) = AsyncStream.makeStream()
    }

    func requestAuthorization() { if authorization.canRequest { setAuthorization(.whenInUse) } }
    func startUpdates() { isUpdating = true; startCount += 1 }
    func stopUpdates() { isUpdating = false }

    func emit(_ sample: LocationSample) { sampleContinuation.yield(sample) }
    func setAuthorization(_ value: LocationAuthorization) {
        authorization = value
        authorizationContinuation.yield(value)
    }
}
