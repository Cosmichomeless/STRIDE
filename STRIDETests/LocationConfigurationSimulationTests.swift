import CoreLocation
import Foundation
import Testing
@testable import STRIDE

/// Compares location configurations on reproducible simulated runs. See docs/PERFORMANCE.md for the
/// model's assumptions and for what these numbers do *not* say (battery on a real device).
///
/// The assertions are about ordering and orders of magnitude, which hold across the noise
/// correlations tried; the exact percentages depend on the assumed noise and are only documented.
struct LocationConfigurationSimulationTests {
    static let straight = RunSimulator.Path.straight(length: 3_000)
    static let winding = RunSimulator.Path.winding(length: 3_000)

    static func profile(_ accuracy: CLLocationAccuracy, _ filter: CLLocationDistance) -> RunSimulator.Profile {
        .init(name: "\(accuracy) / \(filter)", desiredAccuracy: accuracy, distanceFilter: filter)
    }

    static let simulator: RunSimulator = {
        var simulator = RunSimulator()
        simulator.noiseCorrelationPerSecond = 0.97
        return simulator
    }()

    @Test func sameSeedGivesIdenticalResults() {
        let profile = Self.profile(kCLLocationAccuracyBest, 5)
        let a = Self.simulator.run(Self.winding, profile: profile, seed: 7)
        let b = Self.simulator.run(Self.winding, profile: profile, seed: 7)
        let c = Self.simulator.run(Self.winding, profile: profile, seed: 8)
        #expect(a.measured == b.measured)
        #expect(a.delivered == b.delivered)
        #expect(a.measured != c.measured)
    }

    @Test(arguments: [0.9, 0.97, 0.99])
    func largerDistanceFilterDeliversFewerUpdates(correlation: Double) {
        var simulator = RunSimulator()
        simulator.noiseCorrelationPerSecond = correlation
        let delivered = [kCLDistanceFilterNone, 5, 10, 20].map {
            simulator.averaged(Self.straight, profile: Self.profile(kCLLocationAccuracyBest, $0), seeds: 0..<5).delivered
        }
        #expect(delivered == delivered.sorted(by: >))
        // Doubling the filter roughly halves the wake-ups.
        #expect(Double(delivered[2]) < Double(delivered[1]) * 0.6)
        #expect(Double(delivered[1]) < Double(delivered[0]) * 0.6)
    }

    @Test(arguments: [0.9, 0.97, 0.99])
    func noFilterInflatesDistanceMoreThanFiveMeters(correlation: Double) {
        var simulator = RunSimulator()
        simulator.noiseCorrelationPerSecond = correlation
        let none = simulator.averaged(Self.straight, profile: Self.profile(kCLLocationAccuracyBest, kCLDistanceFilterNone), seeds: 0..<10)
        let five = simulator.averaged(Self.straight, profile: Self.profile(kCLLocationAccuracyBest, 5), seeds: 0..<10)
        #expect(none.errorPercent > five.errorPercent)
        #expect(five.errorPercent > 0)   // noise only ever adds distance on a straight road
    }

    @Test func lowerDesiredAccuracyIsNoisier() {
        let best = Self.simulator.averaged(Self.straight, profile: Self.profile(kCLLocationAccuracyBest, 10), seeds: 0..<10)
        let tenMeters = Self.simulator.averaged(Self.straight, profile: Self.profile(kCLLocationAccuracyNearestTenMeters, 10), seeds: 0..<10)
        #expect(tenMeters.errorPercent > best.errorPercent)
        // Same filter, same truth movement: the update count does not depend on desiredAccuracy.
        #expect(tenMeters.delivered == best.delivered)
    }

    @Test func hundredMetersAccuracyIsRejectedByTheAccuracyFilter() {
        let outcome = Self.simulator.run(Self.straight, profile: Self.profile(kCLLocationAccuracyHundredMeters, 50), seed: 1)
        #expect(outcome.delivered > 0)
        #expect(outcome.accepted == 0)
        #expect(outcome.measured == 0)
    }

    @Test func currentConfigurationStaysWithinFivePercentOnBothRoutes() {
        let current = Self.profile(LocationConfiguration.default.desiredAccuracy, LocationConfiguration.default.distanceFilter)
        for path in [Self.straight, Self.winding] {
            let outcome = Self.simulator.averaged(path, profile: current, seeds: 0..<10)
            #expect(abs(outcome.errorPercent) < 5, "error \(outcome.errorPercent)% on a \(Int(path.length)) m path")
        }
    }

    @Test func sparseSamplingCutsCornersOnAWindingPath() {
        // Noise-free: only the sampling geometry is left, so a coarser filter can only shorten the route.
        var simulator = RunSimulator()
        simulator.noiseScale = 0
        let fine = simulator.run(Self.winding, profile: Self.profile(kCLLocationAccuracyBest, 5), seed: 1)
        let coarse = simulator.run(Self.winding, profile: Self.profile(kCLLocationAccuracyBest, 50), seed: 1)
        #expect(coarse.measured < fine.measured)
        #expect(fine.measured <= Self.winding.length)
        #expect(coarse.errorPercent < -1)
    }
}
