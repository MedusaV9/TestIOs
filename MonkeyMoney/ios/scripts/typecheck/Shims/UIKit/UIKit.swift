// UIKit stub — only the surface SoooDreamy touches directly (UIImage,
// haptics, pasteboard, app/device info, representable hosting).
@_exported import Foundation
@_exported import DarwinShims

// MARK: CoreGraphics reference types (normally via CoreGraphics)

public class CGImage {
    public init() {}
    public var width: Int { 0 }
    public var height: Int { 0 }
    public var bytesPerRow: Int { 0 }
    public var colorSpace: CGColorSpace? { nil }
    public func cropping(to rect: CGRect) -> CGImage? { self }
}
public class CGColor {
    public init() {}
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) {}
    public init(gray: CGFloat, alpha: CGFloat) {}
    public var components: [CGFloat]? { nil }
    public var alpha: CGFloat { 1 }
    public static let black = CGColor(gray: 0, alpha: 1), white = CGColor(gray: 1, alpha: 1), clear = CGColor(gray: 0, alpha: 0)
}
public class CGContext {
    public init() {}
    public func setFillColor(_ color: CGColor) {}
    public func fill(_ rect: CGRect) {}
    public func draw(_ image: CGImage, in rect: CGRect) {}
    public func translateBy(x: CGFloat, y: CGFloat) {}
    public func scaleBy(x: CGFloat, y: CGFloat) {}
    public func rotate(by angle: CGFloat) {}
    public func saveGState() {}
    public func restoreGState() {}
}
public class CGColorSpace {
    public init() {}
    public init?(name: CFStringLike) {}
    public static let sRGB: CFStringLike = "kCGColorSpaceSRGB"
    public static let displayP3: CFStringLike = "kCGColorSpaceDisplayP3"
}
public typealias CFStringLike = String
public func CGColorSpaceCreateDeviceRGB() -> CGColorSpace { CGColorSpace() }
public enum CGLineCap: Int32, Sendable { case butt, round, square }
public enum CGLineJoin: Int32, Sendable { case miter, round, bevel }
public enum CGBlendMode: Int32, Sendable { case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity, clear, copy, sourceIn, sourceOut, sourceAtop, destinationOver, destinationIn, destinationOut, destinationAtop, xor, plusDarker, plusLighter }

// MARK: QuartzCore

open class CALayer: NSObject {
    public override init() { super.init() }
    open var frame: CGRect = .zero
    open var bounds: CGRect = .zero
    open var cornerRadius: CGFloat = 0
    open var masksToBounds: Bool = false
    open var backgroundColor: CGColor?
    open var opacity: Float = 1
    open var sublayers: [CALayer]? { nil }
    open func addSublayer(_ layer: CALayer) {}
    open func insertSublayer(_ layer: CALayer, at idx: UInt32) {}
    open func removeFromSuperlayer() {}
    open func setNeedsLayout() {}
    open func layoutIfNeeded() {}
}

// MARK: Responders, views, controllers

