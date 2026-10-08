// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import CoreText

@main
struct HarborApp: App {
    init() {
        if let font = Bundle.main.url(forResource: "InterVariable", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        }
    }
    @State private var profiles = ProfileManager()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            Group {
                // Use the actual lock state for both browsing and presented sheets.
                // An inactive scene (such as the app switcher) can still be unlocked.
                if profiles.isLocked {
                    LockedProfileView(profiles: profiles)
                } else if let browser = profiles.browser {
                    BrowserView(browser: browser, profiles: profiles).id(browser.profileID)
                } else {
                    ContentUnavailableView("Could not open profiles", systemImage: "exclamationmark.triangle",
                                           description: Text(profiles.errorMessage ?? "Please reopen Harbor to try again."))
                }
            }
            .onOpenURL { profiles.openIncomingURL($0) }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: profiles.enteredBackground()
            case .active: profiles.becameActive()
            default: profiles.browser?.saveNow()
            }
        }
    }
}
