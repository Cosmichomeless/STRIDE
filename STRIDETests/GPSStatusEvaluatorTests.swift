import Foundation
import Testing
@testable import STRIDE

struct GPSStatusEvaluatorTests {
    let now = Date(timeIntervalSince1970: 10_000)
    let evaluator = GPSStatusEvaluator()

    private func sample(accuracy: Double, age: TimeInterval) -> LocationSample {
        LocationSample(latitude: 0, longitude: 0, altitude: 0, horizontalAccuracy: accuracy, speed: 0, timestamp: now.addingTimeInterval(-age))
    }

    @Test(arguments: [LocationAuthorization.notDetermined, .denied, .restricted])
    func unavailableWithoutPermission(auth: LocationAuthorization) {
        let status = evaluator.status(authorization: auth, servicesEnabled: true, lastValidSample: sample(accuracy: 5, age: 0), now: now)
        #expect(status == .unavailable)
    }

    @Test func unavailableWhenServicesAreOff() {
        let status = evaluator.status(authorization: .always, servicesEnabled: false, lastValidSample: nil, now: now)
        #expect(status == .unavailable)
    }

    @Test func acquiringWithoutAnyFix() {
        let status = evaluator.status(authorization: .whenInUse, servicesEnabled: true, lastValidSample: nil, now: now)
        #expect(status == .acquiring)
    }

    @Test func goodWithRecentAccurateFix() {
        let status = evaluator.status(authorization: .whenInUse, servicesEnabled: true, lastValidSample: sample(accuracy: 8, age: 1), now: now)
        #expect(status == .good)
    }

    @Test func weakWithRecentInaccurateFix() {
        let status = evaluator.status(authorization: .whenInUse, servicesEnabled: true, lastValidSample: sample(accuracy: 65, age: 1), now: now)
        #expect(status == .weak)
    }

    @Test func lostWhenFixIsOld() {
        let status = evaluator.status(authorization: .always, servicesEnabled: true, lastValidSample: sample(accuracy: 5, age: 30), now: now)
        #expect(status == .lost)
    }

    @Test func accuracyBoundaryIsInclusive() {
        let status = evaluator.status(authorization: .always, servicesEnabled: true, lastValidSample: sample(accuracy: 20, age: 0), now: now)
        #expect(status == .good)
    }
}

struct LocationAuthorizationTests {
    @Test func capabilitiesPerState() {
        #expect(LocationAuthorization.notDetermined.canRequest)
        #expect(!LocationAuthorization.denied.canRequest)
        #expect(LocationAuthorization.denied.canOpenSettings)
        #expect(!LocationAuthorization.restricted.canOpenSettings)
        #expect(LocationAuthorization.whenInUse.canTrack)
        #expect(LocationAuthorization.always.canTrack)
        #expect(!LocationAuthorization.denied.canTrack)
    }

    @Test func messagesExplainDeniedAndRestricted() {
        #expect(LocationAuthorization.denied.message != nil)
        #expect(LocationAuthorization.restricted.message != nil)
        #expect(LocationAuthorization.notDetermined.message == nil)
    }

    @Test func mapsCoreLocationStatuses() {
        #expect(LocationAuthorization(.authorizedWhenInUse) == .whenInUse)
        #expect(LocationAuthorization(.authorizedAlways) == .always)
        #expect(LocationAuthorization(.denied) == .denied)
        #expect(LocationAuthorization(.restricted) == .restricted)
        #expect(LocationAuthorization(.notDetermined) == .notDetermined)
    }
}
