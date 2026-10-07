import Foundation

/// A run as plain values, so `Tracking/` never depends on SwiftData.
struct RunRecord: Sendable, Equatable, Identifiable {
    var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    var status: RunStatus
    /// Active time banked so far, excluding paused time.
    var accumulatedDuration: TimeInterval
    /// Start of the current active interval; `nil` unless `status == .active`.
    var lastResumedAt: Date?
    var distance: Double
    var averagePace: Double?
}

/// An accepted sample as it is stored.
struct TrackPoint: Sendable, Equatable {
    var sample: LocationSample
    var startsSegment: Bool
}

enum RunStoreError: Error, Equatable {
    /// Only one run may be active or paused at a time.
    case anotherRunInProgress(UUID)
    case runNotFound(UUID)
}

/// Boundary between `Tracking/` and `Persistence/`. Writes are synchronous and happen
/// before the coordinator considers a sample part of the run.
@MainActor
protocol RunStore: AnyObject {
    /// The run that is `active` or `paused`, if the app was closed or killed mid-run.
    func activeRun() throws -> RunRecord?
    func run(id: UUID) throws -> RunRecord?
    /// Completed runs, newest first.
    func completedRuns() throws -> [RunRecord]
    /// Inserts or updates a run. Throws `anotherRunInProgress` if it would leave two runs in progress.
    func save(_ run: RunRecord) throws
    /// Appends one accepted point and updates the run's distance in the same write.
    func append(_ point: TrackPoint, to runId: UUID, distance: Double) throws
    /// Points of a run in chronological order.
    func points(of runId: UUID) throws -> [TrackPoint]
    /// Deletes a run together with its points.
    func delete(runId: UUID) throws
}
