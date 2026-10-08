// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WebKit

struct BrowserView: View {
    @Bindable var browser: BrowserModel
    @Bindable var profiles: ProfileManager
    @State private var address = ""
    @State private var chromeCollapsed = false
    @State private var chromeHeight: CGFloat = 56
    @Namespace private var chromeNamespace
    @FocusState private var editingAddress: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geometry in content(in: geometry) }
    }

    private func content(in geometry: GeometryProxy) -> some View {
        ZStack {
            Color(uiColor: .systemBackground)
            // Resident views stay attached to preserve WebKit's media and native full-screen UI.
            ForEach(browser.archive.tabs) { tab in
                if let session = browser.sessions[tab.id] {
                    WebView(webView: session.webView,
                            contentInsets: UIEdgeInsets(
                                top: browser.activeSession?.fullscreen == true ? 0 : geometry.safeAreaInsets.top,
                                left: 0,
                                bottom: browser.activeSession?.fullscreen == true ? 0 : chromeHeight + geometry.safeAreaInsets.bottom,
                                right: 0),
                            onScrollDown: {
                                guard tab.id == browser.selectedID, !editingAddress,
                                      browser.activeSession?.fullscreen != true else { return }
                                setChromeCollapsed(true)
                            })
                        // Extend the viewport under the status bar; the scroll inset keeps
                        // the first page controls clear while allowing content to scroll behind it.
                        .ignoresSafeArea(.container, edges: .vertical)
                        .opacity(tab.id == browser.selectedID ? 1 : 0)
                        .allowsHitTesting(tab.id == browser.selectedID)
                        .accessibilityHidden(tab.id != browser.selectedID)
                }
            }
            if browser.selectedTab.url == nil {
                StartPage(browser: browser, focusAddress: { editingAddress = true }, showPrivacy: { browser.sheet = .privacy })
            } else if let error = browser.activeSession?.loadError {
                ContentUnavailableView {
                    Label("This page couldn’t load", systemImage: "wifi.exclamationmark")
                } description: { Text(error) } actions: {
                    Button("Reload page") { browser.reload() }.buttonStyle(.borderedProminent)
                }.background(Color(uiColor: .systemBackground))
            } else if browser.blocker.ready && browser.activeSession == nil {
                ContentUnavailableView {
                    Label("Page paused", systemImage: "pause.circle")
                } description: { Text("Reload to reconnect after clearing website data.") } actions: {
                    Button("Reload page") { browser.reload() }.buttonStyle(.borderedProminent)
                }
            } else if !browser.blocker.ready {
                ProgressView("Preparing browser…")
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if browser.activeSession?.fullscreen != true {
                chrome(bottomInset: geometry.safeAreaInsets.bottom).onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chromeHeight = $0 }
            }
        }
        .onChange(of: browser.selectedID) { _, _ in editingAddress = false; chromeCollapsed = false; syncAddress() }
        .onChange(of: browser.selectedTab.url) { _, _ in if !editingAddress { syncAddress() } }
        .onChange(of: editingAddress) { _, value in if value { chromeCollapsed = false }; syncAddress() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { browser.saveNow() }
            else { Task { await browser.refreshMedia() } }
        }
        .onAppear { syncAddress() }
        .sheet(item: $browser.sheet) { destination in
            switch destination {
            case .tabs: TabSwitcherView(browser: browser)
            case .history: HistoryView(browser: browser)
            case .bookmarks: BookmarksView(browser: browser)
            case .settings: SettingsView(browser: browser, profiles: profiles)
            case .profiles: ProfilesView(profiles: profiles)
            case .privacy: PrivacyView(browser: browser)
            case .share(let item): ShareSheet(url: item.url)
            case .webDialog(let dialog): WebDialogView(dialog: dialog)
            }
        }
        .onChange(of: browser.downloads.completed?.id) { _, _ in
            // Downloads are offered in the menu if a browser sheet is already open.
            if browser.sheet == nil, let item = browser.downloads.completed { browser.sheet = .share(item) }
        }
        .alert("Open another app?", isPresented: Binding(get: { browser.externalURL != nil }, set: { if !$0 { browser.externalURL = nil } })) {
            Button("Cancel", role: .cancel) { browser.externalURL = nil }
            Button("Open") {
                if let url = browser.externalURL {
                    UIApplication.shared.open(url) { success in
                        if !success { browser.errorMessage = "No installed app can open this link." }
                    }
                }
                browser.externalURL = nil
            }
        } message: { Text(browser.externalURL?.absoluteString ?? "") }
        .alert("Harbor", isPresented: Binding(get: { browser.errorMessage != nil || browser.downloads.errorMessage != nil || profiles.errorMessage != nil }, set: { if !$0 { browser.errorMessage = nil; browser.downloads.errorMessage = nil; profiles.errorMessage = nil } })) {
            Button("OK", role: .cancel) { browser.errorMessage = nil; browser.downloads.errorMessage = nil; profiles.errorMessage = nil }
        } message: { Text(browser.errorMessage ?? browser.downloads.errorMessage ?? profiles.errorMessage ?? "") }
    }

    private func chrome(bottomInset: CGFloat) -> some View {
        GlassEffectContainer(spacing: 8) {
            Group {
                if chromeCollapsed && !editingAddress {
                    Button { setChromeCollapsed(false) } label: {
                        Text(compactAddress)
                            .font(.caption2.weight(.medium))
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .lineLimit(1).truncationMode(.middle)
                            .padding(.horizontal, 10).padding(.vertical, 3)
                            .frame(maxWidth: typeSize.isAccessibilitySize ? 180 : 112)
                            .modifier(BrowserAddressGlass(namespace: chromeNamespace, reduceMotion: reduceMotion))
                            .frame(minHeight: 44, alignment: .bottom)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show browser controls for \(compactAddress), \(browser.profileName) profile")
                    .accessibilityIdentifier("expandBrowserControls")
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)
                } else {
                    HStack(spacing: 6) {
                        if !editingAddress {
                            Button { browser.activeSession?.webView.goBack() } label: {
                                chromeIcon("chevron.left")
                            }
                            .disabled(browser.activeSession?.canGoBack != true)
                            .accessibilityLabel("Back")
                            .harborGlass()
                            .transition(controlTransition)
                        }
                        addressControl
                        if !editingAddress {
                            Button { browser.activeSession?.captureSnapshot(); browser.sheet = .tabs } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(lineWidth: 1.8)
                                    Text("\(browser.archive.tabs.count)")
                                        .font(.caption2.bold()).monospacedDigit()
                                        .lineLimit(1).minimumScaleFactor(0.5)
                                        .padding(.horizontal, 3)
                                }.frame(width: 24, height: 24)
                                    .frame(width: 44, height: 48)
                            }
                            .accessibilityLabel("Tabs, \(browser.archive.tabs.count) open")
                            .accessibilityIdentifier("tabsButton")
                            .harborGlass()
                            .transition(controlTransition)
                            browserMenu
                                .transition(controlTransition)
                        }
                    }
                }
            }
            .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 12)
            .padding(.top, chromeCollapsed ? 0 : 4)
            .padding(.bottom, chromeCollapsed ? -min(12, max(0, bottomInset - 20)) : 4)
        }
        .animation(reduceMotion ? .easeOut(duration: 0.12) : .spring(response: 0.38, dampingFraction: 0.86), value: editingAddress)
    }

    private var controlTransition: AnyTransition {
        reduceMotion ? .opacity : .scale(scale: 0.7, anchor: .bottom).combined(with: .opacity)
    }

    private func chromeIcon(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
            .frame(width: 44, height: 48)
    }

    private var addressControl: some View {
        HStack(spacing: 0) {
            if !typeSize.isAccessibilitySize && !editingAddress {
                Button { browser.sheet = .privacy } label: { chromeIcon("shield.lefthalf.filled") }
                    .accessibilityLabel(browser.protectionStatus)
            }
            TextField("Address", text: $address,
                      prompt: Text("Search or address").foregroundStyle(Color.primary.opacity(0.72)))
                .font(.subheadline)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .keyboardType(.webSearch).submitLabel(.go)
                .focused($editingAddress).onSubmit(submit)
                .accessibilityLabel("Search or enter address")
                .accessibilityIdentifier("addressField")
                .frame(minWidth: 30, minHeight: 48)
                .padding(.leading, editingAddress || typeSize.isAccessibilitySize ? 14 : 0)
            if editingAddress {
                Button(action: submit) { chromeIcon("arrow.right.circle.fill") }
                    .accessibilityLabel("Go")
            } else if browser.selectedTab.url != nil && !typeSize.isAccessibilitySize {
                Button(action: reloadOrStop) {
                    chromeIcon(browser.activeSession?.isLoading == true ? "xmark" : "arrow.clockwise")
                }.accessibilityLabel(browser.activeSession?.isLoading == true ? "Stop loading" : "Reload")
            }
        }
        .modifier(BrowserAddressGlass(namespace: chromeNamespace, reduceMotion: reduceMotion))
        .overlay(alignment: .bottom) {
            if browser.activeSession?.isLoading == true {
                ProgressView(value: browser.activeSession?.progress ?? 0)
                    .tint(.harborBlue).padding(.horizontal, 20)
                    .accessibilityLabel("Page loading")
            }
        }
        .transition(.opacity)
    }

    private var browserMenu: some View {
        Menu {
            Section {
                if let url = browser.selectedTab.url {
                    Button("Share page", systemImage: "square.and.arrow.up") { browser.sheet = .share(ShareItem(url: url)) }
                        .accessibilityIdentifier("sharePageButton")
                }
                Button("Bookmarks", systemImage: "book") { browser.sheet = .bookmarks }
                    .accessibilityIdentifier("bookmarksButton")
                Button("History", systemImage: "clock") { browser.sheet = .history }
                    .accessibilityIdentifier("historyButton")
            }
            Section {
                Button("New tab", systemImage: "plus") { browser.newTab(); editingAddress = true }
                Button("Forward", systemImage: "chevron.right") { browser.activeSession?.webView.goForward() }
                    .disabled(browser.activeSession?.canGoForward != true)
                Button(browser.activeSession?.isLoading == true ? "Stop loading" : "Reload",
                       systemImage: browser.activeSession?.isLoading == true ? "xmark" : "arrow.clockwise",
                       action: reloadOrStop)
                    .disabled(browser.selectedTab.url == nil)
            }
            Section {
                Button("Site protection", systemImage: "shield.lefthalf.filled") { browser.sheet = .privacy }
                Button("Profiles, \(browser.profileName)", systemImage: profiles.currentProfile?.symbol ?? "person.crop.circle") { browser.sheet = .profiles }
                    .accessibilityIdentifier("profilesButton")
                Button("Settings", systemImage: "gearshape") { browser.sheet = .settings }
                    .accessibilityIdentifier("settingsButton")
            }
            if browser.activeSession?.mediaState == .playing || browser.downloads.completed != nil || browser.downloads.activeCount > 0 {
                Section {
                    if browser.activeSession?.mediaState == .playing {
                        Button("Pause media", systemImage: "pause.fill") { browser.activeSession?.webView.pauseAllMediaPlayback(completionHandler: nil) }
                    }
                    if let download = browser.downloads.completed {
                        Button("Save or share download", systemImage: "arrow.down.doc") { browser.sheet = .share(download) }
                    }
                    if browser.downloads.activeCount > 0 { Text("Downloading \(browser.downloads.activeCount) file(s)…") }
                }
            }
        } label: { chromeIcon("ellipsis") }
            .menuOrder(.fixed)
            .harborGlass()
            .accessibilityLabel("Browser menu")
            .accessibilityIdentifier("browserMenuButton")
    }

    private func reloadOrStop() {
        if browser.activeSession?.isLoading == true { browser.activeSession?.webView.stopLoading() }
        else { browser.reload() }
    }

    private func setChromeCollapsed(_ collapsed: Bool) {
        guard chromeCollapsed != collapsed else { return }
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.12) :
            .spring(response: collapsed ? 0.34 : 0.42, dampingFraction: 0.86)
        withAnimation(animation) { chromeCollapsed = collapsed }
    }

    private var compactAddress: String {
        guard let url = browser.selectedTab.url else { return "Search or enter address" }
        return url.host ?? (url.isFileURL ? "Local page" : url.absoluteString)
    }

    private func submit() { browser.navigate(address); editingAddress = false; syncAddress() }
    private func syncAddress() { address = editingAddress ? (browser.selectedTab.url?.absoluteString ?? "") : (browser.selectedTab.url == nil ? "" : compactAddress) }
}

private struct BrowserAddressGlass: ViewModifier {
    let namespace: Namespace.ID
    let reduceMotion: Bool

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder private func glass(_ content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(uiColor: .secondarySystemBackground), in: Capsule())
        } else {
            content.glassEffect(.regular, in: .capsule)
        }
    }

    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            glass(content)
        } else {
            glass(content).glassEffectID("browserAddress", in: namespace)
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct WebDialogView: View {
    let dialog: WebDialog
    @State private var input = ""
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Text(dialog.message)
                if dialog.kind == .prompt { TextField("Response", text: $input) }
            }.navigationTitle(dialog.title.isEmpty ? "Website" : dialog.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if dialog.kind != .alert {
                        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dialog.finish(nil); dismiss() } }
                    }
                    ToolbarItem(placement: .confirmationAction) { Button("OK") { dialog.finish(input); dismiss() } }
                }
        }.presentationDetents([.medium, .large])
            .onAppear { input = dialog.defaultText }
            .onDisappear { dialog.finish(nil) }
    }
}
