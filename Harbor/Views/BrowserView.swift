import SwiftUI

struct BrowserView: View {
    @State private var browser = BrowserModel()
    var body: some View {
        WebView(webView: browser.webView)
            .safeAreaInset(edge: .bottom) {
                HStack {
                    TextField("Search or enter address", text: $browser.address)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .keyboardType(.webSearch).onSubmit { browser.navigate() }
                    Button("Go", systemImage: "arrow.right") { browser.navigate() }.labelStyle(.iconOnly)
                }.padding().glassEffect().padding()
            }
    }
}
