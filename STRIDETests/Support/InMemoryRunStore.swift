import Foundation
@testable import STRIDE

/// Dictionary-backed store for coordinator tests; can be told to fail.
@MainActor
final class InMemoryRunStore: RunStore {
    private(set) var runs: [UUID: RunRecord] = [:]
    private(set) var pointsByRun: [UUID: [TrackPoint]] = [:]
    var failWrites = false

    struct WriteFailure: Error {}

    func activeRun() throws -> RunRecord? { runs.values.first { $0.status.isInProgress } }
    func run(id: UUID) throws -> RunRecord? { runs[id] }
    func completedRuns() throws -> [RunRecord] {
        runs.values.filter { $0.status == .finished }.sorted { $0.startedAt > $1.startedAt }
    }
    func save(_ run: RunRecord) throws {
        if failWrites { throw WriteFailure() }
        if run.status.isInProgress, let other = runs.values.first(where: { $0.status.isInProgress && $0.id != run.id }) {
            throw RunStoreError.anotherRunInProgress(other.id)
        }
        runs[run.id] = run
    }
    func append(_ point: TrackPoint, to runId: UUID, distance: Double) throws {
        if failWrites { throw WriteFailure() }
        guard runs[runId] != nil else { throw RunStoreError.runNotFound(runId) }
        pointsByRun[runId, default: []].append(point)
        runs[runId]?.distance = distance
    }
    func points(of runId: UUID) throws -> [TrackPoint] { pointsByRun[runId] ?? [] }
    func delete(runId: UUID) throws {
        runs[runId] = nil
        pointsByRun[runId] = nil
    }
}
