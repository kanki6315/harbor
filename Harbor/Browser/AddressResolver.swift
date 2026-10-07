import Foundation

enum AddressResolver {
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
           (host.contains(".") || host == "localhost" || host.contains(":")),
           url.user == nil, url.password == nil {
            return url
        }
        return engine.searchURL(value)
    }
}
