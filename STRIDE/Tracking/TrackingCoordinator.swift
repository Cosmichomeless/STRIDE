import Foundation
import Observation

/// Owns the active run for the lifetime of the app. Views only read its state and
/// call its intents; destroying a view can never affect a run.
@MainActor
@Observable
final class TrackingCoordinator {
    private(set) var session = TrackingSession()
    private(set) var lastError: InvalidTransition?
    /// The user asked to start while the permission prompt was showing.
    private(set) var isAwaitingPermission = false

    let location: any LocationProviding
    private let now: @Sendable () -> Date
    @ObservationIgnored private var authorizationTask: Task<Void, Never>?

    init(location: any LocationProviding, now: @escaping @Sendable () -> Date = { Date() }) {
        self.location = location
        self.now = now
        authorizationTask = Task { [weak self] in
            guard let changes = self?.location.authorizationChanges else { return }
            for await authorization in changes {
                self?.authorizationDidChange(authorization)
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

    // MARK: Private

    private func beginRun() {
        isAwaitingPermission = false
        var fresh = TrackingSession()
        do {
            try fresh.start(at: now())
            session = fresh
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
        } catch {
            lastError = error
        }
    }

    private func authorizationDidChange(_ authorization: LocationAuthorization) {
        if isAwaitingPermission {
            if authorization.canTrack { beginRun() } else { isAwaitingPermission = false }
        }
    }
}
