import SwiftUI
import CoreText

@main
struct HarborApp: App {
    init() {
        if let font = Bundle.main.url(forResource: "InterVariable", withExtension: "ttf") {
            CTFontManagerRegisterFontsForURL(font as CFURL, .process, nil)
        }
    }
    var body: some Scene { WindowGroup { BrowserView() } }
}
