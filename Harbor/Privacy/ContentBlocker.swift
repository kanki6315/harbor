// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation
import WebKit

@MainActor @Observable
final class ContentBlocker {
    private(set) var ruleList: WKContentRuleList?
    private(set) var failure: String?
    private(set) var ready = false

    func prepare() async {
        defer { ready = true }
        do {
            guard let url = Bundle.main.url(forResource: "tracker-rules", withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile)
            }
            let rules = try String(contentsOf: url, encoding: .utf8)
            ruleList = try await WKContentRuleListStore.default().compileContentRuleList(
                forIdentifier: "Harbor.trackers.v1", encodedContentRuleList: rules)
        } catch { failure = "Tracker rules could not load. Browsing remains available. \(error.localizedDescription)" }
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
