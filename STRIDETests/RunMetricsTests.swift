import Foundation
import Testing
@testable import STRIDE

struct RunMetricsTests {
    let factory = SampleFactory()

    /// Runs `count` samples, one every `step` seconds, `meters` apart, starting at `start`.
    func run(_ metrics: inout RunMetrics, from start: Double = 0, count: Int, meters: Double, step: TimeInterval = 1, offset: TimeInterval = 0) {
        for i in 0..<count {
            let first = i == 0 && offset == 0
            metrics.add(factory.sample(meters: start + Double(i) * meters, at: offset + Double(i) * step), startsSegment: first)
        }
    }

    // MARK: Distance

    @Test func distanceSumsValidatedSegments() {
        var metrics = RunMetrics()
        run(&metrics, count: 11, meters: 10) // 100 m
        #expect(abs(metrics.distance - 100) < 0.01)
    }

    @Test func firstSampleAddsNoDistance() {
        var metrics = RunMetrics()
        metrics.add(factory.sample(meters: 500), startsSegment: true)
        #expect(metrics.distance == 0)
    }

    @Test func startingASegmentDoesNotAccumulatePhantomDistance() {
        var metrics = RunMetrics()
        metrics.add(factory.sample(meters: 0, at: 0), startsSegment: true)
        metrics.add(factory.sample(meters: 50, at: 10), startsSegment: false)
        // Paused far away, resumed 1 km further.
        metrics.add(factory.sample(meters: 1_050, at: 100), startsSegment: true)
        metrics.add(factory.sample(meters: 1_080, at: 110), startsSegment: false)
        #expect(abs(metrics.distance - 80) < 0.01)
    }

    // MARK: Average pace

    @Test func averagePaceUsesMovingTime() {
        var metrics = RunMetrics()
        run(&metrics, count: 11, meters: 100, step: 30) // 1 km
        // 1 km in 5 minutes of moving time -> 300 s/km
        #expect(abs((metrics.averagePace(elapsed: 300) ?? 0) - 300) < 0.5)
    }

    @Test func averagePaceIsUnknownBeforeMinimumDistance() {
        var metrics = RunMetrics()
        run(&metrics, count: 2, meters: 5)
        #expect(metrics.distance < 10)
        #expect(metrics.averagePace(elapsed: 60) == nil)
    }

    @Test func averagePaceIsUnknownWithoutElapsedTime() {
        var metrics = RunMetrics()
        run(&metrics, count: 11, meters: 10)
        #expect(metrics.averagePace(elapsed: 0) == nil)
    }

    // MARK: Current pace

    @Test func currentPaceUsesRollingWindow() {
        var metrics = RunMetrics()
        // Slow for 60 s (1 m/s), then fast (4 m/s): only the last 20 s should count.
        run(&metrics, count: 60, meters: 1)
        run(&metrics, from: 60, count: 30, meters: 4, offset: 60)
        let pace = metrics.currentPace(at: factory.now(89))
        #expect(abs((pace ?? 0) - 250) < 1) // 4 m/s = 250 s/km
    }

    @Test func currentPaceIsUnknownWithASingleSample() {
        var metrics = RunMetrics()
        metrics.add(factory.sample(), startsSegment: true)
        #expect(metrics.currentPace(at: factory.now(1)) == nil)
    }

    @Test func currentPaceIsUnknownWhenWindowIsTooShort() {
        var metrics = RunMetrics()
        run(&metrics, count: 3, meters: 3) // 2 s covered
        #expect(metrics.currentPace(at: factory.now(2)) == nil)
    }

    @Test func currentPaceIsUnknownWhenStandingStill() {
        var metrics = RunMetrics()
        run(&metrics, count: 15, meters: 0.2) // 14 s, 2.8 m: jitter
        #expect(metrics.currentPace(at: factory.now(14)) == nil)
    }

    @Test func currentPaceBecomesUnknownWhenGPSGoesSparse() {
        var metrics = RunMetrics()
        run(&metrics, count: 15, meters: 3)
        #expect(metrics.currentPace(at: factory.now(14)) != nil)
        #expect(metrics.currentPace(at: factory.now(14 + 10)) != nil)  // boundary is inclusive
        #expect(metrics.currentPace(at: factory.now(14 + 11)) == nil)  // never extrapolated
    }

    @Test func newSegmentResetsTheWindow() {
        var metrics = RunMetrics()
        run(&metrics, count: 15, meters: 3)
        metrics.add(factory.sample(meters: 5_000, at: 100), startsSegment: true)
        #expect(metrics.currentPace(at: factory.now(101)) == nil)
    }

    @Test func rebuildingFromReplayedPointsGivesTheSameMetrics() {
        var live = RunMetrics()
        var replay = RunMetrics()
        var points: [(LocationSample, Bool)] = []
        for i in 0..<40 {
            let startsSegment = i == 0 || i == 20
            points.append((factory.sample(meters: Double(i) * 3, at: Double(i)), startsSegment))
        }
        for (sample, starts) in points { live.add(sample, startsSegment: starts) }
        for (sample, starts) in points { replay.add(sample, startsSegment: starts) }
        #expect(live == replay)
    }
}

struct PaceFormatTests {
    @Test(arguments: [
        (300.0, "5:00"), (330.4, "5:30"), (359.6, "6:00"), (65.0, "1:05"),
    ])
    func formatsPace(seconds: Double, expected: String) {
        #expect(PaceFormat.pace(seconds) == expected)
    }

    @Test(arguments: [nil, 0.0, -5.0, 3_600.0, 10_000.0, Double.infinity, Double.nan])
    func unknownOrMeaninglessPaceIsDashes(seconds: Double?) {
        #expect(PaceFormat.pace(seconds) == "--")
    }

    @Test func formatsDistanceInKilometers() {
        #expect(DistanceFormat.kilometers(0) == "0.00")
        #expect(DistanceFormat.kilometers(1_250) == "1.25")
        #expect(DistanceFormat.kilometers(-3) == "0.00")
    }
}
