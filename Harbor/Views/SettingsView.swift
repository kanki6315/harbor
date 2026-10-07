import SwiftUI

struct SettingsView: View {
    @Bindable var browser: BrowserModel
    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("Privacy") {
                    Toggle("Tracker blocking", isOn: $browser.archive.settings.trackerBlocking)
                    Toggle("Remove tracking parameters", isOn: $browser.archive.settings.stripTrackingParameters)
                    NavigationLink("Website exceptions (\(browser.archive.settings.siteExceptions.count))") {
                        List {
                            ForEach(browser.archive.settings.siteExceptions.sorted(), id: \.self) { site in
                                Text(site).swipeActions {
                                    Button("Remove", role: .destructive) { browser.archive.settings.siteExceptions.remove(site); browser.settingsChanged() }
                                }
                            }
                        }.overlay { if browser.archive.settings.siteExceptions.isEmpty { ContentUnavailableView("No website exceptions", systemImage: "shield") } }
                            .navigationTitle("Website exceptions")
                    }
                    Button("Clear browsing data…", role: .destructive) { confirmClear = true }.disabled(browser.isClearingData)
                    if browser.isClearingData { ProgressView("Clearing browsing data…") }
                }
                Section("Search") {
                    Picker("Search engine", selection: $browser.archive.settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in Text(engine.rawValue).tag(engine) }
                    }
                }
                Section {
                    Toggle("Restore tabs on launch", isOn: $browser.archive.settings.restoreTabs)
                } header: { Text("Browsing") } footer: {
                    Text("Website logins use persistent WebKit storage. Turning off tab restoration does not sign you out.")
                }
                Section {
                    LabeledContent("Inline video", value: "Enabled")
                    LabeledContent("Autoplay", value: "Requires interaction")
                    Text("Native full-screen playback, Picture in Picture and AirPlay are available when supported by the website and iOS.")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Text("Background audio is not enabled. Locking the device or leaving Harbor may pause playback.")
                        .font(.subheadline).foregroundStyle(.secondary)
                } header: { Text("Media") } footer: {
                    Text("Per-site autoplay and media permissions may be added in a future version.")
                }
                Section("About Harbor") {
                    LabeledContent("Rendering engine", value: "Apple WebKit")
                    Text("Harbor uses WKWebView with persistent cookies and website storage. Tracker blocking reduces some tracking; it does not provide complete anonymity.")
                    Text("The app contains no analytics, telemetry, advertising or crash-reporting SDKs. Websites you visit may collect data.")
                    Text("Media codecs, DRM, streaming-service compatibility, Picture in Picture and background behavior depend on iOS, WebKit and each website.")
                    LabeledContent("Version", value: "1.0")
                }.font(.subheadline)
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: browser.archive.settings) { _, _ in browser.settingsChanged() }
                .confirmationDialog("Clear browsing data?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Clear data and close tabs", role: .destructive) { Task { await browser.clearWebsiteData() } }
                } message: {
                    Text("This closes all tabs and removes history, cookies, caches and website storage. You will be signed out of websites. Bookmarks, settings and website exceptions are kept.")
                }
        }
    }
}
