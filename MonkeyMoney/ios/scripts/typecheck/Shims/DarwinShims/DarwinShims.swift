// Implicitly imported into every file (see typecheck.sh). Holds the handful
// of Foundation/CoreGraphics/Darwin declarations that Apple platforms get
// for free with `import Foundation` but swift-corelibs-foundation lacks.
import Foundation

// MARK: CoreGraphics value types missing from corelibs-foundation

public struct CGVector: Equatable, Hashable, Codable {
    public var dx: CGFloat
    public var dy: CGFloat
    public init() { dx = 0; dy = 0 }
    public init(dx: CGFloat, dy: CGFloat) { self.dx = dx; self.dy = dy }
    public init(dx: Double, dy: Double) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public init(dx: Int, dy: Int) { self.dx = CGFloat(dx); self.dy = CGFloat(dy) }
    public static let zero = CGVector()
}

public struct CGAffineTransform: Equatable, Hashable, Codable {
    public var a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat
    public init() { a = 1; b = 0; c = 0; d = 1; tx = 0; ty = 0 }
    public init(a: CGFloat, b: CGFloat, c: CGFloat, d: CGFloat, tx: CGFloat, ty: CGFloat) {
        self.a = a; self.b = b; self.c = c; self.d = d; self.tx = tx; self.ty = ty
    }
    public init(translationX tx: CGFloat, y ty: CGFloat) { self.init(); self.tx = tx; self.ty = ty }
    public init(scaleX sx: CGFloat, y sy: CGFloat) { self.init(); a = sx; d = sy }
    public init(rotationAngle angle: CGFloat) { self.init() }
    public static let identity = CGAffineTransform()
    public var isIdentity: Bool { self == .identity }
    public func translatedBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { self }
    public func scaledBy(x: CGFloat, y: CGFloat) -> CGAffineTransform { self }
    public func rotated(by angle: CGFloat) -> CGAffineTransform { self }
    public func inverted() -> CGAffineTransform { self }
    public func concatenating(_ t2: CGAffineTransform) -> CGAffineTransform { self }
}

extension CGPoint {
    public func applying(_ t: CGAffineTransform) -> CGPoint { self }
}
extension CGSize {
    public func applying(_ t: CGAffineTransform) -> CGSize { self }
}
extension CGRect {
    public func applying(_ t: CGAffineTransform) -> CGRect { self }
}

// MARK: Darwin

/// Apple's `OSStatus` (MacTypes.h); returned by Security & CommonCrypto.
public typealias OSStatus = Int32
public let noErr: OSStatus = 0
public typealias Boolean = UInt8
public typealias NSErrorPointer = UnsafeMutablePointer<NSError?>?

/// Stand-in for Objective-C selectors. `#selector(...)` is rewritten to
/// `Selector(...)` on the typecheck scratch copy, so any method reference
/// must be accepted here.
public struct Selector: Hashable {
    public init(_ method: Any) {}
    public init(_ name: String) {}
}

// MARK: Foundation APIs that only exist on Apple platforms

extension FileManager {
    public func containerURL(forSecurityApplicationGroupIdentifier groupIdentifier: String) -> URL? { nil }
    public func url(forUbiquityContainerIdentifier containerIdentifier: String?) -> URL? { nil }
    public var ubiquityIdentityToken: (any NSCoding & NSCopying & NSObjectProtocol)? { nil }
    public func startDownloadingUbiquitousItem(at url: URL) throws {}
    public func evictUbiquitousItem(at url: URL) throws {}
    public func setUbiquitous(_ flag: Bool, itemAt url: URL, destinationURL: URL) throws {}
}

extension URL {
    public func startAccessingSecurityScopedResource() -> Bool { true }
    public func stopAccessingSecurityScopedResource() {}
}

extension ProcessInfo {
    public var isiOSAppOnMac: Bool { false }
    public var isMacCatalystApp: Bool { false }
}

extension Bundle {
    public var appStoreReceiptURL: URL? { nil }
}

