// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import XCTest

final class HarborUITests: XCTestCase {
    @MainActor func testTabGroupLifecycle() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "-AppleInterfaceStyle", "Light"]
        app.launch()
        XCTAssertTrue(app.buttons["tabsButton"].waitForExistence(timeout: 10))
        app.buttons["tabsButton"].tap()
        app.buttons["newTabGroup"].tap()
        app.textFields["tabGroupName"].tap()
        app.textFields["tabGroupName"].typeText("Research")
        app.buttons["saveTabGroup"].tap()
        XCTAssertTrue(app.staticTexts["No tabs in this group"].waitForExistence(timeout: 5))
        capture(app, name: "phone-group-empty")
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["Research"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["1 in this group · 2 total"].exists)
        capture(app, name: "phone-group")
        app.buttons["allTabsBreadcrumb"].tap()
        let groupCards = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupCard-"))
        XCTAssertEqual(groupCards.count, 1)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupOptions-")).count, 1)
        capture(app, name: "phone-group-card")
        groupCards.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Research"].waitForExistence(timeout: 5))
        app.buttons["allTabsBreadcrumb"].tap()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupOptions-")).firstMatch.tap()
        app.buttons["Move to group"].tap()
        app.buttons["Research"].tap()
        groupCards.firstMatch.tap()
        XCTAssertTrue(app.staticTexts["2 in this group · 2 total"].exists)
        app.buttons["selectedGroupOptions"].tap()
        capture(app, name: "phone-group-menu")
        app.buttons["Rename group"].tap()
        let name = app.textFields["tabGroupName"]
        name.tap()
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8) + "Reading")
        app.buttons["saveTabGroup"].tap()
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["Reading"].waitForExistence(timeout: 5))
        app.buttons["selectedGroupOptions"].tap()
        app.buttons["Delete group"].tap()
        app.buttons["Delete group, keep tabs"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
    }

    @MainActor func testTabGroupsDarkLargeText() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "-AppleInterfaceStyle", "Dark"]
        app.launch()
        XCTAssertTrue(app.buttons["tabsButton"].waitForExistence(timeout: 10))
        app.buttons["tabsButton"].tap()
        app.buttons["newTabGroup"].tap()
        app.textFields["tabGroupName"].tap()
        app.textFields["tabGroupName"].typeText("Weekend reading")
        app.buttons["saveTabGroup"].tap()
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["Weekend reading"].waitForExistence(timeout: 5))
        capture(app, name: "phone-group-dark-large")
        XCTAssertFalse(app.buttons["tabGroupSelector"].exists)
        app.buttons["allTabsBreadcrumb"].tap()
        capture(app, name: "phone-group-preview-dark-large")
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupCard-")).firstMatch.tap()
        let options = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupOptions-")).firstMatch
        options.tap()
        XCTAssertTrue(app.buttons["Remove from group"].waitForExistence(timeout: 5))
        app.buttons["Remove from group"].tap()
        XCTAssertTrue(app.staticTexts["No tabs in this group"].waitForExistence(timeout: 5))
        capture(app, name: "phone-group-empty-dark-large")
        app.buttons["allTabsBreadcrumb"].tap()
        let groupCard = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "tabGroupCard-")).firstMatch
        XCTAssertTrue(groupCard.exists)
        capture(app, name: "phone-group-card-dark-large")
        groupCard.tap()
        XCTAssertTrue(app.navigationBars["Weekend reading"].waitForExistence(timeout: 5))
    }

    @MainActor func testLockDelaySetting() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--locked-profile-fixture"]
        app.launch()
        app.buttons["Switch profile"].tap()
        app.buttons["Edit Personal"].tap()
        XCTAssertTrue(app.buttons["lockAfterPicker"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["30 minutes"].exists)
        app.buttons["lockAfterPicker"].tap()
        XCTAssertTrue(app.buttons["Immediately"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["1 hour"].exists)
    }

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

    @MainActor func testUnifiedMenuOnStartPage() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        let profile = app.buttons["addressProfileButton"]
        XCTAssertTrue(profile.waitForExistence(timeout: 10))
        XCTAssertEqual(profile.label, "Profiles, Personal")
        capture(app, name: "address-profile")
        profile.tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        let menu = app.descendants(matching: .any)["browserMenuButton"]
        XCTAssertTrue(menu.waitForExistence(timeout: 10))
        menu.tap()
        let bookmarks = app.descendants(matching: .any).matching(identifier: "Bookmarks").firstMatch
        XCTAssertTrue(bookmarks.waitForExistence(timeout: 5))
        capture(app, name: "unified-start-menu")
        bookmarks.tap()
        XCTAssertTrue(app.navigationBars["Bookmarks"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        openBrowserDestination(app, "settingsButton")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    @MainActor func testWebsiteDialogsCanBeAnsweredRepeatedly() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        let alertButton = app.webViews.buttons["Show alert"]
        XCTAssertTrue(alertButton.waitForExistence(timeout: 15))
        app.webViews.firstMatch.swipeUp()
        for _ in 0..<2 {
            alertButton.tap()
            XCTAssertTrue(app.staticTexts["Native dialog works"].waitForExistence(timeout: 5))
            app.buttons["OK"].tap()
            XCTAssertTrue(alertButton.waitForExistence(timeout: 5))
        }
        if app.buttons["expandBrowserControls"].exists { app.buttons["expandBrowserControls"].tap() }
        openBrowserDestination(app, "settingsButton")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        alertButton.tap()
        XCTAssertTrue(app.staticTexts["Native dialog works"].waitForExistence(timeout: 5))
        app.buttons["OK"].tap()
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
        let menu = app.descendants(matching: .any)["browserMenuButton"]
        XCTAssertTrue(menu.isHittable)
        XCTAssertEqual(menu.frame.midY, app.textFields["addressField"].frame.midY, accuracy: 2)
        XCTAssertEqual(menu.frame.midY, app.buttons["tabsButton"].frame.midY, accuracy: 2)
        capture(app, name: darkLarge ? "controls-dark-large" : "controls-light")
        menu.tap()
        XCTAssertTrue(app.staticTexts["Bookmarks"].waitForExistence(timeout: 5) || menuDestination(app, "bookmarksButton").exists)
        capture(app, name: "controls-menu")
        openBrowserDestination(app, "bookmarksButton")
        let bookmark = app.buttons["bookmarkCurrentPage"]
        XCTAssertTrue(bookmark.waitForExistence(timeout: 5))
        XCTAssertEqual(bookmark.label, "Bookmark this page")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Remove bookmark for this page")
        capture(app, name: darkLarge ? "bookmarks-dark-large" : "bookmarks-light")
        app.buttons["Done"].tap()
        openBrowserDestination(app, "bookmarksButton")
        XCTAssertEqual(bookmark.label, "Remove bookmark for this page")
        bookmark.tap()
        XCTAssertEqual(bookmark.label, "Bookmark this page")
        app.buttons["Done"].tap()
        openBrowserDestination(app, "historyButton")
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        openBrowserDestination(app, "settingsButton")
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Profiles"].exists)
        app.buttons["Done"].tap()
        openBrowserDestination(app, "sharePageButton")
        XCTAssertTrue(app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 15))
        capture(app, name: "direct-share-sheet")
        app.buttons["header.closeButton"].tap()
    }

    @MainActor func testRenameBookmark() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        openBrowserDestination(app, "bookmarksButton")
        app.buttons["bookmarkCurrentPage"].tap()
        let savedPage = app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Local page")).firstMatch
        XCTAssertTrue(savedPage.waitForExistence(timeout: 5))
        savedPage.press(forDuration: 1)
        app.buttons["Rename"].tap()
        let name = app.textFields["bookmarkRenameName"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        let oldName = name.value as? String ?? ""
        name.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: oldName.count) + "My saved page")
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My saved page")).firstMatch.waitForExistence(timeout: 5))
        capture(app, name: "bookmark-renamed")
        app.buttons["Done"].tap()
        openBrowserDestination(app, "bookmarksButton")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "My saved page")).firstMatch.exists)
    }

    @MainActor func testBookmarkNameSuggestions() {
        checkBookmarkNameSuggestions(largeText: false)
    }

    @MainActor func testBookmarkNameSuggestionsLargeText() {
        checkBookmarkNameSuggestions(largeText: true)
    }

    @MainActor private func checkBookmarkNameSuggestions(largeText: Bool) {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture", "--bookmark-name-fixture"]
        if largeText {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityM"]
        }
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        openBrowserDestination(app, "bookmarksButton")
        app.buttons["bookmarkCurrentPage"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["bookmarkNameLoading"].firstMatch.waitForExistence(timeout: 2))
        capture(app, name: "bookmark-name-loading")
        XCTAssertTrue(app.buttons["useBookmarkName"].waitForExistence(timeout: 8))
        capture(app, name: "bookmark-name-choice")
        let original = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Harbor test page")).firstMatch
        XCTAssertTrue(original.exists)
        app.buttons["keepBookmarkName"].tap()
        XCTAssertTrue(original.exists)
        original.press(forDuration: 1)
        app.buttons["Rename"].tap()
        app.buttons["suggestBookmarkNickname"].tap()
        XCTAssertTrue(app.buttons["useBookmarkNameDraft"].waitForExistence(timeout: 8))
        capture(app, name: "bookmark-rename-suggestion")
        app.buttons["useBookmarkNameDraft"].tap()
        XCTAssertEqual(app.textFields["bookmarkRenameName"].value as? String, "Harbor fixture guide")
        app.buttons["Cancel"].tap()
        XCTAssertTrue(original.waitForExistence(timeout: 5), "Cancelling must keep the original name")
        original.press(forDuration: 1)
        app.buttons["Rename"].tap()
        app.buttons["suggestBookmarkNickname"].tap()
        XCTAssertTrue(app.buttons["useBookmarkNameDraft"].waitForExistence(timeout: 8))
        app.buttons["useBookmarkNameDraft"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Harbor fixture guide")).firstMatch.waitForExistence(timeout: 5))
    }

    @MainActor func testBookmarkFolders() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        openBrowserDestination(app, "bookmarksButton")
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
        openBrowserDestination(app, "historyButton")
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
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "historyButton").waitForExistence(timeout: 15))
        openBrowserDestination(app, "historyButton")
        XCTAssertTrue(app.navigationBars["History"].waitForExistence(timeout: 5))
        return app
    }

    @MainActor func testTabGridDragReordersInBothDirections() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        app.buttons["tabsButton"].tap()
        app.buttons["tabSwitcherNewTab"].tap()
        app.buttons["tabsButton"].tap()
        let page = app.buttons["Open Harbor test page"]
        let newTab = app.buttons["Open New Tab"]
        XCTAssertTrue(page.waitForExistence(timeout: 5) && newTab.exists)
        func assertFirstTab(_ title: String) {
            app.buttons["reorderTabs"].tap()
            XCTAssertTrue(app.navigationBars["Reorder tabs"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.cells.element(boundBy: 0).staticTexts[title].exists)
            app.navigationBars["Reorder tabs"].buttons["Done"].tap()
        }
        assertFirstTab("Harbor test page")
        // Releasing outside the grid must restore the source and allow another drag.
        page.press(forDuration: 0.8, thenDragTo: app.navigationBars.staticTexts["2 tabs"])
        XCTAssertTrue(page.isHittable)
        assertFirstTab("Harbor test page")
        page.press(forDuration: 0.8, thenDragTo: newTab)
        assertFirstTab("New Tab")
        capture(app, name: "phone-tabs-grid-drag-forward")
        page.press(forDuration: 0.8, thenDragTo: newTab)
        assertFirstTab("Harbor test page")
        page.press(forDuration: 0.8, thenDragTo: newTab)
        assertFirstTab("New Tab")
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(newTab.waitForExistence(timeout: 5))
        assertFirstTab("New Tab")
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
        XCTAssertTrue(app.staticTexts["Unloaded. Opens again when selected."].exists,
                      "Reordering must keep the background page unloaded")
        app.buttons["Open Harbor test page"].tap()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15),
                      "Selecting an unloaded tab must reopen its page")
        app.buttons["tabsButton"].tap()
        XCTAssertFalse(app.staticTexts["Unloaded. Opens again when selected."].exists)
        app.buttons["Done"].tap()
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        // The bundled file URL is usable during this session, but only HTTP(S)
        // addresses are restorable. Its tab becomes a start page after relaunch.
        XCTAssertEqual(app.buttons.matching(identifier: "Open New Tab").count, 2)
        XCTAssertFalse(app.buttons["Open Harbor test page"].exists)
        XCTAssertFalse(app.staticTexts["Unloaded. Opens again when selected."].exists)
        capture(app, name: "phone-tabs-local-page-reset")
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
        openBrowserDestination(app, "settingsButton")
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
        XCTAssertEqual(web.frame.minY, app.frame.minY, accuracy: 1,
                       "The website viewport must extend beneath the status bar")
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
        XCTAssertEqual(web.frame.minY, app.frame.minY, accuracy: 1,
                       "The website viewport must extend beneath the status bar")
        app.webViews.firstMatch.swipeUp()
        let reveal = app.buttons["expandBrowserControls"]
        XCTAssertTrue(reveal.waitForExistence(timeout: 5))
        XCTAssertFalse(app.textFields["addressField"].exists)
        XCTAssertEqual(web.frame.height, expandedHeight, accuracy: 1, "Floating controls must not resize the website")
        XCTAssertEqual(web.frame.minY, app.frame.minY, accuracy: 1,
                       "Collapsing controls must keep the website at the screen's top edge")
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
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        openBrowserDestination(app, "New tab")
        // Leaving address editing exposes the profile control too.
        openBrowserDestination(app, "profilesButton")
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        XCTAssertTrue(app.buttons["Switch to Work"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profiles")
        app.buttons["Switch to Work"].tap()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 5))
        XCTAssertEqual(menuDestination(app, "profilesButton").label, "Profiles, Work")
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["1 tab"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        openBrowserDestination(app, "settingsButton")
        let tracker = app.switches["Tracker blocking"]
        XCTAssertTrue(tracker.waitForExistence(timeout: 5))
        tracker.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        XCTAssertEqual(tracker.value as? String, "0")
        app.buttons["Done"].tap()
        openBrowserDestination(app, "profilesButton")
        app.buttons["Switch to Personal"].tap()
        app.buttons["tabsButton"].tap()
        XCTAssertTrue(app.navigationBars["2 tabs"].waitForExistence(timeout: 5))
        app.buttons["Done"].tap()
        openBrowserDestination(app, "settingsButton")
        XCTAssertEqual(app.switches["Tracker blocking"].value as? String, "1")
        app.buttons["Done"].tap()
        openBrowserDestination(app, "profilesButton")
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
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        openBrowserDestination(app, "profilesButton")
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        let enabled = app.switches["returnEnabled"]
        XCTAssertTrue(enabled.waitForExistence(timeout: 5))
        enabled.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let minutes = app.sliders["returnMinutes"]
        if !minutes.waitForExistence(timeout: 5) { print(app.debugDescription) }
        XCTAssertTrue(minutes.exists)
        minutes.adjust(toNormalizedSliderPosition: 0)
        app.buttons["saveReturnPolicy"].tap()
        capture(app, name: "phone-profile-timeout")
        app.buttons["Switch to Work"].tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 5))
        XCTAssertEqual(menuDestination(app, "profilesButton").label, "Profiles, Work")
        XCUIDevice.shared.press(.home)
        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        XCTAssertEqual(menuDestination(app, "profilesButton").label, "Profiles, Work")
        XCUIDevice.shared.press(.home)
        // Exercise the real persisted wall clock and lifecycle without a production debug override.
        Thread.sleep(forTimeInterval: 301)
        app.activate()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        XCTAssertEqual(menuDestination(app, "profilesButton").label, "Profiles, Personal")
    }

    @MainActor func testDeletingActiveProfileWithLivePage() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset", "--fixture"]
        app.launch()
        XCTAssertTrue(app.webViews.staticTexts["Harbor test page"].waitForExistence(timeout: 15))
        openBrowserDestination(app, "profilesButton")
        app.buttons["newProfile"].tap()
        app.textFields["profileName"].tap()
        app.textFields["profileName"].typeText("Work")
        app.buttons["saveProfile"].tap()
        app.buttons["Switch to Personal"].swipeLeft()
        app.buttons["Delete"].tap()
        app.buttons["Delete profile"].tap()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        XCTAssertEqual(menuDestination(app, "profilesButton").label, "Profiles, Work")
        openBrowserDestination(app, "profilesButton")
        XCTAssertTrue(app.buttons["Switch to Work"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Retry deleting Personal"].exists)
        XCTAssertFalse(app.alerts["Harbor"].exists)
    }

    @MainActor func testProfileReturnSettingsValidation() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset"]
        app.launch()
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        openBrowserDestination(app, "profilesButton")
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        app.switches["returnEnabled"].coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.5)).tap()
        let minutes = app.sliders["returnMinutes"]
        XCTAssertTrue(minutes.waitForExistence(timeout: 5))
        minutes.adjust(toNormalizedSliderPosition: 1)
        XCTAssertEqual(minutes.value as? String, "24 hours")
        minutes.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(minutes.value as? String, "5 minutes")
        XCTAssertTrue(app.buttons["saveReturnPolicy"].isEnabled)
        capture(app, name: "phone-profile-return-editor")
        app.buttons["saveReturnPolicy"].tap()
        XCTAssertTrue(app.navigationBars["Profiles"].waitForExistence(timeout: 5))
        capture(app, name: "phone-profile-timeout")
        app.buttons["returnAfter"].tap()
        XCTAssertTrue(app.navigationBars["Return after"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sliders["returnMinutes"].value as? String, "5 minutes")
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
        revealBrowserMenu(app)
        XCTAssertTrue(menuDestination(app, "profilesButton").waitForExistence(timeout: 10))
        openBrowserDestination(app, "profilesButton")
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

    @MainActor private func menuDestination(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        let labels = ["bookmarksButton": "Bookmarks", "historyButton": "History",
                      "settingsButton": "Settings", "sharePageButton": "Share page"]
        let direct = app.descendants(matching: .any).matching(identifier: identifier).firstMatch
        if direct.exists { return direct }
        if identifier == "profilesButton" {
            return app.descendants(matching: .any).matching(NSPredicate(format: "label BEGINSWITH %@", "Profiles, ")).firstMatch
        }
        return app.descendants(matching: .any).matching(identifier: labels[identifier] ?? identifier).firstMatch
    }

    @MainActor private func revealBrowserMenu(_ app: XCUIApplication) {
        if !menuDestination(app, "settingsButton").exists {
            app.descendants(matching: .any)["browserMenuButton"].tap()
        }
    }

    @MainActor private func openBrowserDestination(_ app: XCUIApplication, _ identifier: String) {
        if !menuDestination(app, identifier).exists { revealBrowserMenu(app) }
        // Native menus scroll at accessibility text sizes and only expose nearby rows.
        let menuItems = app.collectionViews.firstMatch
        for _ in 0..<5 {
            let item = menuDestination(app, identifier)
            if item.exists && item.isHittable { break }
            guard menuItems.exists else { break }
            let visibleFrame = menuItems.frame.intersection(app.frame)
            let origin = app.coordinate(withNormalizedOffset: .zero)
            origin.withOffset(CGVector(dx: visibleFrame.midX, dy: visibleFrame.minY + visibleFrame.height * 0.7))
                .press(forDuration: 0.05, thenDragTo: origin.withOffset(
                    CGVector(dx: visibleFrame.midX, dy: visibleFrame.minY + visibleFrame.height * 0.25)))
        }
        let destination = menuDestination(app, identifier)
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
    }

    @MainActor private func capture(_ app: XCUIApplication, name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

}
