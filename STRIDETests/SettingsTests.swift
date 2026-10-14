import Foundation
import Testing
@testable import STRIDE

@MainActor
struct AppSettingsTests {
    /// A throwaway defaults domain so tests never touch each other or the app's real settings.
    private func makeDefaults() -> UserDefaults {
        let name = "stride.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func firstLaunchUsesTheDefaults() {
        let settings = AppSettings(defaults: makeDefaults(), locale: Locale(identifier: "es_ES"))
        #expect(settings.distanceUnit == .kilometers)
        #expect(settings.appearance == .system)
        #expect(settings.goalKind == .none)
        #expect(settings.goal == nil)
        #expect(settings.goalDistance == 5_000)
        #expect(settings.goalTime == 1_800)
        #expect(settings.saveToHealth)
    }

    @Test(arguments: [("en_US", DistanceUnit.miles), ("en_GB", .miles), ("es_ES", .kilometers), ("de_DE", .kilometers), ("fr_FR", .kilometers)])
    func firstLaunchUnitFollowsTheRegion(identifier: String, expected: DistanceUnit) {
        #expect(DistanceUnit.default(for: Locale(identifier: identifier)) == expected)
        #expect(AppSettings(defaults: makeDefaults(), locale: Locale(identifier: identifier)).distanceUnit == expected)
    }

    @Test func everyChoiceSurvivesARelaunch() {
        let defaults = makeDefaults()
        let first = AppSettings(defaults: defaults, locale: en)
        first.distanceUnit = .kilometers
        first.appearance = .dark
        first.goalKind = .time
        first.goalDistance = 10_000
        first.goalTime = 2_400
        first.saveToHealth = false

        let second = AppSettings(defaults: defaults, locale: en)
        #expect(second.distanceUnit == .kilometers)
        #expect(second.appearance == .dark)
        #expect(second.goalKind == .time)
        #expect(second.goalDistance == 10_000)
        #expect(second.goalTime == 2_400)
        #expect(!second.saveToHealth)
        #expect(second.goal == .time(seconds: 2_400))
    }

    @Test func theStoredChoiceWinsOverTheRegion() {
        let defaults = makeDefaults()
        AppSettings(defaults: defaults, locale: en).distanceUnit = .kilometers
        #expect(AppSettings(defaults: defaults, locale: en).distanceUnit == .kilometers)
    }

    @Test func garbageInDefaultsFallsBackToTheDefaults() {
        let defaults = makeDefaults()
        defaults.set("furlongs", forKey: AppSettings.Key.distanceUnit)
        defaults.set("neon", forKey: AppSettings.Key.appearance)
        defaults.set("everything", forKey: AppSettings.Key.goalKind)
        defaults.set(-4.0, forKey: AppSettings.Key.goalDistance)
        defaults.set(99_999_999.0, forKey: AppSettings.Key.goalTime)
        let settings = AppSettings(defaults: defaults, locale: Locale(identifier: "es_ES"))
        #expect(settings.distanceUnit == .kilometers)
        #expect(settings.appearance == .system)
        #expect(settings.goalKind == .none)
        #expect(settings.goalDistance == AppSettings.storedDistanceRange.lowerBound)
        #expect(settings.goalTime == AppSettings.timeRange.upperBound)
    }

    @Test func goalFollowsTheSelectedKind() {
        let settings = AppSettings(defaults: makeDefaults(), locale: en)
        settings.goalKind = .distance
        #expect(settings.goal == .distance(meters: 5_000))
        settings.goalKind = .time
        #expect(settings.goal == .time(seconds: 1_800))
        settings.goalKind = .none
        #expect(settings.goal == nil)
    }

    @Test func distanceGoalStepsInTheUnitBeingShown() {
        let settings = AppSettings(defaults: makeDefaults(), locale: en)
        settings.distanceUnit = .kilometers
        settings.stepDistanceGoal(by: 1)
        #expect(settings.goalDistance == 5_500)

        settings.distanceUnit = .miles
        settings.goalDistance = 5 * 1_609.344
        settings.stepDistanceGoal(by: -1)
        #expect(abs(settings.goalDistance - 4.5 * 1_609.344) < 0.001)
    }

    @Test func distanceGoalStaysInsideItsRange() {
        let settings = AppSettings(defaults: makeDefaults(), locale: en)
        settings.distanceUnit = .kilometers
        settings.goalDistance = 1_000
        settings.stepDistanceGoal(by: -10)
        #expect(settings.goalDistance == 500)
        settings.goalDistance = 99_800
        settings.stepDistanceGoal(by: 10)
        #expect(settings.goalDistance == 100_000)
    }

    @Test func timeGoalStepsAndStaysInsideItsRange() {
        let settings = AppSettings(defaults: makeDefaults(), locale: en)
        settings.stepTimeGoal(by: 1)
        #expect(settings.goalTime == 2_100)
        settings.stepTimeGoal(by: -100)
        #expect(settings.goalTime == 300)
        settings.stepTimeGoal(by: 1_000)
        #expect(settings.goalTime == 36_000)
    }

    @Test func appearanceMapsToTheColorScheme() {
        #expect(AppSettings.Appearance.system.colorScheme == nil)
        #expect(AppSettings.Appearance.light.colorScheme == .light)
        #expect(AppSettings.Appearance.dark.colorScheme == .dark)
    }
}

