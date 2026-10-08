// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI

struct ProfilesView: View {
    @Bindable var profiles: ProfileManager
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ProfileList(profiles: profiles, onSelect: { dismiss() })
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
        }
    }
}

struct ProfileList: View {
    @Bindable var profiles: ProfileManager
    var onSelect: () -> Void = {}
    @State private var editing: BrowserProfile?
    @State private var creating = false
    @State private var deleting: BrowserProfile?
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Form {
            Section {
                ForEach(profiles.profiles) { profile in
                    let layout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading)) : AnyLayout(HStackLayout())
                    layout {
                        Button {
                            if profiles.select(profile.id) { onSelect() }
                        } label: {
                            HStack {
                                Image(systemName: profile.symbol).dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                                Text(profile.name).fixedSize(horizontal: false, vertical: true).layoutPriority(1)
                                    .foregroundStyle(.primary)
                                if profile.isProtected { Image(systemName: "lock.fill").accessibilityLabel("Protected") }
                                Spacer()
                                if profiles.currentProfile?.id == profile.id {
                                    Image(systemName: "checkmark").dynamicTypeSize(...DynamicTypeSize.xxxLarge).foregroundStyle(.tint)
                                }
                            }.frame(minHeight: 44).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                            .accessibilityLabel("Switch to \(profile.name)")
                            .accessibilityValue(profiles.currentProfile?.id == profile.id ? "Current profile" : "")
                        Button { editing = profile } label: {
                            if typeSize.isAccessibilitySize {
                                Label("Edit", systemImage: "pencil").frame(minHeight: 44)
                            } else {
                                Image(systemName: "pencil").frame(width: 44, height: 44)
                            }
                        }.buttonStyle(.borderless).accessibilityLabel("Edit \(profile.name)")
                    }
                    .swipeActions {
                        if profiles.profiles.count > 1 {
                            Button("Delete", role: .destructive) { deleting = profile }
                        }
                    }
                }
                Button("New profile", systemImage: "plus") { creating = true }
                    .accessibilityIdentifier("newProfile")
            } header: { Text("Your profiles") } footer: {
                Text("Each profile has separate tabs, history, bookmarks, website logins and browsing settings. Switching profiles reloads pages and stops their media; downloads stay with their original profile.")
            }
            if let registry = profiles.registry {
                Section {
                    Picker("Default profile", selection: Binding(get: { profiles.registry?.defaultProfileID ?? registry.defaultProfileID }, set: {
                        profiles.configureReturn(defaultID: $0, minutes: profiles.registry?.returnAfterMinutes)
                    })) {
                        ForEach(profiles.profiles) { Text($0.name).tag($0.id) }
                    }.accessibilityIdentifier("defaultProfilePicker")
                    NavigationLink {
                        ProfileReturnSettings(profiles: profiles)
                    } label: {
                        LabeledContent("Return after", value: registry.returnAfterMinutes.map { "\($0) min" } ?? "Never")
                    }.accessibilityIdentifier("returnAfter")
                } header: { Text("When you return") } footer: {
                    Text("After Harbor has been in the background for this long, it opens your default profile. This also works if iOS closes the app. Other profiles keep their saved tabs and data.")
                }
            }
            if !profiles.pendingDeletions.isEmpty {
                Section("Unfinished deletions") {
                    ForEach(profiles.pendingDeletions) { profile in
                        Button("Retry deleting \(profile.name)", role: .destructive) {
                            Task { await profiles.delete(profile.id) }
                        }
                    }
                }
            }
            if profiles.isDeleting { ProgressView("Deleting profile…") }
            if let error = profiles.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .disabled(profiles.isDeleting)
        .navigationTitle("Profiles")
        .sheet(isPresented: $creating) { ProfileEditor(profiles: profiles, profile: nil) }
        .sheet(item: $editing) { ProfileEditor(profiles: profiles, profile: $0) }
        .confirmationDialog("Delete \(deleting?.name ?? "profile")?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }), titleVisibility: .visible) {
            if let deleting {
                Button("Delete profile", role: .destructive) { Task { await profiles.delete(deleting.id) }; self.deleting = nil }
            }
        } message: {
            Text("This permanently removes this profile’s tabs, history, bookmarks, settings, cookies, website storage and temporary downloads. Files already exported to other apps are kept.")
        }
    }
}

