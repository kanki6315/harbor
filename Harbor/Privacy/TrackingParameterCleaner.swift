// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import Foundation

enum TrackingParameterCleaner {
    static let tracking: Set<String> = ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "utm_id", "gclid", "dclid", "fbclid", "mc_cid", "mc_eid", "msclkid"]
    static let signatures: Set<String> = ["signature", "sig", "token", "access_token", "policy", "key-pair-id", "expires", "hmac", "auth"]
    static let media: Set<String> = ["mp4", "m4v", "mov", "m3u8", "mpd", "mp3", "m4a", "aac", "wav", "ogg", "webm", "ts"]
    static func clean(_ url: URL) -> URL {
        guard ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
              !media.contains(url.pathExtension.lowercased()),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let items = parts.queryItems else { return url }
        // Preserve signed requests byte-for-byte. Even an apparently unrelated parameter may be signed.
        guard !items.contains(where: {
            let name = $0.name.lowercased()
            return signatures.contains(name) || name.hasPrefix("x-amz-") || name.hasPrefix("x-goog-")
        }) else { return url }
        guard items.contains(where: { tracking.contains($0.name.lowercased()) }) else { return url }
        // Keep raw encoding and order of all surviving parameters.
        let kept = (parts.percentEncodedQuery ?? "").split(separator: "&", omittingEmptySubsequences: false).filter {
            let key = String($0.split(separator: "=", maxSplits: 1).first ?? "")
            return !tracking.contains((key.removingPercentEncoding ?? key).lowercased())
        }
        parts.percentEncodedQuery = kept.isEmpty ? nil : kept.joined(separator: "&")
        return parts.url ?? url
    }
}
