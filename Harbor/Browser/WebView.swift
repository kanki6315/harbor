// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at https://mozilla.org/MPL/2.0/.

import SwiftUI
import WebKit

struct WebView: UIViewRepresentable {
    let webView: WKWebView
    var contentInsets: UIEdgeInsets = .zero
    var onScrollDown: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        context.coordinator.onScrollDown = onScrollDown
        webView.scrollView.panGestureRecognizer.addTarget(context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        return webView
    }
    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onScrollDown = onScrollDown
        if uiView.scrollView.contentInset != contentInsets {
            uiView.scrollView.contentInset = contentInsets
            uiView.scrollView.verticalScrollIndicatorInsets = contentInsets
        }
    }

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.scrollView.panGestureRecognizer.removeTarget(coordinator, action: #selector(Coordinator.handlePan(_:)))
    }

    final class Coordinator: NSObject {
        var onScrollDown: () -> Void = {}
        private var collapsedThisGesture = false

        @objc func handlePan(_ gesture: UIPanGestureRecognizer) {
            if gesture.state == .began { collapsedThisGesture = false }
            guard gesture.state == .changed, !collapsedThisGesture,
                  let scrollView = gesture.view as? UIScrollView,
                  scrollView.contentSize.height > scrollView.bounds.height,
                  scrollView.contentOffset.y > -scrollView.adjustedContentInset.top,
                  gesture.translation(in: scrollView).y < -24 else { return }
            collapsedThisGesture = true
            onScrollDown()
        }
    }
}
