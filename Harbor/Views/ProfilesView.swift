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
                    } footer: {
                        Text("Unlock with Face ID, Touch ID, or your device passcode. Locks when you switch profiles or leave Harbor. Anyone with your device passcode can unlock this profile.")
                    }
                }
                if let error = profiles.errorMessage { Text(error).foregroundStyle(.red) }
            }.navigationTitle(profile == nil ? "New profile" : "Edit profile")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            let saved = profile.map { profiles.rename($0.id, name: name, symbol: symbol) }
                                ?? profiles.create(name: name, symbol: symbol)
                            if saved { dismiss() }
                        }.disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityIdentifier("saveProfile")
                    }
                }
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
    @State private var minutes = "30"
    @Environment(\.dismiss) private var dismiss
    private var validMinutes: Int? {
        guard let value = Int(minutes), (1...10080).contains(value) else { return nil }
        return value
    }
    var body: some View {
        Form {
            Section {
                Toggle("Return to default profile", isOn: $enabled).accessibilityIdentifier("returnEnabled")
                if enabled {
                    TextField("Minutes", text: $minutes).keyboardType(.numberPad)
                        .accessibilityIdentifier("returnMinutes")
                }
            } footer: {
                Text(enabled ? "Enter 1–10,080 minutes. Time counts only while Harbor is in the background." : "Harbor will keep your last-used profile, even after restarting.")
            }
            if let error = profiles.errorMessage { Text(error).foregroundStyle(.red) }
        }.navigationTitle("Return after").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        guard let id = profiles.registry?.defaultProfileID else { return }
                        profiles.configureReturn(defaultID: id, minutes: enabled ? validMinutes : nil)
                        if profiles.registry?.returnAfterMinutes == (enabled ? validMinutes : nil) { dismiss() }
                    }.disabled(enabled && validMinutes == nil).accessibilityIdentifier("saveReturnPolicy")
                }
            }
            .onAppear {
                enabled = profiles.registry?.returnAfterMinutes != nil
                minutes = String(profiles.registry?.returnAfterMinutes ?? 30)
            }
    }
}

struct LockedProfileView: View {
    @Bindable var profiles: ProfileManager
    @State private var showingProfiles = false

    var body: some View {
        ContentUnavailableView {
            Label(profiles.currentProfile?.name ?? "Profile locked", systemImage: "lock.fill")
        } description: {
            Text(profiles.errorMessage ?? "Unlock this profile to access its tabs and browsing data.")
        } actions: {
            Button("Unlock with \(profiles.authenticationLabel)") {
                Task { await profiles.unlockSelected() }
            }.buttonStyle(.borderedProminent).disabled(profiles.isAuthenticating)
            Button("Switch profile") { showingProfiles = true }.disabled(profiles.isAuthenticating)
        }
        .sheet(isPresented: $showingProfiles) { ProfilesView(profiles: profiles) }
    }
}
