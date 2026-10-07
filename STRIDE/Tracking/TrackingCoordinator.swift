import Foundation
import Observation

/// Owns the active run for the lifetime of the app. Views only read its state and
/// call its intents; destroying a view can never affect a run.
@MainActor
@Observable
final class TrackingCoordinator {
    private(set) var session = TrackingSession()
    private(set) var lastError: InvalidTransition?
    /// Distance and pace of the active run, from validated samples only.
    private(set) var metrics = RunMetrics()
    /// Accepted points of the active run grouped in segments, for the map.
    private(set) var route = Route()
    /// The run being recorded, or the one that just finished until a new one starts.
    private(set) var runId: UUID?
    /// The last storage failure. Tracking continues in memory when a write fails, but the
    /// run is no longer guaranteed to survive a restart, so the UI surfaces this.
    private(set) var persistenceError: (any Error)?
    @ObservationIgnored private var validator = SampleValidator()
    /// The user asked to start while the permission prompt was showing.
    private(set) var isAwaitingPermission = false

    let location: any LocationProviding
    private let store: any RunStore
    private let now: @Sendable () -> Date
    @ObservationIgnored private var authorizationTask: Task<Void, Never>?
    @ObservationIgnored private var sampleTask: Task<Void, Never>?

    init(location: any LocationProviding, store: any RunStore, now: @escaping @Sendable () -> Date = { Date() }) {
        self.location = location
        self.store = store
        self.now = now
        restoreActiveRun()
        authorizationTask = Task { [weak self] in
            guard let changes = self?.location.authorizationChanges else { return }
            for await authorization in changes {
                self?.authorizationDidChange(authorization)
            }
        }
        sampleTask = Task { [weak self] in
            guard let samples = self?.location.samples else { return }
            for await sample in samples {
                self?.receive(sample)
            }
        }
    }

    // MARK: Intents

    func start() {
        guard session.state == .idle || session.state == .finished else { return }
        guard location.authorization.canTrack else {
            if location.authorization.canRequest {
                isAwaitingPermission = true
                location.requestAuthorization()
            }
            return
        }
        beginRun()
    }

    func pause() { perform(.pause) }

    func resume() { perform(.resume) }

    func finish() {
        perform(.finish)
        location.setBackgroundTracking(false)
        location.stopUpdates()
    }

    /// The app left the foreground. Only an *active* run needs the GPS in the background
    /// (iOS keeps delivering updates); idle, paused and finished states release it (battery).
    func appDidEnterBackground() {
        guard session.state != .active else { return }
        location.stopUpdates()
    }

    /// The app is in the foreground again: warm up the GPS so a fix is ready for Start.
    func appDidBecomeActive() {
        location.startUpdates()
    }

    // MARK: Derived state

    func elapsed(at date: Date) -> TimeInterval { session.elapsed(at: date) }

    /// Seconds per kilometer over the last seconds of the run; `nil` unless actively moving.
    func currentPace(at date: Date) -> TimeInterval? {
        session.state == .active ? metrics.currentPace(at: date) : nil
    }

    func averagePace(at date: Date) -> TimeInterval? {
        metrics.averagePace(elapsed: elapsed(at: date))
    }

    // MARK: Private

    private func beginRun() {
        isAwaitingPermission = false
        var fresh = TrackingSession()
        do {
            try fresh.start(at: now())
        } catch {
            lastError = error
            return
        }
        // The run exists in the store before it exists in memory: if it cannot be saved, it does not start.
        let id = UUID()
        do {
            try store.save(record(id: id, session: fresh, metrics: RunMetrics()))
        } catch {
            persistenceError = error
            return
        }
        session = fresh
        metrics = RunMetrics()
        route = Route()
        validator = SampleValidator(segmentStart: fresh.startedAt)
        runId = id
        lastError = nil
        persistenceError = nil
        location.setBackgroundTracking(true)
        location.startUpdates()
    }

    private func perform(_ action: SessionAction) {
        var next = session
        let date = now()
        do {
            switch action {
            case .start: try next.start(at: date)
            case .pause: try next.pause(at: date)
            case .resume: try next.resume(at: date)
            case .finish: try next.finish(at: date)
            }
            session = next
            lastError = nil
            persist()
            // Nothing is connected across a pause: the first sample after resuming starts a new segment.
            switch action {
            case .resume:
                validator.beginSegment(at: date)
                location.setBackgroundTracking(true)
                location.startUpdates()
            case .pause:
                location.setBackgroundTracking(false)
            case .start, .finish:
                break
            }
        } catch {
            lastError = error
        }
    }

    /// Raw sample from the location layer: only an active run keeps samples, and only
    /// those that pass the filter reach the metrics.
    private func receive(_ sample: LocationSample) {
        guard session.state == .active else { return }
        let startsSegment = validator.lastAccepted == nil
        guard validator.process(sample, now: now()).isAccepted else { return }
        metrics.add(sample, startsSegment: startsSegment)
        route.add(sample, startsSegment: startsSegment)
        guard let runId else { return }
        do {
            try store.append(TrackPoint(sample: sample, startsSegment: startsSegment), to: runId, distance: metrics.distance)
        } catch {
            persistenceError = error
        }
    }

    // MARK: Persistence

    private func record(id: UUID, session: TrackingSession, metrics: RunMetrics) -> RunRecord {
        let status: RunStatus = switch session.state {
        case .active: .active
        case .paused: .paused
        case .finished, .idle: .finished
        }
        return RunRecord(
            id: id,
            startedAt: session.startedAt ?? now(),
            finishedAt: session.finishedAt,
            status: status,
            accumulatedDuration: session.accumulated,
            lastResumedAt: session.lastResumedAt,
            distance: metrics.distance,
            averagePace: session.state == .finished ? metrics.averagePace(elapsed: session.accumulated) : nil
        )
    }

    private func persist() {
        guard let runId else { return }
        do {
            try store.save(record(id: runId, session: session, metrics: metrics))
            persistenceError = nil
        } catch {
            persistenceError = error
        }
    }

    /// Rebuilds the session after a relaunch from the persisted run and its points.
    /// The time between the last sample and now is a gap: the first new sample starts a
    /// segment, so no distance is invented across it.
    private func restoreActiveRun() {
        do {
            guard let record = try store.activeRun() else { return }
            var restored = RunMetrics()
            let points = try store.points(of: record.id)
            for point in points {
                restored.add(point.sample, startsSegment: point.startsSegment)
            }
            session = TrackingSession(
                state: record.status == .active ? .active : .paused,
                startedAt: record.startedAt,
                accumulated: record.accumulatedDuration,
                lastResumedAt: record.lastResumedAt
            )
            metrics = restored
            route = Route(points: points)
            runId = record.id
            validator = SampleValidator(segmentStart: now())
            guard session.state == .active else { return }
            if location.authorization.canTrack {
                location.setBackgroundTracking(true)
                location.startUpdates()
            } else {
                perform(.pause)
            }
        } catch {
            persistenceError = error
        }
    }

    private func authorizationDidChange(_ authorization: LocationAuthorization) {
        if isAwaitingPermission {
            if authorization.canTrack { beginRun() } else { isAwaitingPermission = false }
        }
    }
}
