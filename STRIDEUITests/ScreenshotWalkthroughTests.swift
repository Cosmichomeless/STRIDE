import CoreLocation
import XCTest

/// Drives a short synthetic run in the simulator and saves full-screen PNGs of each screen.
/// Not a regression test: it exists to (re)capture the README screenshots. See docs/screenshots/README.md.
///
/// Set `TEST_RUNNER_SHOTS_DIR` to the folder that should receive the PNGs.
final class ScreenshotWalkthroughTests: XCTestCase {
    /// A loop through the Retiro park (Madrid), about 1.3 km, as (latitude, longitude) corners.
    private static let corners: [(Double, Double)] = [
        (40.41530, -3.68330), (40.41620, -3.68020), (40.41850, -3.67800),
        (40.42060, -3.67930), (40.42110, -3.68260), (40.41900, -3.68450),
        (40.41530, -3.68330),
    ]

    private var shotsDirectory: URL? {
        ProcessInfo.processInfo.environment["SHOTS_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// The route sampled every ~3 m, the pace of an easy run at one fix per second.
    private func route() -> [CLLocationCoordinate2D] {
        var points: [CLLocationCoordinate2D] = []
        for (a, b) in zip(Self.corners, Self.corners.dropFirst()) {
            let meters = CLLocation(latitude: a.0, longitude: a.1).distance(from: CLLocation(latitude: b.0, longitude: b.1))
            let steps = max(1, Int(meters / 3))
            for i in 0..<steps {
                let t = Double(i) / Double(steps)
                points.append(CLLocationCoordinate2D(latitude: a.0 + (b.0 - a.0) * t, longitude: a.1 + (b.1 - a.1) * t))
            }
        }
        return points
    }

    private func save(_ name: String, _ app: XCUIApplication) throws {
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let directory = shotsDirectory {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try screenshot.pngRepresentation.write(to: directory.appendingPathComponent("\(name).png"))
        }
    }

    /// Accepts the system location prompt if it shows up (xcodebuild reinstalls the app, which resets the grant).
    @MainActor
    private func allowLocationIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons.matching(
            NSPredicate(format: "label IN %@", ["Allow While Using App", "Permitir al usarse la app"])
        ).firstMatch
        if allow.waitForExistence(timeout: 4) { allow.tap() }
    }

    /// Starts from an empty history and no restored run, so every capture shows the same single run.
    /// A run interrupted by an earlier attempt comes back paused, so it is finished and deleted first.
    @MainActor
    private func resetToCleanState(_ app: XCUIApplication) {
        if app.buttons["Resume"].waitForExistence(timeout: 5) { app.buttons["Finish"].tap() }
        app.tabBars.buttons["History"].tap()
        let delete = app.buttons.matching(NSPredicate(format: "label IN %@", ["Delete", "Eliminar", "Borrar"])).firstMatch
        var guardCount = 0
        while guardCount < 20, app.cells.firstMatch.waitForExistence(timeout: 2) {
            app.cells.firstMatch.swipeLeft()
            if delete.waitForExistence(timeout: 2) { delete.tap() }
            guardCount += 1
        }
        app.tabBars.buttons["Tracking"].tap()
    }

    @MainActor
    func testRecordsARunAndCapturesEachScreen() throws {
        let app = XCUIApplication()
        XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: Self.corners[0].0, longitude: Self.corners[0].1))
        app.launch()
        allowLocationIfAsked()
        resetToCleanState(app)

        let start = app.buttons["Start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        // On a fresh install the banner offers "Allow Location"; grant it so the idle shot shows "GPS ready".
        let allowLocation = app.buttons["Allow Location"]
        if allowLocation.waitForExistence(timeout: 2) {
            allowLocation.tap()
            allowLocationIfAsked()
        }
        // The simulated fix set before the grant is not redelivered: nudge it until the banner turns ready.
        let ready = app.staticTexts["GPS ready"]
        for attempt in 0..<6 where !ready.exists {
            let offset = Double(attempt % 2) * 0.00005
            XCUIDevice.shared.location = XCUILocation(
                location: CLLocation(latitude: Self.corners[0].0 + offset, longitude: Self.corners[0].1)
            )
            _ = ready.waitForExistence(timeout: 4)
        }
        XCTAssertTrue(ready.exists, "GPS never reported ready")
        sleep(1)
        try save("01-tracking-idle", app)

        start.tap()
        allowLocationIfAsked()
        let path = route()
        for (index, point) in path.prefix(120).enumerated() {
            XCUIDevice.shared.location = XCUILocation(location: CLLocation(latitude: point.latitude, longitude: point.longitude))
            Thread.sleep(forTimeInterval: 1)
            if index == 100 { try save("02-tracking-active", app) }
        }

        app.buttons["Finish"].tap()
        sleep(2)
        try save("03-run-details", app)

        app.tabBars.buttons["History"].tap()
        sleep(1)
        try save("04-history", app)
    }
}
