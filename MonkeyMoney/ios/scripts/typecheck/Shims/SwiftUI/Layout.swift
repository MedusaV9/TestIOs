// SwiftUI stub — layout containers, geometry, scroll views, layout modifiers.
import Foundation

// MARK: Geometry primitives

public struct Angle: Hashable, Comparable, Sendable, Animatable {
    public var radians: Double
    public var degrees: Double { get { radians * 180 / .pi } set { radians = newValue * .pi / 180 } }
    public init() { radians = 0 }
    public init(radians: Double) { self.radians = radians }
    public init(degrees: Double) { radians = degrees * .pi / 180 }
    public static func radians(_ radians: Double) -> Angle { Angle(radians: radians) }
    public static func degrees(_ degrees: Double) -> Angle { Angle(degrees: degrees) }
    public static let zero = Angle()
    public static func < (lhs: Angle, rhs: Angle) -> Bool { lhs.radians < rhs.radians }
    public static func + (lhs: Angle, rhs: Angle) -> Angle { Angle(radians: lhs.radians + rhs.radians) }
    public static func - (lhs: Angle, rhs: Angle) -> Angle { Angle(radians: lhs.radians - rhs.radians) }
    public static func * (lhs: Angle, rhs: Double) -> Angle { Angle(radians: lhs.radians * rhs) }
    public var animatableData: Double { get { radians } set { radians = newValue } }
}

public struct UnitPoint: Hashable, Sendable {
    public var x: CGFloat, y: CGFloat
    public init() { x = 0; y = 0 }
    public init(x: CGFloat, y: CGFloat) { self.x = x; self.y = y }
    public static let zero = UnitPoint(x: 0, y: 0), center = UnitPoint(x: 0.5, y: 0.5), leading = UnitPoint(x: 0, y: 0.5), trailing = UnitPoint(x: 1, y: 0.5),
        top = UnitPoint(x: 0.5, y: 0), bottom = UnitPoint(x: 0.5, y: 1), topLeading = UnitPoint(x: 0, y: 0), topTrailing = UnitPoint(x: 1, y: 0),
        bottomLeading = UnitPoint(x: 0, y: 1), bottomTrailing = UnitPoint(x: 1, y: 1)
}

public struct HorizontalAlignment: Hashable, Sendable {
    public init<ID: AlignmentID>(_ id: ID.Type) {}
    private init(_ tag: Int) {}
    public static let leading = HorizontalAlignment(0), center = HorizontalAlignment(1), trailing = HorizontalAlignment(2)
    public static let listRowSeparatorLeading = HorizontalAlignment(3), listRowSeparatorTrailing = HorizontalAlignment(4)
}
public struct VerticalAlignment: Hashable, Sendable {
    public init<ID: AlignmentID>(_ id: ID.Type) {}
    private init(_ tag: Int) {}
    public static let top = VerticalAlignment(0), center = VerticalAlignment(1), bottom = VerticalAlignment(2), firstTextBaseline = VerticalAlignment(3), lastTextBaseline = VerticalAlignment(4)
}
public protocol AlignmentID { static func defaultValue(in context: ViewDimensions) -> CGFloat }
public struct ViewDimensions {
    public var width: CGFloat { 0 }
    public var height: CGFloat { 0 }
    public subscript(guide: HorizontalAlignment) -> CGFloat { 0 }
    public subscript(guide: VerticalAlignment) -> CGFloat { 0 }
    public subscript(explicit guide: HorizontalAlignment) -> CGFloat? { nil }
    public subscript(explicit guide: VerticalAlignment) -> CGFloat? { nil }
}
public struct Alignment: Hashable, Sendable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment
    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) { self.horizontal = horizontal; self.vertical = vertical }
    public static let center = Alignment(horizontal: .center, vertical: .center), leading = Alignment(horizontal: .leading, vertical: .center),
        trailing = Alignment(horizontal: .trailing, vertical: .center), top = Alignment(horizontal: .center, vertical: .top), bottom = Alignment(horizontal: .center, vertical: .bottom),
        topLeading = Alignment(horizontal: .leading, vertical: .top), topTrailing = Alignment(horizontal: .trailing, vertical: .top),
        bottomLeading = Alignment(horizontal: .leading, vertical: .bottom), bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom),
        centerFirstTextBaseline = Alignment(horizontal: .center, vertical: .firstTextBaseline), centerLastTextBaseline = Alignment(horizontal: .center, vertical: .lastTextBaseline),
        leadingFirstTextBaseline = Alignment(horizontal: .leading, vertical: .firstTextBaseline), leadingLastTextBaseline = Alignment(horizontal: .leading, vertical: .lastTextBaseline),
        trailingFirstTextBaseline = Alignment(horizontal: .trailing, vertical: .firstTextBaseline), trailingLastTextBaseline = Alignment(horizontal: .trailing, vertical: .lastTextBaseline)
}

