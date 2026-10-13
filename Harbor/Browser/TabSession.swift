// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WebKit

/// Ephemeral WebKit state. Only TabRecord is serialized.
@MainActor @Observable
final class TabSession: NSObject, Identifiable {
    let id: UUID
    let webView: WKWebView
    weak var browser: BrowserModel?
    var isLoading = false
    var progress = 0.0
    var canGoBack = false
    var canGoForward = false
    var mediaState: WKMediaPlaybackState = .none
    var fullscreen = false
    var loadError: String?
    // WebKit may still expose the previous committed URL after a provisional failure.
    // Keep the request in memory so explicit retry preserves its destination and method.
    private var pendingMainFrameRequest: URLRequest?
    private(set) var failedRequest: URLRequest?
    /// Held only when the preview could not be saved; otherwise the switcher reads it from disk.
    var snapshot: UIImage?
    /// Bumped when a new preview is saved so the switcher reloads it.
    private(set) var previewRevision = 0
    var lastUsed = Date()
    /// Limits automatic reloads after the page's process ends, so a crashing page cannot loop.
    var lastAutomaticReload: Date?
    var hasCommitted = false
    private(set) var isDisposed = false
    private var observations: [NSKeyValueObservation] = []

    init(id: UUID, browser: BrowserModel, configuration: WKWebViewConfiguration? = nil) {
        self.id = id
        self.browser = browser
        let config = configuration ?? WKWebViewConfiguration()
        config.websiteDataStore = browser.websiteDataStore
        config.userContentController = WKUserContentController()
        MediaPolicy.configure(config)
        webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.allowsBackForwardNavigationGestures = true
        webView.isInspectable = false
        observations = [
            webView.observe(\.estimatedProgress, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.progress = view.estimatedProgress }
            },
            webView.observe(\.isLoading, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.isLoading = view.isLoading }
            },
            webView.observe(\.canGoBack, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoBack = view.canGoBack }
            },
            webView.observe(\.canGoForward, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in self?.canGoForward = view.canGoForward }
            },
            webView.observe(\.title, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateMetadata() }
            },
            webView.observe(\.url, options: [.new]) { [weak self] _, _ in
                Task { @MainActor in self?.updateMetadata() }
            },
            webView.observe(\.fullscreenState, options: [.new]) { [weak self] view, _ in
                Task { @MainActor in
                    guard let self else { return }
                    let wasFullscreen = self.fullscreen
                    self.fullscreen = view.fullscreenState != .notInFullscreen
                    // A full-screen tab is never unloaded; recheck the budget once it leaves.
                    if wasFullscreen && !self.fullscreen { self.browser?.scheduleTrim() }
                }
            }
        ]
    }

    func updateMetadata() {
        guard !isDisposed, hasCommitted, let url = webView.url else { return }
        browser?.updateTab(id, url: url, title: webView.title)
    }

    func refreshMediaState() async {
        mediaState = await webView.requestMediaPlaybackState()
    }

    func suspendMediaRecovery() {
        guard !isDisposed else { return }
        webView.evaluateJavaScript("globalThis.harborSuspendMedia?.();", in: nil,
                                   in: MediaPolicy.recoveryWorld, completionHandler: nil)
    }

    func resumeMediaRecovery() {
        guard !isDisposed else { return }
        webView.evaluateJavaScript("globalThis.harborResumeMedia?.();", in: nil,
                                   in: MediaPolicy.recoveryWorld, completionHandler: nil)
    }

    func captureSnapshot() {
        guard !fullscreen, webView.bounds.width > 0, !isLoading else { return }
        let capturedURL = webView.url
        let config = WKSnapshotConfiguration()
        config.snapshotWidth = 320
        webView.takeSnapshot(with: config) { [weak self] image, _ in
            guard let self, !self.isDisposed, self.webView.url == capturedURL,
                  self.browser?.isClearingData == false, let image else { return }
            if self.browser?.savePreview(image, for: self) == true {
                self.snapshot = nil
                self.previewRevision += 1
            } else {
                self.snapshot = image
            }
        }
    }

    func dispose() {
        isDisposed = true
        if browser?.selectedID == id { browser?.dialog = nil }
        browser = nil
        webView.stopLoading()
        webView.pauseAllMediaPlayback(completionHandler: nil)
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
        observations.removeAll()
    }
}

