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
        if host == "localhost" || host.hasSuffix(".localhost") || host.hasSuffix(".local") { return true }
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
