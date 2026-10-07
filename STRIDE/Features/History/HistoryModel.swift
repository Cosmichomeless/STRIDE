import Foundation
import Observation

/// Completed runs for the History tab. Reads and deletes go through the same store the
/// coordinator writes to, so what is listed is exactly what was persisted.
@MainActor
@Observable
final class HistoryModel {
    private(set) var runs: [RunRecord] = []
    /// The last storage failure, shown instead of an empty list that would look like data loss.
    private(set) var error: (any Error)?

    private let store: any RunStore

    init(store: any RunStore) {
        self.store = store
        reload()
    }

    func reload() {
        do {
            runs = try store.completedRuns()
            error = nil
        } catch {
            self.error = error
        }
    }

    func delete(runId: UUID) {
        do {
            try store.delete(runId: runId)
            error = nil
        } catch {
            self.error = error
        }
        reload()
    }

    func run(id: UUID) -> RunRecord? {
        try? store.run(id: id)
    }

    /// The route of a stored run, rebuilt from its points. Empty if the run has none.
    func route(of runId: UUID) -> Route {
        Route(points: (try? store.points(of: runId)) ?? [])
    }
}
