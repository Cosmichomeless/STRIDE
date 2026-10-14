import Foundation
@testable import STRIDE

/// Stands in for Apple Health: records what would be saved and answers permission requests as told.
@MainActor
final class FakeHealth: HealthWriting {
    var access: HealthAccess
    /// What the system sheet ends up granting when `requestAccess` is called.
    var accessAfterRequest: HealthAccess = .authorized
    var saveError: (any Error)?
    private(set) var requestCount = 0
    private(set) var saved: [WorkoutRecord] = []

    init(access: HealthAccess = .authorized) { self.access = access }

    func requestAccess() async throws {
        requestCount += 1
        access = accessAfterRequest
    }

    func save(_ workout: WorkoutRecord) async throws {
        if let saveError { throw saveError }
        saved.append(workout)
    }
}
