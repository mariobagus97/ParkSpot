import XCTest

/// Drives the save → find → found path with the app's UI-testing services (see `UITestServices`).
final class SaveAndFindUITests: XCTestCase {
    func testSaveThenFindThenFound() {
        let app = XCUIApplication()
        app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()

        let park = app.buttons["park_button"]
        XCTAssertTrue(park.waitForExistence(timeout: 10), "Home should offer Park here")
        park.tap()

        let done = app.buttons["details_done"]
        XCTAssertTrue(done.waitForExistence(timeout: 10), "The details sheet should open after the photo")
        done.tap()

        let bar = app.buttons["now_parked_bar"]
        XCTAssertTrue(bar.waitForExistence(timeout: 10), "The now-parked bar should appear")
        bar.tap()

        let found = app.buttons["found_it"]
        XCTAssertTrue(found.waitForExistence(timeout: 10), "Find should open")
        found.tap()

        let barGone = app.buttons["now_parked_bar"]
        let deadline = Date().addingTimeInterval(10)
        while barGone.exists && Date() < deadline { usleep(200_000) }
        XCTAssertFalse(barGone.exists, "The now-parked bar should be gone after Found it")

        app.tabBars.buttons["Your spots"].tap()
        let row = app.cells.containing(.staticText, identifier: "Jl. Sudirman").firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "The ended spot should be listed in Your spots")
    }
}
