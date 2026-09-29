// SwiftUI stub — gestures, accessibility, Liquid Glass (iOS 26).
import Foundation

// MARK: Gestures

public protocol Gesture<Value> {
    associatedtype Value
    associatedtype Body: Gesture
    var body: Self.Body { get }
}
extension Never: Gesture { public typealias Value = Never }
public struct GestureMask: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let none = GestureMask(rawValue: 0), gesture = GestureMask(rawValue: 1), subviews = GestureMask(rawValue: 2), all = GestureMask(rawValue: 3)
}
public struct TapGesture: Gesture {
    public typealias Value = Void
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public var count: Int
    public init(count: Int = 1) { self.count = count }
}
public struct SpatialTapGesture: Gesture {
    public struct Value: Equatable, Sendable { public var location: CGPoint = .zero }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local) {}
}
public struct LongPressGesture: Gesture {
    public typealias Value = Bool
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10) {}
}
public struct DragGesture: Gesture {
    public struct Value: Equatable, Sendable {
        public var time: Date = Date()
        public var location: CGPoint = .zero
        public var startLocation: CGPoint = .zero
        public var translation: CGSize = .zero
        public var velocity: CGSize = .zero
        public var predictedEndLocation: CGPoint = .zero
        public var predictedEndTranslation: CGSize = .zero
    }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public var minimumDistance: CGFloat
    public var coordinateSpace: CoordinateSpace
    public init(minimumDistance: CGFloat = 10, coordinateSpace: CoordinateSpace = .local) { self.minimumDistance = minimumDistance; self.coordinateSpace = coordinateSpace }
    public init(minimumDistance: CGFloat = 10, coordinateSpace: some CoordinateSpaceProtocol) { self.minimumDistance = minimumDistance; self.coordinateSpace = coordinateSpace.coordinateSpace }
}
public struct MagnifyGesture: Gesture {
    public struct Value: Equatable, Sendable { public var time: Date = Date(); public var magnification: CGFloat = 1; public var velocity: CGFloat = 0; public var startAnchor: UnitPoint = .center; public var startLocation: CGPoint = .zero }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(minimumScaleDelta: CGFloat = 0.01) {}
}
public struct MagnificationGesture: Gesture {
    public typealias Value = CGFloat
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(minimumScaleDelta: CGFloat = 0.01) {}
}
public struct RotateGesture: Gesture {
    public struct Value: Equatable, Sendable { public var time: Date = Date(); public var rotation: Angle = .zero; public var velocity: Angle = .zero; public var startAnchor: UnitPoint = .center; public var startLocation: CGPoint = .zero }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(minimumAngleDelta: Angle = .degrees(1)) {}
}
public struct RotationGesture: Gesture {
    public typealias Value = Angle
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(minimumAngleDelta: Angle = .degrees(1)) {}
}
public struct AnyGesture<Value>: Gesture {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<T: Gesture>(_ gesture: T) where T.Value == Value {}
}
public struct _EndedGesture<Content: Gesture>: Gesture { public typealias Value = Content.Value; public typealias Body = Never; public var body: Never { return fatalError() } }
public struct _ChangedGesture<Content: Gesture>: Gesture { public typealias Value = Content.Value; public typealias Body = Never; public var body: Never { return fatalError() } }
public struct _MapGesture<Content: Gesture, Value>: Gesture { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct GestureStateGesture<Base: Gesture, State>: Gesture { public typealias Value = Base.Value; public typealias Body = Never; public var body: Never { return fatalError() } }
public struct SimultaneousGesture<First: Gesture, Second: Gesture>: Gesture {
    public struct Value { public var first: First.Value?; public var second: Second.Value? }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ first: First, _ second: Second) {}
}
public struct SequenceGesture<First: Gesture, Second: Gesture>: Gesture {
    public enum Value { case first(First.Value); case second(First.Value, Second.Value?) }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ first: First, _ second: Second) {}
}
public struct ExclusiveGesture<First: Gesture, Second: Gesture>: Gesture {
    public enum Value { case first(First.Value); case second(Second.Value) }
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ first: First, _ second: Second) {}
}
extension Gesture {
    public func onEnded(_ action: @escaping (Self.Value) -> Void) -> _EndedGesture<Self> { _EndedGesture() }
    public func onChanged(_ action: @escaping (Self.Value) -> Void) -> _ChangedGesture<Self> where Self.Value: Equatable { _ChangedGesture() }
    public func map<T>(_ body: @escaping (Self.Value) -> T) -> _MapGesture<Self, T> { _MapGesture() }
    public func updating<State>(_ state: GestureState<State>, body: @escaping (Self.Value, inout State, inout Transaction) -> Void) -> GestureStateGesture<Self, State> { GestureStateGesture() }
    public func simultaneously<Other: Gesture>(with other: Other) -> SimultaneousGesture<Self, Other> { SimultaneousGesture(self, other) }
    public func sequenced<Other: Gesture>(before other: Other) -> SequenceGesture<Self, Other> { SequenceGesture(self, other) }
    public func exclusively<Other: Gesture>(before other: Other) -> ExclusiveGesture<Self, Other> { ExclusiveGesture(self, other) }
    public func modifiers(_ modifiers: EventModifiers) -> some Gesture<Self.Value> { self }
}
extension View {
    public func gesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
    public func gesture<T: Gesture>(_ gesture: T, isEnabled: Bool) -> some View { self }
    public func gesture<T: Gesture>(_ gesture: T, name: String, isEnabled: Bool = true) -> some View { self }
    public func simultaneousGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
    public func simultaneousGesture<T: Gesture>(_ gesture: T, isEnabled: Bool) -> some View { self }
    public func highPriorityGesture<T: Gesture>(_ gesture: T, including mask: GestureMask = .all) -> some View { self }
    public func highPriorityGesture<T: Gesture>(_ gesture: T, isEnabled: Bool) -> some View { self }
    public func defersSystemGestures(_ edges: Edge.Set) -> some View { self }
    public func contentShape<S: Shape>(_ shape: S, eoFill: Bool = false) -> some View { self }
    public func contentShape<S: Shape>(_ kind: ContentShapeKinds, _ shape: S, eoFill: Bool = false) -> some View { self }
}
public struct ContentShapeKinds: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let interaction = ContentShapeKinds(rawValue: 1), dragPreview = ContentShapeKinds(rawValue: 2), contextMenuPreview = ContentShapeKinds(rawValue: 4), hoverEffect = ContentShapeKinds(rawValue: 8), accessibility = ContentShapeKinds(rawValue: 16), focusEffect = ContentShapeKinds(rawValue: 32)
}

