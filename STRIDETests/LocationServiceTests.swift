import CoreLocation
import Foundation
import Testing
@testable import STRIDE

@MainActor
struct LocationServiceTests {
    @Test func convertsCLLocationKeepingTimestampAccuracyAndSpeed() {
        let date = Date(timeIntervalSince1970: 5_000)
        let location = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 40.4, longitude: -3.7),
            altitude: 650,
            horizontalAccuracy: 7,
            verticalAccuracy: 3,
            course: 90,
            speed: 3.2,
            timestamp: date
        )
        let sample = LocationSample(location)
        #expect(sample.latitude == 40.4)
        #expect(sample.longitude == -3.7)
        #expect(sample.altitude == 650)
        #expect(sample.horizontalAccuracy == 7)
        #expect(sample.speed == 3.2)
        #expect(sample.timestamp == date)
    }

    @Test func appliesConfigurationToManager() {
        let manager = CLLocationManager()
        var configuration = LocationConfiguration.default
        configuration.distanceFilter = 12
        configuration.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        _ = LocationService(manager: manager, configuration: configuration)
        #expect(manager.distanceFilter == 12)
        #expect(manager.desiredAccuracy == kCLLocationAccuracyNearestTenMeters)
        #expect(manager.activityType == .fitness)
        #expect(manager.pausesLocationUpdatesAutomatically == false)
    }

    @Test func delegateUpdatesAreStreamedInOrder() async {
        let manager = CLLocationManager()
        let service = LocationService(manager: manager)
        let locations = (0..<3).map { i in
            CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: 40 + Double(i) * 0.0001, longitude: -3),
                altitude: 0, horizontalAccuracy: 5, verticalAccuracy: 5,
                course: 0, speed: 2, timestamp: Date(timeIntervalSince1970: Double(i))
            )
        }
        service.locationManager(manager, didUpdateLocations: locations)

        var received: [LocationSample] = []
        for await sample in service.samples {
            received.append(sample)
            if received.count == 3 { break }
        }
        #expect(received.map(\.timestamp.timeIntervalSince1970) == [0, 1, 2])
    }

    @Test func invalidFixesDoNotBecomeLastValidSample() async {
        let manager = CLLocationManager()
        let service = LocationService(manager: manager)
        let invalid = CLLocation(
            coordinate: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            altitude: 0, horizontalAccuracy: -1, verticalAccuracy: -1, course: -1, speed: -1, timestamp: .now
        )
        service.locationManager(manager, didUpdateLocations: [invalid])
        for await _ in service.samples { break }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(service.lastValidSample == nil)
    }

    // MARK: Background

    @Test func backgroundUpdatesAreEnabledOnlyWhenTheModeIsDeclared() {
        let manager = CLLocationManager()
        let service = LocationService(manager: manager)
        let declared: [String: Any] = ["UIBackgroundModes": ["location"]]

        #expect(service.applyBackgroundTracking(true, bundleInfo: declared))
        #expect(manager.allowsBackgroundLocationUpdates)
        #expect(manager.showsBackgroundLocationIndicator)

        #expect(!service.applyBackgroundTracking(false, bundleInfo: declared))
        #expect(!manager.allowsBackgroundLocationUpdates)
        #expect(!manager.showsBackgroundLocationIndicator)

        // Without the capability CoreLocation would raise an exception: it must be skipped.
        #expect(!service.applyBackgroundTracking(true, bundleInfo: [:]))
        #expect(!service.applyBackgroundTracking(true, bundleInfo: ["UIBackgroundModes": ["audio"]]))
        #expect(!manager.allowsBackgroundLocationUpdates)
    }

    @Test func theAppBundleDeclaresTheLocationBackgroundMode() {
        #expect(LocationConfiguration.declaresBackgroundLocation(Bundle(for: LocationService.self).infoDictionary))
    }

    @Test func systemIsNeverAskedToPauseUpdatesAutomatically() {
        #expect(LocationConfiguration.default.pausesLocationUpdatesAutomatically == false)
    }
}
