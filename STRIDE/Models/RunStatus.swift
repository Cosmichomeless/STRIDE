import Foundation

enum RunStatus: String, Sendable, Codable, CaseIterable {
    case active
    case paused
    case finished

    /// A run that has not finished yet and must survive an app restart.
    var isInProgress: Bool { self != .finished }
}
