import XCTest

final class FlockBlockLaunchTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testWorkspaceLaunches() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        XCTAssertTrue(app.staticTexts["Four flock lanes"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Blocker tray"].exists)
    }
}
