import Foundation

/// Why a run is paused when the user did not ask for it. The run is never resumed
/// automatically: the user decides, so no unexpected time or distance is added.
enum PauseReason: Sendable, Equatable {
    /// Location access was revoked or restricted while the run was in progress.
    case permissionLost
    /// The app stopped running (killed, crashed, restarted) and nothing was recorded after `at`.
    case interrupted(at: Date)

    var message: String {
        switch self {
        case .permissionLost:
            "Location access was lost, so the run was paused. Allow access, then resume."
        case .interrupted:
            "The app was closed during your run. The time it was closed is not counted. Resume or finish."
        }
    }
}
