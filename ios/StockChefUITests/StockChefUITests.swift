import XCTest

@MainActor
final class StockChefUITests: XCTestCase {
    func testOnboardingStartsWithPrivacyPromise() {
        let app = XCUIApplication()
        app.launchArguments = ["-stockchef_reset_onboarding"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Vos courses restent privées"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Continuer"].exists)
    }

    func testDemoInventoryAndPlannerAreReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["-stockchef_skip_onboarding", "-stockchef_demo"]
        app.launch()
        XCTAssertTrue(app.navigationBars["StockChef"].waitForExistence(timeout: 3))
        app.tabBars.buttons["Mon stock"].tap()
        XCTAssertTrue(app.navigationBars["Mon stock"].waitForExistence(timeout: 2))
        app.tabBars.buttons["Planning"].tap()
        XCTAssertTrue(app.navigationBars["Planning repas"].waitForExistence(timeout: 2))
    }
}
