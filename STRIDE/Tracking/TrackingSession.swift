import Foundation

enum SessionState: Sendable, Equatable {
    case idle
    case active
    case paused
    case finished
}

enum SessionAction: Sendable, Equatable {
    case start, pause, resume, finish
}

struct InvalidTransition: Error, Equatable {
    let action: SessionAction
    let state: SessionState
}

/// The run state machine and its timer, as a pure value type.
///
/// ```text
/// idle ──start──▶ active ──pause──▶ paused ──resume──▶ active
///                   └────────finish─────────┴────────▶ finished
/// ```
///
/// Time never comes from the system clock: every transition and every `elapsed`
/// query receives the instant, so the machine is deterministic in tests and can be
/// rebuilt after a relaunch from its stored fields.
struct TrackingSession: Sendable, Equatable {
    private(set) var state: SessionState = .idle
    private(set) var startedAt: Date?
    private(set) var finishedAt: Date?
    /// Active time already banked, excluding paused time.
    private(set) var accumulated: TimeInterval = 0
    /// Start of the current active interval; `nil` unless `state == .active`.
    private(set) var lastResumedAt: Date?

    init() {}

    /// Rebuilds a session from persisted fields (used when restoring an active run).
    init(state: SessionState, startedAt: Date, finishedAt: Date? = nil, accumulated: TimeInterval, lastResumedAt: Date?) {
        self.state = state
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.accumulated = accumulated
        self.lastResumedAt = state == .active ? lastResumedAt : nil
    }

    var isInProgress: Bool { state == .active || state == .paused }

    /// Active duration at `now`, never counting paused time and never negative.
    func elapsed(at now: Date) -> TimeInterval {
        guard state == .active, let lastResumedAt else { return accumulated }
        return accumulated + max(0, now.timeIntervalSince(lastResumedAt))
    }

    mutating func start(at now: Date) throws(InvalidTransition) {
        guard state == .idle else { throw InvalidTransition(action: .start, state: state) }
        state = .active
        startedAt = now
        lastResumedAt = now
    }

    mutating func pause(at now: Date) throws(InvalidTransition) {
        guard state == .active else { throw InvalidTransition(action: .pause, state: state) }
        accumulated = elapsed(at: now)
        lastResumedAt = nil
        state = .paused
    }

    mutating func resume(at now: Date) throws(InvalidTransition) {
        guard state == .paused else { throw InvalidTransition(action: .resume, state: state) }
        lastResumedAt = now
        state = .active
    }

    /// Finishing is allowed from `active` and `paused`; the final duration is banked.
    mutating func finish(at now: Date) throws(InvalidTransition) {
        guard isInProgress else { throw InvalidTransition(action: .finish, state: state) }
        accumulated = elapsed(at: now)
        lastResumedAt = nil
        finishedAt = now
        state = .finished
    }
}