open class UIResponder: NSObject {
    public override init() { super.init() }
    open func becomeFirstResponder() -> Bool { false }
    open func resignFirstResponder() -> Bool { false }
    open func motionBegan(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
    open func motionEnded(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
    open func motionCancelled(_ motion: UIEvent.EventSubtype, with event: UIEvent?) {}
}

open class UIEvent: NSObject {
    public enum EventType: Int { case touches, motion, remoteControl, presses, scroll, hover, transform }
    public enum EventSubtype: Int {
        case none, motionShake, remoteControlPlay, remoteControlPause, remoteControlStop,
             remoteControlTogglePlayPause, remoteControlNextTrack, remoteControlPreviousTrack,
             remoteControlBeginSeekingBackward, remoteControlEndSeekingBackward,
             remoteControlBeginSeekingForward, remoteControlEndSeekingForward
    }
    open var type: EventType { .touches }
    open var subtype: EventSubtype { .none }
}

@preconcurrency @MainActor open class UIView: UIResponder {
    public override init() { super.init() }
    public init(frame: CGRect) { super.init() }
    open var frame: CGRect = .zero
    open var bounds: CGRect = .zero
    open var center: CGPoint = .zero
    open var backgroundColor: UIColor?
    open var alpha: CGFloat = 1
    open var isHidden: Bool = false
    open var isUserInteractionEnabled: Bool = true
    open var layer: CALayer { CALayer() }
    open var subviews: [UIView] { [] }
    open var superview: UIView? { nil }
    open var window: UIWindow? { nil }
    open var tintColor: UIColor!
    open var clipsToBounds: Bool = false
    open var transform: CGAffineTransform = .identity
    open var contentMode: ContentMode = .scaleToFill
    open var translatesAutoresizingMaskIntoConstraints: Bool = true
    open var safeAreaInsets: UIEdgeInsets { .zero }
    open var traitCollection: UITraitCollection { UITraitCollection() }
    open func addSubview(_ view: UIView) {}
    open func removeFromSuperview() {}
    open func setNeedsLayout() {}
    open func layoutIfNeeded() {}
    open func layoutSubviews() {}
    open func setNeedsDisplay() {}
    open func endEditing(_ force: Bool) -> Bool { true }
    open func sizeToFit() {}
    open func sizeThatFits(_ size: CGSize) -> CGSize { size }
    open func convert(_ point: CGPoint, to view: UIView?) -> CGPoint { point }
    open func convert(_ rect: CGRect, to view: UIView?) -> CGRect { rect }
    open var intrinsicContentSize: CGSize { .zero }
    open func invalidateIntrinsicContentSize() {}
    public enum ContentMode: Int { case scaleToFill, scaleAspectFit, scaleAspectFill, redraw, center, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight }
    public struct AutoresizingMask: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let flexibleWidth = AutoresizingMask(rawValue: 2); public static let flexibleHeight = AutoresizingMask(rawValue: 16) }
    open var autoresizingMask: AutoresizingMask = []
    public static func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void) {}
    public static func animate(withDuration duration: TimeInterval, animations: @escaping () -> Void, completion: ((Bool) -> Void)?) {}
}

@preconcurrency @MainActor open class UIWindow: UIView {
    public override init() { super.init() }
    public init(windowScene: UIWindowScene) { super.init() }
    open var rootViewController: UIViewController?
    open var isKeyWindow: Bool { false }
    open var windowScene: UIWindowScene? { nil }
    open func makeKeyAndVisible() {}
}

@preconcurrency @MainActor open class UIScene: UIResponder {
    public override init() { super.init() }
    open var activationState: ActivationState { .foregroundActive }
    public enum ActivationState: Int { case unattached = -1, foregroundActive, foregroundInactive, background }
}
@preconcurrency @MainActor open class UIWindowScene: UIScene {
    public override init() { super.init() }
    open var windows: [UIWindow] { [] }
    open var keyWindow: UIWindow? { nil }
    open var interfaceOrientation: UIInterfaceOrientation { .portrait }
    open var screen: UIScreen { UIScreen() }
}

public enum UIInterfaceOrientation: Int { case unknown, portrait, portraitUpsideDown, landscapeLeft, landscapeRight }
public struct UIInterfaceOrientationMask: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let portrait = UIInterfaceOrientationMask(rawValue: 2); public static let all = UIInterfaceOrientationMask(rawValue: 30) }

@preconcurrency @MainActor open class UIViewController: UIResponder {
    public override init() { super.init() }
    public init(nibName: String?, bundle: Bundle?) { super.init() }
    open var view: UIView! = UIView()
    open var title: String?
    open var isViewLoaded: Bool { true }
    open var presentingViewController: UIViewController? { nil }
    open var presentedViewController: UIViewController? { nil }
    open var navigationController: UINavigationController? { nil }
    open var modalPresentationStyle: UIModalPresentationStyle = .automatic
    open var isBeingDismissed: Bool { false }
    open var traitCollection: UITraitCollection { UITraitCollection() }
    open func loadView() {}
    open func viewDidLoad() {}
    open func viewWillAppear(_ animated: Bool) {}
    open func viewDidAppear(_ animated: Bool) {}
    open func viewWillDisappear(_ animated: Bool) {}
    open func viewDidDisappear(_ animated: Bool) {}
    open func viewWillLayoutSubviews() {}
    open func viewDidLayoutSubviews() {}
    open func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)? = nil) {}
    open func dismiss(animated flag: Bool, completion: (() -> Void)? = nil) {}
    open func addChild(_ childController: UIViewController) {}
    open func removeFromParent() {}
    open func didMove(toParent parent: UIViewController?) {}
    open var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
}
@preconcurrency @MainActor open class UINavigationController: UIViewController {
    public override init() { super.init() }
    open var viewControllers: [UIViewController] = []
    open func pushViewController(_ viewController: UIViewController, animated: Bool) {}
    open func popViewController(animated: Bool) -> UIViewController? { nil }
}
public enum UIModalPresentationStyle: Int { case fullScreen, pageSheet, formSheet, currentContext, custom, overFullScreen, overCurrentContext, popover, automatic = -2 }

