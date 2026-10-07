import XCTest

final class HarborUITests: XCTestCase {
    @MainActor func testStartPageTabsSettingsAndRestore() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["Where to next?"].exists)
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["1 tab"].waitForExistence(timeout: 5))
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        capture(app, name: "phone-tabs")
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 10))
        app.buttons["Done"].tap()
        app.buttons["moreButton"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["Tracker blocking"].exists)
        capture(app, name: "phone-settings")
    }

    @MainActor func testLocalVideoAcrossBrowserUI() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.staticTexts["Harbor test page"].waitForExistence(timeout: 20))
        let instance = web.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Page instance ")).firstMatch.label
        web.buttons["Play video"].tap()
        XCTAssertTrue(web.staticTexts["Video playing"].waitForExistence(timeout: 5))
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["1 tab"].waitForExistence(timeout: 5))
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        capture(app, name: "phone-tabs-populated")
        app.buttons["Open Harbor test page"].tap()
        XCTAssertTrue(web.staticTexts[instance].waitForExistence(timeout: 5), "Switching tabs must preserve the live page instance")
        XCTAssertTrue(web.staticTexts["Video playing"].exists)
        web.buttons["Pause video"].tap()
        XCTAssertTrue(web.staticTexts["Video paused"].exists)
    }
    @MainActor func testPopupAndPublicNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let popup = app.webViews.links["Open popup tab"]
        XCTAssertTrue(popup.waitForExistence(timeout: 15))
        popup.tap()
        XCTAssertTrue(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "This domain is for use in documentation")).firstMatch.waitForExistence(timeout: 20))
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "This domain is for use in documentation")).firstMatch.waitForExistence(timeout: 20))
    }

    @MainActor func testAudioAndNativeFullscreen() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.buttons["Play audio"].waitForExistence(timeout: 15))
        web.buttons["Play audio"].tap()
        XCTAssertTrue(web.staticTexts["Audio playing"].waitForExistence(timeout: 5))
        web.buttons["Play video"].tap()
        web.buttons["Full-screen video"].tap()
        let media = app.otherElements["Media"].firstMatch
        XCTAssertTrue(media.waitForExistence(timeout: 5))
        media.tap() // Native playback controls auto-hide; reveal them before locating Close.
        let close = app.buttons.matching(NSPredicate(format: "label IN %@", ["Done", "Close", "Close video"])).firstMatch
        if !close.waitForExistence(timeout: 3) { print(app.debugDescription) }
        XCTAssertTrue(close.exists)
        close.tap()
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
    }

    @MainActor func testHLSPlayback() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let play = app.webViews.buttons["Play Apple HLS sample"]
        XCTAssertTrue(play.waitForExistence(timeout: 15))
        play.tap()
        XCTAssertTrue(app.webViews.staticTexts["HLS playing"].waitForExistence(timeout: 25))
    }

    @MainActor func testYouTubeCompatibilityAttempt() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 10))
        address.tap()
        address.typeText("https://www.youtube.com/embed/9zjeImiYtow\n")
        let play = app.webViews.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Play")).firstMatch
        guard play.waitForExistence(timeout: 20) else {
            print("YouTube compatibility observation: " + app.debugDescription)
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "YouTube compatibility response"
            attachment.lifetime = .keepAlways
            add(attachment)
            throw XCTSkip("YouTube did not expose a playable embed in this simulator session; inspect the captured provider response.")
        }
        play.tap()
        app.buttons["tabsButton"].tap()
        guard app.images["Media playing"].waitForExistence(timeout: 15) else {
            print("YouTube playback observation: " + app.debugDescription)
            throw XCTSkip("WebKit did not report playing media after the YouTube play action; physical-device verification remains required.")
        }
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
