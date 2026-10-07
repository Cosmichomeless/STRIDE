import Foundation

enum GPSStatus: Sendable, Equatable {
    /// Authorized but no valid fix yet.
    case acquiring
    /// Recent fix with good horizontal accuracy.
    case good
    /// Recent fix but poor accuracy.
    case weak
    /// Had a fix, but none recently.
    case lost
    /// Location services off or permission missing.
    case unavailable

    var label: String {
        switch self {
        case .acquiring: "Acquiring GPS…"
        case .good: "GPS ready"
        case .weak: "Weak GPS signal"
        case .lost: "GPS signal lost"
        case .unavailable: "GPS unavailable"
        }
    }
}