open class UITraitCollection: NSObject {
    public override init() { super.init() }
    open var userInterfaceStyle: UIUserInterfaceStyle { .light }
    open var horizontalSizeClass: UIUserInterfaceSizeClass { .compact }
    open var verticalSizeClass: UIUserInterfaceSizeClass { .regular }
    open var displayScale: CGFloat { 3 }
    open var preferredContentSizeCategory: UIContentSizeCategory { .large }
    open var userInterfaceIdiom: UIUserInterfaceIdiom { .phone }
}
public enum UIUserInterfaceStyle: Int { case unspecified, light, dark }
public enum UIUserInterfaceSizeClass: Int { case unspecified, compact, regular }
public enum UIUserInterfaceIdiom: Int { case unspecified = -1, phone, pad, tv, carPlay, mac = 5, vision = 6 }
public struct UIContentSizeCategory: RawRepresentable, Equatable, Hashable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let extraSmall = UIContentSizeCategory(rawValue: "XS"), small = UIContentSizeCategory(rawValue: "S"),
        medium = UIContentSizeCategory(rawValue: "M"), large = UIContentSizeCategory(rawValue: "L"),
        extraLarge = UIContentSizeCategory(rawValue: "XL"), extraExtraLarge = UIContentSizeCategory(rawValue: "XXL"),
        extraExtraExtraLarge = UIContentSizeCategory(rawValue: "XXXL"), accessibilityMedium = UIContentSizeCategory(rawValue: "AM"),
        accessibilityLarge = UIContentSizeCategory(rawValue: "AL"), accessibilityExtraLarge = UIContentSizeCategory(rawValue: "AXL"),
        accessibilityExtraExtraLarge = UIContentSizeCategory(rawValue: "AXXL"), accessibilityExtraExtraExtraLarge = UIContentSizeCategory(rawValue: "AXXXL")
}

public struct UIEdgeInsets: Equatable {
    public var top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat
    public init() { top = 0; left = 0; bottom = 0; right = 0 }
    public init(top: CGFloat, left: CGFloat, bottom: CGFloat, right: CGFloat) { self.top = top; self.left = left; self.bottom = bottom; self.right = right }
    public static let zero = UIEdgeInsets()
}

public struct UIRectCorner: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let topLeft = UIRectCorner(rawValue: 1), topRight = UIRectCorner(rawValue: 2), bottomLeft = UIRectCorner(rawValue: 4), bottomRight = UIRectCorner(rawValue: 8), allCorners = UIRectCorner(rawValue: 15) }

// MARK: UIColor

open class UIColor: NSObject {
    public override init() { super.init() }
    public init(red: CGFloat, green: CGFloat, blue: CGFloat, alpha: CGFloat) { super.init() }
    public init(white: CGFloat, alpha: CGFloat) { super.init() }
    public init(hue: CGFloat, saturation: CGFloat, brightness: CGFloat, alpha: CGFloat) { super.init() }
    public init(cgColor: CGColor) { super.init() }
    public init?(named name: String) { super.init() }
    public init?(named name: String, in bundle: Bundle?, compatibleWith traitCollection: UITraitCollection?) { super.init() }
    public init(dynamicProvider: @escaping (UITraitCollection) -> UIColor) { super.init() }
    open var cgColor: CGColor { CGColor() }
    open func withAlphaComponent(_ alpha: CGFloat) -> UIColor { self }
    open func resolvedColor(with traitCollection: UITraitCollection) -> UIColor { self }
    open func getRed(_ red: UnsafeMutablePointer<CGFloat>?, green: UnsafeMutablePointer<CGFloat>?, blue: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) -> Bool { true }
    open func getHue(_ hue: UnsafeMutablePointer<CGFloat>?, saturation: UnsafeMutablePointer<CGFloat>?, brightness: UnsafeMutablePointer<CGFloat>?, alpha: UnsafeMutablePointer<CGFloat>?) -> Bool { true }