public enum Edge: Int8, CaseIterable, Hashable, Sendable {
    case top, leading, bottom, trailing
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ e: Edge) { rawValue = 1 << e.rawValue }
        public static let top = Set(.top), leading = Set(.leading), bottom = Set(.bottom), trailing = Set(.trailing)
        public static let all: Set = [.top, .leading, .bottom, .trailing]
        public static let horizontal: Set = [.leading, .trailing]
        public static let vertical: Set = [.top, .bottom]
    }
}
public enum HorizontalEdge: Int8, CaseIterable, Hashable, Sendable {
    case leading, trailing
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ e: HorizontalEdge) { rawValue = 1 << e.rawValue }
        public static let leading = Set(.leading), trailing = Set(.trailing), all: Set = [.leading, .trailing]
    }
}
public enum VerticalEdge: Int8, CaseIterable, Hashable, Sendable {
    case top, bottom
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public init(_ e: VerticalEdge) { rawValue = 1 << e.rawValue }
        public static let top = Set(.top), bottom = Set(.bottom), all: Set = [.top, .bottom]
    }
}
public struct EdgeInsets: Equatable, Sendable, Animatable {
    public var top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat
    public init() { top = 0; leading = 0; bottom = 0; trailing = 0 }
    public init(top: CGFloat, leading: CGFloat, bottom: CGFloat, trailing: CGFloat) { self.top = top; self.leading = leading; self.bottom = bottom; self.trailing = trailing }
    public init(_ uiEdgeInsets: UIEdgeInsets) { top = uiEdgeInsets.top; leading = uiEdgeInsets.left; bottom = uiEdgeInsets.bottom; trailing = uiEdgeInsets.right }
    public var animatableData: CGFloat { get { top } set { top = newValue } }
}
public enum Axis: Int8, CaseIterable, Hashable, Sendable {
    case horizontal, vertical
    public struct Set: OptionSet, Sendable {
        public let rawValue: Int8
        public init(rawValue: Int8) { self.rawValue = rawValue }
        public static let horizontal = Set(rawValue: 1), vertical = Set(rawValue: 2), all: Set = [.horizontal, .vertical]
    }
}
public enum ContentMode: Hashable, CaseIterable, Sendable { case fit, fill }
public struct SafeAreaRegions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let container = SafeAreaRegions(rawValue: 1), keyboard = SafeAreaRegions(rawValue: 2), all: SafeAreaRegions = [.container, .keyboard]
}
public enum CoordinateSpace: Hashable {
    case global, local
    case named(AnyHashable)
    public var isGlobal: Bool { self == .global }
    public var isLocal: Bool { self == .local }
}
public protocol CoordinateSpaceProtocol { var coordinateSpace: CoordinateSpace { get } }
public struct GlobalCoordinateSpace: CoordinateSpaceProtocol { public init() {}; public var coordinateSpace: CoordinateSpace { .global } }
public struct LocalCoordinateSpace: CoordinateSpaceProtocol { public init() {}; public var coordinateSpace: CoordinateSpace { .local } }
public struct NamedCoordinateSpace: CoordinateSpaceProtocol, Equatable { let name: AnyHashable; public var coordinateSpace: CoordinateSpace { .named(name) } }
extension CoordinateSpaceProtocol where Self == GlobalCoordinateSpace { public static var global: GlobalCoordinateSpace { GlobalCoordinateSpace() } }
extension CoordinateSpaceProtocol where Self == LocalCoordinateSpace { public static var local: LocalCoordinateSpace { LocalCoordinateSpace() } }
extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    public static func named(_ name: some Hashable) -> NamedCoordinateSpace { NamedCoordinateSpace(name: AnyHashable(name)) }
    public static var scrollView: NamedCoordinateSpace { NamedCoordinateSpace(name: "scrollView") }
    public static func scrollView(axis: Axis) -> NamedCoordinateSpace { NamedCoordinateSpace(name: "scrollView") }
}

