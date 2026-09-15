import XCTest

@MainActor
final class PersonBrowserUITests: XCTestCase {
    func testOfflineRelaunchAndRelativeNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store"]
        app.launch()
        let hannah = app.staticTexts["Hannah Ainsley"].firstMatch
        XCTAssertTrue(hannah.waitForExistence(timeout: 30))
        XCTAssertTrue(app.images["portrait.R9PJ-5MX.jpg"].waitForExistence(timeout: 20))
        hannah.tap()
        XCTAssertTrue(app.images["portrait.R9PJ-5MX.jpg"].waitForExistence(timeout: 20))
        let biography = app.staticTexts["Biography"].firstMatch
        for _ in 0..<5 where !biography.isHittable { app.swipeUp() }
        XCTAssertTrue(biography.waitForExistence(timeout: 20))
        let bartholomew = app.staticTexts["Bartholomew Whitcomb"].firstMatch
        for _ in 0..<8 where !bartholomew.isHittable { app.swipeUp() }
        XCTAssertTrue(bartholomew.isHittable)
        bartholomew.tap()
        let title = app.navigationBars["Bartholomew Whitcomb"]
        XCTAssertTrue(title.waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["portrait.T6HV-2CZ.jpg"].waitForExistence(timeout: 20))
        for _ in 0..<5 where !app.staticTexts["Biography"].firstMatch.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Biography"].firstMatch.waitForExistence(timeout: 20))
        // Terminating clears all in-memory view models and image caches.
        app.terminate()
        app.launchArguments = ["--ui-testing", "--offline"]
        app.launch()
        XCTAssertTrue(hannah.waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["portrait.R9PJ-5MX.jpg"].waitForExistence(timeout: 10))
        hannah.tap()
        for _ in 0..<8 where !bartholomew.isHittable { app.swipeUp() }
        XCTAssertTrue(bartholomew.isHittable)
        bartholomew.tap()
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertTrue(app.images["portrait.T6HV-2CZ.jpg"].waitForExistence(timeout: 10))
        for _ in 0..<5 where !app.staticTexts["Biography"].firstMatch.isHittable { app.swipeUp() }
        XCTAssertTrue(app.staticTexts["Biography"].firstMatch.exists)
        XCTAssertFalse(app.staticTexts["Profile unavailable offline. Connect to the internet and try again."].exists)
    }

    func testLargeTextAndDarkAppearance() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                               "--dark-appearance"]
        app.launch()
        let hannah = app.staticTexts["Hannah Ainsley"].firstMatch
        XCTAssertTrue(hannah.waitForExistence(timeout: 30))
        XCTAssertTrue(app.images["portrait.R9PJ-5MX.jpg"].waitForExistence(timeout: 20))
        capture(app, name: "People - large text")
        hannah.tap()
        XCTAssertTrue(app.navigationBars["Hannah Ainsley"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.images["portrait.R9PJ-5MX.jpg"].waitForExistence(timeout: 20))
        capture(app, name: "Profile - large text")
        app.swipeUp()
        capture(app, name: "Profile details - large text")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.navigationBars["People"].waitForExistence(timeout: 10))
    }

    private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    func testFirstLaunchOfflineShowsRetry() {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--reset-test-store", "--offline"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Couldn’t load people"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["Retry"].exists)
    }
}
