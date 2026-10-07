import Foundation
import SwiftData
import Testing
@testable import STRIDE

@MainActor
struct DataModelTests {
    private func sample(_ i: Int, runStart: Date = Date(timeIntervalSince1970: 1_000)) -> LocationSample {
        LocationSample(
            latitude: 40.0 + Double(i) * 0.00001,
            longitude: -3.0,
            altitude: 600,
            horizontalAccuracy: 5,
            speed: 3,
            timestamp: runStart.addingTimeInterval(Double(i))
        )
    }

    @Test func runRoundTripsStatusAndDefaults() throws {
        let container = try StrideSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let run = Run(startedAt: Date(timeIntervalSince1970: 1_000))
        context.insert(run)
        try context.save()

        let fetched = try #require(try context.fetch(FetchDescriptor<Run>()).first)
        #expect(fetched.status == .active)
        #expect(fetched.lastResumedAt == fetched.startedAt)
        #expect(fetched.finishedAt == nil)
        #expect(fetched.status.isInProgress)
    }

    @Test func pausedRunHasNoResumeTimestamp() {
        let run = Run(startedAt: .now, status: .paused, accumulatedDuration: 30)
        #expect(run.lastResumedAt == nil)
        #expect(run.duration == 30)
    }

    @Test func unknownStatusFallsBackToFinished() {
        let run = Run(startedAt: .now)
        run.statusRaw = "garbage"
        #expect(run.status == .finished)
    }

    @Test func thousandsOfPointsAreFetchedPerRunInOrder() throws {
        let container = try StrideSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        let runA = Run(startedAt: Date(timeIntervalSince1970: 1_000))
        let runB = Run(startedAt: Date(timeIntervalSince1970: 9_000))
        context.insert(runA)
        context.insert(runB)
        for i in 0..<3_000 {
            context.insert(LocationPoint(runId: runA.id, sample: sample(i), startsSegment: i == 0))
        }
        for i in 0..<10 {
            context.insert(LocationPoint(runId: runB.id, sample: sample(i)))
        }
        try context.save()

        let runAId = runA.id
        var descriptor = FetchDescriptor<LocationPoint>(
            predicate: #Predicate { $0.runId == runAId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        let points = try context.fetch(descriptor)
        #expect(points.count == 3_000)
        #expect(points.first?.startsSegment == true)
        #expect(points.first!.timestamp < points.last!.timestamp)

        descriptor.fetchLimit = 1
        descriptor.sortBy = [SortDescriptor(\.timestamp, order: .reverse)]
        let last = try context.fetch(descriptor)
        #expect(last.first?.timestamp == points.last?.timestamp)
    }

    @Test func pointConvertsBackToSample() {
        let original = sample(7)
        let point = LocationPoint(runId: UUID(), sample: original)
        #expect(point.sample == original)
    }

    @Test func fetchingRunsDoesNotNeedPoints() throws {
        // Documents the design: Run has no relationship to its points.
        let container = try StrideSchema.makeContainer(inMemory: true)
        let context = ModelContext(container)
        context.insert(Run(startedAt: .now, status: .finished))
        try context.save()
        #expect(try context.fetch(FetchDescriptor<Run>()).count == 1)
    }
}
