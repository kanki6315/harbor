import SwiftUI

struct HistoryView: View {
    @Bindable var browser: BrowserModel
    @State private var search = ""
    @State private var confirmClear = false
    @State private var confirmDelete = false
    @FocusState private var searchFocused: Bool
    @State private var selection: Set<UUID> = []
    @State private var editMode: EditMode = .inactive
    @Environment(\.dismiss) private var dismiss

    private var query: String { search.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var entries: [HistoryEntry] {
        browser.archive.history.filter {
            query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) ||
                $0.url.absoluteString.localizedCaseInsensitiveContains(query)
        }.sorted { $0.visitedAt > $1.visitedAt }
    }
    private var days: [(date: Date, entries: [HistoryEntry])] {
        Dictionary(grouping: entries) { Calendar.current.startOfDay(for: $0.visitedAt) }
            .map { (date: $0.key, entries: $0.value) }
            .sorted { $0.date > $1.date }
    }
    private var editing: Bool { editMode.isEditing }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                ForEach(days, id: \.date) { day in
                    Section {
                        ForEach(day.entries) { entry in
                            Group {
                                if editing {
                                    HistoryRow(entry: entry)
                                } else {
                                    Button { browser.navigate(entry.url); dismiss() } label: {
                                        HistoryRow(entry: entry)
                                    }.buttonStyle(.plain)
                                }
                            }
                            .accessibilityIdentifier("historyVisit")
                            .tag(entry.id)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .swipeActions {
                                if !editing {
                                    Button("Delete", role: .destructive) { remove([entry.id]) }
                                }
                            }
                        }
                    } header: {
                        Text(dayTitle(day.date))
                            .font(.subheadline.weight(.semibold))
                            .textCase(nil)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, $editMode)
            .overlay {
                if entries.isEmpty {
                    ContentUnavailableView(query.isEmpty ? "No history yet" : "No matching pages",
                                           systemImage: query.isEmpty ? "clock" : "magnifyingglass",
                                           description: Text(query.isEmpty ? "Pages you visit appear here, only on this device." : "Try another title or address."))
                }
            }
            .navigationTitle("History")
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search history")
            .searchFocused($searchFocused)
            .searchPresentationToolbarBehavior(.avoidHidingContent)
            .onChange(of: search) { _, _ in selection.removeAll() }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(editing ? "Cancel" : "Select") {
                        searchFocused = false
                        selection.removeAll()
                        withAnimation { editMode = editing ? .inactive : .active }
                    }.disabled(entries.isEmpty && !editing)
                        .accessibilityIdentifier("historySelect")
                }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
                ToolbarItemGroup(placement: .bottomBar) {
                    if editing {
                        Button(selection.count == entries.count && !entries.isEmpty ? "Deselect All" : "Select All") {
                            selection = selection.count == entries.count ? [] : Set(entries.map(\.id))
                        }.disabled(entries.isEmpty)
                        Spacer()
                        Button("Delete (\(selection.count))", role: .destructive) { confirmDelete = true }
                            .disabled(selection.isEmpty)
                            .accessibilityIdentifier("historyDeleteSelected")
                    } else {
                        Spacer()
                        Button("Clear All", role: .destructive) { confirmClear = true }
                            .disabled(browser.archive.history.isEmpty)
                    }
                }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) {
                    browser.archive.history.removeAll()
                    browser.saveNow()
                }
            } message: { Text("This removes your local list of visited pages. Website logins and tabs are kept.") }
            .confirmationDialog("Delete selected visits?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete selected visits", role: .destructive) {
                    remove(selection)
                    editMode = .inactive
                }
            } message: { Text("Only the selected visits will be removed from history. Website logins and tabs are kept.") }
        }
    }

    private func remove(_ ids: Set<UUID>) {
        browser.archive.history.removeAll { ids.contains($0.id) }
        selection.subtract(ids)
        browser.saveNow()
    }

    private func dayTitle(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return String(localized: "Today") }
        if calendar.isDateInYesterday(date) { return String(localized: "Yesterday") }
        let style: Date.FormatStyle = calendar.isDate(date, equalTo: Date(), toGranularity: .year)
            ? .dateTime.weekday(.wide).month(.abbreviated).day()
            : .dateTime.year().month(.abbreviated).day()
        return date.formatted(style)
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    @Environment(\.dynamicTypeSize) private var typeSize

    private var address: String { entry.url.host ?? entry.url.absoluteString }
    private var title: String {
        entry.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? address : entry.title
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
                .lineLimit(typeSize.isAccessibilitySize ? nil : 2)
            let layout = typeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
                : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
            layout {
                Text(address)
                    .font(.subheadline)
                    .lineLimit(typeSize.isAccessibilitySize ? 2 : 1)
                    .truncationMode(.middle)
                if !typeSize.isAccessibilitySize { Spacer(minLength: 0) }
                Text(entry.visitedAt, format: .dateTime.hour().minute())
                    .font(.caption)
                    .monospacedDigit()
                    .fixedSize(horizontal: true, vertical: false)
            }.foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

struct BookmarksView: View {
    @Bindable var browser: BrowserModel
    @State private var search = ""
    @Environment(\.dismiss) private var dismiss
    var bookmarks: [Bookmark] {
        browser.archive.bookmarks.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.url.absoluteString.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(bookmarks) { bookmark in
                    Button { browser.navigate(bookmark.url); dismiss() } label: {
                        Label {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(bookmark.title).foregroundStyle(.primary).lineLimit(2)
                                Text(bookmark.url.host ?? bookmark.url.absoluteString).foregroundStyle(.secondary).font(.subheadline)
                            }.padding(.vertical, 4)
                        } icon: { Image(systemName: "bookmark").foregroundStyle(.tint) }
                    }.swipeActions {
                        Button("Delete", role: .destructive) { browser.archive.bookmarks.removeAll { $0.id == bookmark.id }; browser.saveNow() }
                    }
                }
            }.overlay {
                if bookmarks.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "Keep a good find" : "No matching bookmarks", systemImage: "bookmark",
                                           description: Text(search.isEmpty ? "Open a page, then choose Add bookmark from the More menu." : "Try another title or address."))
                }
            }
            .navigationTitle("Bookmarks").searchable(text: $search, prompt: "Search bookmarks")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
    }
}
