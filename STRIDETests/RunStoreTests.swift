import Foundation
import SwiftData
import Testing
@testable import STRIDE

/// The same contract is checked against the real SwiftData store and the in-memory fake.
@MainActor
struct RunStoreTests {
    private let factory = SampleFactory()

    private func makeStores() throws -> [any RunStore] {
        [SwiftDataRunStore(container: try StrideSchema.makeContainer(inMemory: true)), InMemoryRunStore()]
    }

    private func record(_ id: UUID = UUID(), start: Double = 0, status: RunStatus = .active) -> RunRecord {
        RunRecord(
            id: id, startedAt: factory.now(start), finishedAt: status == .finished ? factory.now(start + 60) : nil,
            status: status, accumulatedDuration: status == .finished ? 60 : 0,
            lastResumedAt: status == .active ? factory.now(start) : nil, distance: 0, averagePace: nil
        )
    }

    @Test func savesAndRestoresTheActiveRun() throws {
        for store in try makeStores() {
            #expect(try store.activeRun() == nil)
            let run = record()
            try store.save(run)
            #expect(try store.activeRun() == run)
        }
    }

    @Test func updatingARunKeepsASingleRow() throws {
        for store in try makeStores() {
            var run = record()
            try store.save(run)
            run.status = .paused
            run.accumulatedDuration = 42
            run.lastResumedAt = nil
            try store.save(run)
            #expect(try store.activeRun() == run)
            #expect(try store.completedRuns().isEmpty)
        }
    }

    @Test func atMostOneRunInProgress() throws {
        for store in try makeStores() {
            let first = record()
            try store.save(first)
            #expect(throws: RunStoreError.anotherRunInProgress(first.id)) {
                try store.save(record(start: 100))
            }
            // A paused run still counts as in progress.
            var paused = first
            paused.status = .paused
            try store.save(paused)
            #expect(throws: RunStoreError.anotherRunInProgress(first.id)) {
                try store.save(record(start: 100, status: .paused))
            }
            // Once finished, a new run may start.
            var done = first
            done.status = .finished
            done.finishedAt = factory.now(60)
            try store.save(done)
            try store.save(record(start: 100))
        }
    }

    @Test func pointsAreAppendedIncrementallyAndReadBackInOrder() throws {
        for store in try makeStores() {
            let run = record()
            try store.save(run)
            for i in 0..<3_000 {
                let point = TrackPoint(sample: factory.sample(meters: Double(i), at: Double(i)), startsSegment: i == 0)
                try store.append(point, to: run.id, distance: Double(i))
            }
            let points = try store.points(of: run.id)
            #expect(points.count == 3_000)
            #expect(points.first?.startsSegment == true)
            #expect(points.last?.sample == factory.sample(meters: 2_999, at: 2_999))
            #expect(try store.run(id: run.id)?.distance == 2_999)
        }
    }

    @Test func appendingToUnknownRunFails() throws {
        for store in try makeStores() {
            let missing = UUID()
            #expect(throws: RunStoreError.runNotFound(missing)) {
                try store.append(TrackPoint(sample: factory.sample(), startsSegment: true), to: missing, distance: 0)
            }
        }
    }

    @Test func completedRunsAreNewestFirstAndExcludeInProgress() throws {
        for store in try makeStores() {
            let old = record(start: 0, status: .finished)
            let recent = record(start: 1_000, status: .finished)
            try store.save(old)
            try store.save(recent)
            try store.save(record(start: 2_000))
            #expect(try store.completedRuns().map(\.id) == [recent.id, old.id])
        }
    }

    @Test func deleteRemovesTheRunAndOnlyItsPoints() throws {
        for store in try makeStores() {
            let a = record(start: 0, status: .finished)
            let b = record(start: 1_000, status: .finished)
            try store.save(a)
            try store.save(b)
            for i in 0..<5 {
                try store.append(TrackPoint(sample: factory.sample(meters: Double(i), at: Double(i)), startsSegment: false), to: a.id, distance: 0)
                try store.append(TrackPoint(sample: factory.sample(meters: Double(i), at: Double(i)), startsSegment: false), to: b.id, distance: 0)
            }
            try store.delete(runId: a.id)
            #expect(try store.run(id: a.id) == nil)
            #expect(try store.points(of: a.id).isEmpty)
            #expect(try store.points(of: b.id).count == 5)
        }
    }

    @Test func completedRunsSurviveReopeningTheStore() throws {
        // A fresh store over the same container simulates a restart of the app.
        let container = try StrideSchema.makeContainer(inMemory: true)
        let first = SwiftDataRunStore(container: container)
        var run = record()
        try first.save(run)
        try first.append(TrackPoint(sample: factory.sample(), startsSegment: true), to: run.id, distance: 0)
        run.status = .finished
        run.finishedAt = factory.now(60)
        run.accumulatedDuration = 60
        run.lastResumedAt = nil
        try first.save(run)

        let second = SwiftDataRunStore(container: container)
        #expect(try second.completedRuns() == [run])
        #expect(try second.points(of: run.id).count == 1)
        #expect(try second.activeRun() == nil)
    }
}