    public static let black = UIColor(), white = UIColor(), clear = UIColor(), red = UIColor(), green = UIColor(), blue = UIColor(),
        yellow = UIColor(), orange = UIColor(), purple = UIColor(), gray = UIColor(), lightGray = UIColor(), darkGray = UIColor(),
        cyan = UIColor(), magenta = UIColor(), brown = UIColor()
    public static let systemRed = UIColor(), systemGreen = UIColor(), systemBlue = UIColor(), systemOrange = UIColor(),
        systemYellow = UIColor(), systemPink = UIColor(), systemPurple = UIColor(), systemTeal = UIColor(), systemIndigo = UIColor(),
        systemBrown = UIColor(), systemMint = UIColor(), systemCyan = UIColor(), systemGray = UIColor(), systemGray2 = UIColor(),
        systemGray3 = UIColor(), systemGray4 = UIColor(), systemGray5 = UIColor(), systemGray6 = UIColor()
    public static let label = UIColor(), secondaryLabel = UIColor(), tertiaryLabel = UIColor(), quaternaryLabel = UIColor(),
        placeholderText = UIColor(), link = UIColor(), separator = UIColor(), opaqueSeparator = UIColor(),
        systemBackground = UIColor(), secondarySystemBackground = UIColor(), tertiarySystemBackground = UIColor(),
        systemGroupedBackground = UIColor(), secondarySystemGroupedBackground = UIColor(), tertiarySystemGroupedBackground = UIColor(),
        systemFill = UIColor(), secondarySystemFill = UIColor(), tertiarySystemFill = UIColor(), quaternarySystemFill = UIColor(),
        lightText = UIColor(), darkText = UIColor(), tintColor = UIColor()
}

// MARK: UIImage & rendering

open class UIImage: NSObject {
    public override init() { super.init() }
    public init?(data: Data) { super.init() }
    public init?(data: Data, scale: CGFloat) { super.init() }
    public init?(named name: String) { super.init() }
    public init?(named name: String, in bundle: Bundle?, with configuration: UIImage.Configuration?) { super.init() }
    public init?(systemName: String) { super.init() }
    public init?(systemName: String, withConfiguration configuration: UIImage.Configuration?) { super.init() }
    public init?(contentsOfFile path: String) { super.init() }
    public init(cgImage: CGImage) { super.init() }
    public init(cgImage: CGImage, scale: CGFloat, orientation: UIImage.Orientation) { super.init() }
    public init(ciImage: AnyObject) { super.init() }

    open var size: CGSize { .zero }
    open var scale: CGFloat { 1 }
    open var cgImage: CGImage? { nil }
    open var imageOrientation: Orientation { .up }
    open var isSymbolImage: Bool { false }
    open func jpegData(compressionQuality: CGFloat) -> Data? { nil }
    open func pngData() -> Data? { nil }
    open func draw(in rect: CGRect) {}
    open func draw(at point: CGPoint) {}
    open func withRenderingMode(_ renderingMode: RenderingMode) -> UIImage { self }
    open func withTintColor(_ color: UIColor) -> UIImage { self }
    open func withTintColor(_ color: UIColor, renderingMode: RenderingMode) -> UIImage { self }
    open func withConfiguration(_ configuration: Configuration) -> UIImage { self }
    open func resizableImage(withCapInsets capInsets: UIEdgeInsets) -> UIImage { self }
    open func preparingThumbnail(of size: CGSize) -> UIImage? { self }
    open func byPreparingThumbnail(ofSize size: CGSize) async -> UIImage? { self }
    open func preparingForDisplay() -> UIImage? { self }
    open func byPreparingForDisplay() async -> UIImage? { self }

    public enum Orientation: Int { case up, down, left, right, upMirrored, downMirrored, leftMirrored, rightMirrored }
    public enum RenderingMode: Int { case automatic, alwaysOriginal, alwaysTemplate }
    open class Configuration: NSObject {}
    open class SymbolConfiguration: Configuration {
        public init(pointSize: CGFloat) {}
        public init(pointSize: CGFloat, weight: UIImage.SymbolWeight) {}
        public init(scale: UIImage.SymbolScale) {}
        public init(hierarchicalColor: UIColor) {}
        public init(paletteColors: [UIColor]) {}
    }
    public enum SymbolWeight: Int { case unspecified, ultraLight, thin, light, regular, medium, semibold, bold, heavy, black }
    public enum SymbolScale: Int { case `default`, unspecified, small, medium, large }
}

