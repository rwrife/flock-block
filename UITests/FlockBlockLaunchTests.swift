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
        XCTAssertTrue(app.buttons["wave.start"].exists)
        // Earn-only unlocks start locked and disabled: no coins, no purchase path.
        for id in ["unlock.fan", "unlock.net", "unlock.decoy"] {
            XCTAssertTrue(app.buttons[id].exists, id)
            XCTAssertFalse(app.buttons[id].isEnabled, id)
        }
    }

    /// Real iPhone journey: start → pick blocker → tap lane → results → replay.
    /// The fixed tutorial wave resolves in bounded time on the pinned runtime.
    @MainActor
    func testOneThumbWaveJourney() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing"]
        app.launch()

        let start = app.buttons["wave.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 10))
        start.tap()

        let wall = app.buttons["blocker.wall"]
        XCTAssertTrue(wall.waitForExistence(timeout: 5))
        wall.tap()

        let lane1 = app.buttons["lane.1"]
        XCTAssertTrue(lane1.waitForExistence(timeout: 5))
        lane1.tap()

        // Fixed fixture: exactly one wall bonk → "score 10" once the wave ends.
        let status = app.staticTexts["wave.status"]
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "score 10"),
                    evaluatedWith: status)
        waitForExpectations(timeout: 40)

        // Results offer both a replay and the next ladder wave.
        XCTAssertTrue(app.buttons["wave.next"].waitForExistence(timeout: 5))
        let replay = app.buttons["wave.replay"]
        XCTAssertTrue(replay.waitForExistence(timeout: 5))
        XCTAssertTrue(replay.isEnabled)
        replay.tap()
        let restart = app.staticTexts["wave.status"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Wave running"),
                    evaluatedWith: restart)
        waitForExpectations(timeout: 10)
    }
}
