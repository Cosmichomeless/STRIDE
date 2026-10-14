import Foundation

/// Whether STRIDE may write workouts to Apple Health. Reading is never requested.
enum HealthAccess: Sendable, Equatable {
    /// Health data does not exist on this device (for example an iPad without Health).
    case unavailable
    /// The system sheet has not been shown yet.
    case notDetermined
    case denied
    case authorized
}

enum HealthError: Error, Equatable {
    /// The workout is in Health but its route could not be attached.
    case routeNotSaved
    case workoutNotSaved
}

/// Boundary between the app and HealthKit, so the rules (when to ask, what to save, what to tell the
/// user) can be tested with a double. Only `HealthKitWriter` imports HealthKit.
@MainActor
protocol HealthWriting: AnyObject {
    var access: HealthAccess { get }
    /// Shows the system permission sheet if it has not been shown; returns once the user answered.
    func requestAccess() async throws
    /// Writes the workout (distance, duration and route). Throws `HealthError.routeNotSaved` if only
    /// the route failed.
    func save(_ workout: WorkoutRecord) async throws
}