struct RunGoalTests {
    @Test func distanceGoalProgress() {
        let goal = RunGoal.distance(meters: 5_000)
        #expect(goal.progress(distance: 0, elapsed: 600) == .init(fraction: 0, isReached: false))
        #expect(goal.progress(distance: 2_500, elapsed: 600) == .init(fraction: 0.5, isReached: false))
        #expect(goal.progress(distance: 5_000, elapsed: 600) == .init(fraction: 1, isReached: true))
        #expect(goal.progress(distance: 7_000, elapsed: 600) == .init(fraction: 1, isReached: true))
    }

    @Test func timeGoalProgressIgnoresDistance() {
        let goal = RunGoal.time(seconds: 1_800)
        #expect(goal.progress(distance: 9_999, elapsed: 450) == .init(fraction: 0.25, isReached: false))
        #expect(goal.progress(distance: 0, elapsed: 1_800).isReached)
    }

    @Test func nonsenseTargetsAndValuesNeverBreakTheBar() {
        #expect(RunGoal.distance(meters: 0).progress(distance: 100, elapsed: 0) == .init(fraction: 0, isReached: false))
        #expect(RunGoal.distance(meters: 1_000).progress(distance: -50, elapsed: 0).fraction == 0)
    }

    @Test func textsUseTheChosenUnitAndLocale() {
        let km = RunGoal.distance(meters: 5_000)
        #expect(km.targetText(unit: .kilometers, locale: en) == "5 km")
        #expect(km.progressText(distance: 2_100, elapsed: 0, unit: .kilometers, locale: en) == "2.10 / 5 km")
        #expect(km.progressText(distance: 2_100, elapsed: 0, unit: .kilometers, locale: Locale(identifier: "es_ES")) == "2,10 / 5 km")

        let miles = RunGoal.distance(meters: 2.5 * 1_609.344)
        #expect(miles.targetText(unit: .miles, locale: en) == "2.5 mi")

        let time = RunGoal.time(seconds: 1_800)
        #expect(time.progressText(distance: 0, elapsed: 725, unit: .kilometers, locale: en) == "12:05 / 30:00")
    }
}

struct UnitFormatTests {
    @Test func milesConvertDistanceAndPace() {
        #expect(DistanceFormat.distanceWithUnit(5_000, unit: .miles, locale: en) == "3.11 mi")
        #expect(DistanceFormat.distanceWithUnit(5_000, unit: .kilometers, locale: en) == "5.00 km")
        // 5:00/km is about 8:03/mi.
        #expect(PaceFormat.paceWithUnit(300, unit: .miles) == "8:03 /mi")
        #expect(PaceFormat.paceWithUnit(300, unit: .kilometers) == "5:00 /km")
        #expect(PaceFormat.paceWithUnit(nil, unit: .miles) == "-- /mi")
    }

    @Test func decimalSeparatorFollowsTheLocale() {
        #expect(DistanceFormat.kilometers(1_250, locale: Locale(identifier: "es_ES")) == "1,25")
        #expect(DistanceFormat.kilometers(1_250, locale: Locale(identifier: "de_DE")) == "1,25")
        #expect(DistanceFormat.kilometers(1_250, locale: en) == "1.25")
    }

    @Test func goalDistanceKeepsOnlyTheDecimalsItNeeds() {
        #expect(DistanceFormat.goal(5_000, unit: .kilometers, locale: en) == "5 km")
        #expect(DistanceFormat.goal(5_500, unit: .kilometers, locale: en) == "5.5 km")
        #expect(DistanceFormat.goal(5_500, unit: .kilometers, locale: Locale(identifier: "fr_FR")) == "5,5 km")
    }

    @Test func runSummaryHonoursTheUnit() {
        let run = RunRecord(
            id: UUID(), startedAt: Date(timeIntervalSince1970: 0), finishedAt: Date(timeIntervalSince1970: 1_500),
            status: .finished, accumulatedDuration: 1_500, lastResumedAt: nil, distance: 5_000, averagePace: 300
        )
        #expect(RunSummary.line(run, unit: .miles, locale: en) == "3.11 mi · 25:00 · 8:03 /mi")
    }
}

struct SpokenFormatTests {
    @Test func durationIsSpokenInWords() {
        #expect(SpokenFormat.duration(65, locale: en) == "1 minute, 5 seconds")
        #expect(SpokenFormat.duration(3_725, locale: en) == "1 hour, 2 minutes, 5 seconds")
        #expect(SpokenFormat.duration(-5, locale: en) == "0 seconds")
    }

    @Test func distanceIsSpokenWithTheUnitName() {
        #expect(SpokenFormat.distance(5_200, unit: .kilometers, locale: en).contains("kilometers"))
        #expect(SpokenFormat.distance(5_200, unit: .kilometers, locale: en).contains("5.2"))
        #expect(SpokenFormat.distance(5_000, unit: .miles, locale: en).contains("miles"))
    }

    @Test func paceIsSpokenPerUnitOrNotAvailable() {
        #expect(SpokenFormat.pace(325, unit: .kilometers, locale: en) == "5 minutes, 25 seconds per kilometer")
        #expect(SpokenFormat.pace(300, unit: .miles, locale: en) == "8 minutes, 3 seconds per mile")
        #expect(SpokenFormat.pace(nil, unit: .kilometers, locale: en) == "Not available")
    }
}
