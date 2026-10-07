import Foundation

struct TabRecord: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL?
    var title = "New Tab"
    var lastUsed = Date()
}

struct HistoryEntry: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL
    var title: String
    var visitedAt = Date()
}

struct Bookmark: Codable, Identifiable, Equatable {
    var id = UUID()
    var url: URL
    var title: String
}

enum SearchEngine: String, Codable, CaseIterable, Identifiable {
    case duckDuckGo = "DuckDuckGo", google = "Google", bing = "Bing"
    var id: Self { self }
    func searchURL(_ query: String) -> URL {
        let base: String
        switch self {
        case .duckDuckGo: base = "https://duckduckgo.com/"
        case .google: base = "https://www.google.com/search"
        case .bing: base = "https://www.bing.com/search"
        }
        var parts = URLComponents(string: base)!
        parts.queryItems = [URLQueryItem(name: "q", value: query)]
        return parts.url!
    }
}

struct BrowserSettings: Codable, Equatable {
    var searchEngine: SearchEngine = .duckDuckGo
    var trackerBlocking = true
    var stripTrackingParameters = true
    var restoreTabs = true
    var siteExceptions: Set<String> = []
}

struct BrowserArchive: Codable {
    var version = 1
    var tabs: [TabRecord] = [TabRecord()]
    var selectedTabID: UUID?
    var history: [HistoryEntry] = []
    var bookmarks: [Bookmark] = []
    var settings = BrowserSettings()
}
