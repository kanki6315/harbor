import XCTest

final class HarborUITests: XCTestCase {
    @MainActor func testLinkHoldOpensInHarborNewTab() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let link = app.webViews.links["Open popup tab"]
        XCTAssertTrue(link.waitForExistence(timeout: 15))
        revealAboveChrome(link, in: app)
        link.press(forDuration: 1)
        XCTAssertTrue(app.buttons["Open in New Tab"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Link"].exists)
        XCTAssertTrue(app.buttons["Open in Default Browser"].exists)
        XCTAssertTrue(app.buttons["Copy Link"].exists)
        app.buttons["Open in New Tab"].tap()
        XCTAssertTrue(app.buttons["tabsButton"].waitForExistence(timeout: 5))
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Open Harbor test page"].exists)
    }

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
        XCTAssertGreaterThan(web.frame.minY, 0, "Website controls must stay below the system status area")
        XCTAssertLessThanOrEqual(web.frame.maxY, app.textFields["addressField"].frame.minY,
                                 "Website viewport must end above browser controls")
        capture(app, name: "phone-website-glass")
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
    @MainActor func testCollapsibleControlsLeaveFooterReachable() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let web = app.webViews.firstMatch
        let footer = web.buttons["Fixed footer action"]
        XCTAssertTrue(footer.waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(footer.frame.maxY, app.textFields["addressField"].frame.minY)
        let expandedHeight = web.frame.height
        app.buttons["collapseBrowserControls"].tap()
        let reveal = app.buttons["expandBrowserControls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["addressField"].exists)
        XCTAssertGreaterThan(web.frame.height, expandedHeight + 40)
        XCTAssertLessThanOrEqual(footer.frame.maxY, reveal.frame.minY)
        footer.tap()
        XCTAssertTrue(web.buttons["Footer tapped"].exists)
        for _ in 0..<5 { web.swipeUp() }
        let end = web.buttons["Page end action"]
        XCTAssertTrue(end.isHittable)
        end.tap()
        XCTAssertTrue(web.buttons["Page end reached"].exists)
        capture(app, name: "phone-minimized-footer")
        reveal.tap()
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(web.buttons["Footer tapped"].frame.maxY, app.textFields["addressField"].frame.minY)
        capture(app, name: "phone-expanded-footer")
    }

    @MainActor func testCollapsedControlsInDarkLargeTextAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                               "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let footer = app.webViews.buttons["Fixed footer action"]
        XCTAssertTrue(footer.waitForExistence(timeout: 15))
        XCTAssertLessThanOrEqual(footer.frame.maxY, app.textFields["addressField"].frame.minY)
        capture(app, name: "phone-dark-large-expanded")
        app.buttons["collapseBrowserControls"].tap()
        let reveal = app.buttons["expandBrowserControls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(footer.frame.maxY, reveal.frame.minY)
        capture(app, name: "phone-dark-large-minimized")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotationSettled = NSPredicate { _, _ in
            app.frame.width > app.frame.height && reveal.frame.minY > 0 &&
                footer.frame.minY > 0 && footer.frame.maxY <= reveal.frame.minY
        }
        expectation(for: rotationSettled, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(reveal.isHittable)
        XCTAssertLessThanOrEqual(footer.frame.maxY, reveal.frame.minY)
        capture(app, name: "phone-landscape-minimized")
        reveal.tap()
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
        XCTAssertLessThanOrEqual(footer.frame.maxY, address.frame.minY)
        capture(app, name: "phone-landscape-expanded")
        address.tap()
        XCTAssertTrue(app.buttons["Go"].exists)
        XCTAssertFalse(app.buttons["collapseBrowserControls"].exists)
    }

    @MainActor func testPopupAndPublicNavigation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let popup = app.webViews.links["Open popup tab"]
        XCTAssertTrue(popup.waitForExistence(timeout: 15))
        revealAboveChrome(popup, in: app)
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
        revealAboveChrome(play, in: app)
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
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
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

    @MainActor private func revealAboveChrome(_ element: XCUIElement, in app: XCUIApplication) {
        // XCTest can consider a web element hittable even when native glass overlaps it.
        for _ in 0..<4 {
            if element.frame.maxY < app.textFields["addressField"].frame.minY - 8 { break }
            app.webViews.firstMatch.swipeUp()
        }
        XCTAssertLessThan(element.frame.maxY, app.textFields["addressField"].frame.minY,
                          "Page controls must scroll above the browser chrome")
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
