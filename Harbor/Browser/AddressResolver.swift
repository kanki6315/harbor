// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import Network

enum AddressResolver {
    // Bundled IANA root-zone snapshot: no typed address is sent to a lookup service.
    private static let domainSuffixes: Set<String> = {
        guard let url = Bundle.main.url(forResource: "tlds-alpha-by-domain", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return ["com", "org", "net"] }
        return Set(text.split(separator: "\n").filter { !$0.hasPrefix("#") }.map { $0.lowercased() })
    }()

    private static func isAddressHost(_ host: String) -> Bool {
        let host = host.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: "."))
        let localSuffixes = ["localhost", "local", "lan", "internal", "home.arpa", "corp"]
        if host == "localhost" || localSuffixes.contains(where: { host.hasSuffix("." + $0) }) { return true }
        let components = host.split(separator: ".", omittingEmptySubsequences: false)
        if components.count == 4, components.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
           IPv4Address(host) != nil { return true }
        if IPv6Address(host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))) != nil { return true }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        return labels.count > 1 && labels.allSatisfy { !$0.isEmpty } && domainSuffixes.contains(String(labels.last!))
    }

    static func resolve(_ input: String, engine: SearchEngine) -> URL? {
        let value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        if !value.contains(where: \.isWhitespace), let url = URL(string: value),
           let scheme = url.scheme?.lowercased(), ["https", "http", "mailto", "tel"].contains(scheme) {
            if ["http", "https"].contains(scheme), url.host == nil { return engine.searchURL(value) }
            return url
        }
        if !value.contains(where: \.isWhitespace),
           let url = URL(string: "https://" + value), let host = url.host,
           isAddressHost(host),
           url.user == nil, url.password == nil {
            return url
        }
        return engine.searchURL(value)
    }
}

struct AddressSuggestion: Identifiable, Equatable {
    enum Kind: Equatable { case tab(UUID), bookmark, history }
    var url: URL
    var title: String
    var kind: Kind
    var id: String { AddressSuggestions.key(url) }
}

/// Completions drawn only from this profile's tabs, bookmarks and history.
/// Typed text never leaves the device for a suggestion service.
enum AddressSuggestions {
    /// Matches one page however it was reached: scheme, "www." and a trailing slash are ignored.
    static func key(_ url: URL) -> String {
        var text = url.absoluteString.lowercased()
        for prefix in ["https://", "http://"] where text.hasPrefix(prefix) { text.removeFirst(prefix.count) }
        if text.hasPrefix("www.") { text.removeFirst(4) }
        if text.hasSuffix("/") { text.removeLast() }
        return text
    }

    static func rank(_ input: String, tabs: [TabRecord], bookmarks: [Bookmark],
                     history: [HistoryEntry], limit: Int = 4) -> [AddressSuggestion] {
        let query = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return [] }
        var bareQuery = query
        for prefix in ["https://", "http://", "www."] where bareQuery.hasPrefix(prefix) { bareQuery.removeFirst(prefix.count) }
        let terms = bareQuery.split(whereSeparator: \.isWhitespace).map(String.init)
        guard !terms.isEmpty else { return [] }

        var visits: [String: Int] = [:]
        for entry in history { visits[key(entry.url), default: 0] += 1 }

        var best: [String: (suggestion: AddressSuggestion, score: Int)] = [:]
        func consider(_ url: URL, _ title: String, _ kind: AddressSuggestion.Kind, bonus: Int) {
            guard ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return }
            let address = key(url), name = title.lowercased()
            guard terms.allSatisfy({ address.contains($0) || name.contains($0) }) else { return }
            var score: Int
            if address.hasPrefix(bareQuery) { score = 100 }
            else if address.split(separator: ".").contains(where: { $0.hasPrefix(bareQuery) }) { score = 80 }
            else if name.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(where: { $0.hasPrefix(terms[0]) }) { score = 60 }
            else { score = 30 }
            score += bonus + min(20, 2 * (visits[address] ?? 0))
            // Shorter addresses first among equals, so a site's home page beats its deep links.
            score -= min(10, address.count / 20)
            if let existing = best[address], existing.score >= score { return }
            let label = title.isEmpty || title == "New Tab" ? (url.host ?? address) : title
            best[address] = (AddressSuggestion(url: url, title: label, kind: kind), score)
        }
        for entry in history { consider(entry.url, entry.title, .history, bonus: 0) }
        for bookmark in bookmarks { consider(bookmark.url, bookmark.title, .bookmark, bonus: 20) }
        for tab in tabs { if let url = tab.url { consider(url, tab.title, .tab(tab.id), bonus: 30) } }
        return best.values.sorted { $0.score != $1.score ? $0.score > $1.score : $0.suggestion.id < $1.suggestion.id }
            .prefix(limit).map(\.suggestion)
    }
}
