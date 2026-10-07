import Foundation
import Observation

enum AppTab: Hashable {
    case tracking, history
}

/// Which tab is visible and what the History stack shows. The app always opens on Tracking,
/// so an active run restored after a relaunch is the first thing the user sees.
@MainActor
@Observable
final class AppNavigation {
    var selection: AppTab = .tracking
    var historyPath: [UUID] = []

    /// After finishing, land on the details of the run that just closed.
    func showFinishedRun(_ id: UUID) {
        historyPath = [id]
        selection = .history
    }
}
