import XCTest

/// The app shows up in the device language, and the longest translations still fit.
final class LocalizationUITests: XCTestCase {
    private func launch(language: String, locale: String, extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-AppleLanguages", "(\(language))", "-AppleLocale", locale, "-uitest-reset-settings", "-uitest-fake-health"] + extra
        app.launch()
        return app
    }

    @MainActor
    func testSpanishShowsTranslatedTabsAndControls() throws {
        let app = launch(language: "es", locale: "es_ES")
        XCTAssertTrue(app.buttons["Iniciar"].waitForExistence(timeout: 10))
        app.tabBars.buttons["Ajustes"].tap()
        XCTAssertTrue(app.navigationBars["Ajustes"].waitForExistence(timeout: 5))
        // es_ES uses kilometers by default.
        XCTAssertTrue(app.buttons["Kilómetros"].isSelected)
        XCTAssertTrue(app.links["Política de privacidad"].exists || app.buttons["Política de privacidad"].exists)
        app.tabBars.buttons["Historial"].tap()
        XCTAssertTrue(app.navigationBars["Historial"].waitForExistence(timeout: 5))
    }

    /// German has the longest words; at the largest accessibility size nothing may clip or lose its label.
    @MainActor
    func testGermanAtLargestAccessibilityTextSizeKeepsEveryScreenUsable() throws {
        let app = launch(
            language: "de", locale: "de_DE",
            extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        )
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 10))
        let audit: XCUIAccessibilityAuditType = [.dynamicType, .elementDetection, .sufficientElementDescription, .textClipped]
        // The audit reports this footnote as possibly clipped although all six lines are on screen
        // (checked on a screenshot); every other finding still fails the test.
        let knownFalsePositive = "Distanzen und Pace werden in dieser Einheit angezeigt."
        let auditScreen = { (app: XCUIApplication) throws in
            try app.performAccessibilityAudit(for: audit) { issue in
                issue.auditType == .textClipped && (issue.element?.label.hasPrefix(knownFalsePositive) == true)
            }
        }
        try auditScreen(app)

        app.tabBars.buttons["Einstellungen"].tap()
        XCTAssertTrue(app.navigationBars["Einstellungen"].waitForExistence(timeout: 5))
        try auditScreen(app)

        app.tabBars.buttons["Verlauf"].tap()
        XCTAssertTrue(app.navigationBars["Verlauf"].waitForExistence(timeout: 5))
        try auditScreen(app)
    }
}
