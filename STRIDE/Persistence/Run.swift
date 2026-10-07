import Foundation
import SwiftData

/// One running session. A `Run` that is `active` or `paused` *is* the persisted
/// active-session state: it carries everything needed to rebuild the timer after
/// the process is killed.
@Model
final class Run {
    @Attribute(.unique) var id: UUID
    var startedAt: Date
    var finishedAt: Date?
    /// Stored as the raw value so the schema stays stable if the enum evolves.
    var statusRaw: String

    /// Active time already accumulated, excluding paused time (seconds).
    var accumulatedDuration: TimeInterval
    /// When the current active interval began. `nil` while paused or finished.
    var lastResumedAt: Date?
    /// Validated distance in meters. Updated incrementally while running.
    var distance: Double
    /// Average pace in seconds per kilometer. `nil` until there is distance.
    var averagePace: Double?

    var status: RunStatus {
        get { RunStatus(rawValue: statusRaw) ?? .finished }
        set { statusRaw = newValue.rawValue }
    }

    /// Final duration of a finished run, or the accumulated duration so far.
    var duration: TimeInterval { accumulatedDuration }

    init(
        id: UUID = UUID(),
        startedAt: Date,
        status: RunStatus = .active,
        accumulatedDuration: TimeInterval = 0,
        lastResumedAt: Date? = nil,
        distance: Double = 0,
        averagePace: Double? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.startedAt = startedAt
        self.statusRaw = status.rawValue
        self.accumulatedDuration = accumulatedDuration
        self.lastResumedAt = lastResumedAt ?? (status == .active ? startedAt : nil)
        self.distance = distance
        self.averagePace = averagePace
        self.finishedAt = finishedAt
    }
}
