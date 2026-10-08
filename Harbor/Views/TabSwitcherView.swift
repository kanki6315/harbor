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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var filtered: [TabRecord] {
        browser.archive.tabs.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || ($0.url?.absoluteString.localizedCaseInsensitiveContains(search) ?? false) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible(), alignment: .top)] : [GridItem(.flexible(), alignment: .top), GridItem(.flexible(), alignment: .top)], spacing: 20) {
                        ForEach(filtered) { tab in
                            TabCard(tab: tab, session: browser.sessions[tab.id], selected: tab.id == browser.selectedID,
                                    largeText: typeSize.isAccessibilitySize, previewURL: browser.previewURL(tab.id),
                                    select: { browser.selectTab(tab.id); dismiss() }, close: { browser.closeTab(tab.id) })
                                .onDrag {
                                    draggedTab = tab.id
                                    let provider = NSItemProvider()
                                    provider.registerDataRepresentation(forTypeIdentifier: TabDragProvider.type.identifier, visibility: .ownProcess) { completion in
                                        completion(Data(tab.id.uuidString.utf8), nil)
                                        return nil
                                    }
                                    return provider
                                }
                                .onDrop(of: [TabDragProvider.type], delegate: TabReorderDropDelegate(
                                    target: tab.id, draggedTab: $draggedTab,
                                    browser: browser, reduceMotion: reduceMotion))
                                .accessibilityAction(named: "Move earlier") { move(tab, by: -1) }
                                .accessibilityAction(named: "Move later") { move(tab, by: 1) }
                        }
                    }.padding(16)
                }
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle(browser.archive.tabs.count == 1 ? "1 tab" : "\(browser.archive.tabs.count) tabs")
                .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search all tabs")
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
        .onAppear { Task { await browser.refreshMedia() } }
        .onDisappear { draggedTab = nil }
    }
    private func move(_ tab: TabRecord, by offset: Int) {
        guard let index = browser.archive.tabs.firstIndex(where: { $0.id == tab.id }),
              browser.archive.tabs.indices.contains(index + offset) else { return }
        browser.moveTab(tab.id, onto: browser.archive.tabs[index + offset].id)
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
                        .accessibilityAction(named: "Move earlier") { move(tab, by: -1) }
                        .accessibilityAction(named: "Move later") { move(tab, by: 1) }
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
                                .task(id: session == nil) {
                                    savedPreview = UIImage(contentsOfFile: previewURL.path)
                                }
    }
}
