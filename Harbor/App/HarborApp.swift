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
                // The switcher preview follows the profile's unlocked session.
                if profiles.isLocked {
                    LockedProfileView(profiles: profiles)
                } else if let browser = profiles.browser {
                    BrowserView(browser: browser, profiles: profiles).id(browser.profileID)
                } else {
                    ContentUnavailableView("Could not open profiles", systemImage: "exclamationmark.triangle",
                                           description: Text(profiles.errorMessage ?? "Please reopen Harbor to try again."))
                }
            }
            .background(ProfilePrivacyCover(enabled: profiles.shouldHideAppSwitcherPreview,
                                            activationRevision: profiles.activationRevision))
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

/// A separate, non-key window covers sheets and native full-screen content too.
/// UIKit's scene notification arrives before the system takes its switcher snapshot.
struct ProfilePrivacyCover: UIViewRepresentable {
    var enabled: Bool
    var activationRevision: UInt

    func makeUIView(context: Context) -> HostView { HostView() }
    func updateUIView(_ view: HostView, context: Context) {
        view.enabled = enabled
        view.activationRevision = activationRevision
        view.refresh()
    }
    static func dismantleUIView(_ view: HostView, coordinator: ()) { view.removeCover() }

    final class HostView: UIView {
        var enabled = false
        var activationRevision: UInt = 0
        private var coveredAtRevision: UInt?
        private var cover: UIWindow?
        private var observers: [NSObjectProtocol] = []

        override init(frame: CGRect) {
            super.init(frame: frame)
            observers = [
                NotificationCenter.default.addObserver(forName: UIScene.willDeactivateNotification, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        guard let self, let scene = note.object as? UIWindowScene, scene === self.window?.windowScene else { return }
                        self.refresh(inactive: true)
                    }
                },
                NotificationCenter.default.addObserver(forName: UIScene.didActivateNotification, object: nil, queue: .main) { [weak self] note in
                    MainActor.assumeIsolated {
                        guard let self, let scene = note.object as? UIWindowScene, scene === self.window?.windowScene else { return }
                        // UIKit activation alone cannot uncover private content. A rendered
                        // activationRevision from becameActive() must authorize it too.
                        self.refresh()
                    }
                }
            ]
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        isolated deinit { observers.forEach(NotificationCenter.default.removeObserver) }
        override func didMoveToWindow() { super.didMoveToWindow(); refresh() }

        func refresh(inactive: Bool? = nil) {
            guard enabled, let scene = window?.windowScene else { removeCover(); return }
            let inactive = inactive ?? (scene.activationState != .foregroundActive)
            if inactive && coveredAtRevision == nil { coveredAtRevision = activationRevision }
            guard inactive || coveredAtRevision == activationRevision else { removeCover(); return }
            guard cover == nil else { return }
            let controller = UIViewController()
            controller.view.backgroundColor = .systemBackground
            let label = UILabel()
            label.text = "Harbor"
            label.font = .preferredFont(forTextStyle: .title1)
            label.textAlignment = .center
            label.frame = scene.effectiveGeometry.coordinateSpace.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            controller.view.addSubview(label)
            let shield = UIWindow(windowScene: scene)
            shield.frame = scene.effectiveGeometry.coordinateSpace.bounds
            shield.windowLevel = .alert + 1
            shield.rootViewController = controller
            shield.accessibilityIdentifier = "profilePrivacyCover"
            shield.isHidden = false
            cover = shield
        }

        func removeCover() {
            coveredAtRevision = nil
            cover?.isHidden = true
            cover = nil
        }
    }
}
