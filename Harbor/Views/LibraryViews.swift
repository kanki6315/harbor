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
    @State private var renamingBookmark: Bookmark?
    @State private var renamingFolder: BookmarkFolder?
    @State private var folderName = ""
    @State private var showingFolderName = false
    @State private var movingBookmark: Bookmark?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            folderContents(nil)
                .navigationDestination(for: BookmarkFolder.self) { folder in
                    folderContents(folder.id)
                }
        }
        .sheet(item: $renamingBookmark) { bookmark in
            BookmarkRenameView(browser: browser, bookmark: bookmark)
        }
        .alert(renamingFolder == nil ? "New folder" : "Rename folder", isPresented: $showingFolderName) {
            TextField("Folder name", text: $folderName)
            Button("Cancel", role: .cancel) { renamingFolder = nil }
            Button("Save") {
                if let folder = renamingFolder { browser.renameBookmarkFolder(folder.id, to: folderName) }
                else { browser.createBookmarkFolder(named: folderName) }
                renamingFolder = nil
            }.disabled(!validFolderName)
        } message: {
            Text("Choose a unique name for this folder.")
        }
        .sheet(item: $movingBookmark) { bookmark in
            NavigationStack {
                List {
                    moveDestination("Unfiled", id: nil, bookmark: bookmark)
                    ForEach(browser.archive.bookmarkFolders) { folder in
                        moveDestination(folder.name, id: folder.id, bookmark: bookmark)
                    }
                }
                .navigationTitle("Move bookmark")
                .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { movingBookmark = nil } } }
            }
        }
    }

    private var validFolderName: Bool {
        let name = BookmarkNaming.normalized(folderName)
        return !name.isEmpty && !browser.archive.bookmarkFolders.contains {
            $0.id != renamingFolder?.id && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
        }
    }

    private func bookmarks(in folderID: UUID?) -> [Bookmark] {
        browser.archive.bookmarks.filter { bookmark in
            if search.isEmpty { return bookmark.folderID == folderID }
            let folder = browser.archive.bookmarkFolders.first { $0.id == bookmark.folderID }
            return (folderID == nil || bookmark.folderID == folderID) &&
                (bookmark.title.localizedCaseInsensitiveContains(search) ||
                 bookmark.url.absoluteString.localizedCaseInsensitiveContains(search) ||
                 folder?.name.localizedCaseInsensitiveContains(search) == true)
        }
    }

    private func folderContents(_ folderID: UUID?) -> some View {
        let visibleBookmarks = bookmarks(in: folderID)
        return List {
            if let url = browser.selectedTab.url {
                Section {
                    Button { browser.toggleBookmark(folderID: folderID) } label: {
                        Label(browser.archive.bookmarks.contains(where: { $0.url == url }) ? "Remove bookmark for this page" : "Bookmark this page", systemImage: "bookmark")
                    }.accessibilityIdentifier("bookmarkCurrentPage")
                }
            }
            if folderID == nil && search.isEmpty && !browser.archive.bookmarkFolders.isEmpty {
                foldersSection
            }
            if visibleBookmarks.isEmpty && (folderID != nil || !search.isEmpty || browser.archive.bookmarkFolders.isEmpty) {
                ContentUnavailableView(search.isEmpty ? (folderID == nil ? "Keep a good find" : "This folder is empty") : "No matching bookmarks",
                                       systemImage: folderID == nil ? "bookmark" : "folder",
                                       description: Text(search.isEmpty ? "Bookmark this page, or move saved pages here using their menu." : "Try another name, folder or address."))
                    .listRowBackground(Color.clear)
            } else if !visibleBookmarks.isEmpty {
                Section(search.isEmpty && folderID == nil ? "Unfiled" : "Saved pages") {
                    ForEach(visibleBookmarks) { bookmark in
                        VStack(alignment: .leading, spacing: 12) {
                            bookmarkRow(bookmark)
                            BookmarkNameSuggestionView(browser: browser, bookmarkID: bookmark.id) {
                                browser.useSuggestedBookmarkName(bookmark.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle(folderID.flatMap { id in browser.archive.bookmarkFolders.first { $0.id == id }?.name } ?? "Bookmarks")
        .searchable(text: $search, prompt: folderID == nil ? "Search all bookmarks" : "Search this folder")
        .toolbar {
            if folderID == nil {
                ToolbarItem(placement: .topBarLeading) {
                    Button("New folder", systemImage: "folder.badge.plus") {
                        renamingFolder = nil; folderName = ""; showingFolderName = true
                    }.accessibilityIdentifier("newBookmarkFolder")
                }
            }
            ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
        }
    }

    private var foldersSection: some View {
        Section {
            ForEach(browser.archive.bookmarkFolders) { folder in
                NavigationLink(value: folder) {
                    Label {
                        HStack {
                            Text(folder.name)
                            Spacer()
                            Text(String(browser.archive.bookmarks.filter { $0.folderID == folder.id }.count))
                                .foregroundStyle(.secondary)
                        }
                    } icon: { Image(systemName: "folder").foregroundStyle(.tint) }
                }
                .swipeActions {
                    Button("Delete folder", role: .destructive) { browser.deleteBookmarkFolder(folder.id) }
                    Button("Rename") { beginRenaming(folder) }.tint(.blue)
                }
                .contextMenu {
                    Button("Rename", systemImage: "pencil") { beginRenaming(folder) }
                    Button("Delete folder", systemImage: "trash", role: .destructive) { browser.deleteBookmarkFolder(folder.id) }
                }
            }
        } header: { Text("Folders") } footer: { Text("Deleting a folder keeps its bookmarks in Unfiled.") }
    }

    private func bookmarkRow(_ bookmark: Bookmark) -> some View {
        Button { browser.navigate(bookmark.url); dismiss() } label: {
            Label {
                VStack(alignment: .leading, spacing: 5) {
                    Text(bookmark.title).foregroundStyle(.primary).lineLimit(2)
                    Text(bookmark.url.host ?? (bookmark.url.isFileURL ? "Local page" : bookmark.url.absoluteString))
                        .foregroundStyle(.secondary).font(.subheadline)
                        .lineLimit(2).truncationMode(.middle)
                    if !search.isEmpty, let folder = browser.archive.bookmarkFolders.first(where: { $0.id == bookmark.folderID }) {
                        Text(folder.name).font(.caption).foregroundStyle(.secondary)
                    }
                }.padding(.vertical, 4)
            } icon: { Image(systemName: "bookmark").foregroundStyle(.tint) }
        }
        .buttonStyle(.plain)
        .swipeActions {
            Button("Delete", role: .destructive) { browser.deleteBookmark(bookmark.id) }
            Button("Rename") { beginRenaming(bookmark) }.tint(.blue)
            Button("Move") { movingBookmark = bookmark }.tint(.orange)
        }
        .contextMenu {
            Button("Rename", systemImage: "pencil") { beginRenaming(bookmark) }
            Button("Move to folder", systemImage: "folder") { movingBookmark = bookmark }
            Button("Delete", systemImage: "trash", role: .destructive) { browser.deleteBookmark(bookmark.id) }
        }
    }

    private func moveDestination(_ name: String, id: UUID?, bookmark: Bookmark) -> some View {
        Button {
            browser.moveBookmark(bookmark.id, to: id)
            movingBookmark = nil
        } label: {
            HStack {
                Label(name, systemImage: "folder")
                Spacer()
                if bookmark.folderID == id { Image(systemName: "checkmark").accessibilityLabel("Current folder") }
            }
        }
    }

    private func beginRenaming(_ bookmark: Bookmark) {
        renamingBookmark = bookmark
    }

    private func beginRenaming(_ folder: BookmarkFolder) {
        renamingFolder = folder; folderName = folder.name; showingFolderName = true
    }
}

/// Choice controls are separate from the navigation button, so using a name never opens the page.
private struct BookmarkNameSuggestionView: View {
    @Bindable var browser: BrowserModel
    let bookmarkID: UUID
    var isDraft = false
    let useName: () -> Void

    var body: some View {
        if let state = browser.bookmarkNameStates[bookmarkID] {
            VStack(alignment: .leading, spacing: 10) {
                switch state {
                case .generating:
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("Suggesting a name…")
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("bookmarkNameLoading")
                case .suggested(let name):
                    Text("Suggested name: \(name)")
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("bookmarkNameSuggestion")
                    Button(action: useName) {
                        Text("Use name")
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .accessibilityIdentifier(isDraft ? "useBookmarkNameDraft" : "useBookmarkName")
                case .unavailable:
                    Text("No suggestion available. Your name is unchanged.")
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    browser.keepOriginalBookmarkName(bookmarkID)
                } label: {
                    Text(state == .unavailable ? "Dismiss" : "Keep original")
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                }.accessibilityIdentifier(isDraft ? "keepBookmarkNameDraft" : "keepBookmarkName")
            }
            .font(.subheadline)
            .buttonStyle(.borderless)
            .padding(.vertical, 4)
        }
    }
}

private struct BookmarkRenameView: View {
    @Bindable var browser: BrowserModel
    let bookmark: Bookmark
    @State private var name: String
    @Environment(\.dismiss) private var dismiss

    init(browser: BrowserModel, bookmark: Bookmark) {
        self.browser = browser
        self.bookmark = bookmark
        _name = State(initialValue: bookmark.title)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name)
                        .accessibilityIdentifier("bookmarkRenameName")
                    Button("Suggest nickname", systemImage: "sparkles") {
                        browser.requestBookmarkName(bookmark)
                    }
                    .disabled(browser.bookmarkNameStates[bookmark.id] == .generating)
                    .accessibilityIdentifier("suggestBookmarkNickname")
                    BookmarkNameSuggestionView(browser: browser, bookmarkID: bookmark.id, isDraft: true) {
                        if case .suggested(let suggestion) = browser.bookmarkNameStates[bookmark.id] {
                            name = suggestion
                            browser.keepOriginalBookmarkName(bookmark.id)
                        }
                    }
                } footer: {
                    Text("Suggestions are made on this device. Choose Use name to fill the field, then Save to rename your bookmark.")
                }
            }
            .navigationTitle("Rename bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        browser.renameBookmark(bookmark.id, to: name)
                        dismiss()
                    }.disabled(BookmarkNaming.normalized(name).isEmpty)
                }
            }
        }
        .onDisappear { browser.keepOriginalBookmarkName(bookmark.id) }
    }
}
