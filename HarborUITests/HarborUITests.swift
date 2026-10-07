import XCTest

final class HarborUITests: XCTestCase {
    @MainActor func testLockedProfileAppearanceAndSwitching() {
        let app = XCUIApplication()
        for (name, extra) in [
            ("phone-locked", [String]()),
            ("phone-locked-accessibility", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        ] {
            app.launchArguments = ["--uitesting", "--reset", "--locked-profile-fixture"] + extra
            app.launch()
            XCTAssertTrue(app.buttons["unlockProfile"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["historyButton"].exists)
            XCTAssertFalse(app.buttons["bookmarksButton"].exists)
            capture(app, name: name)
            if extra.isEmpty {
                XCUIDevice.shared.orientation = .landscapeLeft
                capture(app, name: "phone-locked-landscape")
                XCUIDevice.shared.orientation = .portrait
            }
            app.buttons["Switch profile"].tap()
            XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
            app.terminate()
        }
    }

    @MainActor func testBrowserDestinations() {
        checkBrowserDestinations(darkLarge: false)
    }

    @MainActor func testBrowserDestinationsDarkLarge() {
        checkBrowserDestinations(darkLarge: true)
    }

    @MainActor private func checkBrowserDestinations(darkLarge: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture", "-AppleInterfaceStyle", darkLarge ? "Dark" : "Light",
                               "-UIPreferredContentSizeCategoryName", darkLarge ? "UICTContentSizeCategoryAccessibilityXXXL" : "UICTContentSizeCategoryL"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["historyButton"].isHittable)
        XCTAssertTrue(app.buttons["settingsButton"].isHittable)
        XCTAssertTrue(app.buttons["bookmarksButton"].isHittable)
        XCTAssertLessThan(app.buttons["historyButton"].frame.midX, app.buttons["settingsButton"].frame.midX)
        XCTAssertLessThan(app.webViews.firstMatch.frame.minY, app.buttons["historyButton"].frame.midY, "The website must extend behind the top controls")
        capture(app, name: darkLarge ? "controls-dark-large" : "controls-light")
        app.buttons["bookmarksButton"].tap()
        let bookmark = app.buttons["bookmarkCurrentPage"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmark.label, "Bookmark this page")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Remove bookmark for this page")
        capture(app, name: darkLarge ? "bookmarks-dark-large" : "bookmarks-light")
        app.buttons["Done"].tap()
        app.buttons["bookmarksButton"].tap()
        XCTAssertEqual(bookmark.label, "Remove bookmark for this page")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Bookmark this page")
        app.buttons["Done"].tap()
        app.buttons["historyButton"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["settingsButton"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Profiles"].exists)
        app.buttons["Done"].tap()
        XCTAssertLessThan(app.buttons["sharePageButton"].frame.midX, app.buttons["historyButton"].frame.midX)
        app.buttons["sharePageButton"].tap()
        XCTAssertTrue(app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 15))
        capture(app, name: "direct-share-sheet")
        app.buttons["header.closeButton"].tap()
    }

    @MainActor func testRenameBookmark() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        app.buttons["bookmarksButton"].tap()
        app.buttons["bookmarkCurrentPage"].tap()
        let savedPage = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Local page")).firstMatch
        XCTAssertTrue(savedPage.waitForExistence(timeout: 5))
        savedPage.press(forDuration: 1)
        app.buttons["Rename"].tap()
        let name = app.alerts.textFields["Name"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        let oldName = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count) + "My saved page")
        app.alerts.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My saved page")).firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "bookmark-renamed")
        app.buttons["Done"].tap()
        app.buttons["bookmarksButton"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My saved page")).firstMatch.exists)
    }

    @MainActor func testBookmarkFolders() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        app.buttons["bookmarksButton"].tap()
        app.buttons["newBookmarkFolder"].tap()
        app.alerts.textFields["Folder name"].tap()
        app.alerts.textFields["Folder name"].typeText("Travel")
        app.alerts.buttons["Save"].tap()
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Travel")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Travel"].waitForExistence(timeout: 5))
        app.buttons["bookmarkCurrentPage"].tap()
        let saved = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Local page")).firstMatch
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        capture(app, name: "bookmark-folder")
        saved.press(forDuration: 1)
        app.buttons["Move to folder"].tap()
        app.buttons["Unfiled"].tap()
        XCTAssertTrue(app.staticTexts["This folder is empty"].waitForExistence(timeout: 5))
        app.navigationBars.buttons["Bookmarks"].tap()
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        let folder = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Travel")).firstMatch
        folder.press(forDuration: 1)
        app.buttons["Delete folder"].tap()
        XCTAssertFalse(folder.exists)
        XCTAssertTrue(saved.exists)
        capture(app, name: "bookmark-unfiled")
    }

    @MainActor func testHistorySearchAndClear() {
        let app = openHistoryFixture()
        XCTAssertTrue(app.staticTexts["Today"].exists)
        XCTAssertTrue(app.staticTexts["Yesterday"].exists)
        capture(app, name: "phone-history-light")
        let search = app.searchFields["Search history"]
        search.tap()
        search.typeText("Acadia")
        XCTAssertTrue(app.buttons.matching(identifier: "historyVisit").matching(NSPredicate(format: "label BEGINSWITH %@", "Plan your visit — Acadia National Park,")).firstMatch.exists)
        XCTAssertFalse(app.buttons.matching(identifier: "historyVisit").matching(NSPredicate(format: "label BEGINSWITH %@", "Wikipedia,")).firstMatch.exists)
        search.typeText("no-match")
        XCTAssertTrue(app.staticTexts["No matching pages"].exists)
        capture(app, name: "phone-history-no-results")
        app.buttons["Clear text"].tap()
        app.buttons["historySelect"].tap()
        app.buttons["Select All"].tap()
        XCTAssertTrue(app.buttons["Delete (6)"].exists)
        capture(app, name: "phone-history-selection")
        app.buttons["historySelect"].tap()
        app.buttons["Clear All"].tap()
        XCTAssertTrue(app.buttons["Clear history"].waitForExistence(timeout: 3))
        capture(app, name: "phone-history-clear")
        app.buttons["Clear history"].tap()
        XCTAssertTrue(app.staticTexts["No history yet"].exists)
        XCTAssertFalse(app.buttons["Clear All"].isEnabled)
        capture(app, name: "phone-history-empty")
    }

    @MainActor func testHistoryFilteredSelectionAndPersistence() {
        let app = openHistoryFixture()
        let search = app.searchFields["Search history"]
        search.tap()
        search.typeText("Acadia")
        // Submit search to dismiss the keyboard while preserving the filter.
        search.typeText("\n")
        app.buttons["historySelect"].tap()
        app.buttons["Select All"].tap()
        XCTAssertTrue(app.buttons["Delete (2)"].exists)
        app.buttons["historyDeleteSelected"].tap()
        app.buttons["Delete selected visits"].tap()
        XCTAssertTrue(app.staticTexts["No matching pages"].exists)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["historyButton"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "historyVisit").matching(NSPredicate(format: "label BEGINSWITH %@", "Wikipedia,")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons.matching(identifier: "historyVisit").matching(NSPredicate(format: "label BEGINSWITH %@", "Plan your visit — Acadia National Park,")).firstMatch.exists)
        app.buttons.matching(identifier: "historyVisit").matching(NSPredicate(format: "label BEGINSWITH %@", "Human Interface Guidelines,")).firstMatch.tap()
        XCTAssertTrue(app.navigationBars["History"].waitForNonExistence(timeout: 5))
    }

    @MainActor func testHistoryAccessibilityText() {
        let app = openHistoryFixture(extra: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"])
        capture(app, name: "phone-history-accessibility")

    }

    @MainActor private func openHistoryFixture(extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--history-fixture"]
        if !extra.contains("-AppleInterfaceStyle") { app.launchArguments += ["-AppleInterfaceStyle", "Light"] }
        if !extra.contains("-UIPreferredContentSizeCategoryName") {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryL"]
        }
        app.launchArguments += extra
        app.launch()
        XCTAssertTrue(app.buttons["historyButton"].waitForExistence(timeout: 15))
        app.buttons["historyButton"].tap()
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testTabReorderAndUnloadedPreview() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        let pause = app.webViews.buttons["Pause video"]
        revealAboveChrome(pause, in: app)
        pause.tap()
        app.buttons["tabsButton"].tap()
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        app.buttons["tabOptions"].tap()
        app.buttons["Unload background tabs"].tap()
        XCTAssertTrue(app.staticTexts["Unloaded. Opens again when selected."].waitForExistence(timeout: 5))
        capture(app, name: "phone-tabs-unloaded")
        app.buttons["reorderTabs"].tap()
        XCTAssertTrue(app.navigationBars["Reorder tabs"].waitForExistence(timeout: 5))
        capture(app, name: "phone-tabs-reorder")
        let firstRow = app.cells.element(boundBy: 0)
        let secondRow = app.cells.element(boundBy: 1)
        XCTAssertTrue(firstRow.exists && secondRow.exists)
        firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.5))
            .press(forDuration: 0.5, thenDragTo: secondRow.coordinate(withNormalizedOffset: CGVector(dx: 0.94, dy: 0.9)))
        XCTAssertTrue(app.cells.element(boundBy: 0).staticTexts["New Tab"].exists)
        app.navigationBars["Reorder tabs"].buttons["Done"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.staticTexts["Unloaded. Opens again when selected."].waitForExistence(timeout: 5))
        capture(app, name: "phone-tabs-restored-preview")
    }

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
        app.buttons["settingsButton"].tap()
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
        XCTAssertGreaterThan(web.frame.maxY, app.buttons["tabsButton"].frame.maxY,
                             "Website must draw behind floating controls")
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
    @MainActor func testScrollingCollapsesControlsAndURLRestoresThem() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let web = app.webViews.firstMatch
        let footer = web.buttons["Fixed footer action"]
        XCTAssertTrue(footer.waitForExistence(timeout: 15))
        let expandedHeight = web.frame.height
        app.webViews.firstMatch.swipeUp()
        let reveal = app.buttons["expandBrowserControls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["addressField"].exists)
        XCTAssertEqual(web.frame.height, expandedHeight, accuracy: 1, "Floating controls must not resize the website")
        XCTAssertFalse(app.buttons["historyButton"].exists)
        XCTAssertFalse(app.buttons["settingsButton"].exists)
        for _ in 0..<5 { web.swipeUp() }
        let end = web.buttons["Page end action"]
        XCTAssertTrue(end.isHittable)
        end.tap()
        XCTAssertTrue(web.buttons["Page end reached"].exists)
        capture(app, name: "phone-minimized-footer")
        reveal.tap()
        XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
        capture(app, name: "phone-expanded-footer")
    }

    @MainActor func testRepeatedChromeTransitions() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let web = app.webViews.firstMatch
        XCTAssertTrue(web.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        for _ in 0..<3 {
            web.swipeUp()
            let pill = app.buttons["expandBrowserControls"]
            XCTAssertTrue(pill.waitForExistence(timeout: 5))
            pill.tap()
            XCTAssertTrue(app.textFields["addressField"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.buttons["tabsButton"].isHittable)
            XCTAssertFalse(app.keyboards.firstMatch.exists)
            web.swipeDown()
        }
        capture(app, name: "phone-motion-restored")
    }

    @MainActor func testCollapsedControlsInDarkLargeTextAndLandscape() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture",
                               "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
                               "-AppleInterfaceStyle", "Dark"]
        app.launch()
        let footer = app.webViews.buttons["Fixed footer action"]
        XCTAssertTrue(footer.waitForExistence(timeout: 15))
        capture(app, name: "phone-dark-large-expanded")
        app.webViews.firstMatch.swipeUp()
        let reveal = app.buttons["expandBrowserControls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        capture(app, name: "phone-dark-large-minimized")
        XCUIDevice.shared.orientation = .landscapeLeft
        defer { XCUIDevice.shared.orientation = .portrait }
        let rotationSettled = NSPredicate { _, _ in
            app.frame.width > app.frame.height && reveal.frame.minY > 0 &&
                footer.frame.minY > 0
        }
        expectation(for: rotationSettled, evaluatedWith: app)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(reveal.isHittable)
        capture(app, name: "phone-landscape-minimized")
        reveal.tap()
        let address = app.textFields["addressField"]
        XCTAssertTrue(address.waitForExistence(timeout: 5))
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

    @MainActor func testProfileManagementAndIsolationThroughUI() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        app.buttons["New tab"].tap()
        // Leaving address editing exposes the profile control too.
        app.buttons["profilesButton"].tap()
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["Switch to Work"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profiles")
        app.buttons["Switch to Work"].tap()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["profilesButton"].label, "Profiles, Work")
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["1 tab"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["settingsButton"].tap()
        let tracker = app.switches["Tracker blocking"]
        XCTAssertTrue(tracker.waitForExistence(timeout: 5))
        tracker.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(tracker.value as? String, "0")
        app.buttons["Done"].tap()
        app.buttons["profilesButton"].tap()
        app.buttons["Switch to Personal"].tap()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        app.buttons["settingsButton"].tap()
        XCTAssertEqual(app.switches["Tracker blocking"].value as? String, "1")
        app.buttons["Done"].tap()
        app.buttons["profilesButton"].tap()
        app.buttons["Edit Work"].tap()
        let name = app.textFields["profileName"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "Office")
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["Switch to Office"].waitForExistence(timeout: 5))
        app.buttons["Switch to Office"].swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        XCTAssertTrue(app.buttons["Switch to Office"].waitForNonExistence(timeout: 10))
    }

    @MainActor func testProfileTimeoutAfterBackgroundAndRelaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        app.buttons["profilesButton"].tap()
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        let enabled = app.switches["returnEnabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 5))
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let minutes = app.textFields["returnMinutes"]
        if !minutes.waitForExistence(timeout: 5) { print(app.debugDescription) }
        XCTAssertTrue(minutes.exists)
        minutes.tap()
        minutes.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "1")
        app.buttons["saveReturnPolicy"].tap()
        capture(app, name: "phone-profile-timeout")
        app.buttons["Switch to Work"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["profilesButton"].label, "Profiles, Work")
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["profilesButton"].label, "Profiles, Work")
        XCUIDevice.shared.press(.home)
        // Exercise the real persisted wall clock and lifecycle without a production debug override.
        Thread.sleep(forTimeInterval: 61)
        app.activate()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["profilesButton"].label, "Profiles, Personal")
    }

    @MainActor func testDeletingActiveProfileWithLivePage() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        app.buttons["profilesButton"].tap()
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        app.buttons["Switch to Personal"].swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["profilesButton"].label, "Profiles, Work")
        app.buttons["profilesButton"].tap()
        XCTAssertTrue(app.buttons["Switch to Work"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Retry deleting Personal"].exists)
        XCTAssertFalse(app.alerts["Harbor"].exists)
    }

    @MainActor func testProfileReturnSettingsValidation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        app.buttons["profilesButton"].tap()
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        app.switches["returnEnabled"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let minutes = app.textFields["returnMinutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        minutes.tap()
        minutes.typeText(XCUIKeyboardKey.delete.rawValue + XCUIKeyboardKey.delete.rawValue + "0")
        XCTAssertFalse(app.buttons["saveReturnPolicy"].isEnabled)
        minutes.typeText(XCUIKeyboardKey.delete.rawValue + "5")
        XCTAssertTrue(app.buttons["saveReturnPolicy"].isEnabled)
        capture(app, name: "phone-profile-return-editor")
        app.buttons["saveReturnPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profile-timeout")
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.textFields["returnMinutes"].value as? String, "5")
        app.switches["returnEnabled"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        app.buttons["saveReturnPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.switches["returnEnabled"].value as? String, "0")
    }

    @MainActor func testProfilesDarkLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launch()
        XCTAssertTrue(app.buttons["profilesButton"].waitForExistence(timeout: 10))
        app.buttons["profilesButton"].tap()
        XCTAssertTrue(app.buttons["newProfile"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profiles-dark-large")
        app.buttons["newProfile"].tap()
        XCTAssertTrue(app.textFields["profileName"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profile-editor-dark-large")
    }

    @MainActor private func revealAboveChrome(_ element: XCUIElement, in app: XCUIApplication) {
        // Scrolling can replace the expanded address field with the floating URL pill.
        func controlsTop() -> CGFloat {
            let pill = app.buttons["expandBrowserControls"]
            return pill.exists ? pill.frame.minY : app.textFields["addressField"].frame.minY
        }
        for _ in 0..<4 {
            if element.frame.maxY < controlsTop() - 8 { break }
            app.webViews.firstMatch.swipeUp()
        }
        XCTAssertLessThan(element.frame.maxY, controlsTop(),
                          "Page controls must scroll above the browser chrome")
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
