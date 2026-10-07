import SwiftUI

struct TabSwitcherView: View {
    @Bindable var browser: BrowserModel
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    private var filtered: [TabRecord] {
        browser.archive.tabs.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || ($0.url?.absoluteString.localizedCaseInsensitiveContains(search) ?? false) }
    }
    var body: some View {
        NavigationStack {
            ScrollView {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: search)
                } else {
                    LazyVGrid(columns: typeSize.isAccessibilitySize ? [GridItem(.flexible())] : [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                        ForEach(filtered) { tab in
                            TabCard(tab: tab, session: browser.sessions[tab.id], selected: tab.id == browser.selectedID,
                                    largeText: typeSize.isAccessibilitySize,
                                    select: { browser.selectTab(tab.id); dismiss() }, close: { browser.closeTab(tab.id) })
                        }
                    }.padding(16)
                }
            }.background(Color(uiColor: .systemGroupedBackground))
                .navigationTitle("\(browser.archive.tabs.count) tabs")
                .searchable(text: $search, prompt: "Search all tabs")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                    ToolbarItem(placement: .bottomBar) {
                        Button("New tab", systemImage: "plus") { browser.newTab(); dismiss() }
                    }
                    if browser.lastClosed != nil {
                        ToolbarItem(placement: .bottomBar) { Button("Undo close", systemImage: "arrow.uturn.backward") { browser.undoClose() } }
                    }
                }
        }.onAppear { Task { await browser.refreshMedia() } }
    }
}

private struct TabCard: View {
    let tab: TabRecord
    let session: TabSession?
    let selected: Bool
    let largeText: Bool
    var select: () -> Void
    var close: () -> Void
    var body: some View {
                            VStack(alignment: .leading, spacing: 8) {
                                ZStack(alignment: .topTrailing) {
                                    Button(action: select) {
                                        ZStack {
                                            if let image = session?.snapshot {
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
                            }.accessibilityElement(children: .contain)
    }
}
