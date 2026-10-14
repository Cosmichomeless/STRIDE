import XCTest

/// Settings are chosen and kept across a relaunch. Pinned to English so the labels do not depend on
/// the simulator's language.
final class SettingsUITests: XCTestCase {
    private func launch(reset: Bool) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"] + (reset ? ["-uitest-reset-settings"] : [])
        app.launch()
        return app
    }

    @MainActor
    func testUnitGoalAndAppearanceAreChosenAndKept() throws {
        var app = launch(reset: true)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 10))

        // en_US starts in miles; pick kilometers, then miles again to prove the control works.
        app.buttons["Kilometers"].tap()
        app.buttons["Miles"].tap()
        app.buttons["Distance"].tap()

        // 5 km is 3.1 mi; the stepper snaps to the nearest half mile, so one tap lands on 3.5.
        let increment = app.buttons["goalDistanceStepper-Increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        XCTAssertEqual(increment.value as? String, "3.11 miles")
        increment.tap()
        XCTAssertEqual(increment.value as? String, "3.5 miles")

        app.buttons["Dark"].tap()

        // The goal shows on the Tracking screen, with its progress.
        app.tabBars.buttons["Tracking"].tap()
        let goal = app.otherElements["goalProgress"]
        XCTAssertTrue(goal.waitForExistence(timeout: 5))
        XCTAssertTrue((goal.value as? String)?.contains("percent") == true)

        // Relaunch without resetting: everything is still chosen.
        app.terminate()
        app = launch(reset: false)
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["Miles"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Miles"].isSelected)
        XCTAssertTrue(app.buttons["Distance"].isSelected)
        XCTAssertTrue(app.buttons["Dark"].isSelected)
        XCTAssertEqual(app.buttons["goalDistanceStepper-Increment"].value as? String, "3.5 miles")
    }

    @MainActor
    func testGoalIsOffByDefaultAndStepperAppearsForATimeGoal() throws {
        let app = launch(reset: true)
        app.tabBars.buttons["Tracking"].tap()
        XCTAssertFalse(app.otherElements["goalProgress"].waitForExistence(timeout: 2))

        app.tabBars.buttons["Settings"].tap()
        app.buttons["Time"].tap()
        let increment = app.buttons["goalTimeStepper-Increment"]
        XCTAssertTrue(increment.waitForExistence(timeout: 5))
        XCTAssertEqual(increment.value as? String, "30 minutes")
        increment.tap()
        XCTAssertEqual(increment.value as? String, "35 minutes")
    }

    /// At the largest accessibility text size every tab still shows its controls and the system's
    /// audit finds no clipped or unlabeled elements.
    @MainActor
    func testLargestAccessibilityTextSizeKeepsEveryScreenUsable() throws {
        let app = XCUIApplication()
        app.launchArguments = [
            "-AppleLanguages", "(en)", "-AppleLocale", "en_US", "-uitest-reset-settings",
            "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ]
        app.launch()

        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 10))
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .sufficientElementDescription, .textClipped])

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .sufficientElementDescription, .textClipped])

        app.tabBars.buttons["History"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        try app.performAccessibilityAudit(for: [.dynamicType, .elementDetection, .sufficientElementDescription, .textClipped])
    }
}
