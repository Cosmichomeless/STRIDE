import Foundation
import Testing
@testable import STRIDE

@MainActor
struct HealthTests {
    private let factory = SampleFactory()

    /// A finished 1 km run: points every 10 s, with a pause between the 5th point (40 s) and the 6th (110 s).
    private func finishedRun(id: UUID = UUID(), distance: Double = 1_000) -> (RunRecord, [TrackPoint]) {
        var points: [TrackPoint] = []
        for index in 0..<10 {
            // The second half starts 60 s late, as if the run had been paused in between.
            let seconds = Double(index) * 10 + (index >= 5 ? 60 : 0)
            points.append(TrackPoint(sample: factory.sample(meters: Double(index) * 100, at: seconds), startsSegment: index == 0 || index == 5))
        }
        let run = RunRecord(
            id: id, startedAt: factory.now(0), finishedAt: factory.now(160), status: .finished,
            accumulatedDuration: 90, lastResumedAt: nil, distance: distance, averagePace: 360
        )
        return (run, points)
    }

    private func makeSync(
        health: FakeHealth = FakeHealth(), saveToHealth: Bool = true
    ) -> (HealthSync, FakeHealth, InMemoryRunStore, UUID) {
        let name = "stride.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        let settings = AppSettings(defaults: defaults, locale: Locale(identifier: "en_US"))
        settings.saveToHealth = saveToHealth
        let store = InMemoryRunStore()
        let (run, points) = finishedRun()
        try? store.save(run)
        for point in points { try? store.append(point, to: run.id, distance: run.distance) }
        return (HealthSync(health: health, settings: settings, store: store), health, store, run.id)
    }

    // MARK: Workout

    @Test func aFinishedRunBecomesAWorkoutWithItsRouteAndPause() throws {
        let (run, points) = finishedRun()
        let workout = try #require(WorkoutRecord(run: run, points: points))
        #expect(workout.start == factory.now(0))
        #expect(workout.end == factory.now(160))
        #expect(workout.distance == 1_000)
        #expect(workout.route.count == 10)
        #expect(workout.pauses == [DateInterval(start: factory.now(40), end: factory.now(110))])
    }

    @Test func pausedTimeIsTheGapBetweenSegments() throws {
        let (run, points) = finishedRun()
        let workout = try #require(WorkoutRecord(run: run, points: points))
        let end = workout.end.timeIntervalSince(workout.start)
        let paused = workout.pauses.reduce(0) { $0 + $1.duration }
        #expect(end - paused == run.accumulatedDuration)
    }

    @Test func runsThatAreNotWorthSavingProduceNoWorkout() {
        var (run, points) = finishedRun()
        run.distance = 0
        #expect(WorkoutRecord(run: run, points: points) == nil)

        (run, points) = finishedRun()
        run.status = .paused
        #expect(WorkoutRecord(run: run, points: points) == nil)

        (run, points) = finishedRun()
        run.finishedAt = nil
        #expect(WorkoutRecord(run: run, points: points) == nil)
    }

    @Test func aRunWithoutPausesHasNone() throws {
        var (run, points) = finishedRun()
        points = Array(points.prefix(5))
        run.finishedAt = factory.now(50)
        #expect(try #require(WorkoutRecord(run: run, points: points)).pauses.isEmpty)
    }

    // MARK: When to save

    @Test func aFinishedRunIsSavedOnceAccessIsGranted() async {
        let (sync, health, _, id) = makeSync()
        await sync.runFinished(id)
        #expect(sync.outcomes[id] == .saved)
        #expect(health.saved.count == 1)
        #expect(health.requestCount == 0)
    }

    @Test func theFirstFinishedRunAsksForAccessInContext() async {
        let (sync, health, _, id) = makeSync(health: FakeHealth(access: .notDetermined))
        await sync.runFinished(id)
        #expect(health.requestCount == 1)
        #expect(sync.outcomes[id] == .saved)
        #expect(sync.access == .authorized)
    }

    @Test func denyingAccessSavesNothingAndSaysSo() async {
        let health = FakeHealth(access: .notDetermined)
        health.accessAfterRequest = .denied
        let (sync, _, _, id) = makeSync(health: health)
        await sync.runFinished(id)
        #expect(sync.outcomes[id] == .accessDenied)
        #expect(health.saved.isEmpty)
        #expect(sync.access == .denied)
    }