private struct ProfileEditor: View {
    @Bindable var profiles: ProfileManager
    let profile: BrowserProfile?
    @State private var name = ""
    @State private var symbol = BrowserProfile.symbols[0]
    @State private var requiresAuthentication = false
    @State private var isSaving = false
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                TextField("Profile name", text: $name).accessibilityIdentifier("profileName")
                    .onChange(of: name) { _, value in if value.count > 60 { name = String(value.prefix(60)) } }
                Picker("Icon", selection: $symbol) {
                    ForEach(BrowserProfile.symbols, id: \.self) { symbol in
                        Label(iconName(symbol), systemImage: symbol).tag(symbol)
                    }
                }
                if let profile {
                    Section {
                        Toggle("Require \(profiles.authenticationLabel)", isOn: Binding(
                            get: { profiles.profiles.first(where: { $0.id == profile.id })?.isProtected ?? false },
                            set: { enabled in Task { await profiles.setProtection(profile.id, enabled: enabled) } }
                        )).disabled(profiles.isAuthenticating)
                        if profiles.profiles.first(where: { $0.id == profile.id })?.isProtected == true {
                            Picker("Lock after", selection: Binding(
                                get: { profiles.profiles.first(where: { $0.id == profile.id })?.effectiveLockAfterMinutes ?? 30 },
                                set: { minutes in Task { await profiles.setLockAfter(profile.id, minutes: minutes) } }
                            )) {
                                Text("Immediately").tag(0)
                                Text("1 minute").tag(1)
                                Text("5 minutes").tag(5)
                                Text("15 minutes").tag(15)
                                Text("30 minutes").tag(30)
                                Text("1 hour").tag(60)
                            }.disabled(profiles.isAuthenticating)
                                .accessibilityIdentifier("lockAfterPicker")
                        }
                    } footer: {
                        Text("Unlock with Face ID, Touch ID, or your device passcode. The lock delay starts when you leave Harbor. Switching profiles or restarting Harbor locks immediately. Anyone with your device passcode can unlock this profile.")
                    }
                }
                if profile == nil {
                    Section {
                        Toggle("Require \(profiles.authenticationLabel)", isOn: $requiresAuthentication)
                            .accessibilityIdentifier("newProfileProtection")
                    } footer: {
                        Text("Unlock with Face ID, Touch ID, or your device passcode. Anyone with your device passcode can unlock this profile.")
                    }
                }
                if let error = profiles.errorMessage { Text(error).foregroundStyle(.red) }
            }.disabled(isSaving).navigationTitle(profile == nil ? "New profile" : "Edit profile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(isSaving) }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            isSaving = true
                            Task {
                                let saved: Bool
                                if let profile {
                                    saved = profiles.rename(profile.id, name: name, symbol: symbol)
                                } else {
                                    saved = await profiles.create(name: name, symbol: symbol,
                                                                  requiresAuthentication: requiresAuthentication)
                                }
                                isSaving = false
                                if saved { dismiss() }
                            }
                        }.disabled(isSaving || profiles.isAuthenticating || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("saveProfile")
                    }
                }
                .interactiveDismissDisabled(isSaving)
                .onAppear { name = profile?.name ?? ""; symbol = profile?.symbol ?? BrowserProfile.symbols[0] }
        }
    }
    private func iconName(_ symbol: String) -> String {
        ["person.crop.circle": "Person", "briefcase": "Work", "house": "Home", "book": "Reading", "leaf": "Leaf", "star": "Star"][symbol] ?? "Person"
    }
}

