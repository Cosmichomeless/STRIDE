import Foundation
import Testing
@testable import STRIDE

@MainActor
struct TrackingCoordinatorTests {
    final class Clock: @unchecked Sendable {
        var current = Date(timeIntervalSince1970: 1_000)
        func advance(_ s: TimeInterval) { current = current.addingTimeInterval(s) }
    }

    private func make(authorization: LocationAuthorization = .whenInUse) -> (TrackingCoordinator, FakeLocationProvider, Clock) {
        let clock = Clock()
        let location = FakeLocationProvider(authorization: authorization)
        return (TrackingCoordinator(location: location, now: { clock.current }), location, clock)
    }

    @Test func fullRunLifecycleDrivesSessionState() {
        let (coordinator, location, clock) = make()
        coordinator.start()
        #expect(coordinator.session.state == .active)
        #expect(location.isUpdating)

        clock.advance(30)
        coordinator.pause()
        clock.advance(100)
        coordinator.resume()
        clock.advance(20)
        #expect(coordinator.elapsed(at: clock.current) == 50)

        coordinator.finish()
        #expect(coordinator.session.state == .finished)
        #expect(!location.isUpdating)
    }

    @Test func invalidIntentIsRecordedAndDoesNotChangeState() {
        let (coordinator, _, _) = make()
        coordinator.resume()
        #expect(coordinator.session.state == .idle)
        #expect(coordinator.lastError == InvalidTransition(action: .resume, state: .idle))
    }

    @Test func cannotStartWithoutPermission() {
        let (coordinator, location, _) = make(authorization: .denied)
        coordinator.start()
        #expect(coordinator.session.state == .idle)
        #expect(!location.isUpdating)
    }

    @Test func startWaitsForPermissionPromptThenBeginsRun() async {
        let (coordinator, _, _) = make(authorization: .notDetermined)
        coordinator.start()
        #expect(coordinator.session.state == .idle)
        #expect(coordinator.isAwaitingPermission)

        // FakeLocationProvider grants when asked; the change arrives through the stream.
        for _ in 0..<50 where coordinator.session.state == .idle {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(coordinator.session.state == .active)
        #expect(!coordinator.isAwaitingPermission)
    }

    @Test func denyingThePromptCancelsThePendingStart() async {
        let (coordinator, location, _) = make(authorization: .notDetermined)
        location.promptResult = .denied
        coordinator.start()
        for _ in 0..<50 where coordinator.isAwaitingPermission {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(coordinator.session.state == .idle)
        #expect(!coordinator.isAwaitingPermission)
    }

    @Test func startingAgainAfterFinishCreatesAFreshRun() {
        let (coordinator, _, clock) = make()
        coordinator.start()
        clock.advance(60)
        coordinator.finish()
        clock.advance(10)
        coordinator.start()
        #expect(coordinator.session.state == .active)
        #expect(coordinator.elapsed(at: clock.current) == 0)
    }

    // MARK: Samples and metrics

    private func fix(meters: Double, _ clock: Clock, accuracy: Double = 5) -> LocationSample {
        let perDegree = Geodesy.earthRadius * .pi / 180
        return LocationSample(
            latitude: 40 + meters / perDegree, longitude: -3, altitude: 0,
            horizontalAccuracy: accuracy, speed: -1, timestamp: clock.current
        )
    }

    /// Lets the coordinator's stream consumer process what was emitted.
    private func settle(_ coordinator: TrackingCoordinator, until condition: () -> Bool) async {
        for _ in 0..<100 where !condition() {
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func acceptedSamplesAccumulateDistance() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        for i in 0..<6 {
            clock.advance(1)
            location.emit(fix(meters: Double(i) * 5, clock))
        }
        await settle(coordinator) { coordinator.metrics.distance > 24 }
        #expect(abs(coordinator.metrics.distance - 25) < 0.01)
        #expect(coordinator.currentPace(at: clock.current) != nil)
    }

    @Test func noisySamplesNeverReachTheMetrics() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 8, clock))
        clock.advance(1); location.emit(fix(meters: 450, clock))               // impossible jump
        clock.advance(1); location.emit(fix(meters: 60, clock, accuracy: 80))   // imprecise
        clock.advance(1); location.emit(fix(meters: 12, clock))
        await settle(coordinator) { coordinator.metrics.distance > 11 }
        #expect(abs(coordinator.metrics.distance - 12) < 0.01)
    }

    @Test func samplesWhilePausedAreDiscardedAndResumeIsNotConnected() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 10, clock))
        await settle(coordinator) { coordinator.metrics.distance > 9 }

        coordinator.pause()
        clock.advance(30); location.emit(fix(meters: 500, clock))   // dropped
        clock.advance(30)
        coordinator.resume()
        clock.advance(1); location.emit(fix(meters: 1_000, clock))  // starts a new segment
        clock.advance(1); location.emit(fix(meters: 1_010, clock))
        await settle(coordinator) { coordinator.metrics.distance > 19 }

        #expect(abs(coordinator.metrics.distance - 20) < 0.01)
    }

    @Test func paceIsUnknownWhilePaused() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        for i in 0..<10 {
            clock.advance(1)
            location.emit(fix(meters: Double(i) * 3, clock))
        }
        await settle(coordinator) { coordinator.metrics.distance > 26 }
        #expect(coordinator.currentPace(at: clock.current) != nil)
        coordinator.pause()
        #expect(coordinator.currentPace(at: clock.current) == nil)
    }

    @Test func samplesBeforeStartingAreIgnored() async {
        let (coordinator, location, clock) = make()
        location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 20, clock))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(coordinator.metrics.distance == 0)
    }

    @Test func newRunStartsWithFreshMetrics() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 10, clock))
        await settle(coordinator) { coordinator.metrics.distance > 9 }
        coordinator.finish()
        clock.advance(5)
        coordinator.start()
        #expect(coordinator.metrics.distance == 0)
    }
}
