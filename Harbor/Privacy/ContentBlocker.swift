// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import WebKit
import CryptoKit

@MainActor @Observable
final class ContentBlocker {
    private(set) var ruleList: WKContentRuleList?
    private(set) var failure: String?
    private(set) var ready = false

    private static var sharedRules: Task<WKContentRuleList, Error>?

    func prepare() async {
        defer { ready = true }
        do {
            if Self.sharedRules == nil {
                Self.sharedRules = Task<WKContentRuleList, Error> {
                    let (identifier, rules) = try await Task.detached(priority: .utility) {
                        guard let url = Bundle.main.url(forResource: "tracker-rules", withExtension: "json") else {
                            throw CocoaError(.fileNoSuchFile)
                        }
                        let data = try Data(contentsOf: url)
                        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                        return ("Harbor.trackers." + digest, String(decoding: data, as: UTF8.self))
                    }.value
                    let store = WKContentRuleListStore.default()!
                    let current: WKContentRuleList
                    if let cached = try? await store.contentRuleList(forIdentifier: identifier) {
                        current = cached
                    } else {
                        guard let compiled = try await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rules) else {
                            throw CocoaError(.coderReadCorrupt)
                        }
                        current = compiled
                    }
                    await Self.pruneObsoleteRules(in: store, keeping: identifier)
                    return current
                }
            }
            ruleList = try await Self.sharedRules!.value
        } catch {
            Self.sharedRules = nil
            failure = "Tracker rules could not load. Browsing remains available. \(error.localizedDescription)"
        }
    }

    static func pruneObsoleteRules(in store: WKContentRuleListStore, keeping identifier: String) async {
        // Only remove Harbor tracker caches, and only after the replacement is usable.
        let identifiers = await store.availableIdentifiers() ?? []
        for old in identifiers where old.hasPrefix("Harbor.trackers.") && old != identifier {
            try? await store.removeContentRuleList(forIdentifier: old)
        }
    }

    func apply(to webView: WKWebView, url: URL?, settings: BrowserSettings) {
        let controller = webView.configuration.userContentController
        controller.removeAllContentRuleLists()
        guard settings.trackerBlocking, let ruleList,
              !settings.siteExceptions.contains(Self.siteKey(url) ?? "") else { return }
        controller.add(ruleList)
    }

    static func siteKey(_ url: URL?) -> String? {
        guard let host = url?.host?.lowercased(), !host.isEmpty else { return nil }
        return host.hasSuffix(".") ? String(host.dropLast()) : host
    }
}
