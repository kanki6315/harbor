import SwiftUI
import WebKit

@MainActor @Observable
final class BrowserModel {
    var archive: BrowserArchive
    var webView: WKWebView
    var address = ""
    var errorMessage: String?
    private let store: BrowserStore
    init(store: BrowserStore = BrowserStore()) {
        self.store = store
        archive = (try? store.load()) ?? BrowserArchive()
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        MediaPolicy.configure(configuration)
        webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
    }
    func navigate() {
        guard let url = AddressResolver.resolve(address, engine: archive.settings.searchEngine) else { return }
        webView.load(URLRequest(url: url))
    }
}
