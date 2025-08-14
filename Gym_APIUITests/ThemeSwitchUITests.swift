import XCTest

final class ThemeSwitchUITests: XCTestCase {
    func testLaunchAndTabsExist() throws {
        let app = XCUIApplication()
        app.launch()
        // Basic smoke: Tab bar items exist
        XCTAssertTrue(app.tabBars.buttons["Home"].exists)
        XCTAssertTrue(app.tabBars.buttons["Classes"].exists)
        XCTAssertTrue(app.tabBars.buttons["Events"].exists)
        XCTAssertTrue(app.tabBars.buttons["Messages"].exists)
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }
}

