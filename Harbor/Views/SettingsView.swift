import SwiftUI

struct SettingsView: View {
    @Bindable var browser: BrowserModel
    @Bindable var profiles: ProfileManager
    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    NavigationLink("Profiles") { ProfileList(profiles: profiles) }
                    LabeledContent("Current profile", value: browser.profileName)
                } footer: { Text("Settings apply to this profile.") }
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
                    NavigationLink("Backup") {
                        Form {
                            Section {
                                Text("Device backups can include profiles, bookmarks, settings and website exceptions.")
                                Text("Tabs, history and activity timestamps are excluded from new backups. Older backups may still contain them.")
                                Text("Backup does not sync Harbor across devices. Website logins and storage are managed by iOS and may not be restored.")
                            }
                        }
                        .navigationTitle("Backup")
                    }
                    Button("Clear browsing data…", role: .destructive) { confirmClear = true }.disabled(browser.isClearingData)
                    if browser.isClearingData { ProgressView("Clearing browsing data…") }
                }
                Section("Search") {
                    Picker("Search engine", selection: $browser.archive.settings.searchEngine) {
                        ForEach(SearchEngine.allCases) { engine in Text(engine.rawValue).tag(engine) }
                    }
                }
                Section("Browsing") {
                    Toggle("Restore tabs on launch", isOn: $browser.archive.settings.restoreTabs)
                }
                Section("About Harbor") {
                    LabeledContent("Version", value: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown")
                }
            }.navigationTitle("Settings")
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: browser.archive.settings) { _, _ in browser.settingsChanged() }
                .confirmationDialog("Clear browsing data for \(browser.profileName)?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Clear data and close tabs", role: .destructive) { Task { await browser.clearWebsiteData() } }
                } message: {
                    Text("Closes this profile’s tabs and deletes its history and website data, signing you out of websites. Keeps bookmarks, settings and website exceptions.")
                }
        }
    }
}
