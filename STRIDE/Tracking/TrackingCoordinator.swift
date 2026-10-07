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
    @ObservationIgnored private var validator = SampleValidator()
    /// The user asked to start while the permission prompt was showing.
    private(set) var isAwaitingPermission = false

    let location: any LocationProviding
    private let now: @Sendable () -> Date
    @ObservationIgnored private var authorizationTask: Task<Void, Never>?
    @ObservationIgnored private var sampleTask: Task<Void, Never>?

    init(location: any LocationProviding, now: @escaping @Sendable () -> Date = { Date() }) {
        self.location = location
        self.now = now
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
        location.stopUpdates()
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
            session = fresh
            metrics = RunMetrics()
            validator = SampleValidator(segmentStart: fresh.startedAt)
            lastError = nil
            location.startUpdates()
        } catch {
            lastError = error
        }
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
            // Nothing is connected across a pause: the first sample after resuming starts a new segment.
            if action == .resume { validator.beginSegment(at: date) }
        } catch {
            lastError = error
        }
    }

    /// Raw sample from the location layer: only an active run keeps samples, and only
    /// those that pass the filter reach the metrics.
    private func receive(_ sample: LocationSample) {
        guard session.state == .active else { return }
        let startsSegment = validator.lastAccepted == nil
        if validator.process(sample, now: now()).isAccepted {
            metrics.add(sample, startsSegment: startsSegment)
        }
    }

    private func authorizationDidChange(_ authorization: LocationAuthorization) {
        if isAwaitingPermission {
            if authorization.canTrack { beginRun() } else { isAwaitingPermission = false }
        }
    }
}
