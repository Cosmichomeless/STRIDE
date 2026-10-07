import Foundation
import Testing
@testable import STRIDE

struct SampleFilterTests {
    private let factory = SampleFactory()
    let filter = SampleFilter()
    var t0: Date { factory.t0 }
    var metersPerDegree: Double { factory.metersPerDegree }

    func sample(meters: Double = 0, at seconds: TimeInterval = 0, accuracy: Double = 5, speed: Double = -1) -> LocationSample {
        factory.sample(meters: meters, at: seconds, accuracy: accuracy, speed: speed)
    }
    func now(_ seconds: TimeInterval) -> Date { factory.now(seconds) }

    // MARK: Geodesy

    @Test func haversineMatchesKnownDistances() {
        #expect(abs(Geodesy.distance(from: sample(meters: 0), to: sample(meters: 100)) - 100) < 0.01)
        let a = LocationSample(latitude: 0, longitude: 0, altitude: 0, horizontalAccuracy: 1, speed: 0, timestamp: t0)
        let b = LocationSample(latitude: 1, longitude: 0, altitude: 0, horizontalAccuracy: 1, speed: 0, timestamp: t0)
        #expect(abs(Geodesy.distance(from: a, to: b) - 111_195) < 1)
        #expect(Geodesy.distance(from: a, to: a) == 0)
    }

    // MARK: Individual rules

    @Test func acceptsGoodFirstSample() {
        #expect(filter.evaluate(sample(), previous: nil, now: now(0)) == .accepted)
    }

    @Test func rejectsInvalidAccuracy() {
        #expect(filter.evaluate(sample(accuracy: -1), previous: nil, now: now(0)) == .rejected(.invalidAccuracy))
    }

    @Test func lowAccuracyBoundaryIsInclusive() {
        #expect(filter.evaluate(sample(accuracy: 30), previous: nil, now: now(0)) == .accepted)
        #expect(filter.evaluate(sample(accuracy: 30.1), previous: nil, now: now(0)) == .rejected(.lowAccuracy))
    }

    @Test func staleBoundaryIsInclusive() {
        #expect(filter.evaluate(sample(at: 0), previous: nil, now: now(10)) == .accepted)
        #expect(filter.evaluate(sample(at: 0), previous: nil, now: now(10.1)) == .rejected(.stale))
    }

    @Test func rejectsCachedFixFromBeforeTheRun() {
        let decision = filter.evaluate(sample(at: -3), previous: nil, now: now(1), notBefore: now(0))
        #expect(decision == .rejected(.beforeSegmentStart))
    }

    @Test func reportedSpeedAboveLimitIsRejectedAndUnknownIsIgnored() {
        #expect(filter.evaluate(sample(speed: 12.5), previous: nil, now: now(0)) == .rejected(.impossibleReportedSpeed))
        #expect(filter.evaluate(sample(speed: 12), previous: nil, now: now(0)) == .accepted)
        #expect(filter.evaluate(sample(speed: -1), previous: nil, now: now(0)) == .accepted)
    }

    @Test func rejectsNonIncreasingTimestamps() {
        let previous = sample(meters: 0, at: 5)
        #expect(filter.evaluate(sample(meters: 10, at: 5), previous: previous, now: now(6)) == .rejected(.outOfOrder))
        #expect(filter.evaluate(sample(meters: 10, at: 4), previous: previous, now: now(6)) == .rejected(.outOfOrder))
    }

    @Test func rejectsDuplicateCoordinates() {
        let previous = sample(meters: 0, at: 0)
        #expect(filter.evaluate(sample(meters: 0, at: 1), previous: previous, now: now(1)) == .rejected(.duplicate))
        #expect(filter.evaluate(sample(meters: 0.9, at: 1), previous: previous, now: now(1)) == .rejected(.duplicate))
        #expect(filter.evaluate(sample(meters: 1.1, at: 1), previous: previous, now: now(1)) == .accepted)
    }

    @Test func impossibleJumpBoundary() {
        let previous = sample(meters: 0, at: 0)
        #expect(filter.evaluate(sample(meters: 11.9, at: 1), previous: previous, now: now(1)) == .accepted)
        #expect(filter.evaluate(sample(meters: 12.5, at: 1), previous: previous, now: now(1)) == .rejected(.impossibleJump))
    }