public func UIImageWriteToSavedPhotosAlbum(_ image: UIImage, _ completionTarget: Any?, _ completionSelector: Selector?, _ contextInfo: UnsafeMutableRawPointer?) {}
public func UISaveVideoAtPathToSavedPhotosAlbum(_ videoPath: String, _ completionTarget: Any?, _ completionSelector: Selector?, _ contextInfo: UnsafeMutableRawPointer?) {}
public func UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(_ videoPath: String) -> Bool { true }
public func UIImageJPEGRepresentation(_ image: UIImage, _ compressionQuality: CGFloat) -> Data? { nil }
public func UIImagePNGRepresentation(_ image: UIImage) -> Data? { nil }

open class UIGraphicsRendererFormat: NSObject {
    public required override init() { super.init() }
    open var bounds: CGRect { .zero }
    open class func `default`() -> Self { Self.init() }
}
open class UIGraphicsImageRendererFormat: UIGraphicsRendererFormat {
    public required init() { super.init() }
    open var scale: CGFloat = 1
    open var opaque: Bool = false
    open var preferredRange: Range = .automatic
    public enum Range: Int { case unspecified = -1, automatic, extended, standard }
    open class func preferred() -> Self { Self.init() }
}
open class UIGraphicsRenderer: NSObject {
    public override init() { super.init() }
}
open class UIGraphicsImageRendererContext: NSObject {
    public override init() { super.init() }
    open var cgContext: CGContext { CGContext() }
    open var format: UIGraphicsImageRendererFormat { UIGraphicsImageRendererFormat() }
    open var currentImage: UIImage { UIImage() }
    open func fill(_ rect: CGRect) {}
    open func stroke(_ rect: CGRect) {}
    open func clip(to rect: CGRect) {}
}
open class UIGraphicsImageRenderer: UIGraphicsRenderer {
    public init(size: CGSize) { super.init() }
    public init(size: CGSize, format: UIGraphicsImageRendererFormat) { super.init() }
    public init(bounds: CGRect) { super.init() }
    public init(bounds: CGRect, format: UIGraphicsImageRendererFormat) { super.init() }
    open func image(actions: (UIGraphicsImageRendererContext) -> Void) -> UIImage { UIImage() }
    open func pngData(actions: (UIGraphicsImageRendererContext) -> Void) -> Data { Data() }
    open func jpegData(withCompressionQuality compressionQuality: CGFloat, actions: (UIGraphicsImageRendererContext) -> Void) -> Data { Data() }
}

open class UIBezierPath: NSObject {
    public override init() { super.init() }
    public init(rect: CGRect) { super.init() }
    public init(ovalIn rect: CGRect) { super.init() }
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat) { super.init() }
    public init(roundedRect rect: CGRect, byRoundingCorners corners: UIRectCorner, cornerRadii: CGSize) { super.init() }
    open func move(to point: CGPoint) {}
    open func addLine(to point: CGPoint) {}
    open func addCurve(to endPoint: CGPoint, controlPoint1: CGPoint, controlPoint2: CGPoint) {}
    open func addQuadCurve(to endPoint: CGPoint, controlPoint: CGPoint) {}
    open func close() {}
    open func fill() {}
    open func stroke() {}
    open func addClip() {}
    open var lineWidth: CGFloat = 1
    open var cgPath: AnyObject { self }
}

// MARK: Fonts

