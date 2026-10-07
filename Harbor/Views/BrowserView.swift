import SwiftUI
import WebKit

private enum BrowserSheet: String, Identifiable {
    case tabs, history, bookmarks, settings, privacy, profiles
    var id: String { rawValue }
}

struct BrowserView: View {
    @Bindable var browser: BrowserModel
    @Bindable var profiles: ProfileManager
    @State private var address = ""
    @State private var sheet: BrowserSheet?
    @State private var share: ShareItem?
    @State private var chromeCollapsed = false
    @State private var chromeHeight: CGFloat = 117
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
                            contentInsets: UIEdgeInsets(top: 0, left: 0,
                                bottom: browser.activeSession?.fullscreen == true ? 0 : chromeHeight + geometry.safeAreaInsets.bottom,
                                right: 0),
                            onScrollDown: {
                                guard tab.id == browser.selectedID, !editingAddress,
                                      browser.activeSession?.fullscreen != true else { return }
                                setChromeCollapsed(true)
                            })
                        .ignoresSafeArea(.container, edges: .bottom)
                        .opacity(tab.id == browser.selectedID ? 1 : 0)
                        .allowsHitTesting(tab.id == browser.selectedID)
                        .accessibilityHidden(tab.id != browser.selectedID)
                }
            }
            if browser.selectedTab.url == nil {
                StartPage(browser: browser, focusAddress: { editingAddress = true }, showPrivacy: { sheet = .privacy })
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
        .overlay(alignment: .top) {
            if browser.activeSession?.fullscreen != true && !chromeCollapsed && !editingAddress {
                topChrome.transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if browser.activeSession?.fullscreen != true {
                chrome.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { chromeHeight = $0 }
            }
        }
        .onChange(of: browser.selectedID) { _, _ in editingAddress = false; chromeCollapsed = false; syncAddress() }
        .onChange(of: browser.selectedTab.url) { _, _ in if !editingAddress { syncAddress() } }
        .onChange(of: editingAddress) { _, value in if value { chromeCollapsed = false; syncAddress() } }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { browser.saveNow() }
            else { Task { await browser.refreshMedia() } }
        }
        .onAppear { syncAddress() }
        .sheet(item: $sheet) { destination in
            switch destination {
            case .tabs: TabSwitcherView(browser: browser)
            case .history: HistoryView(browser: browser)
            case .bookmarks: BookmarksView(browser: browser)
            case .settings: SettingsView(browser: browser, profiles: profiles)
            case .profiles: ProfilesView(profiles: profiles)
            case .privacy: PrivacyView(browser: browser)
            }
        }
        .sheet(item: $share) { item in ShareSheet(url: item.url) }
        .sheet(item: Binding(get: { browser.dialog }, set: { browser.dialog = $0 })) { dialog in
            WebDialogView(dialog: dialog)
        }
        .onChange(of: browser.downloads.completed?.id) { _, _ in
            // Downloads are offered in the menu if a browser sheet is already open.
            if sheet == nil { share = browser.downloads.completed }
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

    private var topChrome: some View {
        GlassEffectContainer(spacing: 8) {
            HStack {
                if browser.selectedTab.url != nil || browser.downloads.completed != nil || browser.downloads.activeCount > 0 {
                    Menu {
                        if let url = browser.selectedTab.url {
                            Button("Share page", systemImage: "square.and.arrow.up") { share = ShareItem(url: url) }
                            Button(browser.archive.bookmarks.contains(where: { $0.url == url }) ? "Remove bookmark" : "Add bookmark", systemImage: "bookmark") { browser.toggleBookmark() }
                        }
                        if browser.activeSession?.mediaState == .playing {
                            Button("Pause media", systemImage: "pause.fill") { browser.activeSession?.webView.pauseAllMediaPlayback(completionHandler: nil) }
                        }
                        if let download = browser.downloads.completed {
                            Button("Save or share download", systemImage: "arrow.down.doc") { share = download }
                        }
                        if browser.downloads.activeCount > 0 { Text("Downloading \(browser.downloads.activeCount) file(s)…") }
                    } label: {
                        Image(systemName: "ellipsis")
                            .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                            .frame(width: 48, height: 48)
                    }
                    .harborGlass()
                    .accessibilityLabel("Page actions")
                    .accessibilityIdentifier("pageActionsButton")
                }
                Spacer(minLength: 8)
                HStack(spacing: 0) {
                    Button { sheet = .history } label: {
                        Image(systemName: "clock").frame(width: 48, height: 48)
                    }
                    .accessibilityLabel("History")
                    .accessibilityIdentifier("historyButton")
                    Button { sheet = .settings } label: {
                        Image(systemName: "gearshape").frame(width: 48, height: 48)
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settingsButton")
                }
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .harborGlass()
            }
            .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 16)
            .padding(.vertical, 4)
        }
    }

    private var chrome: some View {
        GlassEffectContainer(spacing: 8) {
            VStack(spacing: 8) {
                if chromeCollapsed && !editingAddress {
                    Button { setChromeCollapsed(false) } label: {
                        Label(compactAddress, systemImage: profiles.currentProfile?.symbol ?? "person.crop.circle")
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1).truncationMode(.middle)
                            .padding(.horizontal, 18).padding(.vertical, 8)
                            .modifier(BrowserAddressGlass(namespace: chromeNamespace, reduceMotion: reduceMotion))
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show browser controls for \(compactAddress), \(browser.profileName) profile")
                    .accessibilityIdentifier("expandBrowserControls")
                    .frame(maxWidth: .infinity)
                    .transition(.opacity)

                } else {
                    HStack(spacing: 0) {
                        Button { editingAddress = false; sheet = .privacy } label: {
                            Image(systemName: "shield.lefthalf.filled").dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 48)
                        }.accessibilityLabel(browser.protectionStatus)
                        Button { editingAddress = false; sheet = .profiles } label: {
                            Image(systemName: profiles.currentProfile?.symbol ?? "person.crop.circle")
                                .dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 48)
                        }.accessibilityLabel("Profiles, \(browser.profileName)")
                            .accessibilityIdentifier("profilesButton")
                        TextField("Search or enter address", text: $address,
                                  prompt: Text(typeSize.isAccessibilitySize ? "Address" : "Search or enter address")
                                    .foregroundStyle(Color.primary.opacity(0.72)))
                            .textInputAutocapitalization(.never).autocorrectionDisabled()
                            .keyboardType(.webSearch).submitLabel(.go)
                            .focused($editingAddress).onSubmit(submit)
                            .accessibilityIdentifier("addressField")
                            .frame(minHeight: 48)
                        if editingAddress {
                            Button(action: submit) { Image(systemName: "arrow.right.circle.fill").dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 48) }
                                .accessibilityLabel("Go")
                        } else if browser.selectedTab.url != nil {
                            Button {
                                if browser.activeSession?.isLoading == true { browser.activeSession?.webView.stopLoading() }
                                else { browser.reload() }
                            } label: {
                                Image(systemName: browser.activeSession?.isLoading == true ? "xmark" : "arrow.clockwise").dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 48)
                            }.accessibilityLabel(browser.activeSession?.isLoading == true ? "Stop loading" : "Reload")
                        }

                    }.padding(.horizontal, 4)
                        .modifier(BrowserAddressGlass(namespace: chromeNamespace, reduceMotion: reduceMotion))
                        .transition(.opacity)
                        .overlay(alignment: .bottom) {
                            if browser.activeSession?.isLoading == true {
                                ProgressView(value: browser.activeSession?.progress ?? 0)
                                    .tint(.harborBlue).padding(.horizontal, 24)
                                    .accessibilityLabel("Page loading")
                            }
                        }
                    if !editingAddress {
                        HStack(spacing: 0) {
                            action("Back", symbol: "chevron.left") { browser.activeSession?.webView.goBack() }
                                .disabled(browser.activeSession?.canGoBack != true)
                            action("Forward", symbol: "chevron.right") { browser.activeSession?.webView.goForward() }
                                .disabled(browser.activeSession?.canGoForward != true)
                            action("New tab", symbol: "plus") { browser.newTab(); editingAddress = true }
                            Button { browser.activeSession?.captureSnapshot(); sheet = .tabs } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 5).strokeBorder(lineWidth: 1.8)
                                    Text("\(browser.archive.tabs.count)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .monospacedDigit().lineLimit(1).minimumScaleFactor(0.5)
                                        .padding(.horizontal, 3)
                                }.frame(width: 27, height: 27)
                                    .frame(maxWidth: .infinity, minHeight: 48)
                            }.accessibilityLabel("Tabs, \(browser.archive.tabs.count) open").accessibilityIdentifier("tabsButton")
                            action("Bookmarks", symbol: "book") { sheet = .bookmarks }
                                .accessibilityIdentifier("bookmarksButton")
                        }.harborGlass()
                            .transition(reduceMotion ? .opacity :
                                .offset(y: 12).combined(with: .opacity))
                    }
                }
            }
            .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 16).padding(.top, 8).padding(.bottom, 5)
        }
    }
    private func setChromeCollapsed(_ collapsed: Bool) {
        guard chromeCollapsed != collapsed else { return }
        let animation: Animation = reduceMotion ? .easeOut(duration: 0.12) :
            .smooth(duration: collapsed ? 0.24 : 0.32, extraBounce: 0)
        withAnimation(animation) { chromeCollapsed = collapsed }
    }

    private var compactAddress: String {
        guard let url = browser.selectedTab.url else { return "Search or enter address" }
        return url.host ?? (url.isFileURL ? "Local page" : url.absoluteString)
    }

    private func action(_ name: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Image(systemName: symbol).dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(maxWidth: .infinity, minHeight: 48) }.accessibilityLabel(name)
    }
    private func submit() { browser.navigate(address); editingAddress = false }
    private func syncAddress() { address = browser.selectedTab.url?.absoluteString ?? "" }
}

private struct BrowserAddressGlass: ViewModifier {
    let namespace: Namespace.ID
    let reduceMotion: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceMotion {
            content.harborGlass()
        } else {
            content.harborGlass().glassEffectID("browserAddress", in: namespace)
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
