// SwiftUI stub — core: View protocol, result builders, primitive containers,
// property wrappers, environment, App/Scene. Signatures follow the iOS 26
// SDK (`View`/`App`/`Scene` are @MainActor since the iOS 18 SDK).
@_exported import Foundation
@_exported import UIKit
@_exported import Combine
@_exported import Observation
@_exported import CoreTransferable
@_exported import DarwinShims

/// Lets stub modules outside SwiftUI add initializers to SwiftUI value types
/// (Swift requires cross-module inits to delegate to an existing one).
public struct _StubInit { public init() {} }

// MARK: View

@MainActor @preconcurrency
public protocol View {
    associatedtype Body: View
    @ViewBuilder @MainActor @preconcurrency var body: Self.Body { get }
}

extension Never: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

extension Optional: View where Wrapped: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct EmptyView: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct TupleView<T>: View {
    public var value: T
    public init(_ value: T) { self.value = value }
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct _ConditionalContent<TrueContent: View, FalseContent: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct AnyView: View {
    public init<V: View>(_ view: V) {}
    public init<V: View>(erasing view: V) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct Group<Content> {
    init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Group: View where Content: View {
    public init(@ViewBuilder content: () -> Content) { self.init() }
}

@resultBuilder
public struct ViewBuilder {
    public static func buildBlock() -> EmptyView { EmptyView() }
    public static func buildBlock<C: View>(_ c: C) -> C { c }
    public static func buildBlock<C0: View, C1: View>(_ c0: C0, _ c1: C1) -> TupleView<(C0, C1)> { TupleView((c0, c1)) }
    public static func buildBlock<C0: View, C1: View, C2: View>(_ c0: C0, _ c1: C1, _ c2: C2) -> TupleView<(C0, C1, C2)> { TupleView((c0, c1, c2)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> TupleView<(C0, C1, C2, C3)> { TupleView((c0, c1, c2, c3)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> TupleView<(C0, C1, C2, C3, C4)> { TupleView((c0, c1, c2, c3, c4)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> TupleView<(C0, C1, C2, C3, C4, C5)> { TupleView((c0, c1, c2, c3, c4, c5)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> TupleView<(C0, C1, C2, C3, C4, C5, C6)> { TupleView((c0, c1, c2, c3, c4, c5, c6)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8)) }
    public static func buildBlock<C0: View, C1: View, C2: View, C3: View, C4: View, C5: View, C6: View, C7: View, C8: View, C9: View>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> TupleView<(C0, C1, C2, C3, C4, C5, C6, C7, C8, C9)> { TupleView((c0, c1, c2, c3, c4, c5, c6, c7, c8, c9)) }
    public static func buildExpression<C: View>(_ content: C) -> C { content }
    public static func buildIf<C: View>(_ content: C?) -> C? { content }
    public static func buildEither<T: View, F: View>(first: T) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildEither<T: View, F: View>(second: F) -> _ConditionalContent<T, F> { _ConditionalContent() }
    public static func buildLimitedAvailability<C: View>(_ content: C) -> AnyView { AnyView(content) }
}

// MARK: ForEach

public protocol DynamicViewContent: View {
    associatedtype Data: Collection
    var data: Data { get }
}

public struct ForEach<Data: RandomAccessCollection, ID: Hashable, Content> {
    public var data: Data
    public var content: (Data.Element) -> Content
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(data: Data, content: @escaping (Data.Element) -> Content) { self.data = data; self.content = content }
}
extension ForEach: View, DynamicViewContent where Content: View {
    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable { self.init(data: data, content: content) }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder content: @escaping (Data.Element) -> Content) { self.init(data: data, content: content) }
    public init<C>(_ data: Binding<C>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content) where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, ID == C.Element.ID, C: MutableCollection & RandomAccessCollection, C.Element: Identifiable, C.Index: Hashable { fatalError() }
    public init<C>(_ data: Binding<C>, id: KeyPath<C.Element, ID>, @ViewBuilder content: @escaping (Binding<C.Element>) -> Content) where Data == LazyMapSequence<C.Indices, (C.Index, ID)>, C: MutableCollection & RandomAccessCollection, C.Index: Hashable { fatalError() }
    public init(_ data: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) where Data == Range<Int>, ID == Int { self.init(data: data, content: content) }
}
extension DynamicViewContent {
    public func onDelete(perform action: ((IndexSet) -> Void)?) -> some DynamicViewContent { self }
    public func onMove(perform action: ((IndexSet, Int) -> Void)?) -> some DynamicViewContent { self }
}

// MARK: ViewModifier

@MainActor @preconcurrency
public protocol ViewModifier {
    associatedtype Body: View
    typealias Content = _ViewModifier_Content<Self>
    @ViewBuilder @MainActor @preconcurrency func body(content: Self.Content) -> Self.Body
}
public struct _ViewModifier_Content<Modifier: ViewModifier>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct ModifiedContent<Content, Modifier> {
    public var content: Content
    public var modifier: Modifier
    public init(content: Content, modifier: Modifier) { self.content = content; self.modifier = modifier }
}
extension ModifiedContent: View where Content: View, Modifier: ViewModifier {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension View {
    public func modifier<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}
extension ViewModifier {
    public func concat<T: ViewModifier>(_ modifier: T) -> ModifiedContent<Self, T> { ModifiedContent(content: self, modifier: modifier) }
}
public struct EmptyModifier: ViewModifier {
    public init() {}
    public static let identity = EmptyModifier()
    public func body(content: Content) -> some View { content }
}

// MARK: Dynamic properties

public protocol DynamicProperty {
    mutating func update()
}
extension DynamicProperty {
    public mutating func update() {}
}

@propertyWrapper
public struct State<Value>: DynamicProperty {
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public init(wrappedValue value: Value) { box = Box(value) }
    public init(initialValue value: Value) { box = Box(value) }
    public var wrappedValue: Value {
        get { box.value }
        nonmutating set { box.value = newValue }
    }
    public var projectedValue: Binding<Value> { Binding(get: { self.box.value }, set: { self.box.value = $0 }) }
}
extension State where Value: ExpressibleByNilLiteral {
    public init() { self.init(wrappedValue: nil) }
}

@propertyWrapper @dynamicMemberLookup
public struct Binding<Value> {
    private let getter: () -> Value
    private let setter: (Value) -> Void
    public var transaction: Transaction = Transaction()
    public init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { getter = get; setter = set }
    public init(get: @escaping () -> Value, set: @escaping (Value, Transaction) -> Void) { getter = get; setter = { set($0, Transaction()) } }
    public init(projectedValue: Binding<Value>) { self = projectedValue }
    public var wrappedValue: Value {
        get { getter() }
        nonmutating set { setter(newValue) }
    }
    public var projectedValue: Binding<Value> { self }
    public static func constant(_ value: Value) -> Binding<Value> { Binding(get: { value }, set: { _ in }) }
    public subscript<Subject>(dynamicMember keyPath: WritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding<Subject>(get: { self.wrappedValue[keyPath: keyPath] }, set: { var v = self.wrappedValue; v[keyPath: keyPath] = $0; self.wrappedValue = v })
    }
    public func transaction(_ transaction: Transaction) -> Binding<Value> { self }
    public func animation(_ animation: Animation? = .default) -> Binding<Value> { self }
}
extension Binding {
    public init<V>(_ base: Binding<V>) where Value == V? {
        self.init(get: { base.wrappedValue }, set: { if let v = $0 { base.wrappedValue = v } })
    }
    public init?(_ base: Binding<Value?>) {
        guard let initial = base.wrappedValue else { return nil }
        self.init(get: { base.wrappedValue ?? initial }, set: { base.wrappedValue = $0 })
    }
}
extension Binding: Identifiable where Value: Identifiable {
    public var id: Value.ID { wrappedValue.id }
}
extension Binding: @unchecked Sendable {}

@propertyWrapper
public struct Environment<Value>: DynamicProperty {
    private let read: () -> Value
    public init(_ keyPath: KeyPath<EnvironmentValues, Value>) { read = { EnvironmentValues()[keyPath: keyPath] } }
    public var wrappedValue: Value { read() }
}
extension Environment where Value: AnyObject & Observable {
    public init(_ objectType: Value.Type) { read = { fatalError() } }
}
extension Environment {
    public init<T: AnyObject & Observable>(_ objectType: T.Type) where Value == T? { read = { nil } }
}
extension Environment where Value: Observable & AnyObject {
    public var projectedValue: Bindable<Value> { Bindable(wrappedValue: wrappedValue) }
}

@propertyWrapper @dynamicMemberLookup
public struct Bindable<Value> {
    public var wrappedValue: Value
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(_ wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(projectedValue: Bindable<Value>) { self = projectedValue }
    public var projectedValue: Bindable<Value> { self }
}
extension Bindable where Value: AnyObject {
    public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<Value, Subject>) -> Binding<Subject> {
        Binding(get: { self.wrappedValue[keyPath: keyPath] }, set: { self.wrappedValue[keyPath: keyPath] = $0 })
    }
}

@propertyWrapper
public struct AppStorage<Value>: DynamicProperty {
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public var wrappedValue: Value { get { box.value } nonmutating set { box.value = newValue } }
    public var projectedValue: Binding<Value> { Binding(get: { self.box.value }, set: { self.box.value = $0 }) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Bool { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Int { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Double { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == String { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == URL { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Data { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value == Date { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == Int { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String, store: UserDefaults? = nil) where Value: RawRepresentable, Value.RawValue == String { box = Box(wrappedValue) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Bool? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Int? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Double? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == String? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == URL? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Data? { box = Box(nil) }
    public init(_ key: String, store: UserDefaults? = nil) where Value == Date? { box = Box(nil) }
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == String { box = Box(nil) }
    public init<R>(_ key: String, store: UserDefaults? = nil) where Value == R?, R: RawRepresentable, R.RawValue == Int { box = Box(nil) }
}

@propertyWrapper
public struct SceneStorage<Value>: DynamicProperty {
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public var wrappedValue: Value { get { box.value } nonmutating set { box.value = newValue } }
    public var projectedValue: Binding<Value> { Binding(get: { self.box.value }, set: { self.box.value = $0 }) }
    public init(wrappedValue: Value, _ key: String) where Value == Bool { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String) where Value == Int { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String) where Value == Double { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String) where Value == String { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == String { box = Box(wrappedValue) }
    public init(wrappedValue: Value, _ key: String) where Value: RawRepresentable, Value.RawValue == Int { box = Box(wrappedValue) }
    public init(_ key: String) where Value == String? { box = Box(nil) }
    public init(_ key: String) where Value == Int? { box = Box(nil) }
}

@propertyWrapper
public struct FocusState<Value: Hashable>: DynamicProperty {
    @propertyWrapper @dynamicMemberLookup
    public struct Binding {
        private let get: () -> Value
        private let set: (Value) -> Void
        init(get: @escaping () -> Value, set: @escaping (Value) -> Void) { self.get = get; self.set = set }
        public var wrappedValue: Value { get { get() } nonmutating set { set(newValue) } }
        public var projectedValue: FocusState<Value>.Binding { self }
        public subscript<T>(dynamicMember keyPath: WritableKeyPath<Value, T>) -> SwiftUI.Binding<T> {
            SwiftUI.Binding(get: { self.wrappedValue[keyPath: keyPath] }, set: { var v = self.wrappedValue; v[keyPath: keyPath] = $0; self.wrappedValue = v })
        }
    }
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public init() where Value == Bool { box = Box(false) }
    public init<T: Hashable>() where Value == T? { box = Box(nil) }
    public var wrappedValue: Value { get { box.value } nonmutating set { box.value = newValue } }
    public var projectedValue: FocusState<Value>.Binding { Binding(get: { self.box.value }, set: { self.box.value = $0 }) }
}

@propertyWrapper
public struct Namespace: DynamicProperty {
    public struct ID: Hashable {}
    public init() {}
    public var wrappedValue: Namespace.ID { ID() }
}

@propertyWrapper
public struct GestureState<Value>: DynamicProperty {
    private final class Box { var value: Value; init(_ v: Value) { value = v } }
    private let box: Box
    public init(wrappedValue: Value) { box = Box(wrappedValue) }
    public init(initialValue: Value) { box = Box(initialValue) }
    public init(wrappedValue: Value, resetTransaction: Transaction) { box = Box(wrappedValue) }
    public init(wrappedValue: Value, reset: @escaping (Value, inout Transaction) -> Void) { box = Box(wrappedValue) }
    public var wrappedValue: Value { box.value }
    public var projectedValue: GestureState<Value> { self }
}

@propertyWrapper
public struct ScaledMetric<Value: BinaryFloatingPoint>: DynamicProperty {
    public init(wrappedValue: Value) { self.wrappedValue = wrappedValue }
    public init(wrappedValue: Value, relativeTo textStyle: Font.TextStyle) { self.wrappedValue = wrappedValue }
    public var wrappedValue: Value
}

@propertyWrapper
public struct StateObject<ObjectType: ObservableObject>: DynamicProperty {
    private let object: ObjectType
    public init(wrappedValue thunk: @autoclosure @escaping () -> ObjectType) { object = thunk() }
    public var wrappedValue: ObjectType { object }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { ObservedObject<ObjectType>.Wrapper(object) }
}
@propertyWrapper
public struct ObservedObject<ObjectType: ObservableObject>: DynamicProperty {
    @dynamicMemberLookup public struct Wrapper {
        let object: ObjectType
        init(_ o: ObjectType) { object = o }
        public subscript<Subject>(dynamicMember keyPath: ReferenceWritableKeyPath<ObjectType, Subject>) -> Binding<Subject> {
            Binding(get: { self.object[keyPath: keyPath] }, set: { self.object[keyPath: keyPath] = $0 })
        }
    }
    public init(wrappedValue: ObjectType) { self.wrappedValue = wrappedValue }
    public init(initialValue: ObjectType) { self.wrappedValue = initialValue }
    public var wrappedValue: ObjectType
    public var projectedValue: Wrapper { Wrapper(wrappedValue) }
}
@propertyWrapper
public struct EnvironmentObject<ObjectType: ObservableObject>: DynamicProperty {
    public init() {}
    public var wrappedValue: ObjectType { fatalError() }
    public var projectedValue: ObservedObject<ObjectType>.Wrapper { fatalError() }
}

@propertyWrapper
public struct UIApplicationDelegateAdaptor<DelegateType: NSObject & UIApplicationDelegate>: DynamicProperty {
    public init(_ delegateType: DelegateType.Type = DelegateType.self) {}
    public var wrappedValue: DelegateType { fatalError() }
}

// MARK: Environment

public protocol EnvironmentKey {
    associatedtype Value
    static var defaultValue: Value { get }
}

public struct EnvironmentValues {
    public init() {}
    private var storage: [ObjectIdentifier: Any] = [:]
    public subscript<K: EnvironmentKey>(key: K.Type) -> K.Value {
        get { storage[ObjectIdentifier(key)] as? K.Value ?? K.defaultValue }
        set { storage[ObjectIdentifier(key)] = newValue }
    }
    public subscript<T: AnyObject & Observable>(objectType: T.Type) -> T? {
        get { nil }
        set {}
    }

    public var dismiss: DismissAction { DismissAction() }
    public var isPresented: Bool { false }
    public var openURL: OpenURLAction = OpenURLAction { _ in .systemAction }
    public var refresh: RefreshAction? { nil }
    public var scenePhase: ScenePhase { .active }
    public var colorScheme: ColorScheme = .light
    public var colorSchemeContrast: ColorSchemeContrast { .standard }
    public var locale: Locale = .current
    public var calendar: Calendar = .current
    public var timeZone: TimeZone = .current
    public var layoutDirection: LayoutDirection = .leftToRight
    public var isEnabled: Bool = true
    public var isFocused: Bool { false }
    public var isSearching: Bool { false }
    public var dismissSearch: DismissSearchAction { DismissSearchAction() }
    public var dynamicTypeSize: DynamicTypeSize = .large
    public var sizeCategory: ContentSizeCategory = .large
    public var horizontalSizeClass: UserInterfaceSizeClass? = .compact
    public var verticalSizeClass: UserInterfaceSizeClass? = .regular
    public var displayScale: CGFloat = 3
    public var pixelLength: CGFloat { 1 / displayScale }
    public var accessibilityReduceMotion: Bool { false }
    public var accessibilityReduceTransparency: Bool { false }
    public var accessibilityDifferentiateWithoutColor: Bool { false }
    public var accessibilityInvertColors: Bool { false }
    public var accessibilityVoiceOverEnabled: Bool { false }
    public var accessibilitySwitchControlEnabled: Bool { false }
    public var accessibilityEnabled: Bool = false
    public var accessibilityDimFlashingLights: Bool { false }
    public var accessibilityPlayAnimatedImages: Bool { true }
    public var accessibilityShowButtonShapes: Bool { false }
    public var legibilityWeight: LegibilityWeight? = nil
    public var redactionReasons: RedactionReasons = []
    public var isLuminanceReduced: Bool = false
    public var controlSize: ControlSize = .regular
    public var font: Font? = nil
    public var lineLimit: Int? = nil
    public var multilineTextAlignment: TextAlignment = .leading
    public var truncationMode: Text.TruncationMode = .tail
    public var minimumScaleFactor: CGFloat = 1
    public var allowsTightening: Bool = false
    public var lineSpacing: CGFloat = 0
    public var textCase: Text.Case? = nil
    public var imageScale: Image.Scale = .medium
    public var symbolRenderingMode: SymbolRenderingMode? = nil
    public var symbolVariants: SymbolVariants = .none
    public var editMode: Binding<EditMode>? = nil
    public var presentationMode: Binding<PresentationMode> { .constant(PresentationMode()) }
    public var undoManager: UndoManager? { nil }
    public var supportsMultipleWindows: Bool { false }
    public var openWindow: OpenWindowAction { OpenWindowAction() }
    public var dismissWindow: DismissWindowAction { DismissWindowAction() }
    public var defaultMinListRowHeight: CGFloat = 44
    public var defaultMinListHeaderHeight: CGFloat? = nil
    public var headerProminence: Prominence = .standard
    public var backgroundProminence: BackgroundProminence = .standard
    public var backgroundMaterial: Material? = nil
    public var menuOrder: MenuOrder = .automatic
    public var menuIndicatorVisibility: Visibility = .automatic
    public var isScrollEnabled: Bool = true
    public var contentTransition: ContentTransition = .identity
    public var contentTransitionAddsDrawingGroup: Bool = false
    public var searchSuggestionsPlacement: SearchSuggestionsPlacement { .automatic }
    public var keyboardShortcut: KeyboardShortcut? { nil }
    public var isHoverEffectEnabled: Bool = true
    public var buttonRepeatBehavior: ButtonRepeatBehavior = .automatic
    public var appearsActive: Bool { true }
    public var isSceneCaptured: Bool { false }
    public var physicalMetrics: Int { 0 }
}

public struct DismissAction {
    public func callAsFunction() {}
}
public struct DismissSearchAction {
    public func callAsFunction() {}
}
public struct RefreshAction {
    public func callAsFunction() async {}
}
public struct OpenURLAction {
    public struct Result {
        public static let handled = Result()
        public static let discarded = Result()
        public static let systemAction = Result()
        public static func systemAction(_ url: URL) -> Result { Result() }
    }
    public init(handler: @escaping (URL) -> OpenURLAction.Result) {}
    public func callAsFunction(_ url: URL) {}
    public func callAsFunction(_ url: URL, completion: @escaping (Bool) -> Void) {}
}
public struct OpenWindowAction {
    public func callAsFunction(id: String) {}
    public func callAsFunction<D: Codable & Hashable>(id: String, value: D) {}
    public func callAsFunction<D: Codable & Hashable>(value: D) {}
}
public struct DismissWindowAction {
    public func callAsFunction() {}
    public func callAsFunction(id: String) {}
}
public struct PresentationMode {
    public var isPresented: Bool { true }
    public mutating func dismiss() {}
}

public enum ScenePhase: Comparable, Hashable { case background, inactive, active }
public enum ColorScheme: CaseIterable, Hashable, Sendable { case light, dark }
public enum ColorSchemeContrast: CaseIterable, Hashable { case standard, increased }
public enum LayoutDirection: CaseIterable, Hashable { case leftToRight, rightToLeft }
public enum UserInterfaceSizeClass: Hashable { case compact, regular }
public enum LegibilityWeight: Hashable { case regular, bold }
public enum EditMode: Hashable { case inactive, transient, active; public var isEditing: Bool { self != .inactive } }
public enum Prominence: Hashable { case standard, increased }
public enum BackgroundProminence: Hashable { case standard, increased }
public enum MenuOrder: Hashable { case automatic, priority, fixed }
public enum Visibility: Hashable, CaseIterable { case automatic, visible, hidden }
public enum ControlSize: CaseIterable, Hashable { case mini, small, regular, large, extraLarge }
public enum DynamicTypeSize: Hashable, Comparable, CaseIterable {
    case xSmall, small, medium, large, xLarge, xxLarge, xxxLarge, accessibility1, accessibility2, accessibility3, accessibility4, accessibility5
    public var isAccessibilitySize: Bool { self >= .accessibility1 }
}
public enum ContentSizeCategory: Hashable, CaseIterable {
    case extraSmall, small, medium, large, extraLarge, extraExtraLarge, extraExtraExtraLarge,
         accessibilityMedium, accessibilityLarge, accessibilityExtraLarge, accessibilityExtraExtraLarge, accessibilityExtraExtraExtraLarge
    public var isAccessibilityCategory: Bool { false }
}
public struct RedactionReasons: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let placeholder = RedactionReasons(rawValue: 1)
    public static let privacy = RedactionReasons(rawValue: 2)
    public static let invalidated = RedactionReasons(rawValue: 4)
}
public struct KeyboardShortcut: Hashable {
    public static let defaultAction = KeyboardShortcut(.return)
    public static let cancelAction = KeyboardShortcut(.escape)
    public init(_ key: KeyEquivalent, modifiers: EventModifiers = .command) {}
}
public struct KeyEquivalent: Hashable, Sendable, ExpressibleByExtendedGraphemeClusterLiteral {
    public init(extendedGraphemeClusterLiteral value: Character) {}
    public init(_ character: Character) {}
    public static let `return` = KeyEquivalent("\r"), escape = KeyEquivalent("\u{1b}"), space = KeyEquivalent(" "), tab = KeyEquivalent("\t"), delete = KeyEquivalent("\u{8}")
    public static let upArrow = KeyEquivalent("\u{F700}"), downArrow = KeyEquivalent("\u{F701}"), leftArrow = KeyEquivalent("\u{F702}"), rightArrow = KeyEquivalent("\u{F703}")
}
public struct EventModifiers: OptionSet, Hashable, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let capsLock = EventModifiers(rawValue: 1), shift = EventModifiers(rawValue: 2), control = EventModifiers(rawValue: 4), option = EventModifiers(rawValue: 8), command = EventModifiers(rawValue: 16), numericPad = EventModifiers(rawValue: 32), all = EventModifiers(rawValue: 63)
}
public enum ButtonRepeatBehavior: Hashable { case automatic, enabled, disabled }

extension View {
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some View { self }
    public func environment<T: AnyObject & Observable>(_ object: T?) -> some View { self }
    public func environmentObject<T: ObservableObject>(_ object: T) -> some View { self }
    public func transformEnvironment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, transform: @escaping (inout V) -> Void) -> some View { self }
    public func preferredColorScheme(_ colorScheme: ColorScheme?) -> some View { self }
    public func dynamicTypeSize(_ size: DynamicTypeSize) -> some View { self }
    public func dynamicTypeSize<T: RangeExpression>(_ range: T) -> some View where T.Bound == DynamicTypeSize { self }
    public func redacted(reason: RedactionReasons) -> some View { self }
    public func unredacted() -> some View { self }
    public func privacySensitive(_ sensitive: Bool = true) -> some View { self }
    public func disabled(_ disabled: Bool) -> some View { self }
    public func hidden() -> some View { self }
    public func allowsHitTesting(_ enabled: Bool) -> some View { self }
    public func id<ID: Hashable>(_ id: ID) -> some View { self }
    public func tag<V: Hashable>(_ tag: V) -> some View { self }
    public func tag<V: Hashable>(_ tag: V, includeOptional: Bool) -> some View { self }
    public func equatable() -> EquatableView<Self> where Self: Equatable { EquatableView(content: self) }
    public func controlSize(_ controlSize: ControlSize) -> some View { self }
    public func layoutDirectionBehavior(_ behavior: LayoutDirectionBehavior) -> some View { self }
    public func persistentSystemOverlays(_ visibility: Visibility) -> some View { self }
    public func statusBarHidden(_ hidden: Bool = true) -> some View { self }
    public func defersSystemGestures(on edges: Edge.Set) -> some View { self }
    public func handlesExternalEvents(preferring: Set<String>, allowing: Set<String>) -> some View { self }
    public func userActivity(_ activityType: String, isActive: Bool = true, _ update: @escaping (NSUserActivity) -> Void) -> some View { self }
    public func onContinueUserActivity(_ activityType: String, perform action: @escaping (NSUserActivity) -> Void) -> some View { self }
    public func onOpenURL(perform action: @escaping (URL) -> Void) -> some View { self }
    public func widgetURL(_ url: URL?) -> some View { self }
    public func interactionActivityTrackingTag(_ tag: String) -> some View { self }
    public func headerProminence(_ prominence: Prominence) -> some View { self }
    public func backgroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
    public func menuOrder(_ order: MenuOrder) -> some View { self }
    public func menuIndicator(_ visibility: Visibility) -> some View { self }
    public func menuActionDismissBehavior(_ behavior: MenuActionDismissBehavior) -> some View { self }
    public func labelsHidden() -> some View { self }
    public func labelsVisibility(_ visibility: Visibility) -> some View { self }
    public func keyboardShortcut(_ key: KeyEquivalent, modifiers: EventModifiers = .command) -> some View { self }
    public func keyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View { self }
    public func hoverEffect(_ effect: HoverEffect = .automatic, isEnabled: Bool = true) -> some View { self }
    public func hoverEffectDisabled(_ disabled: Bool = true) -> some View { self }
    public func focusable(_ isFocusable: Bool = true) -> some View { self }
    public func focusEffectDisabled(_ disabled: Bool = true) -> some View { self }
    public func defaultFocus<V: Hashable>(_ binding: FocusState<V>.Binding, _ value: V, priority: DefaultFocusEvaluationPriority = .automatic) -> some View { self }
    public func prefersDefaultFocus(_ prefersDefaultFocus: Bool = true, in namespace: Namespace.ID) -> some View { self }
    public func focusScope(_ namespace: Namespace.ID) -> some View { self }
    public func focusSection() -> some View { self }
    public func buttonRepeatBehavior(_ behavior: ButtonRepeatBehavior) -> some View { self }
    public func springLoadingBehavior(_ behavior: SpringLoadingBehavior) -> some View { self }
}
public struct EquatableView<Content: View & Equatable>: View {
    public var content: Content
    public init(content: Content) { self.content = content }
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public enum LayoutDirectionBehavior: Hashable { case fixed, mirrors }
public struct MenuActionDismissBehavior: Hashable { public static let automatic = MenuActionDismissBehavior(), enabled = MenuActionDismissBehavior(), disabled = MenuActionDismissBehavior() }
public struct HoverEffect { public static let automatic = HoverEffect(), highlight = HoverEffect(), lift = HoverEffect() }
public enum DefaultFocusEvaluationPriority: Hashable { case automatic, userInitiated }
public struct SpringLoadingBehavior: Hashable { public static let automatic = SpringLoadingBehavior(), enabled = SpringLoadingBehavior(), disabled = SpringLoadingBehavior() }

// MARK: App & Scene

@MainActor @preconcurrency
public protocol App {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
    @MainActor @preconcurrency init()
}
extension App {
    @MainActor public static func main() {}
}

@MainActor @preconcurrency
public protocol Scene {
    associatedtype Body: Scene
    @SceneBuilder @MainActor @preconcurrency var body: Self.Body { get }
}
extension Never: Scene {}

@resultBuilder
public struct SceneBuilder {
    public static func buildBlock<C: Scene>(_ c: C) -> C { c }
    public static func buildBlock<C0: Scene, C1: Scene>(_ c0: C0, _ c1: C1) -> _TupleScene { _TupleScene() }
    public static func buildBlock<C0: Scene, C1: Scene, C2: Scene>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleScene { _TupleScene() }
    public static func buildBlock<C0: Scene, C1: Scene, C2: Scene, C3: Scene>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleScene { _TupleScene() }
    public static func buildOptional<C: Scene>(_ c: C?) -> C? { c }
    public static func buildEither<T: Scene, F: Scene>(first: T) -> _ConditionalScene<T, F> { _ConditionalScene() }
    public static func buildEither<T: Scene, F: Scene>(second: F) -> _ConditionalScene<T, F> { _ConditionalScene() }
}
public struct _TupleScene: Scene {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct _ConditionalScene<T: Scene, F: Scene>: Scene {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Optional: Scene where Wrapped: Scene {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

public struct WindowGroup<Content: View>: Scene {
    public init(@ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
    public init(id: String, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, id: String, @ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct Settings<Content: View>: Scene {
    public init(@ViewBuilder content: () -> Content) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

extension Scene {
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some Scene { self }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some Scene { self }
    public func backgroundTask<D: Sendable, R: Sendable>(_ task: BackgroundTask<D, R>, action: @escaping @Sendable (D) async -> R) -> some Scene { self }
    public func handlesExternalEvents(matching conditions: Set<String>) -> some Scene { self }
    public func defaultAppStorage(_ store: UserDefaults) -> some Scene { self }
    public func windowResizability(_ resizability: WindowResizability) -> some Scene { self }
    public func commands<Content: Commands>(@CommandsBuilder content: () -> Content) -> some Scene { self }
    public func environment<V>(_ keyPath: WritableKeyPath<EnvironmentValues, V>, _ value: V) -> some Scene { self }
    public func environment<T: AnyObject & Observable>(_ object: T?) -> some Scene { self }
    public func environmentObject<T: ObservableObject>(_ object: T) -> some Scene { self }
}
public struct BackgroundTask<Request, Response> {
    public static var appRefresh: BackgroundTask<String?, Void> { BackgroundTask<String?, Void>() }
    public static func appRefresh(_ identifier: String) -> BackgroundTask<Void, Void> { BackgroundTask<Void, Void>() }
    public static var urlSession: BackgroundTask<String, Void> { BackgroundTask<String, Void>() }
    public static func urlSession(_ identifier: String) -> BackgroundTask<Void, Void> { BackgroundTask<Void, Void>() }
    public static func urlSession(matching: @escaping (String) -> Bool) -> BackgroundTask<String, Void> { BackgroundTask<String, Void>() }
}
public enum WindowResizability { case automatic, contentSize, contentMinSize }
public protocol Commands {}
@resultBuilder public struct CommandsBuilder { public static func buildBlock<C: Commands>(_ c: C) -> C { c } }
