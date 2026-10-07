import SwiftUI

struct HistoryView: View {
    @Bindable var browser: BrowserModel
    @State private var search = ""
    @State private var confirmClear = false
    @Environment(\.dismiss) private var dismiss
    var entries: [HistoryEntry] {
        browser.archive.history.filter { search.isEmpty || $0.title.localizedCaseInsensitiveContains(search) || $0.url.absoluteString.localizedCaseInsensitiveContains(search) }
    }
    var body: some View {
        NavigationStack {
            List {
                ForEach(entries) { entry in
                    Button { browser.navigate(entry.url); dismiss() } label: {
                        VStack(alignment: .leading, spacing: 5) {
                            Text(entry.title).foregroundStyle(.primary).lineLimit(2)
                            Text(entry.url.host ?? entry.url.absoluteString).foregroundStyle(.secondary).font(.subheadline)
                            Text(entry.visitedAt, format: .dateTime.month().day().hour().minute()).foregroundStyle(.secondary).font(.caption)
                        }.padding(.vertical, 4)
                    }.swipeActions {
                        Button("Delete", role: .destructive) { browser.archive.history.removeAll { $0.id == entry.id }; browser.saveNow() }
                    }
                }
            }.overlay {
                if entries.isEmpty {
                    ContentUnavailableView(search.isEmpty ? "No history yet" : "No matching pages", systemImage: "clock",
                                           description: Text(search.isEmpty ? "Pages you visit appear here, only on this device." : "Try another title or address."))
                }
            }
            .navigationTitle("History").searchable(text: $search, prompt: "Search history")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Clear", role: .destructive) { confirmClear = true }.disabled(browser.archive.history.isEmpty) }
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
            .confirmationDialog("Clear all history?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear history", role: .destructive) { browser.archive.history.removeAll(); browser.saveNow() }
            } message: { Text("This removes your local list of visited pages. Website logins and tabs are kept.") }
        }
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