/// Foundation's localized resource type (not in swift-corelibs-foundation).
public struct LocalizedStringResource: ExpressibleByStringInterpolation, Hashable, Sendable {
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation<T>(_ value: T) {}
        public mutating func appendInterpolation<T>(_ value: T, format: String) {}
        public mutating func appendInterpolation<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatOutput == String {}
    }
    public struct BundleDescription: Hashable, Sendable {
        public static let main = BundleDescription()
        public static func atURL(_ url: URL) -> BundleDescription { BundleDescription() }
        public static func forClass(_ anyClass: AnyClass) -> BundleDescription { BundleDescription() }
    }
    public let key: String
    public let defaultValue: String.LocalizationValue
    public var table: String?
    public var locale: Locale = .current
    public var bundle: BundleDescription = .main
    public var comment: String?
    public init(_ key: String, defaultValue: String.LocalizationValue? = nil, table: String? = nil, locale: Locale = .current, bundle: BundleDescription = .main, comment: String? = nil) {
        self.key = key; self.defaultValue = defaultValue ?? String.LocalizationValue(key); self.table = table; self.locale = locale; self.bundle = bundle; self.comment = comment
    }
    public init(stringLiteral value: String) { key = value; defaultValue = String.LocalizationValue(value) }
    public init(stringInterpolation: StringInterpolation) { key = ""; defaultValue = String.LocalizationValue("") }
    public init(_ keyAndValue: String.LocalizationValue, table: String? = nil, locale: Locale = .current, bundle: BundleDescription = .main, comment: String? = nil) { key = ""; defaultValue = keyAndValue }
    public static func == (lhs: LocalizedStringResource, rhs: LocalizedStringResource) -> Bool { lhs.key == rhs.key }
    public func hash(into hasher: inout Hasher) { hasher.combine(key) }
}
extension String {
    public struct LocalizationValue: ExpressibleByStringInterpolation, Hashable, Sendable {
        public struct StringInterpolation: StringInterpolationProtocol, Sendable {
            public init(literalCapacity: Int, interpolationCount: Int) {}
            public mutating func appendLiteral(_ literal: String) {}
            public mutating func appendInterpolation<T>(_ value: T) {}
        }
        let raw: String
        public init(_ value: String) { raw = value }
        public init(stringLiteral value: String) { raw = value }
        public init(stringInterpolation: StringInterpolation) { raw = "" }
    }
    public init(localized resource: LocalizedStringResource) { self = resource.key }
    public init(localized keyAndValue: String.LocalizationValue, table: String? = nil, bundle: Bundle? = nil, locale: Locale = .current, comment: StaticString? = nil) { self = keyAndValue.raw }
}

/// Darwin Foundation's IndexSet-based collection edits (used with
/// `ForEach.onDelete` / `.onMove`); absent from swift-corelibs-foundation.
extension RangeReplaceableCollection {
    public mutating func remove(atOffsets offsets: IndexSet) {
        for offset in offsets.reversed() {
            remove(at: index(startIndex, offsetBy: offset))
        }
    }
}
extension MutableCollection where Self: RangeReplaceableCollection {
    public mutating func move(fromOffsets source: IndexSet, toOffset destination: Int) {
        let moving = source.map { self[index(startIndex, offsetBy: $0)] }
        remove(atOffsets: source)
        let shift = source.filter { $0 < destination }.count
        insert(contentsOf: moving, at: index(startIndex, offsetBy: destination - shift))
    }
}

// Only the pieces the app touches are modelled — extend when the compiler
// reports a missing Darwin-only Foundation symbol.

/// Foundation classes absent from swift-corelibs-foundation.
open class UndoManager: NSObject {
    public override init() { super.init() }
    open var canUndo: Bool { false }
    open var canRedo: Bool { false }
    open func undo() {}
    open func redo() {}
    open func registerUndo<TargetType: AnyObject>(withTarget target: TargetType, handler: @escaping (TargetType) -> Void) {}
    open func removeAllActions() {}
    open var levelsOfUndo: Int = 0
}
open class NSUserActivity: NSObject {
    public init(activityType: String) { self.activityType = activityType; super.init() }
    public let activityType: String
    open var title: String?
    open var userInfo: [AnyHashable: Any]?
    open var webpageURL: URL?
    open var targetContentIdentifier: String?
    open var isEligibleForSearch: Bool = false
    open var isEligibleForHandoff: Bool = true
    open var isEligibleForPrediction: Bool = false
    open var persistentIdentifier: String?
    open func becomeCurrent() {}
    open func resignCurrent() {}
    open func invalidate() {}
    open func addUserInfoEntries(from otherDictionary: [AnyHashable: Any]) {}
}
open class FileWrapper: NSObject {
    public init(regularFileWithContents contents: Data) { super.init() }
    public init(directoryWithFileWrappers childrenByPreferredName: [String: FileWrapper]) { super.init() }
    public init(url: URL, options: ReadingOptions = []) throws { super.init() }
    public struct ReadingOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let immediate = ReadingOptions(rawValue: 1), withoutMapping = ReadingOptions(rawValue: 2) }
    public struct WritingOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let atomic = WritingOptions(rawValue: 1), withNameUpdating = WritingOptions(rawValue: 2) }
    open var regularFileContents: Data? { nil }
    open var fileWrappers: [String: FileWrapper]? { nil }
    open var isRegularFile: Bool { true }
    open var isDirectory: Bool { false }
    open var preferredFilename: String?
    open var filename: String?
    open func addFileWrapper(_ child: FileWrapper) -> String { "" }
    open func write(to url: URL, options: WritingOptions = [], originalContentsURL: URL?) throws {}
}
