import SwiftUI
import WebKit

/// Full-screen web view for the stage (iPad) and the controller (iPhone):
/// inline media, no user gesture needed for audio, no bounce, reload when the
/// web content process dies or the server is briefly unreachable.
struct WebView: UIViewRepresentable {
    var url: URL

    final class Coordinator: NSObject, WKNavigationDelegate {
        var url: URL
        init(url: URL) { self.url = url }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            retry(webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            webView.reload()
        }

        private func retry(_ webView: WKWebView) {
            let target = url
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { webView.load(URLRequest(url: target)) }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(url: url) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = true
        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.isOpaque = false
        web.backgroundColor = UIColor(red: 0.05, green: 0.03, blue: 0.13, alpha: 1)
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        web.allowsLinkPreview = false
        if #available(iOS 16.4, *) { web.isInspectable = true }
        web.load(URLRequest(url: url))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        if context.coordinator.url != url {
            context.coordinator.url = url
            web.load(URLRequest(url: url))
        }
    }
}
