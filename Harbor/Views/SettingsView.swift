// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UIKit

struct SettingsView: View {
    @Bindable var browser: BrowserModel
    @Bindable var profiles: ProfileManager
    @Environment(\.openURL) private var openURL
    @State private var showDefaultBrowserHelp = false
    @State private var confirmClear = false
    @State private var path: [String]

    init(browser: BrowserModel, profiles: ProfileManager, opensProfiles: Bool = false) {
        self.browser = browser
        self.profiles = profiles
        _path = State(initialValue: opensProfiles ? ["profiles"] : [])
    }
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack(path: $path) {
            Form {
                Section {
                    NavigationLink("Profiles", value: "profiles")
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
                Section {
                    Button {
                        guard let url = URL(string: UIApplication.openDefaultApplicationsSettingsURLString) else {
                            showDefaultBrowserHelp = true
                            return
                        }
                        openURL(url) { accepted in
                            showDefaultBrowserHelp = !accepted
                        }
                    } label: {
                        HStack {
                            Text("Default browser")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    .accessibilityIdentifier("defaultBrowserSettings")
                    .accessibilityHint("Opens iOS Settings to choose your default browser")
                } footer: {
                    Text("Choose Harbor as your default browser in iOS Settings. This applies to all profiles.")
                }
            }.navigationTitle("Settings")
                .navigationDestination(for: String.self) { _ in
                    ProfileList(profiles: profiles)
                }
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .onChange(of: browser.archive.settings) { _, _ in browser.settingsChanged() }
                .alert("Open iOS Settings", isPresented: $showDefaultBrowserHelp) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("Go to Apps → Default Apps → Browser App and select Harbor.")
                }
                .confirmationDialog("Clear browsing data for \(browser.profileName)?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Clear data and close tabs", role: .destructive) { Task { await browser.clearWebsiteData() } }
                } message: {
                    Text("Closes this profile’s tabs and deletes its history and website data, signing you out of websites. Keeps bookmarks, settings and website exceptions.")
                }
        }
    }
}
