// WebKit stub — the subset the app shell uses (signatures follow Apple's docs).
import Foundation
import UIKit

@preconcurrency @MainActor open class UIScrollView: UIView {
    public enum ContentInsetAdjustmentBehavior: Int { case automatic, scrollableAxes, never, always }
    open var isScrollEnabled: Bool = true
    open var bounces: Bool = true
    open var contentInsetAdjustmentBehavior: ContentInsetAdjustmentBehavior = .automatic
    open var showsVerticalScrollIndicator: Bool = true
    open var showsHorizontalScrollIndicator: Bool = true
}

public struct WKAudiovisualMediaTypes: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let audio = WKAudiovisualMediaTypes(rawValue: 1)
    public static let video = WKAudiovisualMediaTypes(rawValue: 2)
    public static let all = WKAudiovisualMediaTypes(rawValue: 3)
}

open class WKPreferences: NSObject {
    public override init() { super.init() }
    open var javaScriptCanOpenWindowsAutomatically: Bool = false
}

open class WKWebpagePreferences: NSObject {
    public override init() { super.init() }
    open var allowsContentJavaScript: Bool = true
}

open class WKWebViewConfiguration: NSObject {
    public override init() { super.init() }
    open var allowsInlineMediaPlayback: Bool = false
    open var mediaTypesRequiringUserActionForPlayback: WKAudiovisualMediaTypes = .all
    open var allowsAirPlayForMediaPlayback: Bool = true
    open var allowsPictureInPictureMediaPlayback: Bool = true
    open var preferences: WKPreferences = WKPreferences()
    open var defaultWebpagePreferences: WKWebpagePreferences = WKWebpagePreferences()
    open var suppressesIncrementalRendering: Bool = false
}

open class WKNavigation: NSObject {}
open class WKFrameInfo: NSObject { open var isMainFrame: Bool { true } }
open class WKNavigationAction: NSObject { open var request: URLRequest { URLRequest(url: URL(fileURLWithPath: "/")) } }
public enum WKNavigationActionPolicy: Int { case cancel, allow, download }

@MainActor public protocol WKNavigationDelegate: NSObjectProtocol {
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!)
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error)
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error)
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView)
}
extension WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {}
    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {}
    public func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {}
    public func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {}
}

@MainActor public protocol WKUIDelegate: NSObjectProtocol {
    func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void)
    func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void)
}
extension WKUIDelegate {
    public func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor () -> Void) { completionHandler() }
    public func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping @MainActor (Bool) -> Void) { completionHandler(false) }
}

@preconcurrency @MainActor open class WKWebView: UIView {
    public init(frame: CGRect, configuration: WKWebViewConfiguration) { super.init(frame: frame) }
    open weak var navigationDelegate: WKNavigationDelegate?
    open weak var uiDelegate: WKUIDelegate?
    open var scrollView: UIScrollView { UIScrollView() }
    open var url: URL? { nil }
    open var isOpaque: Bool = true
    open var isInspectable: Bool = false
    open var allowsBackForwardNavigationGestures: Bool = false
    open var allowsLinkPreview: Bool = true
    open var customUserAgent: String?
    @discardableResult open func load(_ request: URLRequest) -> WKNavigation? { nil }
    @discardableResult open func reload() -> WKNavigation? { nil }
    open func evaluateJavaScript(_ javaScriptString: String, completionHandler: (@MainActor (Any?, Error?) -> Void)? = nil) {}
}
