import SwiftUI
import WebKit

struct WebViewRepresentable: NSViewRepresentable {
    let controller: WebViewController

    func makeNSView(context: Context) -> WKWebView {
        controller.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Controller owns navigation; nothing to sync.
    }
}
