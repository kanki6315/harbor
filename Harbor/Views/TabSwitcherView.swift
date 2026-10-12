// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import UniformTypeIdentifiers

struct TabSwitcherView: View {
    @Bindable var browser: BrowserModel
    @State private var search = ""
    @State private var showingReorder = false
    @State private var draggedTab: UUID?
    @State private var showingGroupEditor = false
    @State private var editingGroup: TabGroup?
    @State private var groupName = ""
    @State private var tabToGroup: UUID?
    @State private var deletingGroup: TabGroup?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var filtered: [TabRecord] {
        browser.groupedTabs.filter { tab in
            (browser.selectedTabGroup != nil || tab.groupID == nil) && matchesSearch(tab)
        }
    }
    private func matchesSearch(_ tab: TabRecord) -> Bool {
        search.isEmpty || tab.title.localizedCaseInsensitiveContains(search)
            || (tab.url?.absoluteString.localizedCaseInsensitiveContains(search) ?? false)
    }

    private var filteredGroups: [TabGroup] {
        guard browser.selectedTabGroup == nil else { return [] }
        return browser.archive.tabGroups.filter { group in
            search.isEmpty || group.name.localizedCaseInsensitiveContains(search)
                || browser.archive.tabs.contains { $0.groupID == group.id && matchesSearch($0) }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                groupSelector.padding(.horizontal, 16).padding(.top, 8)
                if filtered.isEmpty && filteredGroups.isEmpty {
                    if search.isEmpty {
                        ContentUnavailableView("No tabs in this group", systemImage: "rectangle.stack",
                                               description: Text("Create a tab here, or move one from All Tabs using its menu."))
                    } else {
                        ContentUnavailableView.search(text: search)
                    }
                } else {
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible(), alignment: .top)] : [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 20) {
                        ForEach(filteredGroups) { group in
                            groupCard(group)
                        }
                        ForEach(filtered) { tab in
                            TabDragSource(id: tab.id, draggedTab: $draggedTab) {
                                TabCard(tab: tab, session: browser.sessions[tab.id], selected: tab.id == browser.selectedID,
                                    largeText: typeSize.isAccessibilitySize, previewURL: browser.previewURL(tab.id),
                                    select: { browser.selectTab(tab.id); dismiss() }, close: { browser.closeTab(tab.id) })
                                .contextMenu { tabGroupActions(tab) }
                                .overlay(alignment: .topLeading) {
                                    Menu { tabGroupActions(tab) } label: {
                                        Image(systemName: "ellipsis.circle")
                                            .frame(width: 44, height: 44)
                                            .background(.regularMaterial, in: Circle())
                                    }
                                    .padding(5)
                                    .accessibilityLabel("Group options for \(tab.title)")
                                    .accessibilityIdentifier("tabGroupOptions-\(tab.id)")
                                }
                            }
                                // Keep an empty insertion slot while the native preview carries the card.
                                .opacity(draggedTab == tab.id ? 0 : 1)

                                .onDrop(of: [TabDragProvider.type], delegate: TabReorderDropDelegate(
                                    target: tab.id, draggedTab: $draggedTab,
                                    browser: browser, reduceMotion: reduceMotion))
                                .accessibilityAction(named: "Move earlier") { move(tab, by: -1) }
                                .accessibilityAction(named: "Move later") { move(tab, by: 1) }
                        }
                    }.padding(16)
                }
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(browser.selectedTabGroup?.name ?? (browser.archive.tabs.count == 1 ? "1 tab" : "\(browser.archive.tabs.count) tabs"))
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: browser.selectedTabGroup == nil ? "Search all tabs" : "Search this group")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Reorder", systemImage: "arrow.up.arrow.down") { showingReorder = true }
                            .disabled(browser.archive.tabs.count < 2)
                            .accessibilityIdentifier("reorderTabs")
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Menu {
                            Button("Unload background tabs", systemImage: "moon") {
                                Task { await browser.unloadBackgroundTabs() }
                            }
                            .disabled(!browser.sessions.keys.contains(where: { $0 != browser.selectedID }))
                            Text("Keeps the current tab and playing media open. Unloaded pages reload when selected.")
                        } label: {
                            Label("Tab options", systemImage: "ellipsis.circle")
                        }
                        .accessibilityIdentifier("tabOptions")
                    }
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .bottomBar) {
                        Button("New tab", systemImage: "plus") { browser.newTab(); dismiss() }.accessibilityIdentifier("tabSwitcherNewTab")
                    }
                    if browser.lastClosed != nil {
                        ToolbarItem(placement: .bottomBar) { Button("Undo close", systemImage: "arrow.uturn.backward") { browser.undoClose() } }
                    }
                }
        }
        .sheet(isPresented: $showingReorder) { reorderSheet }
        .sheet(isPresented: $showingGroupEditor) { groupEditor }
        .confirmationDialog("Delete group?", isPresented: Binding(get: { deletingGroup != nil }, set: { if !$0 { deletingGroup = nil } }), titleVisibility: .visible) {
            Button("Delete group, keep tabs", role: .destructive) {
                if let group = deletingGroup { browser.deleteTabGroup(group.id) }
                deletingGroup = nil
            }
        } message: {
            Text("All tabs in this group will stay open in All Tabs.")
        }
        .onAppear { Task { await browser.refreshMedia() } }
        .onDisappear { draggedTab = nil }
    }
    private func move(_ tab: TabRecord, by offset: Int) {
        guard let index = filtered.firstIndex(where: { $0.id == tab.id }),
              filtered.indices.contains(index + offset) else { return }
        browser.moveTab(tab.id, onto: filtered[index + offset].id)
    }

    private func moveInAllTabs(_ tab: TabRecord, by offset: Int) {
        guard let index = browser.archive.tabs.firstIndex(where: { $0.id == tab.id }),
              browser.archive.tabs.indices.contains(index + offset) else { return }
        browser.moveTab(tab.id, onto: browser.archive.tabs[index + offset].id)
    }

    private var groupSelector: some View {
        VStack(alignment: .leading, spacing: 4) {
            Menu {
                Button("All Tabs (\(browser.archive.tabs.count))", systemImage: "square.on.square") {
                    browser.selectTabGroup(nil); search = ""
                }
                ForEach(browser.archive.tabGroups) { group in
                    Button {
                        browser.selectTabGroup(group.id); search = ""
                    } label: {
                        Label("\(group.name) (\(browser.archive.tabs.filter { $0.groupID == group.id }.count))",
                              systemImage: group.id == browser.archive.selectedTabGroupID ? "checkmark" : "rectangle.stack")
                    }
                }
                Divider()
                Button("New group", systemImage: "plus") { editGroup() }
                if let group = browser.selectedTabGroup {
                    Button("Rename group", systemImage: "pencil") { editGroup(group) }
                    Button("Delete group", systemImage: "trash", role: .destructive) { deletingGroup = group }
                }
            } label: {
                HStack {
                    Label(browser.selectedTabGroup?.name ?? "All Tabs", systemImage: "rectangle.stack")
                        .font(.headline).multilineTextAlignment(.leading)
                    Spacer()
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                }.frame(minHeight: 44)
            }
            .accessibilityLabel("Tab groups, \(browser.selectedTabGroup?.name ?? "All Tabs")")
            .accessibilityIdentifier("tabGroupSelector")
            if browser.selectedTabGroup != nil {
                Text("\(browser.groupedTabs.count) in this group · \(browser.archive.tabs.count) total")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func groupCard(_ group: TabGroup) -> some View {
        let tabs = browser.archive.tabs.filter { $0.groupID == group.id }
        let containsSelected = tabs.contains { $0.id == browser.selectedID }
        return VStack(alignment: .leading, spacing: 6) {
            Button {
                browser.selectTabGroup(group.id)
                search = ""
            } label: {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "rectangle.stack.fill")
                        .font(.title).foregroundStyle(.tint)
                    if !typeSize.isAccessibilitySize {
                        ForEach(tabs.prefix(3)) { tab in
                            Text(tab.title).font(.subheadline).lineLimit(1)
                        }
                        if tabs.isEmpty {
                            Text("No tabs yet").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                .frame(height: typeSize.isAccessibilitySize ? 130 : 205)
                .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 18))
                .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(containsSelected ? Color.accentColor : .clear, lineWidth: 4))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open group \(group.name), \(tabs.count) tabs")
            .accessibilityIdentifier("tabGroupCard-\(group.id)")
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                if containsSelected {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint)
                        .accessibilityLabel("Contains selected tab")
                }
                Text(group.name).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            Text(tabs.count == 1 ? "1 tab" : "\(tabs.count) tabs")
                .font(.caption).foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .contain)
        .contextMenu {
            Button("Rename group", systemImage: "pencil") { editGroup(group) }
            Button("Delete group", systemImage: "trash", role: .destructive) { deletingGroup = group }
        }
    }

    @ViewBuilder private func tabGroupActions(_ tab: TabRecord) -> some View {
        if let group = browser.archive.tabGroups.first(where: { $0.id == tab.groupID }) {
            Text("In \(group.name)")
            Button("Remove from group", systemImage: "rectangle.stack.badge.minus") {
                browser.moveTab(tab.id, toGroup: nil)
            }
        }
        Menu("Move to group", systemImage: "rectangle.stack") {
            ForEach(browser.archive.tabGroups.filter { $0.id != tab.groupID }) { group in
                Button(group.name) { browser.moveTab(tab.id, toGroup: group.id) }
            }
            Button("New group", systemImage: "plus") { editGroup(tabID: tab.id) }
        }
    }

    private func editGroup(_ group: TabGroup? = nil, tabID: UUID? = nil) {
        editingGroup = group
        groupName = group?.name ?? ""
        tabToGroup = tabID
        showingGroupEditor = true
    }

    private var groupEditor: some View {
        NavigationStack {
            Form {
                TextField("Group name", text: $groupName)
                    .textInputAutocapitalization(.words)
                    .accessibilityIdentifier("tabGroupName")
            }
            .navigationTitle(editingGroup == nil ? "New group" : "Rename group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showingGroupEditor = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let group = editingGroup { browser.renameTabGroup(group.id, name: groupName) }
                        else { browser.createTabGroup(name: groupName, tabID: tabToGroup); search = "" }
                        showingGroupEditor = false
                    }
                    .disabled(groupName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("saveTabGroup")
                }
            }
        }
    }

    private var reorderSheet: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(browser.archive.tabs) { tab in
                        HStack {
                            Image(systemName: tab.id == browser.selectedID ? "checkmark.circle.fill" : "globe")
                                .foregroundStyle(tab.id == browser.selectedID ? Color.accentColor : .secondary)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(tab.title).font(.body).lineLimit(2)
                                Text(tab.url?.host ?? "Start page").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityAction(named: "Move earlier") { moveInAllTabs(tab, by: -1) }
                        .accessibilityAction(named: "Move later") { moveInAllTabs(tab, by: 1) }
                    }
                    .onMove { browser.moveTabs(from: $0, to: $1) }
                } footer: {
                    Text("Drag the handles to change tab order. You can also drag previews in the tab grid.")
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Reorder tabs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { showingReorder = false } } }
        }
    }
}

