import Foundation
import Testing
@testable import STRIDE

@MainActor
struct TrackingCoordinatorTests {
    final class Clock: @unchecked Sendable {
        var current = Date(timeIntervalSince1970: 1_000)
        func advance(_ s: TimeInterval) { current = current.addingTimeInterval(s) }
    }

    private func makeWithStore() -> (TrackingCoordinator, FakeLocationProvider, Clock, InMemoryRunStore) {
        let clock = Clock()
        let location = FakeLocationProvider()
        let store = InMemoryRunStore()
        return (TrackingCoordinator(location: location, store: store, now: { clock.current }), location, clock, store)
    }

    private func make(authorization: LocationAuthorization = .whenInUse) -> (TrackingCoordinator, FakeLocationProvider, Clock) {
        let clock = Clock()
        let location = FakeLocationProvider(authorization: authorization)
        return (TrackingCoordinator(location: location, store: InMemoryRunStore(), now: { clock.current }), location, clock)
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

    // MARK: Persistence and recovery

    @Test func startPersistsTheActiveRunImmediately() throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let coordinator = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        coordinator.start()
        let saved = try #require(try store.activeRun())
        #expect(saved.id == coordinator.runId)
        #expect(saved.status == .active)
        #expect(saved.startedAt == clock.current)
    }

    @Test func everyTransitionIsPersisted() throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let coordinator = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        coordinator.start()
        clock.advance(30)
        coordinator.pause()
        let paused = try #require(try store.activeRun())
        #expect(paused.status == .paused)
        #expect(paused.accumulatedDuration == 30)
        #expect(paused.lastResumedAt == nil)

        clock.advance(60)
        coordinator.resume()
        #expect(try store.activeRun()?.status == .active)

