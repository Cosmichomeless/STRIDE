import Foundation
import Observation

/// Decides when a finished run goes to Apple Health and tells the UI how it went. The permission sheet
/// appears in context: when the first run finishes, or when the user turns the setting back on.
@MainActor
@Observable
final class HealthSync {
    enum Outcome: Equatable, Sendable {
        case saved
        /// The workout is in Health but the route is not.
        case savedWithoutRoute
        /// The user has not allowed STRIDE to write to Health.
        case accessDenied
        case failed

        var isSaved: Bool { self == .saved || self == .savedWithoutRoute }
    }

    private(set) var access: HealthAccess
    /// How saving each run went, for the runs finished during this launch.
    private(set) var outcomes: [UUID: Outcome] = [:]

    private let health: any HealthWriting
    private let settings: AppSettings
    private let store: any RunStore
    /// Runs being written right now, so a second tap on "Try again" cannot save the same run twice.
    private var saving: Set<UUID> = []

    init(health: any HealthWriting, settings: AppSettings, store: any RunStore) {
        self.health = health
        self.settings = settings
        self.store = store
        access = health.access
    }

    /// The user can change the permission in the Settings app while STRIDE is in the background.
    func refreshAccess() {
        access = health.access
    }

    /// The user turned "Save runs to Health" on: ask now if the system has not been asked yet.
    func settingEnabled() async {
        guard settings.saveToHealth, health.access == .notDetermined else {
            refreshAccess()
            return
        }
        try? await health.requestAccess()
        refreshAccess()
    }

    /// Saves a finished run unless the user turned Health off, the run has no distance or it is already saved.
    func runFinished(_ id: UUID) async {
        guard settings.saveToHealth, outcomes[id]?.isSaved != true, saving.insert(id).inserted else { return }
        defer { saving.remove(id) }
        guard let run = try? store.run(id: id), run.status == .finished, run.distance > 0 else { return }

        if health.access == .notDetermined {
            try? await health.requestAccess()
        }
        refreshAccess()
        switch access {
        case .unavailable:
            return
        case .notDetermined, .denied:
            outcomes[id] = .accessDenied
            return
        case .authorized:
            break
        }

        guard let points = try? store.points(of: id), let workout = WorkoutRecord(run: run, points: points) else {
            outcomes[id] = .failed
            return
        }
        do {
            try await health.save(workout)
            outcomes[id] = .saved
        } catch HealthError.routeNotSaved {
            outcomes[id] = .savedWithoutRoute
        } catch {
            outcomes[id] = .failed
        }
    }
}
