import XCTest

@MainActor
final class ObsidianUITests: XCTestCase {
    func testSearchAndYouTubeNavigation() {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launch()
        let homeQuery = app.textFields["homeQuery"]
        XCTAssertTrue(homeQuery.waitForExistence(timeout: 10))
        let home = XCTAttachment(screenshot: app.screenshot())
        home.name = "Obsidian iPhone home"
        home.lifetime = .keepAlways
        add(home)

        homeQuery.tap()
        homeQuery.typeText("hello world\n")
        let address = app.textFields["addressInput"]
        let search = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "google.com/search?q="), object: address)
        XCTAssertEqual(XCTWaiter.wait(for: [search], timeout: 15), .completed)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))

        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.buttons["newTabButton"].waitForExistence(timeout: 5))
        app.buttons["newTabButton"].tap()
        XCTAssertTrue(homeQuery.waitForExistence(timeout: 5))
        homeQuery.tap()
        homeQuery.typeText("youtube\n")
        let youtube = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value CONTAINS %@", "youtube.com"), object: address)
        XCTAssertEqual(XCTWaiter.wait(for: [youtube], timeout: 15), .completed)
        XCTAssertTrue(app.webViews.firstMatch.waitForExistence(timeout: 10))
    }
}
