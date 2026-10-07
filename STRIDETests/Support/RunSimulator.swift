import CoreLocation
import Foundation
@testable import STRIDE

/// Deterministic generator (SplitMix64), so every simulated run is reproducible from its seed.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// Standard normal (Box-Muller).
    mutating func gaussian() -> Double {
        let u1 = max(Double.random(in: 0..<1, using: &self), 1e-12)
        let u2 = Double.random(in: 0..<1, using: &self)
        return (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
    }
}

/// Replays a known path through a model of CoreLocation and the real validation/metrics pipeline,
/// to compare location configurations without a device (see docs/PERFORMANCE.md).
///
/// It is a **model**: the noise levels per `desiredAccuracy` are assumptions, not measurements.
/// It says how the pipeline reacts to a configuration, not how a given phone behaves.
struct RunSimulator {
    /// A path in local meters (x east, y north) sampled densely, with its cumulative length.
    struct Path {
        let points: [SIMD2<Double>]
        let cumulative: [Double]
        var length: Double { cumulative.last ?? 0 }

        init(points: [SIMD2<Double>]) {
            var total = 0.0
            var cumulative = [0.0]
            for i in points.indices.dropFirst() {
                let d = points[i] - points[i - 1]
                total += (d.x * d.x + d.y * d.y).squareRoot()
                cumulative.append(total)
            }
            self.points = points
            self.cumulative = cumulative
        }

        /// A straight road heading north.
        static func straight(length: Double) -> Path {
            Path(points: stride(from: 0.0, through: length, by: 0.5).map { SIMD2(0, $0) })
        }

        /// A winding path (switchbacks): the shape where sparse sampling cuts corners.
        static func winding(length: Double, amplitude: Double = 25, wavelength: Double = 150) -> Path {
            Path(points: stride(from: 0.0, through: length, by: 0.5).map {
                SIMD2(amplitude * sin(2 * .pi * $0 / wavelength), $0)
            })
        }

        func position(at distance: Double) -> SIMD2<Double> {
            let target = min(max(distance, 0), length)
            var low = 0, high = cumulative.count - 1
            while high - low > 1 {
                let mid = (low + high) / 2
                if cumulative[mid] <= target { low = mid } else { high = mid }
            }
            let span = cumulative[high] - cumulative[low]
            let t = span > 0 ? (target - cumulative[low]) / span : 0
            return points[low] + (points[high] - points[low]) * t
        }
    }

    struct Profile {
        var name: String
        var desiredAccuracy: CLLocationAccuracy
        var distanceFilter: CLLocationDistance
    }

    struct Outcome {
        var truth: Double
        var measured: Double
        /// Updates the location layer delivered.
        var delivered: Int
        /// Updates that passed validation and were stored.
        var accepted: Int
        var errorPercent: Double { (measured - truth) / truth * 100 }
    }

    /// Nominal 1-σ position error per axis (m) for a `desiredAccuracy`. **Assumed** values.
    static func sigma(for accuracy: CLLocationAccuracy) -> Double {
        switch accuracy {
        case ...kCLLocationAccuracyBest: 5
        case ...kCLLocationAccuracyNearestTenMeters: 10
        default: 50
        }
    }

    var speed = 3.0
    /// Correlation of the position error between two fixes one second apart. GPS error drifts
    /// slowly rather than being white noise, so it inflates distance less than independent noise.
    var noiseCorrelationPerSecond = 0.9
    /// Scales the position error; 0 removes it, leaving only the sampling geometry.
    var noiseScale = 1.0

    func run(_ path: Path, profile: Profile, seed: UInt64) -> Outcome {
        var rng = SeededGenerator(seed: seed)
        let nominalSigma = Self.sigma(for: profile.desiredAccuracy)
        let sigma = nominalSigma * noiseScale
        let reportedAccuracy = nominalSigma * 1.5   // radius holding ~68 % of a 2-D Gaussian error
        let origin = Date(timeIntervalSince1970: 100_000)
        let metersPerDegree = Geodesy.earthRadius * .pi / 180
        let cosLat = cos(40 * Double.pi / 180)

        var validator = SampleValidator(segmentStart: origin)
        var metrics = RunMetrics()
        var error = SIMD2<Double>(sigma * rng.gaussian(), sigma * rng.gaussian())
        var lastDeliveredAt: Double?
        var lastDeliveredTime = 0.0
        var delivered = 0, accepted = 0

        var time = 0.0
        while speed * time <= path.length {
            let travelled = speed * time
            let due = lastDeliveredAt.map { profile.distanceFilter <= 0 || travelled - $0 >= profile.distanceFilter } ?? true
            if due {
                let dt = time - lastDeliveredTime
                let phi = pow(noiseCorrelationPerSecond, dt)
                let innovation = (1 - phi * phi).squareRoot() * sigma
                error = SIMD2(phi * error.x + innovation * rng.gaussian(), phi * error.y + innovation * rng.gaussian())
                let truth = path.position(at: travelled) + error
                let sample = LocationSample(
                    latitude: 40 + truth.y / metersPerDegree, longitude: -3 + truth.x / (metersPerDegree * cosLat),
                    altitude: 0, horizontalAccuracy: reportedAccuracy, speed: -1,
                    timestamp: origin.addingTimeInterval(time)
                )
                delivered += 1
                let startsSegment = validator.lastAccepted == nil
                if validator.process(sample, now: sample.timestamp).isAccepted {
                    accepted += 1
                    metrics.add(sample, startsSegment: startsSegment)
                }
                lastDeliveredAt = travelled
                lastDeliveredTime = time
            }
            time += 1   // GPS fixes arrive at most once per second
        }
        return Outcome(truth: path.length, measured: metrics.distance, delivered: delivered, accepted: accepted)
    }

    /// Mean outcome over several seeds, so one lucky or unlucky noise sequence does not decide.
    func averaged(_ path: Path, profile: Profile, seeds: Range<UInt64> = 0..<30) -> Outcome {
        let outcomes = seeds.map { run(path, profile: profile, seed: $0) }
        let n = Double(outcomes.count)
        return Outcome(
            truth: path.length,
            measured: outcomes.reduce(0) { $0 + $1.measured } / n,
            delivered: outcomes.reduce(0) { $0 + $1.delivered } / outcomes.count,
            accepted: outcomes.reduce(0) { $0 + $1.accepted } / outcomes.count
        )
    }
}
