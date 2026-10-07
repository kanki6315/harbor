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
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background: profiles.enteredBackground()
            case .active: profiles.becameActive()
            default: profiles.browser?.saveNow()
            }
        }
    }
}