open class UIFont: NSObject {
    public override init() { super.init() }
    open var pointSize: CGFloat { 17 }
    open var lineHeight: CGFloat { 22 }
    open var capHeight: CGFloat { 12 }
    open var ascender: CGFloat { 16 }
    open var descender: CGFloat { -4 }
    open class func systemFont(ofSize fontSize: CGFloat) -> UIFont { UIFont() }
    open class func systemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont { UIFont() }
    open class func systemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight, width: UIFont.Width) -> UIFont { UIFont() }
    open class func monospacedSystemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont { UIFont() }
    open class func monospacedDigitSystemFont(ofSize fontSize: CGFloat, weight: UIFont.Weight) -> UIFont { UIFont() }
    open class func boldSystemFont(ofSize fontSize: CGFloat) -> UIFont { UIFont() }
    open class func preferredFont(forTextStyle style: UIFont.TextStyle) -> UIFont { UIFont() }
    public init?(name fontName: String, size fontSize: CGFloat) { super.init() }
    open func withSize(_ fontSize: CGFloat) -> UIFont { self }
    public struct Weight: RawRepresentable, Equatable, Hashable { public let rawValue: CGFloat; public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public static let ultraLight = Weight(rawValue: -0.8), thin = Weight(rawValue: -0.6), light = Weight(rawValue: -0.4), regular = Weight(rawValue: 0),
            medium = Weight(rawValue: 0.23), semibold = Weight(rawValue: 0.3), bold = Weight(rawValue: 0.4), heavy = Weight(rawValue: 0.56), black = Weight(rawValue: 0.62) }
    public struct Width: RawRepresentable, Equatable, Hashable { public let rawValue: CGFloat; public init(rawValue: CGFloat) { self.rawValue = rawValue }
        public static let compressed = Width(rawValue: -0.3), condensed = Width(rawValue: -0.2), standard = Width(rawValue: 0), expanded = Width(rawValue: 0.2) }
    public struct TextStyle: RawRepresentable, Equatable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let largeTitle = TextStyle(rawValue: "largeTitle"), title1 = TextStyle(rawValue: "title1"), title2 = TextStyle(rawValue: "title2"),
            title3 = TextStyle(rawValue: "title3"), headline = TextStyle(rawValue: "headline"), subheadline = TextStyle(rawValue: "subheadline"),
            body = TextStyle(rawValue: "body"), callout = TextStyle(rawValue: "callout"), footnote = TextStyle(rawValue: "footnote"),
            caption1 = TextStyle(rawValue: "caption1"), caption2 = TextStyle(rawValue: "caption2"), extraLargeTitle = TextStyle(rawValue: "xlt"), extraLargeTitle2 = TextStyle(rawValue: "xlt2") }
}
open class UIFontMetrics: NSObject {
    public init(forTextStyle textStyle: UIFont.TextStyle) { super.init() }
    open class var `default`: UIFontMetrics { UIFontMetrics(forTextStyle: .body) }
    open func scaledValue(for value: CGFloat) -> CGFloat { value }
    open func scaledFont(for font: UIFont) -> UIFont { font }
}

// MARK: Haptics

@preconcurrency @MainActor open class UIFeedbackGenerator: NSObject {
    public override init() { super.init() }
    open func prepare() {}
}
@preconcurrency @MainActor open class UIImpactFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackStyle: Int { case light, medium, heavy, soft, rigid }
    public override init() { super.init() }
    public init(style: FeedbackStyle) { super.init() }
    public init(style: FeedbackStyle, view: UIView) { super.init() }
    open func impactOccurred() {}
    open func impactOccurred(intensity: CGFloat) {}
    open func impactOccurred(at location: CGPoint) {}
    open func impactOccurred(intensity: CGFloat, at location: CGPoint) {}
}
@preconcurrency @MainActor open class UINotificationFeedbackGenerator: UIFeedbackGenerator {
    public enum FeedbackType: Int { case success, warning, error }
    public override init() { super.init() }
    open func notificationOccurred(_ notificationType: FeedbackType) {}
    open func notificationOccurred(_ notificationType: FeedbackType, at location: CGPoint) {}
}
@preconcurrency @MainActor open class UISelectionFeedbackGenerator: UIFeedbackGenerator {
    public override init() { super.init() }
    open func selectionChanged() {}
    open func selectionChanged(at location: CGPoint) {}
}

// MARK: Application, device, screen, pasteboard

@preconcurrency @MainActor open class UIApplication: UIResponder {
    public override init() { super.init() }
    open class var shared: UIApplication { UIApplication() }
    open var delegate: (any UIApplicationDelegate)?
    open var applicationState: State { .active }
    open var isIdleTimerDisabled: Bool = false
    open var applicationIconBadgeNumber: Int = 0
    open var connectedScenes: Set<UIScene> { [] }
    open var supportsAlternateIcons: Bool { true }
    open var alternateIconName: String? { nil }
    open var backgroundTimeRemaining: TimeInterval { 30 }
    open var isRegisteredForRemoteNotifications: Bool { false }
    open var preferredContentSizeCategory: UIContentSizeCategory { .large }
    open func setAlternateIconName(_ alternateIconName: String?) async throws {}
    open func setAlternateIconName(_ alternateIconName: String?, completionHandler: ((Error?) -> Void)? = nil) {}
    open func open(_ url: URL, options: [OpenExternalURLOptionsKey: Any] = [:], completionHandler: ((Bool) -> Void)? = nil) {}
    open func open(_ url: URL, options: [OpenExternalURLOptionsKey: Any] = [:]) async -> Bool { true }
    open func canOpenURL(_ url: URL) -> Bool { true }
    open func registerForRemoteNotifications() {}
    open func unregisterForRemoteNotifications() {}
    open func beginBackgroundTask(withName taskName: String? = nil, expirationHandler handler: (() -> Void)? = nil) -> UIBackgroundTaskIdentifier { UIBackgroundTaskIdentifier(rawValue: 1) }
    open func endBackgroundTask(_ identifier: UIBackgroundTaskIdentifier) {}
    open func sendAction(_ action: Selector, to target: Any?, from sender: Any?, for event: UIEvent?) -> Bool { true }

