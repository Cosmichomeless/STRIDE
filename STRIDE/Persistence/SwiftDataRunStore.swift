import Foundation
import SwiftData

@MainActor
final class SwiftDataRunStore: RunStore {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    func activeRun() throws -> RunRecord? {
        try inProgress().first.map(Self.record)
    }

    func run(id: UUID) throws -> RunRecord? {
        try fetchRun(id: id).map(Self.record)
    }

    func completedRuns() throws -> [RunRecord] {
        let finished = RunStatus.finished.rawValue
        let descriptor = FetchDescriptor<Run>(
            predicate: #Predicate { $0.statusRaw == finished },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor).map(Self.record)
    }

    func save(_ record: RunRecord) throws {
        if record.status.isInProgress, let other = try inProgress().first(where: { $0.id != record.id }) {
            throw RunStoreError.anotherRunInProgress(other.id)
        }
        let run: Run
        if let existing = try fetchRun(id: record.id) {
            run = existing
        } else {
            run = Run(id: record.id, startedAt: record.startedAt)
            context.insert(run)
        }
        run.startedAt = record.startedAt
        run.finishedAt = record.finishedAt
        run.status = record.status
        run.accumulatedDuration = record.accumulatedDuration
        run.lastResumedAt = record.lastResumedAt
        run.distance = record.distance
        run.averagePace = record.averagePace
        try commit()
    }

    func append(_ point: TrackPoint, to runId: UUID, distance: Double) throws {
        guard let run = try fetchRun(id: runId) else { throw RunStoreError.runNotFound(runId) }
        context.insert(LocationPoint(runId: runId, sample: point.sample, startsSegment: point.startsSegment))
        run.distance = distance
        try commit()
    }

    func points(of runId: UUID) throws -> [TrackPoint] {
        let descriptor = FetchDescriptor<LocationPoint>(
            predicate: #Predicate { $0.runId == runId },
            sortBy: [SortDescriptor(\.timestamp)]
        )
        return try context.fetch(descriptor).map { TrackPoint(sample: $0.sample, startsSegment: $0.startsSegment) }
    }

    func delete(runId: UUID) throws {
        try context.delete(model: LocationPoint.self, where: #Predicate { $0.runId == runId })
        try context.delete(model: Run.self, where: #Predicate { $0.id == runId })
        try commit()
    }

    // MARK: Private

    private func inProgress() throws -> [Run] {
        let active = RunStatus.active.rawValue, paused = RunStatus.paused.rawValue
        let descriptor = FetchDescriptor<Run>(
            predicate: #Predicate { $0.statusRaw == active || $0.statusRaw == paused },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    private func fetchRun(id: UUID) throws -> Run? {
        var descriptor = FetchDescriptor<Run>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    private func commit() throws {
        do {
            try context.save()
        } catch {
            context.rollback()
            throw error
        }
    }

    private static func record(_ run: Run) -> RunRecord {
        RunRecord(
            id: run.id, startedAt: run.startedAt, finishedAt: run.finishedAt, status: run.status,
            accumulatedDuration: run.accumulatedDuration, lastResumedAt: run.lastResumedAt,
            distance: run.distance, averagePace: run.averagePace
        )
    }
}
