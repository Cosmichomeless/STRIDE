import Foundation
import Testing
@testable import STRIDE

struct TrackingSessionTests {
    let t0 = Date(timeIntervalSince1970: 1_000)
    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func startsIdleWithZeroElapsed() {
        let session = TrackingSession()
        #expect(session.state == .idle)
        #expect(session.elapsed(at: at(100)) == 0)
        #expect(!session.isInProgress)
    }

    @Test func activeTimeAdvancesWithTheClock() throws {
        var session = TrackingSession()
        try session.start(at: t0)
        #expect(session.state == .active)
        #expect(session.elapsed(at: at(42)) == 42)
    }

    @Test func pausedTimeIsExcluded() throws {
        var session = TrackingSession()
        try session.start(at: t0)
        try session.pause(at: at(60))
        #expect(session.elapsed(at: at(60)) == 60)
        #expect(session.elapsed(at: at(600)) == 60) // frozen while paused
        try session.resume(at: at(600))
        #expect(session.elapsed(at: at(630)) == 90)
    }

    @Test func finishBanksFinalDurationFromActive() throws {
        var session = TrackingSession()
        try session.start(at: t0)
        try session.finish(at: at(100))
        #expect(session.state == .finished)
        #expect(session.elapsed(at: at(5_000)) == 100)
        #expect(session.finishedAt == at(100))
    }

    @Test func finishFromPausedKeepsPausedDuration() throws {
        var session = TrackingSession()
        try session.start(at: t0)
        try session.pause(at: at(30))
        try session.finish(at: at(500))
        #expect(session.elapsed(at: at(900)) == 30)
    }

    @Test(arguments: [
        (SessionState.idle, SessionAction.pause),
        (.idle, .resume),
        (.idle, .finish),
        (.active, .start),
        (.active, .resume),
        (.paused, .start),
        (.paused, .pause),
        (.finished, .start),
        (.finished, .pause),
        (.finished, .resume),
        (.finished, .finish),
    ])
    func invalidTransitionsAreRejectedAndLeaveStateUnchanged(state: SessionState, action: SessionAction) throws {
        var session = try make(state)
        let before = session
        #expect(throws: InvalidTransition(action: action, state: state)) {
            switch action {
            case .start: try session.start(at: at(1_000))
            case .pause: try session.pause(at: at(1_000))
            case .resume: try session.resume(at: at(1_000))
            case .finish: try session.finish(at: at(1_000))
            }
        }
        #expect(session == before)
    }

    @Test func clockGoingBackwardsNeverProducesNegativeTime() throws {
        var session = TrackingSession()
        try session.start(at: t0)
        #expect(session.elapsed(at: at(-50)) == 0)
    }

    @Test func restoredSessionContinuesCounting() {
        let restored = TrackingSession(state: .active, startedAt: t0, accumulated: 120, lastResumedAt: at(200))
        #expect(restored.elapsed(at: at(230)) == 150)
    }

    @Test func restoredPausedSessionIgnoresResumeTimestamp() {
        let restored = TrackingSession(state: .paused, startedAt: t0, accumulated: 120, lastResumedAt: at(200))
        #expect(restored.lastResumedAt == nil)
        #expect(restored.elapsed(at: at(999)) == 120)
    }

    private func make(_ state: SessionState) throws -> TrackingSession {
        var s = TrackingSession()
        switch state {
        case .idle: break
        case .active: try s.start(at: t0)
        case .paused: try s.start(at: t0); try s.pause(at: at(10))
        case .finished: try s.start(at: t0); try s.finish(at: at(10))
        }
        return s
    }
}

struct DurationFormatTests {
    @Test func formatsMinutesAndHours() {
        #expect(DurationFormat.clock(0) == "0:00")
        #expect(DurationFormat.clock(65.9) == "1:05")
        #expect(DurationFormat.clock(3_600) == "1:00:00")
        #expect(DurationFormat.clock(3_725) == "1:02:05")
        #expect(DurationFormat.clock(-5) == "0:00")
    }
}