    public enum State: Int { case active, inactive, background }
    public struct OpenExternalURLOptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let universalLinksOnly = OpenExternalURLOptionsKey(rawValue: "ulo") }
    public struct LaunchOptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let url = LaunchOptionsKey(rawValue: "url"), remoteNotification = LaunchOptionsKey(rawValue: "rn"), shortcutItem = LaunchOptionsKey(rawValue: "si") }
    public static let openSettingsURLString = "app-settings:"
    public static let openNotificationSettingsURLString = "app-settings:notifications"
    public static let didBecomeActiveNotification = Notification.Name("UIApplicationDidBecomeActive")
    public static let willResignActiveNotification = Notification.Name("UIApplicationWillResignActive")
    public static let didEnterBackgroundNotification = Notification.Name("UIApplicationDidEnterBackground")
    public static let willEnterForegroundNotification = Notification.Name("UIApplicationWillEnterForeground")
    public static let willTerminateNotification = Notification.Name("UIApplicationWillTerminate")
    public static let didReceiveMemoryWarningNotification = Notification.Name("UIApplicationDidReceiveMemoryWarning")
    public static let userDidTakeScreenshotNotification = Notification.Name("UIApplicationUserDidTakeScreenshot")
    public static let significantTimeChangeNotification = Notification.Name("UIApplicationSignificantTimeChange")
}
public struct UIBackgroundTaskIdentifier: RawRepresentable, Equatable, Hashable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let invalid = UIBackgroundTaskIdentifier(rawValue: 0)
}
public enum UIBackgroundFetchResult: UInt { case newData, noData, failed }
public enum UIBackgroundRefreshStatus: Int { case restricted, denied, available }

@preconcurrency @MainActor public protocol UIApplicationDelegate: NSObjectProtocol {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data)
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error)
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void)
    func applicationDidBecomeActive(_ application: UIApplication)
    func applicationWillResignActive(_ application: UIApplication)
    func applicationDidEnterBackground(_ application: UIApplication)
    func applicationWillEnterForeground(_ application: UIApplication)
    func applicationWillTerminate(_ application: UIApplication)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration
}
extension UIApplicationDelegate {
    public func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    public func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool { true }
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {}
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {}
    public func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {}
    public func applicationDidBecomeActive(_ application: UIApplication) {}
    public func applicationWillResignActive(_ application: UIApplication) {}
    public func applicationDidEnterBackground(_ application: UIApplication) {}
    public func applicationWillEnterForeground(_ application: UIApplication) {}
    public func applicationWillTerminate(_ application: UIApplication) {}
    public func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any]) -> Bool { false }
    public func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration { UISceneConfiguration() }
}
extension UIApplication {
    public struct OpenURLOptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
}
extension UIScene { public class ConnectionOptions: NSObject {} }
open class UISceneSession: NSObject { public override init() { super.init() } }
open class UISceneConfiguration: NSObject { public override init() { super.init() } }

@preconcurrency @MainActor open class UIDevice: NSObject {
    public override init() { super.init() }
    open class var current: UIDevice { UIDevice() }
    open var name: String { "iPhone" }
    open var model: String { "iPhone" }
    open var systemName: String { "iOS" }
    open var systemVersion: String { "26.0" }
    open var identifierForVendor: UUID? { nil }
    open var userInterfaceIdiom: UIUserInterfaceIdiom { .phone }
    open var orientation: UIDeviceOrientation { .portrait }
    open var batteryLevel: Float { 1 }
    open var isBatteryMonitoringEnabled: Bool = false
    open var batteryState: BatteryState { .unknown }
    public enum BatteryState: Int { case unknown, unplugged, charging, full }
    public static let orientationDidChangeNotification = Notification.Name("UIDeviceOrientationDidChange")
    public static let batteryLevelDidChangeNotification = Notification.Name("UIDeviceBatteryLevelDidChange")
}
public enum UIDeviceOrientation: Int { case unknown, portrait, portraitUpsideDown, landscapeLeft, landscapeRight, faceUp, faceDown }