private enum TabDragProvider {
    static let type = UTType(exportedAs: "com.arjunakankipati.harbor.tab-reorder")
}

// UIKit supplies a drag-end callback on iOS 26, including cancellation and
// releases outside a drop target. Keep the hosting controller alive while its
// card moves through the grid so the source always receives that callback.
private struct TabDragSource<Content: View>: UIViewControllerRepresentable {
    let id: UUID
    @Binding var draggedTab: UUID?
    @ViewBuilder var content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIHostingController<Content> {
        let controller = UIHostingController(rootView: content())
        controller.view.backgroundColor = .clear
        let interaction = UIDragInteraction(delegate: context.coordinator)
        interaction.isEnabled = true
        controller.view.addInteraction(interaction)
        return controller
    }

    func updateUIViewController(_ controller: UIHostingController<Content>, context: Context) {
        context.coordinator.source = self
        controller.rootView = content()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: UIHostingController<Content>, context: Context) -> CGSize? {
        uiViewController.sizeThatFits(in: CGSize(width: proposal.width ?? 0, height: proposal.height ?? .greatestFiniteMagnitude))
    }

    final class Coordinator: NSObject, UIDragInteractionDelegate {
        var source: TabDragSource

        init(_ source: TabDragSource) { self.source = source }

        func dragInteraction(_ interaction: UIDragInteraction, itemsForBeginning session: any UIDragSession) -> [UIDragItem] {
            guard source.draggedTab == nil, let view = interaction.view else { return [] }
            let id = source.id
            let provider = NSItemProvider()
            provider.registerDataRepresentation(forTypeIdentifier: TabDragProvider.type.identifier, visibility: .ownProcess) { completion in
                completion(Data(id.uuidString.utf8), nil)
                return nil
            }
            let item = UIDragItem(itemProvider: provider)
            // Capture before hiding the source; the floating preview stays visible.
            let image = UIGraphicsImageRenderer(size: view.bounds.size).image { _ in
                view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
            }
            item.localObject = image
            item.previewProvider = {
                let parameters = UIDragPreviewParameters()
                parameters.backgroundColor = .clear
                return UIDragPreview(view: UIImageView(image: image), parameters: parameters)
            }
            return [item]
        }

