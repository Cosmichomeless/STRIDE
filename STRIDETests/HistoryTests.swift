import Foundation
import Testing
@testable import STRIDE

@MainActor
struct HistoryTests {
    private func finished(_ id: UUID = UUID(), start: TimeInterval, distance: Double = 5_000, duration: TimeInterval = 1_500) -> RunRecord {
        RunRecord(
            id: id, startedAt: Date(timeIntervalSince1970: start), finishedAt: Date(timeIntervalSince1970: start + duration),
            status: .finished, accumulatedDuration: duration, lastResumedAt: nil, distance: distance,
            averagePace: distance > 0 ? duration / (distance / 1000) : nil
        )
    }

    private func point(_ lat: Double, segment: Bool) -> TrackPoint {
        TrackPoint(
            sample: LocationSample(latitude: lat, longitude: -3, altitude: 0, horizontalAccuracy: 5, speed: -1, timestamp: Date(timeIntervalSince1970: 0)),
            startsSegment: segment
        )
    }

    @Test func listsOnlyCompletedRunsNewestFirst() throws {
        let store = InMemoryRunStore()
        let old = finished(start: 100), recent = finished(start: 900)
        try store.save(old)
        try store.save(recent)
        try store.save(RunRecord(id: UUID(), startedAt: Date(timeIntervalSince1970: 2_000), finishedAt: nil, status: .active,
                                 accumulatedDuration: 0, lastResumedAt: Date(timeIntervalSince1970: 2_000), distance: 0, averagePace: nil))
        let history = HistoryModel(store: store)
        #expect(history.runs.map(\.id) == [recent.id, old.id])
    }

    @Test func emptyStoreGivesAnEmptyList() {
        let history = HistoryModel(store: InMemoryRunStore())
        #expect(history.runs.isEmpty)
        #expect(history.error == nil)
    }

    @Test func reloadPicksUpNewlyFinishedRuns() throws {
        let store = InMemoryRunStore()
        let history = HistoryModel(store: store)
        #expect(history.runs.isEmpty)
        try store.save(finished(start: 10))
        history.reload()
        #expect(history.runs.count == 1)
    }

    @Test func deleteRemovesTheRunAndItsPoints() throws {
        let store = InMemoryRunStore()
        let keep = finished(start: 10), drop = finished(start: 20)
        try store.save(keep)
        try store.save(drop)
        try store.append(point(40, segment: true), to: drop.id, distance: 0)
        let history = HistoryModel(store: store)

        history.delete(runId: drop.id)
        #expect(history.runs.map(\.id) == [keep.id])
        #expect(try store.points(of: drop.id).isEmpty)
    }

    @Test func detailsRouteIsRebuiltFromStoredPoints() throws {
        let store = InMemoryRunStore()
        let run = finished(start: 10)
        try store.save(run)
        try store.append(point(40.000, segment: true), to: run.id, distance: 0)
        try store.append(point(40.001, segment: false), to: run.id, distance: 111)
        try store.append(point(40.010, segment: true), to: run.id, distance: 111)
        let history = HistoryModel(store: store)

        #expect(history.route(of: run.id).segments.map(\.count) == [2, 1])
        #expect(history.run(id: run.id)?.id == run.id)
        #expect(history.route(of: UUID()).isEmpty)
        #expect(history.run(id: UUID()) == nil)
    }

    @Test func rowSummaryShowsDistanceDurationAndPace() {
        let run = finished(start: 0, distance: 5_200, duration: 1_690)
        #expect(RunSummary.distance(run) == "5.20 km")
        #expect(RunSummary.duration(run) == "28:10")
        #expect(RunSummary.pace(run) == "5:25 /km")
        #expect(RunSummary.line(run) == "5.20 km · 28:10 · 5:25 /km")
    }

    @Test func runWithoutDistanceShowsNoPace() {
        let run = finished(start: 0, distance: 0, duration: 60)
        #expect(RunSummary.line(run) == "0.00 km · 1:00 · -- /km")
    }

    @Test func appOpensOnTrackingAndFinishingLandsOnTheRunDetails() {
        let navigation = AppNavigation()
        #expect(navigation.selection == .tracking)
        #expect(navigation.historyPath.isEmpty)

        let id = UUID()
        navigation.showFinishedRun(id)
        #expect(navigation.selection == .history)
        #expect(navigation.historyPath == [id])
    }
}