@preconcurrency @MainActor open class UIScreen: NSObject {
    public override init() { super.init() }
    open class var main: UIScreen { UIScreen() }
    open var bounds: CGRect { CGRect(x: 0, y: 0, width: 393, height: 852) }
    open var nativeBounds: CGRect { bounds }
    open var scale: CGFloat { 3 }
    open var nativeScale: CGFloat { 3 }
    open var brightness: CGFloat = 1
    open var maximumFramesPerSecond: Int { 120 }
    public static let brightnessDidChangeNotification = Notification.Name("UIScreenBrightnessDidChange")
}

open class UIPasteboard: NSObject {
    public override init() { super.init() }
    open class var general: UIPasteboard { UIPasteboard() }
    open var string: String?
    open var strings: [String]?
    open var url: URL?
    open var image: UIImage?
    open var hasStrings: Bool { false }
    open var hasImages: Bool { false }
    open var hasURLs: Bool { false }
    open var changeCount: Int { 0 }
    open func setItems(_ items: [[String: Any]], options: [UIPasteboard.OptionsKey: Any]) {}
    public struct OptionsKey: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let expirationDate = OptionsKey(rawValue: "exp"), localOnly = OptionsKey(rawValue: "local") }
    public static let changedNotification = Notification.Name("UIPasteboardChanged")
}

// MARK: Misc

@preconcurrency @MainActor open class UIActivityViewController: UIViewController {
    public init(activityItems: [Any], applicationActivities: [UIActivity]?) { super.init() }
    open var completionWithItemsHandler: ((UIActivity.ActivityType?, Bool, [Any]?, Error?) -> Void)?
    open var excludedActivityTypes: [UIActivity.ActivityType]?
}
open class UIActivity: NSObject {
    public struct ActivityType: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
}
public struct UIAccessibility {
    public static var isReduceMotionEnabled: Bool { false }
    public static var isVoiceOverRunning: Bool { false }
    public static var isReduceTransparencyEnabled: Bool { false }
    public static var isBoldTextEnabled: Bool { false }
    public static func post(notification: UIAccessibility.Notification, argument: Any?) {}
    public struct Notification: RawRepresentable, Hashable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }
        public static let announcement = Notification(rawValue: 1), screenChanged = Notification(rawValue: 2), layoutChanged = Notification(rawValue: 3) }
}
public enum UIKeyboardType: Int { case `default`, asciiCapable, numbersAndPunctuation, URL, numberPad, phonePad, namePhonePad, emailAddress, decimalPad, twitter, webSearch, asciiCapableNumberPad }
public enum UIReturnKeyType: Int { case `default`, go, google, join, next, route, search, send, yahoo, done, emergencyCall, `continue` }
public enum UITextAutocapitalizationType: Int { case none, words, sentences, allCharacters }
public enum UITextAutocorrectionType: Int { case `default`, no, yes }
public struct UITextContentType: RawRepresentable, Hashable, Equatable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let name = UITextContentType(rawValue: "name"), givenName = UITextContentType(rawValue: "givenName"), familyName = UITextContentType(rawValue: "familyName"),
        nickname = UITextContentType(rawValue: "nickname"), organizationName = UITextContentType(rawValue: "organizationName"), URL = UITextContentType(rawValue: "URL"),
        emailAddress = UITextContentType(rawValue: "emailAddress"), telephoneNumber = UITextContentType(rawValue: "telephoneNumber"), username = UITextContentType(rawValue: "username"),
        password = UITextContentType(rawValue: "password"), newPassword = UITextContentType(rawValue: "newPassword"), oneTimeCode = UITextContentType(rawValue: "oneTimeCode"),
        streetAddressLine1 = UITextContentType(rawValue: "streetAddressLine1"), addressCity = UITextContentType(rawValue: "addressCity"), postalCode = UITextContentType(rawValue: "postalCode"),
        countryName = UITextContentType(rawValue: "countryName"), fullStreetAddress = UITextContentType(rawValue: "fullStreetAddress"), location = UITextContentType(rawValue: "location"),
        dateTime = UITextContentType(rawValue: "dateTime"), birthdate = UITextContentType(rawValue: "birthdate"), creditCardNumber = UITextContentType(rawValue: "creditCardNumber")
}
