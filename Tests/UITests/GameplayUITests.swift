import XCTest

final class GameplayUITests: XCTestCase {
    @MainActor func testOpenGamePauseAndSelectWithoutDragging() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["playNow"].waitForExistence(timeout: 10))
        app.buttons["playNow"].tap()
        XCTAssertTrue(app.buttons["dismissCoach"].waitForExistence(timeout: 15))
        app.buttons["dismissCoach"].tap()
        XCTAssertTrue(app.buttons["tile-0"].exists)
        app.buttons["Pause game"].tap()
        XCTAssertTrue(app.staticTexts["Your timer is paused."].exists)
        app.buttons["Resume"].tap()
        app.buttons["tile-0"].tap()
        XCTAssertTrue(app.buttons["tile-0"].isSelected)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Gameplay"; screenshot.lifetime = .keepAlways; add(screenshot)
    }
}