private struct ProfileReturnSettings: View {
    @Bindable var profiles: ProfileManager
    @State private var enabled = false
    @State private var minutes = 30.0
    @Environment(\.dismiss) private var dismiss
    private var durationLabel: String {
        let value = Int(minutes)
        let hours = value / 60
        let remainder = value % 60
        if hours == 0 { return "\(value) minutes" }
        let hourLabel = hours == 1 ? "1 hour" : "\(hours) hours"
        return remainder == 0 ? hourLabel : "\(hourLabel) \(remainder) minutes"
    }
    var body: some View {
        Form {
            Section {
                Toggle("Return to default profile", isOn: $enabled).accessibilityIdentifier("returnEnabled")
                if enabled {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(durationLabel).accessibilityIdentifier("returnDuration")
                        Slider(value: $minutes, in: 5...1440, step: 5) {
                            Text("Return after")
                        } minimumValueLabel: {
                            Text("5 min")
                        } maximumValueLabel: {
                            Text("24 hr")
                        }
                        .accessibilityValue(durationLabel)
                        .accessibilityIdentifier("returnMinutes")
                    }
                }
            } footer: {
                Text(enabled ? "When you reopen Harbor after this much time away, it switches to your default profile." : "Harbor will keep your last-used profile, even after restarting.")
            }
            if let error = profiles.errorMessage { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Return after").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let id = profiles.registry?.defaultProfileID else { return }
                        profiles.configureReturn(defaultID: id, minutes: enabled ? Int(minutes) : nil)
                        if profiles.registry?.returnAfterMinutes == (enabled ? Int(minutes) : nil) { dismiss() }
                    }.accessibilityIdentifier("saveReturnPolicy")
                }
            }
            .onAppear {
                enabled = profiles.registry?.returnAfterMinutes != nil
                minutes = Double(min(1440, max(5, profiles.registry?.returnAfterMinutes ?? 30)))
            }
    }
}

struct LockedProfileView: View {
    @Bindable var profiles: ProfileManager
    @State private var showingProfiles = false

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if typeSize.isAccessibilitySize {
                    HStack(spacing: 16) {
                        HarborMark().frame(width: 60, height: 60)
                        wordmark
                    }
                    .padding(24).padding(.bottom, 16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.harborNavy)
                } else {
                    ZStack(alignment: .top) {
                        HorizonArtwork()
                        VStack(spacing: 4) {
                            HarborMark().frame(width: 94, height: 94)
                            wordmark
                            Text("An open place to return to.")
                                .font(.subheadline).foregroundStyle(.white)
                        }.padding(.top, 16)
                    }.frame(height: 350)
                }

                VStack(alignment: .leading, spacing: 26) {
                    VStack(alignment: .leading, spacing: 8) {
                        Label(profiles.currentProfile?.name ?? "Profile locked", systemImage: "lock.fill")
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text("Unlock this profile to access its tabs and browsing data.")
                            .font(.body).foregroundStyle(Color.primary.opacity(0.72))
                    }
                    VStack(spacing: 12) {
                        Button {
                            Task { await profiles.unlockSelected() }
                        } label: {
                            HStack(spacing: 12) {
                                if profiles.isAuthenticating { ProgressView().tint(.white) }
                                Text("Unlock with \(profiles.authenticationLabel)")
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.borderedProminent).buttonBorderShape(.capsule)
                        .disabled(profiles.isAuthenticating)
                        .accessibilityIdentifier("unlockProfile")

                        Button("Switch profile") { showingProfiles = true }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .disabled(profiles.isAuthenticating)
                    }
                    if let error = profiles.errorMessage {
                        Label(error, systemImage: "exclamationmark.circle")
                            .font(.body).foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(24).frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(uiColor: .systemGroupedBackground), in: UnevenRoundedRectangle(topLeadingRadius: 26, topTrailingRadius: 26))
                .padding(.top, -16)
            }
        }
        .scrollClipDisabled()
        .background {
            VStack(spacing: 0) {
                Color.harborNavy.frame(height: 350)
                Color(uiColor: .systemGroupedBackground)
            }.ignoresSafeArea(.container, edges: .vertical)
        }
        .accessibilityIdentifier("lockedProfile")
        .sheet(isPresented: $showingProfiles) { ProfilesView(profiles: profiles) }
    }

    private var wordmark: some View {
        Text("Harbor")
            .font(.custom("InterVariable", size: 34, relativeTo: .largeTitle).bold())
            .foregroundStyle(.white)
    }
}
