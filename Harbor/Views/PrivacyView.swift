// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct PrivacyView: View {
    @Bindable var browser: BrowserModel
    @State private var confirmClear = false
    @State private var changed = false
    @State private var cleared = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Label(browser.protectionStatus, systemImage: "shield.lefthalf.filled").font(.headline)
                    if let failure = browser.blocker.failure { Text(failure).foregroundStyle(.secondary) }
                    Text("Harbor blocks a small set of common third-party trackers. WebKit does not provide a reliable blocked-request count.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                if let site = browser.site {
                    Section {
                        Toggle("Block trackers on this website", isOn: Binding(get: {
                            !browser.archive.settings.siteExceptions.contains(site)
                        }, set: { enabled in
                            if enabled { browser.archive.settings.siteExceptions.remove(site) }
                            else { browser.archive.settings.siteExceptions.insert(site) }
                            browser.settingsChanged(); changed = true
                        })).disabled(!browser.archive.settings.trackerBlocking)
                        if !browser.archive.settings.trackerBlocking {
                            Text("Turn on tracker blocking in Settings to use per-site protection.").font(.footnote).foregroundStyle(.secondary)
                        }
                        if changed {
                            Button("Reload to apply to this page", systemImage: "arrow.clockwise") { browser.reload(); dismiss() }
                            Text("Reloading may discard unsaved input.").font(.footnote).foregroundStyle(.secondary)
                        }
                    } header: { Text(site) } footer: {
                        Text("If a video or sign-in flow breaks, turn off blocking for this website and reload. Exceptions are saved for this exact hostname.")
                    }
                    Section {
                        Button("Clear website data…", role: .destructive) { confirmClear = true }.disabled(browser.isClearingData)
                        if browser.isClearingData { ProgressView("Clearing…") }
                        if cleared {
                            Text("Website data cleared. Reload when you’re ready to reconnect.").font(.subheadline)
                            Button("Reload website") { browser.reload(); dismiss() }
                        }
                    } footer: {
                        Text("WebKit groups some storage by domain. Clearing may sign you out of related subdomains too.")
                    }
                } else {
                    Section { Text("Visit a website to manage its protection and stored data.").foregroundStyle(.secondary) }
                }
            }.navigationTitle("Privacy").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
                .confirmationDialog("Clear data for \(browser.site ?? "this website") in \(browser.profileName)?", isPresented: $confirmClear, titleVisibility: .visible) {
                    Button("Clear website data", role: .destructive) {
                        Task { await browser.clearWebsiteData(site: browser.site); cleared = true }
                    }
                } message: { Text("Cookies, cached files and website storage will be removed where WebKit can identify the domain. You may be signed out. Related subdomains may also be affected.") }
        }
    }
}