        clock.advance(10)
        coordinator.finish()
        #expect(try store.activeRun() == nil)
        let done = try #require(try store.completedRuns().first)
        #expect(done.status == .finished)
        #expect(done.accumulatedDuration == 40)
        #expect(done.finishedAt == clock.current)
    }

    @Test func acceptedPointsAreWrittenAndRejectedOnesAreNot() async throws {
        let (coordinator, location, clock, store) = makeWithStore()
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 450, clock))   // rejected
        clock.advance(1); location.emit(fix(meters: 6, clock))
        await settle(coordinator) { coordinator.metrics.distance > 5 }
        let id = try #require(coordinator.runId)
        let points = try store.points(of: id)
        #expect(points.count == 2)
        #expect(points.first?.startsSegment == true)
        #expect(points.last?.startsSegment == false)
        #expect(abs(try #require(try store.run(id: id)).distance - 6) < 0.01)
    }

    @Test func relaunchRestoresAPausedRun() async throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let first = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        first.start()
        clock.advance(45)
        first.pause()

        clock.advance(3_600)
        let second = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        #expect(second.session.state == .paused)
        #expect(second.runId == first.runId)
        #expect(second.elapsed(at: clock.current) == 45)
    }

    @Test func relaunchRestoresAnActiveRunRebuildsMetricsAndLeavesAGap() async throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let firstLocation = FakeLocationProvider()
        let first = TrackingCoordinator(location: firstLocation, store: store, now: { clock.current })
        first.start()
        for i in 0..<6 {
            clock.advance(1)
            firstLocation.emit(fix(meters: Double(i) * 5, clock))
        }
        await settle(first) { first.metrics.distance > 24 }

        // The process dies. 20 s later the app is relaunched.
        clock.advance(20)
        let secondLocation = FakeLocationProvider()
        let second = TrackingCoordinator(location: secondLocation, store: store, now: { clock.current })
        #expect(second.session.state == .active)
        #expect(secondLocation.isUpdating)
        #expect(abs(second.metrics.distance - 25) < 0.01)
        #expect(second.runId == first.runId)

        // The first sample after the gap does not connect to the last stored one.
        clock.advance(1); secondLocation.emit(fix(meters: 400, clock))
        clock.advance(1); secondLocation.emit(fix(meters: 405, clock))
        await settle(second) { second.metrics.distance > 29 }
        #expect(abs(second.metrics.distance - 30) < 0.01)
        let id = try #require(second.runId)
        #expect(try store.points(of: id).filter(\.startsSegment).count == 2)
    }

    @Test func relaunchWithoutPermissionPausesTheActiveRun() throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let first = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        first.start()
        clock.advance(10)

        let second = TrackingCoordinator(location: FakeLocationProvider(authorization: .denied), store: store, now: { clock.current })
        #expect(second.session.state == .paused)
        #expect(try store.activeRun()?.status == .paused)
    }

    @Test func relaunchWithoutAnActiveRunIsIdle() throws {
        let clock = Clock()
        let store = InMemoryRunStore()
        let first = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        first.start()
        clock.advance(10)
        first.finish()

        let second = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        #expect(second.session.state == .idle)
        #expect(second.runId == nil)
        #expect(try store.completedRuns().count == 1)
    }

    @Test func runDoesNotStartIfItCannotBeSaved() {
        let clock = Clock()
        let store = InMemoryRunStore()
        store.failWrites = true
        let location = FakeLocationProvider()
        let coordinator = TrackingCoordinator(location: location, store: store, now: { clock.current })
        coordinator.start()
        #expect(coordinator.session.state == .idle)
        #expect(coordinator.persistenceError != nil)
        #expect(!location.isUpdating)
    }

    @Test func trackingContinuesInMemoryWhenALaterWriteFails() async {
        let (coordinator, location, clock, store) = makeWithStore()
        coordinator.start()
        store.failWrites = true
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 10, clock))
        await settle(coordinator) { coordinator.metrics.distance > 9 }
        #expect(coordinator.session.state == .active)
        #expect(coordinator.persistenceError != nil)
    }

    // MARK: Background

    @Test func backgroundTrackingFollowsTheRun() {
        let (coordinator, location, clock) = make()
        #expect(!location.isBackgroundTracking)
        coordinator.start()
        #expect(location.isBackgroundTracking)

        clock.advance(10)
        coordinator.pause()
        #expect(!location.isBackgroundTracking)

        coordinator.resume()
        #expect(location.isBackgroundTracking)

        coordinator.finish()
        #expect(!location.isBackgroundTracking)
        #expect(!location.isUpdating)
    }

    @Test func idleAppReleasesTheGPSInTheBackground() {
        let (coordinator, location, _) = make()
        coordinator.appDidBecomeActive()
        #expect(location.isUpdating)
        coordinator.appDidEnterBackground()
        #expect(!location.isUpdating)
    }

    @Test func activeRunKeepsTrackingInTheBackground() {
        let (coordinator, location, _) = make()
        coordinator.start()
        coordinator.appDidEnterBackground()
        #expect(location.isUpdating)
        #expect(location.isBackgroundTracking)
        coordinator.appDidBecomeActive()
        #expect(location.isUpdating)
    }

    @Test func pausedRunReleasesTheGPSInTheBackgroundAndResumeRestartsIt() {
        let (coordinator, location, clock) = make()
        coordinator.start()
        clock.advance(5)
        coordinator.pause()
        coordinator.appDidEnterBackground()
        #expect(!location.isUpdating)
        coordinator.appDidBecomeActive()
        coordinator.appDidEnterBackground()
        coordinator.resume()
        #expect(location.isUpdating)
        #expect(location.isBackgroundTracking)
    }

    @Test func restoredActiveRunReenablesBackgroundTracking() {
        let clock = Clock()
        let store = InMemoryRunStore()
        let first = TrackingCoordinator(location: FakeLocationProvider(), store: store, now: { clock.current })
        first.start()
        let location = FakeLocationProvider()
        _ = TrackingCoordinator(location: location, store: store, now: { clock.current })
        #expect(location.isUpdating)
        #expect(location.isBackgroundTracking)
    }

    // MARK: Route

    @Test func routeHoldsOnlyAcceptedPointsAndSplitsAtPauses() async {
        let (coordinator, location, clock) = make()
        #expect(coordinator.route.isEmpty)
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        clock.advance(1); location.emit(fix(meters: 8, clock))
        clock.advance(1); location.emit(fix(meters: 450, clock))               // impossible jump
        clock.advance(1); location.emit(fix(meters: 60, clock, accuracy: 80))   // imprecise
        clock.advance(1); location.emit(fix(meters: 12, clock))
        await settle(coordinator) { coordinator.route.pointCount >= 3 }
        #expect(coordinator.route.segments.map(\.count) == [3])

        coordinator.pause()
        clock.advance(30)
        coordinator.resume()
        clock.advance(1); location.emit(fix(meters: 1_000, clock))
        clock.advance(1); location.emit(fix(meters: 1_010, clock))
        await settle(coordinator) { coordinator.route.pointCount >= 5 }
        #expect(coordinator.route.segments.map(\.count) == [3, 2])
    }

    @Test func routeIsRestoredAfterRelaunchAndTheGapStartsASegment() async {
        let clock = Clock()
        let store = InMemoryRunStore()
        let firstLocation = FakeLocationProvider()
        let first = TrackingCoordinator(location: firstLocation, store: store, now: { clock.current })
        first.start()
        for i in 0..<4 {
            clock.advance(1)
            firstLocation.emit(fix(meters: Double(i) * 5, clock))
        }
        await settle(first) { first.route.pointCount == 4 }

        clock.advance(20)
        let secondLocation = FakeLocationProvider()
        let second = TrackingCoordinator(location: secondLocation, store: store, now: { clock.current })
        #expect(second.route.segments.map(\.count) == [4])

        clock.advance(1); secondLocation.emit(fix(meters: 400, clock))
        await settle(second) { second.route.pointCount == 5 }
        #expect(second.route.segments.map(\.count) == [4, 1])
    }

    @Test func newRunClearsThePreviousRoute() async {
        let (coordinator, location, clock) = make()
        coordinator.start()
        clock.advance(1); location.emit(fix(meters: 0, clock))
        await settle(coordinator) { !coordinator.route.isEmpty }
        coordinator.finish()
        #expect(!coordinator.route.isEmpty)   // still available to show the completed route

        coordinator.start()
        #expect(coordinator.route.isEmpty)
    }
}