// MARK: Accessibility

public struct AccessibilityTraits: OptionSet, Sendable {
    public let rawValue: UInt64
    public init(rawValue: UInt64) { self.rawValue = rawValue }
    public static let isButton = AccessibilityTraits(rawValue: 1 << 0), isHeader = AccessibilityTraits(rawValue: 1 << 1), isSelected = AccessibilityTraits(rawValue: 1 << 2), isLink = AccessibilityTraits(rawValue: 1 << 3),
        isSearchField = AccessibilityTraits(rawValue: 1 << 4), isImage = AccessibilityTraits(rawValue: 1 << 5), playsSound = AccessibilityTraits(rawValue: 1 << 6), isKeyboardKey = AccessibilityTraits(rawValue: 1 << 7),
        isStaticText = AccessibilityTraits(rawValue: 1 << 8), isSummaryElement = AccessibilityTraits(rawValue: 1 << 9), updatesFrequently = AccessibilityTraits(rawValue: 1 << 10), startsMediaSession = AccessibilityTraits(rawValue: 1 << 11),
        allowsDirectInteraction = AccessibilityTraits(rawValue: 1 << 12), causesPageTurn = AccessibilityTraits(rawValue: 1 << 13), isModal = AccessibilityTraits(rawValue: 1 << 14), isToggle = AccessibilityTraits(rawValue: 1 << 15),
        isTabBar = AccessibilityTraits(rawValue: 1 << 16)
}
public enum AccessibilityChildBehavior: Hashable, Sendable { case ignore, contain, combine }
public struct AccessibilityActionKind: Equatable, Sendable {
    public static let `default` = AccessibilityActionKind(), escape = AccessibilityActionKind(), magicTap = AccessibilityActionKind(), delete = AccessibilityActionKind(), showMenu = AccessibilityActionKind()
    public init(named name: Text) {}
    private init() {}
}
public enum AccessibilityAdjustmentDirection: Hashable, Sendable { case increment, decrement }
public enum AccessibilityLabeledPairRole: Hashable, Sendable { case label, content }
public struct AccessibilityDirectTouchOptions: OptionSet, Sendable { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let silentOnTouch = AccessibilityDirectTouchOptions(rawValue: 1), requiresActivation = AccessibilityDirectTouchOptions(rawValue: 2) }
public struct AccessibilityCustomContentKey: Equatable, Sendable { public init(_ label: Text, id: String) {}; public init(_ labelKey: LocalizedStringKey, id: String) {}; public init(_ labelKey: LocalizedStringKey) {} }
public struct AccessibilityTechnologies: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let voiceOver = AccessibilityTechnologies(rawValue: 1), switchControl = AccessibilityTechnologies(rawValue: 2) }
public struct AccessibilityAttachmentModifier: ViewModifier { public func body(content: Content) -> some View { content } }
public struct AccessibilityZoomGestureAction { public enum Direction: Sendable { case zoomIn, zoomOut }; public let direction: Direction = .zoomIn; public let location: UnitPoint = .center; public let point: CGPoint = .zero }
public struct AccessibilityActionCategory: Equatable, Sendable { public static let `default` = AccessibilityActionCategory(), edit = AccessibilityActionCategory(); public init(_ name: Text) {}; private init() {} }
@propertyWrapper public struct AccessibilityFocusState<Value: Hashable>: DynamicProperty {
    @propertyWrapper public struct Binding { public var wrappedValue: Value; public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }; public var projectedValue: Binding { self } }
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public init() where Value == Bool { box = Box(false) }
    public init(for technologies: AccessibilityTechnologies) where Value == Bool { box = Box(false) }
    public init<T: Hashable>() where Value == T? { box = Box(nil) }
    public init<T: Hashable>(for technologies: AccessibilityTechnologies) where Value == T? { box = Box(nil) }
    public var wrappedValue: Value { get { box.value } nonmutating set { box.value = newValue } }
    public var projectedValue: Binding { Binding(wrappedValue: box.value) }
}
extension View {
    public func accessibilityLabel(_ label: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel(_ label: Text, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel<S: StringProtocol>(_ label: S, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabel<V: View>(@ViewBuilder content: (PlaceholderContentView<Self>) -> V) -> some View { self }
    public func accessibilityValue(_ value: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityValue(_ valueKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityHint(_ hint: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityHint(_ hintKey: LocalizedStringKey) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityHint<S: StringProtocol>(_ hint: S) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityInputLabels(_ inputLabels: [Text]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityInputLabels(_ inputLabelKeys: [LocalizedStringKey]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityInputLabels<S: StringProtocol>(_ inputLabels: [S]) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityHidden(_ hidden: Bool, isEnabled: Bool) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilitySortPriority(_ sortPriority: Double) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityElement(children: AccessibilityChildBehavior = .ignore) -> some View { self }
    public func accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityAction(named nameKey: LocalizedStringKey, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityAction<S: StringProtocol>(named name: S, _ handler: @escaping () -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityAction<L: View>(action: @escaping () -> Void, @ViewBuilder label: () -> L) -> some View { self }
    public func accessibilityActions<Content: View>(@ViewBuilder _ content: () -> Content) -> some View { self }
    public func accessibilityActions<Content: View>(category: AccessibilityActionCategory, @ViewBuilder _ content: () -> Content) -> some View { self }
    public func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityScrollAction(_ handler: @escaping (Edge) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityZoomAction(_ handler: @escaping (AccessibilityZoomGestureAction) -> Void) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityRepresentation<V: View>(@ViewBuilder representation: () -> V) -> some View { self }
    public func accessibilityChildren<V: View>(@ViewBuilder children: () -> V) -> some View { self }
    public func accessibilityShowsLargeContentViewer() -> some View { self }
    public func accessibilityShowsLargeContentViewer<V: View>(@ViewBuilder _ largeContentView: () -> V) -> some View { self }
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityRespondsToUserInteraction(_ respondsToUserInteraction: Bool = true) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityLabeledPair<ID: Hashable>(role: AccessibilityLabeledPairRole, id: ID, in namespace: Namespace.ID) -> some View { self }
    public func accessibilityLinkedGroup<ID: Hashable>(id: ID, in namespace: Namespace.ID) -> some View { self }
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ label: Text, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View { self }
    public func accessibilityRotor<Content: AccessibilityRotorContent>(_ labelKey: LocalizedStringKey, @AccessibilityRotorContentBuilder entries: @escaping () -> Content) -> some View { self }
    public func accessibilityCustomContent(_ key: AccessibilityCustomContentKey, _ value: Text?, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityCustomContent<V: StringProtocol>(_ key: AccessibilityCustomContentKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityCustomContent(_ labelKey: LocalizedStringKey, _ value: Text?, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityCustomContent<V: StringProtocol>(_ labelKey: LocalizedStringKey, _ value: V, importance: AXCustomContent.Importance = .default) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityDirectTouch(_ isDirectTouchArea: Bool = true, options: AccessibilityDirectTouchOptions = []) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityFocused(_ condition: AccessibilityFocusState<Bool>.Binding) -> some View { self }
    public func accessibilityFocused<Value: Hashable>(_ binding: AccessibilityFocusState<Value>.Binding, equals value: Value) -> some View { self }
    public func accessibilityActivationPoint(_ activationPoint: CGPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityActivationPoint(_ activationPoint: UnitPoint) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityIgnoresInvertColors(_ active: Bool = true) -> some View { self }
    public func accessibilityDragPoint(_ point: UnitPoint, description: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityDropPoint(_ point: UnitPoint, description: Text) -> ModifiedContent<Self, AccessibilityAttachmentModifier> { ModifiedContent(content: self, modifier: AccessibilityAttachmentModifier()) }
    public func accessibilityDefaultFocus<Value: Hashable>(_ binding: AccessibilityFocusState<Value>.Binding, _ value: Value, priority: DefaultFocusEvaluationPriority = .automatic) -> some View { self }
}
extension ModifiedContent where Modifier == AccessibilityAttachmentModifier {
    public func accessibilityLabel(_ label: Text) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityValue(_ value: Text) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityValue(_ valueKey: LocalizedStringKey) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityHint(_ hint: Text) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityHint(_ hintKey: LocalizedStringKey) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityHint<S: StringProtocol>(_ hint: S) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityIdentifier(_ identifier: String) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityHidden(_ hidden: Bool) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAddTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityRemoveTraits(_ traits: AccessibilityTraits) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilitySortPriority(_ sortPriority: Double) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAction(_ actionKind: AccessibilityActionKind = .default, _ handler: @escaping () -> Void) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAction(named name: Text, _ handler: @escaping () -> Void) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAction(named nameKey: LocalizedStringKey, _ handler: @escaping () -> Void) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAction<S: StringProtocol>(named name: S, _ handler: @escaping () -> Void) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityAdjustableAction(_ handler: @escaping (AccessibilityAdjustmentDirection) -> Void) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityInputLabels(_ inputLabels: [Text]) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityInputLabels<S: StringProtocol>(_ inputLabels: [S]) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityRespondsToUserInteraction(_ respondsToUserInteraction: Bool = true) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
    public func accessibilityActivationPoint(_ activationPoint: UnitPoint) -> ModifiedContent<Content, AccessibilityAttachmentModifier> { self }
}
public enum AXCustomContent { public enum Importance: Sendable { case `default`, high } }
public protocol AccessibilityRotorContent {}
@resultBuilder public struct AccessibilityRotorContentBuilder {
    public static func buildBlock<C: AccessibilityRotorContent>(_ c: C) -> C { c }
}
public struct AccessibilityRotorEntry<ID: Hashable>: AccessibilityRotorContent {
    public init(_ label: Text, id: ID, in namespace: Namespace.ID? = nil, prepare: @escaping () -> Void = {}) {}
    public init<L: StringProtocol>(_ label: L, id: ID, in namespace: Namespace.ID? = nil, prepare: @escaping () -> Void = {}) {}
}
extension ForEach: AccessibilityRotorContent where Content: AccessibilityRotorContent {}

// MARK: Liquid Glass (iOS 26)

public struct Glass: Equatable, Sendable {
    public static var regular: Glass { Glass() }
    public static var clear: Glass { Glass() }
    public static var identity: Glass { Glass() }
    public func tint(_ color: Color?) -> Glass { self }
    public func interactive(_ isEnabled: Bool = true) -> Glass { self }
}
public struct GlassEffectContainer<Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(spacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
}
public struct GlassEffectTransition: Sendable {
    public static var identity: GlassEffectTransition { GlassEffectTransition() }
    public static var matchedGeometry: GlassEffectTransition { GlassEffectTransition() }
    public static func matchedGeometry(properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center) -> GlassEffectTransition { GlassEffectTransition() }
    public static var materialize: GlassEffectTransition { GlassEffectTransition() }
}
extension View {
    public func glassEffect(_ glass: Glass = .regular, in shape: some Shape = DefaultGlassEffectShape(), isEnabled: Bool = true) -> some View { self }
    public func glassEffectID(_ id: (some Hashable & Sendable)?, in namespace: Namespace.ID) -> some View { self }
    public func glassEffectUnion(id: (some Hashable & Sendable)?, namespace: Namespace.ID) -> some View { self }
    public func glassEffectTransition(_ transition: GlassEffectTransition, isEnabled: Bool = true) -> some View { self }
    public func glassBackgroundEffect(displayMode: GlassBackgroundDisplayMode = .always) -> some View { self }
    public func glassBackgroundEffect<S: InsettableShape>(in shape: S, displayMode: GlassBackgroundDisplayMode = .always) -> some View { self }
}
public struct DefaultGlassEffectShape: InsettableShape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> DefaultGlassEffectShape { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public enum GlassBackgroundDisplayMode: Hashable, Sendable { case always, implicit, never }