    // MARK: Sequences

    @Test func readmeNoiseScenarioKeepsTheTrackClean() {
        // A, B (8 m), C (450 m — noise), D (returns near B)
        var validator = SampleValidator(segmentStart: now(0))
        let a = validator.process(sample(meters: 0, at: 0), now: now(0))
        let b = validator.process(sample(meters: 8, at: 3), now: now(3))
        let c = validator.process(sample(meters: 450, at: 4), now: now(4))
        let d = validator.process(sample(meters: 12, at: 5), now: now(5))
        #expect(a == .accepted)
        #expect(b == .accepted)
        #expect(c == .rejected(.impossibleJump))
        #expect(d == .accepted)
        #expect(validator.rejections == [.impossibleJump: 1])
        // The reference after C was still B, so D was measured against B, not C.
        #expect(abs(Geodesy.distance(from: sample(meters: 8), to: validator.lastAccepted!) - 4) < 0.01)
    }

    @Test func realDisplacementIsAcceptedAfterAnOutage() {
        // A tunnel: no samples for 60 s, then a fix 400 m away (6.7 m/s: plausible).
        var validator = SampleValidator(segmentStart: now(0))
        _ = validator.process(sample(meters: 0, at: 0), now: now(0))
        #expect(validator.process(sample(meters: 400, at: 60), now: now(60)) == .accepted)
    }

    @Test func persistentOffsetIsAcceptedOnceTimeMakesItPlausible() {
        var validator = SampleValidator(segmentStart: now(0))
        _ = validator.process(sample(meters: 0, at: 0), now: now(0))
        // 100 m away is impossible after 2 s (50 m/s)...
        #expect(validator.process(sample(meters: 100, at: 2), now: now(2)) == .rejected(.impossibleJump))
        // ...but plausible after 10 s (10 m/s) if the position stays there.
        #expect(validator.process(sample(meters: 100, at: 10), now: now(10)) == .accepted)
    }

    @Test func steadyRunIsFullyAccepted() {
        var validator = SampleValidator(segmentStart: now(0))
        let decisions = (0..<600).map { i in
            validator.process(sample(meters: Double(i) * 3, at: Double(i)), now: now(Double(i)))
        }
        #expect(decisions.allSatisfy { $0.isAccepted })
        #expect(validator.rejectedCount == 0)
    }

    @Test func standingStillDoesNotProduceAcceptedPoints() {
        var validator = SampleValidator(segmentStart: now(0))
        _ = validator.process(sample(meters: 0, at: 0), now: now(0))
        for i in 1...30 {
            let jitter = Double(i % 3) * 0.3
            #expect(validator.process(sample(meters: jitter, at: Double(i)), now: now(Double(i))) == .rejected(.duplicate))
        }
        #expect(validator.rejections[.duplicate] == 30)
    }

    @Test func newSegmentIsNotConnectedToThePreviousPosition() {
        var validator = SampleValidator(segmentStart: now(0))
        _ = validator.process(sample(meters: 0, at: 0), now: now(0))
        validator.beginSegment(at: now(100))
        // Without segment reset this 5 km move in 1 s would be an impossible jump.
        #expect(validator.process(sample(meters: 5_000, at: 101), now: now(101)) == .accepted)
    }

    @Test func segmentStartRejectsLateCachedFix() {
        var validator = SampleValidator(segmentStart: now(50))
        #expect(validator.process(sample(at: 49), now: now(51)) == .rejected(.beforeSegmentStart))
        #expect(validator.process(sample(at: 51), now: now(51)) == .accepted)
    }

    @Test func customThresholdsAreHonoured() {
        let strict = SampleFilter(maxHorizontalAccuracy: 10, maxSampleAge: 2, maxSpeed: 5, minDistance: 3)
        #expect(strict.evaluate(sample(accuracy: 11), previous: nil, now: now(0)) == .rejected(.lowAccuracy))
        #expect(strict.evaluate(sample(at: 0), previous: nil, now: now(3)) == .rejected(.stale))
        #expect(strict.evaluate(sample(meters: 6, at: 1), previous: sample(at: 0), now: now(1)) == .rejected(.impossibleJump))
        #expect(strict.evaluate(sample(meters: 2, at: 1), previous: sample(at: 0), now: now(1)) == .rejected(.duplicate))
    }
}
