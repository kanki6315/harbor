import SwiftUI
import WebKit

private enum BrowserSheet: String, Identifiable {
    case tabs, history, bookmarks, settings, privacy
    var id: String { rawValue }
}

struct BrowserView: View {
    @State private var browser = BrowserModel()
    @State private var address = ""
    @State private var sheet: BrowserSheet?
    @State private var share: ShareItem?
    @FocusState private var editingAddress: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
            // Resident views stay attached to preserve WebKit's media and native full-screen UI.
            ForEach(browser.archive.tabs) { tab in
                if let session = browser.sessions[tab.id] {
                    WebView(webView: session.webView)
                        // Keep the page beneath the system status area and floating glass controls.
                        // WebKit's automatic scroll insets keep page controls reachable above the bar.
                        .ignoresSafeArea(.container, edges: .vertical)
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
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if browser.activeSession?.fullscreen != true { chrome }
        }
        .onChange(of: browser.selectedID) { _, _ in editingAddress = false; syncAddress() }
        .onChange(of: browser.selectedTab.url) { _, _ in if !editingAddress { syncAddress() } }
        .onChange(of: editingAddress) { _, value in if value { syncAddress() } }
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
            case .settings: SettingsView(browser: browser)
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
        .alert("Harbor", isPresented: Binding(get: { browser.errorMessage != nil || browser.downloads.errorMessage != nil }, set: { if !$0 { browser.errorMessage = nil; browser.downloads.errorMessage = nil } })) {
            Button("OK", role: .cancel) { browser.errorMessage = nil; browser.downloads.errorMessage = nil }
        } message: { Text(browser.errorMessage ?? browser.downloads.errorMessage ?? "") }
    }

    private var chrome: some View {
        VStack(spacing: 8) {
            if browser.activeSession?.isLoading == true {
                ProgressView(value: browser.activeSession?.progress ?? 0).tint(.harborBlue).accessibilityLabel("Page loading")
            }
            HStack(spacing: 0) {
                Button { editingAddress = false; sheet = .privacy } label: {
                    Image(systemName: "shield.lefthalf.filled").dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(width: 44, height: 48)
                }.accessibilityLabel(browser.protectionStatus)
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
            }.padding(.horizontal, 4).harborGlass()
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
                    Menu {
                        if let url = browser.selectedTab.url {
                            Button("Share page", systemImage: "square.and.arrow.up") { share = ShareItem(url: url) }
                            Button(browser.archive.bookmarks.contains(where: { $0.url == url }) ? "Remove bookmark" : "Add bookmark", systemImage: "bookmark") { browser.toggleBookmark() }
                        }
                        Button("Bookmarks", systemImage: "book") { sheet = .bookmarks }
                        Button("History", systemImage: "clock") { sheet = .history }
                        if browser.activeSession?.mediaState == .playing {
                            Button("Pause media", systemImage: "pause.fill") { browser.activeSession?.webView.pauseAllMediaPlayback(completionHandler: nil) }
                        }
                        if let download = browser.downloads.completed {
                            Button("Save or share download", systemImage: "arrow.down.doc") { share = download }
                        }
                        if browser.downloads.activeCount > 0 { Text("Downloading \(browser.downloads.activeCount) file(s)…") }
                        Button("Settings", systemImage: "gearshape") { sheet = .settings }
                    } label: {
                        Image(systemName: "ellipsis").dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(maxWidth: .infinity, minHeight: 48)
                    }.accessibilityLabel("More").accessibilityIdentifier("moreButton")
                }.harborGlass()
            }
        }
        .padding(.horizontal, typeSize.isAccessibilitySize ? 8 : 16).padding(.top, 8).padding(.bottom, 5)
    }
    private func action(_ name: String, symbol: String, perform: @escaping () -> Void) -> some View {
        Button(action: perform) { Image(systemName: symbol).dynamicTypeSize(...DynamicTypeSize.xxxLarge).frame(maxWidth: .infinity, minHeight: 48) }.accessibilityLabel(name)
    }
    private func submit() { browser.navigate(address); editingAddress = false }
    private func syncAddress() { address = browser.selectedTab.url?.absoluteString ?? "" }
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