    @Test func aDeniedUserIsNotAskedAgain() async {
        let (sync, health, _, id) = makeSync(health: FakeHealth(access: .denied))
        await sync.runFinished(id)
        #expect(health.requestCount == 0)
        #expect(sync.outcomes[id] == .accessDenied)
    }

    @Test func turningTheSettingOffSavesNothingAndAsksNothing() async {
        let (sync, health, _, id) = makeSync(health: FakeHealth(access: .notDetermined), saveToHealth: false)
        await sync.runFinished(id)
        #expect(health.requestCount == 0)
        #expect(health.saved.isEmpty)
        #expect(sync.outcomes[id] == nil)
    }

    @Test func aDeviceWithoutHealthIsLeftAlone() async {
        let (sync, health, _, id) = makeSync(health: FakeHealth(access: .unavailable))
        await sync.runFinished(id)
        #expect(health.requestCount == 0)
        #expect(health.saved.isEmpty)
        #expect(sync.outcomes[id] == nil)
    }

    @Test func aRunWithoutDistanceIsNotSaved() async throws {
        let (sync, health, store, id) = makeSync()
        var run = try #require(try store.run(id: id))
        run.distance = 0
        try store.save(run)
        await sync.runFinished(id)
        #expect(health.saved.isEmpty)
        #expect(sync.outcomes[id] == nil)
    }

    @Test func aRunStillInProgressIsNotSaved() async throws {
        let (sync, health, store, id) = makeSync()
        var run = try #require(try store.run(id: id))
        run.status = .paused
        run.finishedAt = nil
        try store.save(run)
        await sync.runFinished(id)
        #expect(health.saved.isEmpty)
    }

    @Test func aSavedRunIsNeverSavedTwice() async {
        let (sync, health, _, id) = makeSync()
        await sync.runFinished(id)
        await sync.runFinished(id)
        #expect(health.saved.count == 1)
    }

    // MARK: Failures

    @Test func aFailureCanBeRetried() async {
        let (sync, health, _, id) = makeSync()
        health.saveError = HealthError.workoutNotSaved
        await sync.runFinished(id)
        #expect(sync.outcomes[id] == .failed)

        health.saveError = nil
        await sync.runFinished(id)
        #expect(sync.outcomes[id] == .saved)
        #expect(health.saved.count == 1)
    }

    @Test func aMissingRouteIsReportedSeparately() async {
        let (sync, health, _, id) = makeSync()
        health.saveError = HealthError.routeNotSaved
        await sync.runFinished(id)
        #expect(sync.outcomes[id] == .savedWithoutRoute)
        #expect(sync.outcomes[id]?.isSaved == true)
    }

    // MARK: Setting

    @Test func turningTheSettingOnAsksOnlyIfTheSystemHasNotBeenAsked() async {
        let (fresh, freshHealth, _, _) = makeSync(health: FakeHealth(access: .notDetermined))
        await fresh.settingEnabled()
        #expect(freshHealth.requestCount == 1)
        #expect(fresh.access == .authorized)

        let (denied, deniedHealth, _, _) = makeSync(health: FakeHealth(access: .denied))
        await denied.settingEnabled()
        #expect(deniedHealth.requestCount == 0)
        #expect(denied.access == .denied)
    }

    @Test func refreshPicksUpAChangeMadeInTheSettingsApp() {
        let (sync, health, _, _) = makeSync(health: FakeHealth(access: .denied))
        #expect(sync.access == .denied)
        health.access = .authorized
        sync.refreshAccess()
        #expect(sync.access == .authorized)
    }

    // MARK: Declarations

    /// STRIDE only writes to Health: asking to read would need a reason it does not have.
    @Test func theAppExplainsWhatItWritesAndAsksToReadNothing() {
        let info = Bundle(for: HealthSync.self).infoDictionary ?? [:]
        #expect((info["NSHealthUpdateUsageDescription"] as? String)?.isEmpty == false)
        #expect(info["NSHealthShareUsageDescription"] == nil)
    }
}