        func dragInteraction(_ interaction: UIDragInteraction, previewForLifting item: UIDragItem, session: any UIDragSession) -> UITargetedDragPreview? {
            guard let view = interaction.view, let image = item.localObject as? UIImage else { return nil }
            let parameters = UIDragPreviewParameters()
            parameters.backgroundColor = .clear
            let target = UIDragPreviewTarget(container: view, center: CGPoint(x: view.bounds.midX, y: view.bounds.midY))
            return UITargetedDragPreview(view: UIImageView(image: image), parameters: parameters, target: target)
        }

        func dragInteraction(_ interaction: UIDragInteraction, sessionWillBegin session: any UIDragSession) {
            source.draggedTab = source.id
        }

        func dragInteraction(_ interaction: UIDragInteraction, session: any UIDragSession, didEndWith operation: UIDropOperation) {
            if source.draggedTab == source.id { source.draggedTab = nil }
        }

        func dragInteraction(_ interaction: UIDragInteraction, sessionIsRestrictedToDraggingApplication session: any UIDragSession) -> Bool {
            true
        }
    }
}

private struct TabReorderDropDelegate: DropDelegate {
    let target: UUID
    @Binding var draggedTab: UUID?
    let browser: BrowserModel
    let reduceMotion: Bool

    func validateDrop(info: DropInfo) -> Bool {
        draggedTab != nil && info.hasItemsConforming(to: [TabDragProvider.type])
    }

