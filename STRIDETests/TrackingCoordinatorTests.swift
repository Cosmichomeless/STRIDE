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
}