extension TabSession: WKNavigationDelegate {
    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let browser, let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let scheme = url.scheme?.lowercased() ?? ""
        let topLevel = navigationAction.targetFrame?.isMainFrame ?? true
        if !["https", "http", "about", "blob", "data"].contains(scheme) {
            #if DEBUG
            if scheme == "file", browser.isTesting, url.path.hasPrefix(Bundle.main.bundlePath) {
                decisionHandler(.allow); return
            }
            #endif
            if topLevel, navigationAction.navigationType == .linkActivated,
               !["javascript", "file"].contains(scheme) { browser.externalURL = url }
            decisionHandler(.cancel)
            return
        }
        if topLevel, url.host == "apps.apple.com", navigationAction.navigationType == .linkActivated {
            browser.externalURL = url
            decisionHandler(.cancel)
            return
        }
        if navigationAction.shouldPerformDownload {
            decisionHandler(downloadPolicy(isMainFrame: navigationAction.targetFrame?.isMainFrame,
                                           sourceIsMainFrame: navigationAction.sourceFrame.isMainFrame,
                                           navigationType: navigationAction.navigationType))
            return
        }
        if topLevel {
            // Only rewrite explicit links. Script navigations and redirects must retain WebKit history and request semantics.
            if browser.archive.settings.stripTrackingParameters,
               Self.canRewriteTrackingParameters(method: navigationAction.request.httpMethod,
                                                 type: navigationAction.navigationType,
                                                 isMainFrame: navigationAction.targetFrame?.isMainFrame == true) {
                let cleaned = TrackingParameterCleaner.clean(url)
                if cleaned != url {
                    var request = navigationAction.request
                    request.url = cleaned
                    decisionHandler(.cancel)
                    webView.load(request)
                    return
                }
            }
            browser.blocker.apply(to: webView, url: url, settings: browser.archive.settings)
        }
        if navigationAction.targetFrame?.isMainFrame == true {
            pendingMainFrameRequest = navigationAction.request
            failedRequest = nil
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        decisionHandler(responsePolicy(isMainFrame: navigationResponse.isForMainFrame,
                                       canShowMIMEType: navigationResponse.canShowMIMEType,
                                       disposition: disposition))
    }

    func downloadPolicy(isMainFrame: Bool?, sourceIsMainFrame: Bool = false,
                        navigationType: WKNavigationType = .other) -> WKNavigationActionPolicy {
        // A main-page link may download into a new window without a target frame.
        if isMainFrame == true || (isMainFrame == nil && sourceIsMainFrame && navigationType == .linkActivated) {
            return .download
        }
        reportBlockedDownload()
        return .cancel
    }

    func responsePolicy(isMainFrame: Bool, canShowMIMEType: Bool,
                        disposition: String) -> WKNavigationResponsePolicy {
        if canShowMIMEType && !disposition.hasPrefix("attachment") { return .allow }
        if isMainFrame { return .download }
        reportBlockedDownload()
        return .cancel
    }

    private func reportBlockedDownload() {
        browser?.downloads.errorMessage = "Harbor blocked a download from an embedded page or automatic new window. Try opening the download link in a new tab."
    }

