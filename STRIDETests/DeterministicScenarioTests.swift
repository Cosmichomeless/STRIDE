import Foundation
import Testing
@testable import STRIDE

/// Whole-pipeline scenarios (filter → session → metrics) with fixed sample sequences,
/// plus exact boundaries and rule precedence. No clock, no randomness, no CoreLocation.
struct DeterministicScenarioTests {
    let factory = SampleFactory()

    func sample(_ meters: Double, at seconds: TimeInterval, accuracy: Double = 5, speed: Double = -1) -> LocationSample {
        factory.sample(meters: meters, at: seconds, accuracy: accuracy, speed: speed)
    }

    // MARK: Pipeline

    /// A steady 3 m/s run of 600 s, with a bad fix of every kind injected between the good ones.
    @Test func noiseDoesNotChangeTheMeasuredDistance() {
        var validator = SampleValidator(segmentStart: factory.now(0))
        var metrics = RunMetrics()
        var firstAccepted = true
        func feed(_ s: LocationSample) {
            if validator.process(s, now: s.timestamp).isAccepted {
                metrics.add(s, startsSegment: firstAccepted)
                firstAccepted = false
            }
        }
        for i in 0...600 {
            let t = Double(i), meters = t * 3
            feed(sample(meters, at: t))
            guard i < 600 else { continue }
            switch i % 3 {
            case 0: feed(sample(meters + 450, at: t + 0.5))                 // impossible jump
            case 1: feed(sample(meters + 1.5, at: t + 0.5, accuracy: 80))   // low accuracy
            default: feed(sample(meters, at: t + 0.5))                      // duplicate coordinate
            }
        }
        #expect(abs(metrics.distance - 1_800) < 0.01)
        #expect(validator.rejections == [.impossibleJump: 200, .lowAccuracy: 200, .duplicate: 200])
        #expect(validator.rejectedCount == 600)
    }

    @Test func samplingRateDoesNotChangeTheDistance() {
        func distance(everySeconds step: Int) -> Double {
            var metrics = RunMetrics()
            for t in stride(from: 0, through: 600, by: step) {
                metrics.add(sample(Double(t) * 3, at: Double(t)), startsSegment: t == 0)
            }
            return metrics.distance
        }
        #expect(abs(distance(everySeconds: 1) - distance(everySeconds: 5)) < 0.01)
        #expect(abs(distance(everySeconds: 1) - 1_800) < 0.01)
    }

    @Test func pauseAddsNeitherTimeNorDistance() throws {
        var session = TrackingSession()
        var validator = SampleValidator(segmentStart: factory.now(0))
        var metrics = RunMetrics()
        func run(from start: Double, to end: Double, origin: Double, first: Bool) {
            for t in stride(from: start, through: end, by: 1) {
                let s = sample(origin + (t - start) * 3, at: t)
                if validator.process(s, now: s.timestamp).isAccepted {
                    metrics.add(s, startsSegment: first && t == start)
                }
            }
        }
        try session.start(at: factory.now(0))
        run(from: 0, to: 60, origin: 0, first: true)
        try session.pause(at: factory.now(60))
        // Five minutes paused; the runner resumes 2 km away.
        try session.resume(at: factory.now(360))
        validator.beginSegment(at: factory.now(360))
        run(from: 360, to: 420, origin: 2_000, first: true)
        try session.finish(at: factory.now(420))

        #expect(session.elapsed(at: factory.now(9_999)) == 120)
        #expect(abs(metrics.distance - 360) < 0.01)
        #expect(abs((metrics.averagePace(elapsed: 120) ?? 0) - 120 / 0.36) < 0.01)
    }

