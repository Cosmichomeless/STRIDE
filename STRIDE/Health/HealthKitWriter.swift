import CoreLocation
import Foundation
import HealthKit

/// Writes finished runs to Apple Health as running workouts with their route. STRIDE only shares: it
/// asks to write workouts, distance and routes, and asks to read nothing.
@MainActor
final class HealthKitWriter: HealthWriting {
    private let store = HKHealthStore()
    private let distanceType = HKQuantityType(.distanceWalkingRunning)

    private var shareTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), distanceType, HKSeriesType.workoutRoute()]
    }

    var access: HealthAccess {
        guard HKHealthStore.isHealthDataAvailable() else { return .unavailable }
        switch store.authorizationStatus(for: HKObjectType.workoutType()) {
        case .notDetermined: return .notDetermined
        case .sharingAuthorized: return .authorized
        case .sharingDenied: return .denied
        @unknown default: return .denied
        }
    }

    func requestAccess() async throws {
        try await store.requestAuthorization(toShare: shareTypes, read: [])
    }

    func save(_ workout: WorkoutRecord) async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor

        let builder = HKWorkoutBuilder(healthStore: store, configuration: configuration, device: .local())
        try await builder.beginCollection(at: workout.start)
        let distance = HKQuantitySample(
            type: distanceType,
            quantity: HKQuantity(unit: .meter(), doubleValue: workout.distance),
            start: workout.start,
            end: workout.end
        )
        try await builder.addSamples([distance])
        let events = workout.pauses.flatMap { pause in
            [
                HKWorkoutEvent(type: .pause, dateInterval: DateInterval(start: pause.start, duration: 0), metadata: nil),
                HKWorkoutEvent(type: .resume, dateInterval: DateInterval(start: pause.end, duration: 0), metadata: nil),
            ]
        }
        if !events.isEmpty { try await builder.addWorkoutEvents(events) }
        try await builder.endCollection(at: workout.end)
        guard let saved = try await builder.finishWorkout() else { throw HealthError.workoutNotSaved }

        guard !workout.route.isEmpty else { return }
        do {
            let routeBuilder = HKWorkoutRouteBuilder(healthStore: store, device: .local())
            let locations = workout.route.map(Self.location)
            // Health takes the route in batches; one call per thousand points keeps each one small.
            for start in stride(from: 0, to: locations.count, by: 1_000) {
                try await routeBuilder.insertRouteData(Array(locations[start..<min(start + 1_000, locations.count)]))
            }
            _ = try await routeBuilder.finishRoute(with: saved, metadata: nil)
        } catch {
            throw HealthError.routeNotSaved
        }
    }

    /// The altitude is not passed on: its accuracy is not recorded, and an invalid one is better than a made-up one.
    private static func location(_ sample: LocationSample) -> CLLocation {
        CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: sample.latitude, longitude: sample.longitude),
            altitude: 0,
            horizontalAccuracy: sample.horizontalAccuracy,
            verticalAccuracy: -1,
            course: -1,
            speed: sample.speed,
            timestamp: sample.timestamp
        )
    }
}

/// Used by UI tests (`-uitest-fake-health`): the system permission sheet cannot be driven there.
@MainActor
final class StubHealthWriter: HealthWriting {
    private(set) var access: HealthAccess = .authorized
    func requestAccess() async throws {}
    func save(_ workout: WorkoutRecord) async throws {}
}