    static func canRewriteTrackingParameters(method: String?, type: WKNavigationType, isMainFrame: Bool) -> Bool {
        isMainFrame && method == "GET" && type == .linkActivated
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        loadError = nil
    }
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        hasCommitted = true
        pendingMainFrameRequest = nil
        failedRequest = nil
        loadError = nil
        updateMetadata()
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        updateMetadata()
        if let url = webView.url { browser?.recordVisit(url: url, title: webView.title ?? url.host ?? "Page") }
        captureSnapshot()
        // A loading tab is never unloaded; recheck the budget once it settles.
        browser?.scheduleTrim()
    }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        if failed(error) { failedRequest = pendingMainFrameRequest }
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { failed(error) }
    @discardableResult private func failed(_ error: Error) -> Bool {
        let error = error as NSError
        guard error.code != NSURLErrorCancelled, !(error.domain == "WebKitErrorDomain" && error.code == 102) else { return false }
        loadError = error.localizedDescription
        isLoading = false
        return true
    }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        mediaState = .none
        browser?.contentProcessTerminated(self)
    }
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        browser?.downloads.accept(download)
    }
    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        browser?.downloads.accept(download)
    }
}

extension TabSession: WKUIDelegate {
    func webView(_ webView: WKWebView, contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
                 completionHandler: @escaping (UIContextMenuConfiguration?) -> Void) {
        guard let url = elementInfo.linkURL else { completionHandler(nil); return }
        // Replace WebKit's suggested actions: its Open action can launch the system browser.
        // A custom menu without a preview also avoids a preview commit opening externally.
        completionHandler(UIContextMenuConfiguration(identifier: nil, previewProvider: nil) { [weak self] _ in
            var actions: [UIAction] = []
            if ["http", "https", "about", "blob", "data"].contains(url.scheme?.lowercased() ?? "") {
                actions.append(UIAction(title: "Open Link", image: UIImage(systemName: "arrow.up.right")) { [weak self] _ in
                    self?.webView.load(URLRequest(url: url))
                })
                actions.append(UIAction(title: "Open in New Tab", image: UIImage(systemName: "plus.square.on.square")) { [weak self] _ in
                    self?.browser?.newTab(url: url)
                })
            }
            if ["http", "https"].contains(url.scheme?.lowercased() ?? "") {
                actions.append(UIAction(title: "Open in Default Browser", image: UIImage(systemName: "safari")) { [weak self] _ in
                    UIApplication.shared.open(url) { [weak self] success in
                        if !success { self?.browser?.errorMessage = "This link could not be opened in the default browser." }
                    }
                })
            }
            actions.append(UIAction(title: "Copy Link", image: UIImage(systemName: "doc.on.doc")) { _ in
                UIPasteboard.general.url = url
            })
            return UIMenu(children: actions)
        })
    }

    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard navigationAction.targetFrame == nil else { return nil }
        return browser?.createPopup(configuration: configuration, url: navigationAction.request.url)
    }
    func webViewDidClose(_ webView: WKWebView) { browser?.closeTab(id) }

    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
        guard !isDisposed, let browser, browser.canPresentDialog(from: id) else { completionHandler(); return }
        browser.dialog = WebDialog(title: frame.securityOrigin.host, message: message, kind: .alert) { _ in completionHandler() }
    }
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
        guard !isDisposed, let browser, browser.canPresentDialog(from: id) else { completionHandler(false); return }
        browser.dialog = WebDialog(title: frame.securityOrigin.host, message: message, kind: .confirm) { completionHandler($0 != nil) }
    }
    func webView(_ webView: WKWebView, runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?, initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        guard !isDisposed, let browser, browser.canPresentDialog(from: id) else { completionHandler(nil); return }
        browser.dialog = WebDialog(title: frame.securityOrigin.host, message: prompt, kind: .prompt,
                                   defaultText: defaultText ?? "", completion: completionHandler)
    }
}

@MainActor final class WebDialog: Identifiable {
    enum Kind { case alert, confirm, prompt }
    let id = UUID()
    let title: String
    let message: String
    let kind: Kind
    let defaultText: String
    private var completion: ((String?) -> Void)?
    init(title: String, message: String, kind: Kind, defaultText: String = "", completion: @escaping (String?) -> Void) {
        self.title = title; self.message = message; self.kind = kind
        self.defaultText = defaultText; self.completion = completion
    }
    func finish(_ value: String?) {
        let callback = completion
        completion = nil
        callback?(value)
    }
}