    func dropEntered(info: DropInfo) {
        guard validateDrop(info: info), let draggedTab, draggedTab != target else { return }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.22)) {
            browser.moveTab(draggedTab, onto: target)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: validateDrop(info: info) ? .move : .cancel)
    }

    func performDrop(info: DropInfo) -> Bool {
        guard validateDrop(info: info) else { return false }
        // Ordering already follows the drag. Moving again here would undo it
        // when the target card has shifted into the source's former position.
        draggedTab = nil
        return true
    }
}

private struct TabCard: View {
    let tab: TabRecord
    let session: TabSession?
    let selected: Bool
    let largeText: Bool
    let previewURL: URL
    @State private var savedPreview: UIImage?
    var select: () -> Void
    var close: () -> Void
    var body: some View {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Button(action: select) {
                                        ZStack {
                                            if let image = session?.snapshot ?? savedPreview {
                                                Image(uiImage: image).resizable().scaledToFill()
                                            } else {
                                                Color.harborNavy
                                                VStack(spacing: 12) {
                                                    if tab.url == nil { HarborMark().frame(width: 64, height: 64) }
                                                    else { Image(systemName: "globe").font(.largeTitle).foregroundStyle(Color.harborWave) }
                                                    Text(tab.url?.host ?? "Harbor").font(.headline).foregroundStyle(.white).lineLimit(2).padding(.horizontal)
                                                }
                                            }
                                        }.frame(height: largeText ? 130 : 205).frame(maxWidth: .infinity)
                                            .clipShape(RoundedRectangle(cornerRadius: 18))
                                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(selected ? Color.accentColor : .clear, lineWidth: 4))
                                    }.buttonStyle(.plain).accessibilityLabel("Open \(tab.title)")
                                    Button(action: close) {
                                        Image(systemName: "xmark").font(.subheadline.bold()).frame(width: 44, height: 44)
                                            .background(.regularMaterial, in: Circle())
                                    }.buttonStyle(.plain).padding(5).accessibilityLabel("Close \(tab.title)")
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    if selected { Image(systemName: "checkmark.circle.fill").foregroundStyle(.tint).accessibilityLabel("Selected") }
                                    Text(tab.title).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    if session?.mediaState == .playing {
                                        Image(systemName: "speaker.wave.2.fill").foregroundStyle(.tint).accessibilityLabel("Media playing")
                                    }
                                }
                                Text(tab.url?.host ?? "Start page").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                if tab.url != nil && session == nil {
                                    Label("Unloaded", systemImage: "moon")
                                        .font(.caption).foregroundStyle(.secondary)
                                        .accessibilityLabel("Unloaded. Opens again when selected.")
                                }
                            }.accessibilityElement(children: .contain)
                                .task(id: session?.previewRevision ?? -1) {
                                    let url = previewURL
                                    let image = await Task.detached(priority: .utility) {
                                        UIImage(contentsOfFile: url.path)?.preparingForDisplay()
                                    }.value
                                    guard !Task.isCancelled else { return }
                                    savedPreview = image
                                }
    }
}