public struct ProposedViewSize: Equatable, Sendable {
    public var width: CGFloat?, height: CGFloat?
    public init(width: CGFloat?, height: CGFloat?) { self.width = width; self.height = height }
    public init(_ size: CGSize) { width = size.width; height = size.height }
    public static let zero = ProposedViewSize(width: 0, height: 0), unspecified = ProposedViewSize(width: nil, height: nil), infinity = ProposedViewSize(width: .infinity, height: .infinity)
    public func replacingUnspecifiedDimensions(by size: CGSize = CGSize(width: 10, height: 10)) -> CGSize { CGSize(width: width ?? size.width, height: height ?? size.height) }
}

// MARK: Stacks & grids

public struct HStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct VStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct ZStack<Content: View>: View {
    public init(alignment: Alignment = .center, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct LazyHStack<Content: View>: View {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct LazyVStack<Content: View>: View {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct PinnedScrollableViews: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public init() { rawValue = 0 }
    public static let sectionHeaders = PinnedScrollableViews(rawValue: 1), sectionFooters = PinnedScrollableViews(rawValue: 2)
}
public struct GridItem: Sendable {
    public enum Size: Sendable {
        case fixed(CGFloat)
        case flexible(minimum: CGFloat = 10, maximum: CGFloat = .infinity)
        case adaptive(minimum: CGFloat, maximum: CGFloat = .infinity)
    }
    public var size: Size
    public var spacing: CGFloat?
    public var alignment: Alignment?
    public init(_ size: Size = .flexible(), spacing: CGFloat? = nil, alignment: Alignment? = nil) { self.size = size; self.spacing = spacing; self.alignment = alignment }
}
public struct LazyVGrid<Content: View>: View {
    public init(columns: [GridItem], alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct LazyHGrid<Content: View>: View {
    public init(rows: [GridItem], alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, pinnedViews: PinnedScrollableViews = .init(), @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct Grid<Content: View>: View {
    public init(alignment: Alignment = .center, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct GridRow<Content: View>: View {
    public init(alignment: VerticalAlignment? = nil, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension View {
    public func gridCellColumns(_ count: Int) -> some View { self }
    public func gridCellAnchor(_ anchor: UnitPoint) -> some View { self }
    public func gridCellUnsizedAxes(_ axes: Axis.Set) -> some View { self }
    public func gridColumnAlignment(_ guide: HorizontalAlignment) -> some View { self }
}
public struct ViewThatFits<Content: View>: View {
    public init(in axes: Axis.Set = [.horizontal, .vertical], @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct Spacer: View {
    public var minLength: CGFloat?
    public init(minLength: CGFloat? = nil) { self.minLength = minLength }
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct Divider: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

// MARK: Geometry reader

public struct GeometryProxy {
    public var size: CGSize { .zero }
    public var safeAreaInsets: EdgeInsets { EdgeInsets() }
    public func frame(in coordinateSpace: CoordinateSpace) -> CGRect { .zero }
    public func frame(in coordinateSpace: some CoordinateSpaceProtocol) -> CGRect { .zero }
    public func bounds(of coordinateSpace: NamedCoordinateSpace) -> CGRect? { nil }
    public subscript<T>(anchor: Anchor<T>) -> T { fatalError() }
}
public struct GeometryReader<Content: View>: View {
    public init(@ViewBuilder content: @escaping (GeometryProxy) -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct Anchor<Value> {
    public struct Source {
        public static func rect(_ r: CGRect) -> Anchor<CGRect>.Source { Anchor<CGRect>.Source() }
        public static var bounds: Anchor<CGRect>.Source { Anchor<CGRect>.Source() }
        public static func point(_ p: CGPoint) -> Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
        public static func unitPoint(_ p: UnitPoint) -> Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
        public static var center: Anchor<CGPoint>.Source { Anchor<CGPoint>.Source() }
    }
}

// MARK: Scroll views

public struct ScrollView<Content: View>: View {
    public var axes: Axis.Set
    public var showsIndicators: Bool
    public init(_ axes: Axis.Set = .vertical, showsIndicators: Bool = true, @ViewBuilder content: () -> Content) { self.axes = axes; self.showsIndicators = showsIndicators }
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct ScrollViewProxy {
    public func scrollTo<ID: Hashable>(_ id: ID, anchor: UnitPoint? = nil) {}
}
public struct ScrollViewReader<Content: View>: View {
    public init(@ViewBuilder content: @escaping (ScrollViewProxy) -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct ScrollIndicatorVisibility: Hashable {
    public static let automatic = ScrollIndicatorVisibility(), visible = ScrollIndicatorVisibility(), hidden = ScrollIndicatorVisibility(), never = ScrollIndicatorVisibility()
}
public struct ScrollDismissesKeyboardMode: Hashable {
    public static let automatic = ScrollDismissesKeyboardMode(), immediately = ScrollDismissesKeyboardMode(), interactively = ScrollDismissesKeyboardMode(), never = ScrollDismissesKeyboardMode()
}
public struct ScrollBounceBehavior: Hashable {
    public static let automatic = ScrollBounceBehavior(), always = ScrollBounceBehavior(), basedOnSize = ScrollBounceBehavior()
}
public protocol ScrollTargetBehavior {}
public struct PagingScrollTargetBehavior: ScrollTargetBehavior { public init() {} }
public struct ViewAlignedScrollTargetBehavior: ScrollTargetBehavior {
    public struct LimitBehavior { public static let automatic = LimitBehavior(), always = LimitBehavior(), never = LimitBehavior(), alwaysByFew = LimitBehavior(), alwaysByOne = LimitBehavior() }
    public init(limitBehavior: LimitBehavior = .automatic) {}
    public init(anchor: UnitPoint?) {}
    public init(limitBehavior: LimitBehavior, anchor: UnitPoint?) {}
}
extension ScrollTargetBehavior where Self == PagingScrollTargetBehavior { public static var paging: PagingScrollTargetBehavior { PagingScrollTargetBehavior() } }
extension ScrollTargetBehavior where Self == ViewAlignedScrollTargetBehavior {
    public static var viewAligned: ViewAlignedScrollTargetBehavior { ViewAlignedScrollTargetBehavior() }
    public static func viewAligned(limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior) -> ViewAlignedScrollTargetBehavior { ViewAlignedScrollTargetBehavior(limitBehavior: limitBehavior) }
    public static func viewAligned(anchor: UnitPoint?) -> ViewAlignedScrollTargetBehavior { ViewAlignedScrollTargetBehavior(anchor: anchor) }
}
public struct ScrollPosition: Equatable {
    public init(idType: (some Hashable).Type = Never.self) {}
    public init(id: some Hashable, anchor: UnitPoint? = nil) {}
    public init(edge: Edge) {}
    public init(point: CGPoint) {}
    public init(x: CGFloat, y: CGFloat) {}
    public var viewID: (any Hashable)? { nil }
    public func viewID<T: Hashable>(type: T.Type = T.self) -> T? { nil }
    public var edge: Edge? { nil }
    public var point: CGPoint? { nil }
    public var isPositionedByUser: Bool { false }
    public mutating func scrollTo(id: some Hashable, anchor: UnitPoint? = nil) {}
    public mutating func scrollTo(edge: Edge) {}
    public mutating func scrollTo(point: CGPoint) {}
    public mutating func scrollTo(x: CGFloat) {}
    public mutating func scrollTo(y: CGFloat) {}
    public static func == (lhs: ScrollPosition, rhs: ScrollPosition) -> Bool { true }
}
public struct ScrollGeometry: Equatable, Sendable {
    public var contentOffset: CGPoint = .zero
    public var contentSize: CGSize = .zero
    public var contentInsets: EdgeInsets = EdgeInsets()
    public var containerSize: CGSize = .zero
    public var visibleRect: CGRect { .zero }
    public var bounds: CGRect { .zero }
}
public enum ScrollPhase: Hashable, Sendable { case idle, tracking, interacting, decelerating, animating; public var isScrolling: Bool { self != .idle } }
public struct ScrollPhaseChangeContext { public var geometry: ScrollGeometry { ScrollGeometry() }; public var velocity: CGVector? { nil } }
public struct ContentMarginPlacement {
    public static let automatic = ContentMarginPlacement(), scrollContent = ContentMarginPlacement(), scrollIndicators = ContentMarginPlacement()
}
public struct ScrollEdgeEffectStyle: Hashable, Sendable {
    public static let automatic = ScrollEdgeEffectStyle(), soft = ScrollEdgeEffectStyle(), hard = ScrollEdgeEffectStyle()
}

extension View {
    public func scrollDisabled(_ disabled: Bool) -> some View { self }
    public func scrollIndicators(_ visibility: ScrollIndicatorVisibility, axes: Axis.Set = [.vertical, .horizontal]) -> some View { self }
    public func scrollIndicatorsFlash(onAppear: Bool) -> some View { self }
    public func scrollIndicatorsFlash<T: Equatable>(trigger value: T) -> some View { self }
    public func scrollDismissesKeyboard(_ mode: ScrollDismissesKeyboardMode) -> some View { self }
    public func scrollBounceBehavior(_ behavior: ScrollBounceBehavior, axes: Axis.Set = [.vertical]) -> some View { self }
    public func scrollClipDisabled(_ disabled: Bool = true) -> some View { self }
    public func scrollContentBackground(_ visibility: Visibility) -> some View { self }
    public func scrollTargetLayout(isEnabled: Bool = true) -> some View { self }
    public func scrollTargetBehavior(_ behavior: some ScrollTargetBehavior) -> some View { self }
    public func scrollPosition<ID: Hashable>(id: Binding<ID?>, anchor: UnitPoint? = nil) -> some View { self }
    public func scrollPosition(_ position: Binding<ScrollPosition>, anchor: UnitPoint? = nil) -> some View { self }
    public func defaultScrollAnchor(_ anchor: UnitPoint?) -> some View { self }
    public func defaultScrollAnchor(_ anchor: UnitPoint?, for role: ScrollAnchorRole) -> some View { self }
    public func scrollTransition(_ configuration: ScrollTransitionConfiguration = .interactive, axis: Axis? = nil, transition: @escaping (EmptyVisualEffect, ScrollTransitionPhase) -> some VisualEffect) -> some View { self }
    public func scrollTransition(topLeading: ScrollTransitionConfiguration, bottomTrailing: ScrollTransitionConfiguration, axis: Axis? = nil, transition: @escaping (EmptyVisualEffect, ScrollTransitionPhase) -> some VisualEffect) -> some View { self }
    public func onScrollGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (ScrollGeometry) -> T, action: @escaping (T, T) -> Void) -> some View { self }
    public func onScrollPhaseChange(_ action: @escaping (ScrollPhase, ScrollPhase) -> Void) -> some View { self }
    public func onScrollPhaseChange(_ action: @escaping (ScrollPhase, ScrollPhase, ScrollPhaseChangeContext) -> Void) -> some View { self }
    public func onScrollVisibilityChange(threshold: Double = 0.5, _ action: @escaping (Bool) -> Void) -> some View { self }
    public func onScrollTargetVisibilityChange<ID: Hashable>(idType: ID.Type, threshold: Double = 0.5, _ action: @escaping ([ID]) -> Void) -> some View { self }
    public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for placement: ContentMarginPlacement = .automatic) -> some View { self }
    public func contentMargins(_ length: CGFloat, for placement: ContentMarginPlacement = .automatic) -> some View { self }
    public func contentMargins(_ edges: Edge.Set = .all, _ insets: EdgeInsets, for placement: ContentMarginPlacement = .automatic) -> some View { self }
    public func scrollEdgeEffectStyle(_ style: ScrollEdgeEffectStyle?, for edges: Edge.Set) -> some View { self }
    public func scrollEdgeEffectHidden(_ hidden: Bool = true, for edges: Edge.Set = .all) -> some View { self }
    public func scrollEdgeEffectDisabled(_ disabled: Bool = true, for edges: Edge.Set = .all) -> some View { self }
}
public struct ScrollAnchorRole: Hashable { public static let initialOffset = ScrollAnchorRole(), sizeChanges = ScrollAnchorRole(), alignment = ScrollAnchorRole() }
public struct ScrollTransitionConfiguration {
    public static let identity = ScrollTransitionConfiguration(), interactive = ScrollTransitionConfiguration(), animated = ScrollTransitionConfiguration()
    public static func interactive(timingCurve: UnitCurve) -> ScrollTransitionConfiguration { ScrollTransitionConfiguration() }
    public static func animated(_ animation: Animation = .default) -> ScrollTransitionConfiguration { ScrollTransitionConfiguration() }
    public func threshold(_ threshold: ScrollTransitionPhase.Threshold) -> ScrollTransitionConfiguration { self }
}
public enum ScrollTransitionPhase: Hashable {
    case topLeading, identity, bottomTrailing
    public var isIdentity: Bool { self == .identity }
    public var value: Double { self == .identity ? 0 : (self == .topLeading ? -1 : 1) }
    public struct Threshold { public static let visible = Threshold(), hidden = Threshold(), centered = Threshold(); public static func visible(_ fraction: Double) -> Threshold { Threshold() }; public func interpolated(towards other: Threshold, amount: Double) -> Threshold { self }; public func inset(by distance: Double) -> Threshold { self } }
}
public protocol VisualEffect: Sendable, Animatable {}
public struct EmptyVisualEffect: VisualEffect {
    public init() {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
extension VisualEffect {
    public func opacity(_ opacity: Double) -> some VisualEffect { self }
    public func scaleEffect(_ scale: CGFloat, anchor: UnitPoint = .center) -> some VisualEffect { self }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some VisualEffect { self }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some VisualEffect { self }
    public func offset(_ offset: CGSize) -> some VisualEffect { self }
    public func blur(radius: CGFloat, opaque: Bool = false) -> some VisualEffect { self }
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some VisualEffect { self }
    public func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some VisualEffect { self }
    public func brightness(_ amount: Double) -> some VisualEffect { self }
    public func saturation(_ amount: Double) -> some VisualEffect { self }
    public func hueRotation(_ angle: Angle) -> some VisualEffect { self }
    public func grayscale(_ amount: Double) -> some VisualEffect { self }
    public func contrast(_ amount: Double) -> some VisualEffect { self }
}
public struct EmptyAnimatableData: VectorArithmetic {
    public init() {}
    public static var zero: EmptyAnimatableData { EmptyAnimatableData() }
    public static func + (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
    public static func - (lhs: EmptyAnimatableData, rhs: EmptyAnimatableData) -> EmptyAnimatableData { lhs }
    public static func += (lhs: inout EmptyAnimatableData, rhs: EmptyAnimatableData) {}
    public static func -= (lhs: inout EmptyAnimatableData, rhs: EmptyAnimatableData) {}
    public mutating func scale(by rhs: Double) {}
    public var magnitudeSquared: Double { 0 }
}

// MARK: Layout modifiers

extension View {
    public func frame(width: CGFloat? = nil, height: CGFloat? = nil, alignment: Alignment = .center) -> some View { self }
    public func frame(minWidth: CGFloat? = nil, idealWidth: CGFloat? = nil, maxWidth: CGFloat? = nil, minHeight: CGFloat? = nil, idealHeight: CGFloat? = nil, maxHeight: CGFloat? = nil, alignment: Alignment = .center) -> some View { self }
    public func frame() -> some View { self }
    public func padding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
    public func padding(_ length: CGFloat) -> some View { self }
    public func padding(_ insets: EdgeInsets) -> some View { self }
    public func padding3D(_ length: CGFloat) -> some View { self }
    public func offset(_ offset: CGSize) -> some View { self }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some View { self }
    public func position(_ position: CGPoint) -> some View { self }
    public func position(x: CGFloat = 0, y: CGFloat = 0) -> some View { self }
    public func aspectRatio(_ aspectRatio: CGFloat? = nil, contentMode: ContentMode) -> some View { self }
    public func aspectRatio(_ aspectRatio: CGSize, contentMode: ContentMode) -> some View { self }
    public func scaledToFit() -> some View { self }
    public func scaledToFill() -> some View { self }
    public func fixedSize() -> some View { self }
    public func fixedSize(horizontal: Bool, vertical: Bool) -> some View { self }
    public func layoutPriority(_ value: Double) -> some View { self }
    public func zIndex(_ value: Double) -> some View { self }
    public func ignoresSafeArea(_ regions: SafeAreaRegions = .all, edges: Edge.Set = .all) -> some View { self }
    public func edgesIgnoringSafeArea(_ edges: Edge.Set) -> some View { self }
    public func safeAreaInset<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View { self }
    public func safeAreaInset<V: View>(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View { self }
    public func safeAreaPadding(_ insets: EdgeInsets) -> some View { self }
    public func safeAreaPadding(_ length: CGFloat) -> some View { self }
    public func safeAreaPadding(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
    public func safeAreaBar<V: View>(edge: VerticalEdge, alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View { self }
    public func safeAreaBar<V: View>(edge: HorizontalEdge, alignment: VerticalAlignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> V) -> some View { self }
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center) -> some View { self }
    public func containerRelativeFrame(_ axes: Axis.Set, count: Int, span: Int = 1, spacing: CGFloat, alignment: Alignment = .center) -> some View { self }
    public func containerRelativeFrame(_ axes: Axis.Set, alignment: Alignment = .center, _ length: @escaping (CGFloat, Axis) -> CGFloat) -> some View { self }
    public func alignmentGuide(_ g: HorizontalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View { self }
    public func alignmentGuide(_ g: VerticalAlignment, computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View { self }
    public func coordinateSpace(_ name: NamedCoordinateSpace) -> some View { self }
    public func coordinateSpace<T: Hashable>(name: T) -> some View { self }
    public func onGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (GeometryProxy) -> T, action: @escaping (T, T) -> Void) -> some View { self }
    public func onGeometryChange<T: Equatable>(for type: T.Type, of transform: @escaping (GeometryProxy) -> T, action: @escaping (T) -> Void) -> some View { self }
    public func geometryGroup() -> some View { self }
    public func flipsForRightToLeftLayoutDirection(_ enabled: Bool) -> some View { self }
    public func background<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
    public func background<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
    public func background(ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
    public func background<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    public func background<T: Shape>(in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    public func background<S: ShapeStyle, T: InsettableShape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    public func background<T: InsettableShape>(in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    @_disfavoredOverload public func background<Background: View>(_ background: Background, alignment: Alignment = .center) -> some View { self }
    public func overlay<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
    public func overlay<S: ShapeStyle>(_ style: S, ignoresSafeAreaEdges edges: Edge.Set = .all) -> some View { self }
    public func overlay<S: ShapeStyle, T: Shape>(_ style: S, in shape: T, fillStyle: FillStyle = FillStyle()) -> some View { self }
    @_disfavoredOverload public func overlay<Overlay: View>(_ overlay: Overlay, alignment: Alignment = .center) -> some View { self }
    public func containerBackground<S: ShapeStyle>(_ style: S, for container: ContainerBackgroundPlacement) -> some View { self }
    public func containerBackground<V: View>(for container: ContainerBackgroundPlacement, alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
    public func containerShape<T: InsettableShape>(_ shape: T) -> some View { self }
    public func backgroundExtensionEffect() -> some View { self }
}
public struct ContainerBackgroundPlacement: Hashable, Sendable {
    public static let navigation = ContainerBackgroundPlacement(), tabView = ContainerBackgroundPlacement(), widget = ContainerBackgroundPlacement()
}

// MARK: Layout protocol (custom layouts)

public protocol Layout: Animatable {
    associatedtype Cache = Void
    typealias Subviews = LayoutSubviews
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache) -> CGSize
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Cache)
    func makeCache(subviews: Subviews) -> Cache
}
extension Layout where Cache == Void {
    public func makeCache(subviews: Subviews) -> Void {}
}
extension Layout {
    public func callAsFunction<V: View>(@ViewBuilder _ content: () -> V) -> some View { content() }
}
public struct LayoutSubviews: RandomAccessCollection {
    public typealias Element = LayoutSubview
    public var startIndex: Int { 0 }
    public var endIndex: Int { 0 }
    public subscript(index: Int) -> LayoutSubview { LayoutSubview() }
    public func index(after i: Int) -> Int { i + 1 }
    public func index(before i: Int) -> Int { i - 1 }
}
public struct LayoutSubview {
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero }
    public func place(at position: CGPoint, anchor: UnitPoint = .topLeading, proposal: ProposedViewSize) {}
    public func dimensions(in proposal: ProposedViewSize) -> ViewDimensions { ViewDimensions() }
    public var priority: Double { 0 }
    public var spacing: ViewSpacing { ViewSpacing() }
    public subscript<K: LayoutValueKey>(key: K.Type) -> K.Value { K.defaultValue }
}
public struct ViewSpacing {
    public init() {}
    public static let zero = ViewSpacing()
    public func distance(to next: ViewSpacing, along axis: Axis) -> CGFloat { 8 }
}
public protocol LayoutValueKey { associatedtype Value; static var defaultValue: Value { get } }
public struct AnyLayout: Layout {
    public init<L: Layout>(_ layout: L) {}
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct HStackLayout: Layout {
    public init(alignment: VerticalAlignment = .center, spacing: CGFloat? = nil) {}
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct VStackLayout: Layout {
    public init(alignment: HorizontalAlignment = .center, spacing: CGFloat? = nil) {}
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct ZStackLayout: Layout {
    public init(alignment: Alignment = .center) {}
    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize { .zero }
    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {}
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