    @Test func replayingTheSameSequenceGivesTheSameDecisions() {
        let sequence: [LocationSample] = [
            sample(0, at: 0), sample(5, at: 2), sample(600, at: 3), sample(7, at: 4, accuracy: -1),
            sample(10, at: 5), sample(10, at: 6), sample(14, at: 7, speed: 30), sample(16, at: 8),
        ]
        func decisions() -> ([FilterDecision], [RejectionReason: Int]) {
            var validator = SampleValidator(segmentStart: factory.now(0))
            let result = sequence.map { validator.process($0, now: $0.timestamp) }
            return (result, validator.rejections)
        }
        let (first, firstRejections) = decisions()
        let (second, secondRejections) = decisions()
        #expect(first == second)
        #expect(firstRejections == secondRejections)
        #expect(first == [
            .accepted, .accepted, .rejected(.impossibleJump), .rejected(.invalidAccuracy),
            .accepted, .rejected(.duplicate), .rejected(.impossibleReportedSpeed), .accepted,
        ])
    }

    // MARK: Rule precedence

    /// When a sample breaks several rules, the first rule in the filter's order is the one reported.
    @Test(arguments: [
        // accuracy < 0 beats a stale timestamp
        (-1.0, -20.0, -1.0, RejectionReason.invalidAccuracy),
        // low accuracy beats a timestamp before the segment start
        (80.0, -20.0, -1.0, .lowAccuracy),
        // before the segment start beats stale
        (5.0, -20.0, -1.0, .beforeSegmentStart),
    ])
    func firstBrokenRuleIsReported(accuracy: Double, timestamp: Double, speed: Double, expected: RejectionReason) {
        let filter = SampleFilter()
        let decision = filter.evaluate(
            sample(0, at: timestamp, accuracy: accuracy, speed: speed),
            previous: nil, now: factory.now(30), notBefore: factory.now(0)
        )
        #expect(decision == .rejected(expected))
    }

    @Test func staleBeatsReportedSpeedAndReportedSpeedBeatsOrdering() {
        let filter = SampleFilter()
        #expect(filter.evaluate(sample(0, at: 0, speed: 50), previous: nil, now: factory.now(60)) == .rejected(.stale))
        let previous = sample(0, at: 5)
        #expect(filter.evaluate(sample(10, at: 4, speed: 50), previous: previous, now: factory.now(5)) == .rejected(.impossibleReportedSpeed))
    }

    // MARK: Exact boundaries

    @Test func currentPaceWindowBoundariesAreInclusive() {
        func pace(coveredMeters: Double, seconds: Double) -> TimeInterval? {
            var metrics = RunMetrics()
            metrics.add(sample(0, at: 0), startsSegment: true)
            metrics.add(sample(coveredMeters, at: seconds), startsSegment: false)
            return metrics.currentPace(at: factory.now(seconds))
        }
        // 5.01 m, not 5: meters round-trip through degrees and can land a hair under the threshold.
        #expect(abs((pace(coveredMeters: 5.01, seconds: 5) ?? 0) - 5 / 0.00501) < 0.01)
        #expect(pace(coveredMeters: 4.9, seconds: 5) == nil)
        #expect(pace(coveredMeters: 5, seconds: 4.9) == nil)
    }

    @Test func averagePaceStartsAtTenMeters() {
        func average(meters: Double) -> TimeInterval? {
            var metrics = RunMetrics()
            metrics.add(sample(0, at: 0), startsSegment: true)
            metrics.add(sample(meters, at: 10), startsSegment: false)
            return metrics.averagePace(elapsed: 10)
        }
        #expect(average(meters: 10.01) != nil)
        #expect(average(meters: 9.9) == nil)
    }

    @Test func oldSamplesLeaveTheWindowAtTwentySeconds() {
        var metrics = RunMetrics()
        // 0..20 s at 1 m/s (slow), then one fix at 40 s: the 20 s window now holds only the last two.
        for t in 0...20 { metrics.add(sample(Double(t), at: Double(t)), startsSegment: t == 0) }
        metrics.add(sample(20 + 40, at: 40), startsSegment: false) // 2 m/s over the last 20 s
        #expect(abs((metrics.currentPace(at: factory.now(40)) ?? 0) - 500) < 0.5)
    }

    // MARK: Session

    @Test func repeatedPausesAccumulateOnlyActiveTime() throws {
        var session = TrackingSession()
        var clock = 0.0
        try session.start(at: factory.now(clock))
        for _ in 0..<10 {
            clock += 10
            try session.pause(at: factory.now(clock))
            clock += 5
            try session.resume(at: factory.now(clock))
        }
        clock += 10
        try session.finish(at: factory.now(clock))
        #expect(session.elapsed(at: factory.now(clock + 1_000)) == 110)
        #expect(session.startedAt == factory.now(0))
        #expect(session.finishedAt == factory.now(160))
    }

    @Test func finishingRightAfterStartLeavesAZeroLengthRun() throws {
        var session = TrackingSession()
        try session.start(at: factory.now(0))
        try session.finish(at: factory.now(0))
        #expect(session.state == .finished)
        #expect(session.elapsed(at: factory.now(500)) == 0)
    }

    @Test func rebuiltSessionMatchesTheLiveOne() throws {
        var live = TrackingSession()
        try live.start(at: factory.now(0))
        try live.pause(at: factory.now(40))
        try live.resume(at: factory.now(100))
        let rebuilt = TrackingSession(
            state: live.state, startedAt: live.startedAt!, finishedAt: live.finishedAt,
            accumulated: live.accumulated, lastResumedAt: live.lastResumedAt
        )
        #expect(rebuilt == live)
        #expect(rebuilt.elapsed(at: factory.now(130)) == live.elapsed(at: factory.now(130)))
    }
}

struct GeodesyAndFormatEdgeTests {
    func point(_ latitude: Double, _ longitude: Double) -> LocationSample {
        LocationSample(latitude: latitude, longitude: longitude, altitude: 0, horizontalAccuracy: 5, speed: -1, timestamp: Date(timeIntervalSince1970: 0))
    }

    @Test func distanceIsSymmetric() {
        let a = point(40.4153, -3.6833), b = point(40.4211, -3.6826)
        #expect(Geodesy.distance(from: a, to: b) == Geodesy.distance(from: b, to: a))
    }

    @Test func aDegreeOfLongitudeShrinksWithLatitude() {
        let equator = Geodesy.distance(from: point(0, 0), to: point(0, 1))
        let sixty = Geodesy.distance(from: point(60, 0), to: point(60, 1))
        #expect(abs(equator - 111_195) < 1)
        #expect(abs(sixty - equator / 2) < 100)
    }

    @Test func distanceCrossesTheAntimeridian() {
        let d = Geodesy.distance(from: point(0, 179.9), to: point(0, -179.9))
        #expect(abs(d - 22_239) < 1)
    }

    @Test func identicalPointsAtThePoleAreZeroApart() {
        #expect(Geodesy.distance(from: point(90, 0), to: point(90, 120)) < 0.001)
    }

    @Test(arguments: [(59.5, "1:00"), (359.5, "6:00"), (3_599.4, "59:59")])
    func paceRoundsToTheNearestSecond(seconds: Double, expected: String) {
        #expect(PaceFormat.pace(seconds) == expected)
    }

    @Test(arguments: [(59.999, "0:59"), (3_599.9, "59:59"), (36_000, "10:00:00")])
    func durationTruncatesInsteadOfRounding(seconds: Double, expected: String) {
        #expect(DurationFormat.clock(seconds) == expected)
    }
}
