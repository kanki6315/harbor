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
            if profiles.isLocked {
                LockedProfileView(profiles: profiles)
            } else if let browser = profiles.browser {
                BrowserView(browser: browser, profiles: profiles).id(browser.profileID)
                    .overlay {
                        if scenePhase != .active && profiles.currentProfile?.isProtected == true {
                            Color(uiColor: .systemBackground).ignoresSafeArea()
                                .overlay { Image(systemName: "lock.fill").font(.largeTitle) }
                        }
                    }
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
