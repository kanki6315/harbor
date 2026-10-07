import XCTest
final class HarborUITests: XCTestCase {
    func testLaunch() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.textFields["Search or enter address"].waitForExistence(timeout: 10))
    }
}
