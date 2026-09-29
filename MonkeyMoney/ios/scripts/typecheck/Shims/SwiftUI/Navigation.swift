// SwiftUI stub — NavigationStack, TabView/Tab, toolbars, List/Form/Section,
// searchable, list row modifiers.
import Foundation

// MARK: Navigation

public struct NavigationPath: Equatable {
    public init() {}
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable {}
    public init<S: Sequence>(_ elements: S) where S.Element: Hashable & Codable {}
    public var count: Int { 0 }
    public var isEmpty: Bool { true }
    public var codable: NavigationPath.CodableRepresentation? { nil }
    public mutating func append<V: Hashable>(_ value: V) {}
    public mutating func append<V: Hashable & Codable>(_ value: V) {}
    public mutating func removeLast(_ k: Int = 1) {}
    public struct CodableRepresentation: Codable, Equatable {}
}
public struct NavigationStack<Data, Root: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder root: () -> Root) where Data == NavigationPath {}
    public init(path: Binding<NavigationPath>, @ViewBuilder root: () -> Root) where Data == NavigationPath {}
    public init(path: Binding<Data>, @ViewBuilder root: () -> Root) where Data: MutableCollection & RandomAccessCollection & RangeReplaceableCollection, Data.Element: Hashable {}
}
public struct NavigationSplitView<Sidebar: View, Content: View, Detail: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder content: () -> Content, @ViewBuilder detail: () -> Detail) {}
    public init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) where Content == EmptyView {}
    public init(columnVisibility: Binding<NavigationSplitViewVisibility>, @ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) where Content == EmptyView {}
}
public struct NavigationSplitViewVisibility: Equatable, Sendable { public static let automatic = NavigationSplitViewVisibility(), all = NavigationSplitViewVisibility(), doubleColumn = NavigationSplitViewVisibility(), detailOnly = NavigationSplitViewVisibility() }
public struct NavigationView<Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: () -> Content) {}
}
public struct NavigationLink<Label: View, Destination: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {}
    public init(destination: Destination, @ViewBuilder label: () -> Label) {}
    public init(isActive: Binding<Bool>, @ViewBuilder destination: () -> Destination, @ViewBuilder label: () -> Label) {}
}
extension NavigationLink where Destination == Never {
    public init<P: Hashable>(value: P?, @ViewBuilder label: () -> Label) {}
    public init<P: Hashable & Codable>(value: P?, @ViewBuilder label: () -> Label) {}
}
extension NavigationLink where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder destination: () -> Destination) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder destination: () -> Destination) {}
    public init(_ titleKey: LocalizedStringKey, destination: Destination) {}
    public init<S: StringProtocol>(_ title: S, destination: Destination) {}
}
extension NavigationLink where Label == Text, Destination == Never {
    public init<P: Hashable>(_ titleKey: LocalizedStringKey, value: P?) {}
    public init<S: StringProtocol, P: Hashable>(_ title: S, value: P?) {}
    public init<P: Hashable & Codable>(_ titleKey: LocalizedStringKey, value: P?) {}
    public init<S: StringProtocol, P: Hashable & Codable>(_ title: S, value: P?) {}
}
extension NavigationLink where Label == SwiftUI.Label<Text, Image>, Destination == Never {
    public init<P: Hashable>(_ titleKey: LocalizedStringKey, systemImage: String, value: P?) {}
    public init<S: StringProtocol, P: Hashable>(_ title: S, systemImage: String, value: P?) {}
}
extension NavigationLink where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder destination: () -> Destination) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder destination: () -> Destination) {}
}
public enum NavigationBarItem { public enum TitleDisplayMode: Hashable, Sendable { case automatic, inline, large } }
public struct ToolbarTitleDisplayMode: Hashable, Sendable { public static let automatic = ToolbarTitleDisplayMode(), large = ToolbarTitleDisplayMode(), inlineLarge = ToolbarTitleDisplayMode(), inline = ToolbarTitleDisplayMode() }
public struct NavigationTransition: Sendable { }
public protocol NavigationTransitionProtocol {}
public struct ZoomNavigationTransition: NavigationTransitionProtocol {}
public struct AutomaticNavigationTransition: NavigationTransitionProtocol {}
extension NavigationTransitionProtocol where Self == ZoomNavigationTransition {
    public static func zoom(sourceID: some Hashable, in namespace: Namespace.ID) -> ZoomNavigationTransition { ZoomNavigationTransition() }
}
extension NavigationTransitionProtocol where Self == AutomaticNavigationTransition { public static var automatic: AutomaticNavigationTransition { AutomaticNavigationTransition() } }
public struct MatchedTransitionSourceConfiguration {
    public func background<S: ShapeStyle>(_ style: S) -> some MatchedTransitionSourceConfigurationProtocol { self }
    public func clipShape<S: Shape>(_ shape: S) -> some MatchedTransitionSourceConfigurationProtocol { self }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some MatchedTransitionSourceConfigurationProtocol { self }
}
public protocol MatchedTransitionSourceConfigurationProtocol {}
extension MatchedTransitionSourceConfiguration: MatchedTransitionSourceConfigurationProtocol {}
public struct EmptyMatchedTransitionSourceConfiguration: MatchedTransitionSourceConfigurationProtocol {
    public func background<S: ShapeStyle>(_ style: S) -> some MatchedTransitionSourceConfigurationProtocol { self }
    public func clipShape<S: Shape>(_ shape: S) -> some MatchedTransitionSourceConfigurationProtocol { self }
    public func shadow(color: Color = .black, radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some MatchedTransitionSourceConfigurationProtocol { self }
}

extension View {
    public func navigationTitle(_ titleKey: LocalizedStringKey) -> some View { self }
    public func navigationTitle<S: StringProtocol>(_ title: S) -> some View { self }
    public func navigationTitle(_ title: Text) -> some View { self }
    public func navigationTitle(_ title: Binding<String>) -> some View { self }
    public func navigationTitle<V: View>(@ViewBuilder _ title: () -> V) -> some View { self }
    public func navigationSubtitle(_ subtitleKey: LocalizedStringKey) -> some View { self }
    public func navigationSubtitle<S: StringProtocol>(_ subtitle: S) -> some View { self }
    public func navigationSubtitle(_ subtitle: Text) -> some View { self }
    public func navigationBarTitleDisplayMode(_ displayMode: NavigationBarItem.TitleDisplayMode) -> some View { self }
    public func navigationBarBackButtonHidden(_ hidesBackButton: Bool = true) -> some View { self }
    public func navigationBarHidden(_ hidden: Bool) -> some View { self }
    public func navigationBarTitle(_ title: Text) -> some View { self }
    public func navigationDestination<D: Hashable, C: View>(for data: D.Type, @ViewBuilder destination: @escaping (D) -> C) -> some View { self }
    public func navigationDestination<V: View>(isPresented: Binding<Bool>, @ViewBuilder destination: () -> V) -> some View { self }
    public func navigationDestination<D: Hashable, C: View>(item: Binding<D?>, @ViewBuilder destination: @escaping (D) -> C) -> some View { self }
    public func navigationSplitViewColumnWidth(_ width: CGFloat) -> some View { self }
    public func navigationSplitViewColumnWidth(min: CGFloat? = nil, ideal: CGFloat, max: CGFloat? = nil) -> some View { self }
    public func navigationSplitViewStyle<S: NavigationSplitViewStyle>(_ style: S) -> some View { self }
    public func navigationTransition(_ style: some NavigationTransitionProtocol) -> some View { self }
    public func matchedTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some View { self }
    public func matchedTransitionSource(id: some Hashable, in namespace: Namespace.ID, configuration: @escaping (EmptyMatchedTransitionSourceConfiguration) -> some MatchedTransitionSourceConfigurationProtocol) -> some View { self }
    public func toolbarTitleDisplayMode(_ mode: ToolbarTitleDisplayMode) -> some View { self }
    public func toolbarRole(_ role: ToolbarRole) -> some View { self }
    public func toolbarTitleMenu<C: View>(@ViewBuilder content: () -> C) -> some View { self }
}
public protocol NavigationSplitViewStyle {}
public struct AutomaticNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
public struct BalancedNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
public struct ProminentDetailNavigationSplitViewStyle: NavigationSplitViewStyle { public init() {} }
extension NavigationSplitViewStyle where Self == AutomaticNavigationSplitViewStyle { public static var automatic: AutomaticNavigationSplitViewStyle { AutomaticNavigationSplitViewStyle() } }
extension NavigationSplitViewStyle where Self == BalancedNavigationSplitViewStyle { public static var balanced: BalancedNavigationSplitViewStyle { BalancedNavigationSplitViewStyle() } }
extension NavigationSplitViewStyle where Self == ProminentDetailNavigationSplitViewStyle { public static var prominentDetail: ProminentDetailNavigationSplitViewStyle { ProminentDetailNavigationSplitViewStyle() } }
public struct ToolbarRole: Hashable, Sendable { public static let automatic = ToolbarRole(), navigationStack = ToolbarRole(), browser = ToolbarRole(), editor = ToolbarRole() }

// MARK: Toolbar

public protocol ToolbarContent {
    associatedtype Body: ToolbarContent
    @ToolbarContentBuilder var body: Self.Body { get }
}
public protocol CustomizableToolbarContent: ToolbarContent where Self.Body: CustomizableToolbarContent {}
extension Never: ToolbarContent, CustomizableToolbarContent {}
public struct _TupleToolbarContent: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct _ConditionalToolbarContent<T: ToolbarContent, F: ToolbarContent>: ToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension _ConditionalToolbarContent: CustomizableToolbarContent where T: CustomizableToolbarContent, F: CustomizableToolbarContent {}
extension Optional: ToolbarContent where Wrapped: ToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Optional: CustomizableToolbarContent where Wrapped: CustomizableToolbarContent {}
@resultBuilder
public struct ToolbarContentBuilder {
    public static func buildBlock() -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C: ToolbarContent>(_ c: C) -> C { c }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent>(_ c0: C0, _ c1: C1) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildBlock<C0: ToolbarContent, C1: ToolbarContent, C2: ToolbarContent, C3: ToolbarContent, C4: ToolbarContent, C5: ToolbarContent, C6: ToolbarContent, C7: ToolbarContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> _TupleToolbarContent { _TupleToolbarContent() }
    public static func buildExpression<C: ToolbarContent>(_ content: C) -> C { content }
    public static func buildIf<C: ToolbarContent>(_ content: C?) -> C? { content }
    public static func buildEither<T: ToolbarContent, F: ToolbarContent>(first: T) -> _ConditionalToolbarContent<T, F> { _ConditionalToolbarContent() }
    public static func buildEither<T: ToolbarContent, F: ToolbarContent>(second: F) -> _ConditionalToolbarContent<T, F> { _ConditionalToolbarContent() }
    public static func buildLimitedAvailability<C: ToolbarContent>(_ content: C) -> _TupleToolbarContent { _TupleToolbarContent() }
}
public struct ToolbarItemPlacement: Sendable {
    public static let automatic = ToolbarItemPlacement(), principal = ToolbarItemPlacement(), navigation = ToolbarItemPlacement(), primaryAction = ToolbarItemPlacement(),
        secondaryAction = ToolbarItemPlacement(), status = ToolbarItemPlacement(), confirmationAction = ToolbarItemPlacement(), cancellationAction = ToolbarItemPlacement(),
        destructiveAction = ToolbarItemPlacement(), keyboard = ToolbarItemPlacement(), topBarLeading = ToolbarItemPlacement(), topBarTrailing = ToolbarItemPlacement(),
        bottomBar = ToolbarItemPlacement(), navigationBarLeading = ToolbarItemPlacement(), navigationBarTrailing = ToolbarItemPlacement(), title = ToolbarItemPlacement(),
        largeTitle = ToolbarItemPlacement(), largeSubtitle = ToolbarItemPlacement(), subtitle = ToolbarItemPlacement()
    public static func accessoryBar<ID: Hashable>(id: ID) -> ToolbarItemPlacement { ToolbarItemPlacement() }
}
public struct ToolbarItem<ID, Content: View>: ToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) where ID == Void {}
    public init(id: String, placement: ToolbarItemPlacement = .automatic, showsByDefault: Bool = true, @ViewBuilder content: () -> Content) where ID == String {}
}
extension ToolbarItem: CustomizableToolbarContent where ID == String {}
public struct ToolbarItemGroup<Content: View>: ToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> Content) {}
    public init<C: View, L: View>(placement: ToolbarItemPlacement = .automatic, @ViewBuilder content: () -> C, @ViewBuilder label: () -> L) where Content == LabeledToolbarItemGroupContent<C, L> {}
}
public struct LabeledToolbarItemGroupContent<Content: View, Label: View>: View { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct ToolbarSpacer: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ sizing: SpacerSizing = .flexible, placement: ToolbarItemPlacement = .automatic) {}
}
public struct SpacerSizing: Hashable, Sendable { public static let flexible = SpacerSizing(), fixed = SpacerSizing() }
public struct DefaultToolbarItem: ToolbarContent, CustomizableToolbarContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(kind: ToolbarDefaultItemKind, placement: ToolbarItemPlacement = .automatic) {}
}
public struct ToolbarDefaultItemKind: Hashable, Sendable { public static let search = ToolbarDefaultItemKind(), title = ToolbarDefaultItemKind(), sidebarToggle = ToolbarDefaultItemKind(), back = ToolbarDefaultItemKind() }
public struct ToolbarPlacement: Sendable {
    public static let automatic = ToolbarPlacement(), bottomBar = ToolbarPlacement(), navigationBar = ToolbarPlacement(), tabBar = ToolbarPlacement(), bottomOrnament = ToolbarPlacement()
    public static func accessoryBar<ID: Hashable>(id: ID) -> ToolbarPlacement { ToolbarPlacement() }
}
extension ToolbarContent {
    public func sharedBackgroundVisibility(_ visibility: Visibility) -> some ToolbarContent { self }
    public func hidden(_ hidden: Bool = true) -> some ToolbarContent { self }
    public func matchedTransitionSource(id: some Hashable, in namespace: Namespace.ID) -> some ToolbarContent { self }
}
extension CustomizableToolbarContent {
    public func defaultCustomization(_ defaultVisibility: Visibility = .automatic, options: ToolbarCustomizationOptions = []) -> some CustomizableToolbarContent { self }
    public func customizationBehavior(_ behavior: ToolbarCustomizationBehavior) -> some CustomizableToolbarContent { self }
}
public struct ToolbarCustomizationOptions: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let alwaysAvailable = ToolbarCustomizationOptions(rawValue: 1) }
public struct ToolbarCustomizationBehavior: Sendable { public static let `default` = ToolbarCustomizationBehavior(), reorderable = ToolbarCustomizationBehavior(), disabled = ToolbarCustomizationBehavior() }
extension Group: ToolbarContent where Content: ToolbarContent {
    public init(@ToolbarContentBuilder content: () -> Content) { self.init() }
}
extension Group: CustomizableToolbarContent where Content: CustomizableToolbarContent {}
extension View {
    public func toolbar<Content: View>(@ViewBuilder content: () -> Content) -> some View { self }
    public func toolbar<Content: ToolbarContent>(@ToolbarContentBuilder content: () -> Content) -> some View { self }
    public func toolbar<Content: CustomizableToolbarContent>(id: String, @ToolbarContentBuilder content: () -> Content) -> some View { self }
    public func toolbar(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbarVisibility(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbar(removing defaultItemKind: ToolbarDefaultItemKind?) -> some View { self }
    public func toolbarBackground<S: ShapeStyle>(_ style: S, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbarBackground(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbarBackgroundVisibility(_ visibility: Visibility, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbarColorScheme(_ colorScheme: ColorScheme?, for bars: ToolbarPlacement...) -> some View { self }
    public func toolbarItemHidden(_ hidden: Bool = true) -> some View { self }
}

// MARK: TabView

public struct TabView<SelectionValue: Hashable, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {}
    public init<C: TabContent>(selection: Binding<SelectionValue>, @TabContentBuilder<SelectionValue> content: () -> C) where Content == TabContentBuilder<SelectionValue>.Content<C> {}
}
extension TabView where SelectionValue == Int {
    public init(@ViewBuilder content: () -> Content) {}
}
extension TabView where SelectionValue == Never {
    public init<C: TabContent>(@TabContentBuilder<Never> content: () -> C) where Content == TabContentBuilder<Never>.Content<C> {}
}
public protocol TabContent<TabValue> {
    associatedtype TabValue: Hashable
    associatedtype Body: TabContent
    @TabContentBuilder<TabValue> var body: Self.Body { get }
}
public struct _TupleTabContent<TabValue: Hashable>: TabContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct _ConditionalTabContent<T: TabContent, F: TabContent>: TabContent where T.TabValue == F.TabValue {
    public typealias TabValue = T.TabValue
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Optional: TabContent where Wrapped: TabContent {
    public typealias TabValue = Wrapped.TabValue
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Never: TabContent {
    public typealias TabValue = Never
}
@resultBuilder
public struct TabContentBuilder<TabValue: Hashable> {
    public struct Content<C: TabContent>: View where C.TabValue == TabValue { public typealias Body = Never; public var body: Never { return fatalError() } }
    public static func buildBlock<C: TabContent>(_ c: C) -> C where C.TabValue == TabValue { c }
    public static func buildBlock<C0: TabContent, C1: TabContent>(_ c0: C0, _ c1: C1) -> _TupleTabContent<TabValue> where C0.TabValue == TabValue, C1.TabValue == TabValue { _TupleTabContent() }
    public static func buildBlock<C0: TabContent, C1: TabContent, C2: TabContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleTabContent<TabValue> where C0.TabValue == TabValue, C1.TabValue == TabValue, C2.TabValue == TabValue { _TupleTabContent() }
    public static func buildBlock<C0: TabContent, C1: TabContent, C2: TabContent, C3: TabContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleTabContent<TabValue> where C0.TabValue == TabValue, C1.TabValue == TabValue, C2.TabValue == TabValue, C3.TabValue == TabValue { _TupleTabContent() }
    public static func buildBlock<C0: TabContent, C1: TabContent, C2: TabContent, C3: TabContent, C4: TabContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> _TupleTabContent<TabValue> where C0.TabValue == TabValue, C1.TabValue == TabValue, C2.TabValue == TabValue, C3.TabValue == TabValue, C4.TabValue == TabValue { _TupleTabContent() }
    public static func buildBlock<C0: TabContent, C1: TabContent, C2: TabContent, C3: TabContent, C4: TabContent, C5: TabContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> _TupleTabContent<TabValue> where C0.TabValue == TabValue, C1.TabValue == TabValue, C2.TabValue == TabValue, C3.TabValue == TabValue, C4.TabValue == TabValue, C5.TabValue == TabValue { _TupleTabContent() }
    public static func buildExpression<C: TabContent>(_ content: C) -> C where C.TabValue == TabValue { content }
    public static func buildIf<C: TabContent>(_ content: C?) -> C? where C.TabValue == TabValue { content }
    public static func buildEither<T: TabContent, F: TabContent>(first: T) -> _ConditionalTabContent<T, F> where T.TabValue == TabValue, F.TabValue == TabValue { _ConditionalTabContent() }
    public static func buildEither<T: TabContent, F: TabContent>(second: F) -> _ConditionalTabContent<T, F> where T.TabValue == TabValue, F.TabValue == TabValue { _ConditionalTabContent() }
}
public struct Tab<Value: Hashable, Content: View, Label: View>: TabContent {
    public typealias TabValue = Value
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(value: Value, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public init(value: Value, role: TabRole?, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where Value == Never {}
    public init(role: TabRole?, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) where Value == Never {}
}
extension Tab where Label == DefaultTabLabel {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {}
    public init(_ title: Text, systemImage: String, value: Value, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, image: String, value: Value, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, image: String, value: Value, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, systemImage: String, value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, image: String, value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {}
    public init(value: Value, role: TabRole?, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) where Value == Never {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) where Value == Never {}
    public init(_ titleKey: LocalizedStringKey, image: String, @ViewBuilder content: () -> Content) where Value == Never {}
    public init(_ titleKey: LocalizedStringKey, systemImage: String, role: TabRole?, @ViewBuilder content: () -> Content) where Value == Never {}
    public init(role: TabRole?, @ViewBuilder content: () -> Content) where Value == Never {}
}
public struct DefaultTabLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct TabRole: Hashable, Sendable { public static let search = TabRole() }
public struct TabSection<Header: View, Content: TabContent, Footer: View, SelectionValue: Hashable>: TabContent where Content.TabValue == SelectionValue {
    public typealias TabValue = SelectionValue
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@TabContentBuilder<SelectionValue> content: () -> Content, @ViewBuilder header: () -> Header) where Footer == EmptyView {}
    public init(@TabContentBuilder<SelectionValue> content: () -> Content) where Header == EmptyView, Footer == EmptyView {}
    public init(_ titleKey: LocalizedStringKey, @TabContentBuilder<SelectionValue> content: () -> Content) where Header == Text, Footer == EmptyView {}
    public init<S: StringProtocol>(_ title: S, @TabContentBuilder<SelectionValue> content: () -> Content) where Header == Text, Footer == EmptyView {}
}
extension ForEach: TabContent where Content: TabContent {
    public typealias TabValue = Content.TabValue
    public init(_ data: Data, @TabContentBuilder<Content.TabValue> content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable { self.init(data: data, content: content) }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @TabContentBuilder<Content.TabValue> content: @escaping (Data.Element) -> Content) { self.init(data: data, content: content) }
}
extension ForEach: ToolbarContent where Content: ToolbarContent {
    public init(_ data: Data, @ToolbarContentBuilder content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable { self.init(data: data, content: content) }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ToolbarContentBuilder content: @escaping (Data.Element) -> Content) { self.init(data: data, content: content) }
}
public struct TabPlacement: Hashable, Sendable { public static let automatic = TabPlacement(), pinned = TabPlacement(), sidebarOnly = TabPlacement() }
public struct TabCustomizationBehavior: Hashable, Sendable { public static let automatic = TabCustomizationBehavior(), reorderable = TabCustomizationBehavior(), disabled = TabCustomizationBehavior() }
public struct TabViewCustomization: Equatable, Sendable {
    public init() {}
    public mutating func resetTabOrder() {}
    public mutating func resetVisibility() {}
    public mutating func resetSectionOrder() {}
}
public struct AdaptableTabBarPlacement: Hashable, Sendable { public static let automatic = AdaptableTabBarPlacement(), tabBar = AdaptableTabBarPlacement(), sidebar = AdaptableTabBarPlacement() }
extension TabContent {
    public func badge(_ count: Int) -> some TabContent<TabValue> { self }
    public func badge(_ label: Text?) -> some TabContent<TabValue> { self }
    public func badge(_ key: LocalizedStringKey?) -> some TabContent<TabValue> { self }
    public func badge<S: StringProtocol>(_ label: S?) -> some TabContent<TabValue> { self }
    public func tabPlacement(_ placement: TabPlacement) -> some TabContent<TabValue> { self }
    public func hidden(_ hidden: Bool = true) -> some TabContent<TabValue> { self }
    public func defaultVisibility(_ visibility: Visibility, for placement: AdaptableTabBarPlacement) -> some TabContent<TabValue> { self }
    public func customizationID(_ id: String) -> some TabContent<TabValue> { self }
    public func customizationBehavior(_ behavior: TabCustomizationBehavior, for placements: AdaptableTabBarPlacement...) -> some TabContent<TabValue> { self }
    public func accessibilityLabel(_ label: Text) -> some TabContent<TabValue> { self }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> some TabContent<TabValue> { self }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> some TabContent<TabValue> { self }
    public func accessibilityHint(_ hint: Text) -> some TabContent<TabValue> { self }
    public func accessibilityIdentifier(_ identifier: String) -> some TabContent<TabValue> { self }
    public func contextMenu<M: View>(@ViewBuilder menuItems: () -> M) -> some TabContent<TabValue> { self }
    public func dropDestination<T: Transferable>(for payloadType: T.Type = T.self, action: @escaping ([T]) -> Void) -> some TabContent<TabValue> { self }
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some TabContent<TabValue> { self }
    public func swipeActions<T: View>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some TabContent<TabValue> { self }
    public func sectionActions<T: View>(@ViewBuilder content: () -> T) -> some TabContent<TabValue> { self }
    public func disabled(_ disabled: Bool) -> some TabContent<TabValue> { self }
    public func popover<T: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge? = nil, @ViewBuilder content: @escaping () -> T) -> some TabContent<TabValue> { self }
    public func springLoadingBehavior(_ behavior: SpringLoadingBehavior) -> some TabContent<TabValue> { self }
}
public protocol TabViewStyle {}
public struct DefaultTabViewStyle: TabViewStyle { public init() {} }
public struct PageTabViewStyle: TabViewStyle {
    public struct IndexDisplayMode: Hashable, Sendable { public static let automatic = IndexDisplayMode(), always = IndexDisplayMode(), never = IndexDisplayMode() }
    public init(indexDisplayMode: IndexDisplayMode = .automatic) {}
}
public struct SidebarAdaptableTabViewStyle: TabViewStyle { public init() {} }
public struct TabBarOnlyTabViewStyle: TabViewStyle { public init() {} }
public struct GroupedTabViewStyle: TabViewStyle { public init() {} }
extension TabViewStyle where Self == DefaultTabViewStyle { public static var automatic: DefaultTabViewStyle { DefaultTabViewStyle() } }
extension TabViewStyle where Self == PageTabViewStyle {
    public static var page: PageTabViewStyle { PageTabViewStyle() }
    public static func page(indexDisplayMode: PageTabViewStyle.IndexDisplayMode) -> PageTabViewStyle { PageTabViewStyle(indexDisplayMode: indexDisplayMode) }
}
extension TabViewStyle where Self == SidebarAdaptableTabViewStyle { public static var sidebarAdaptable: SidebarAdaptableTabViewStyle { SidebarAdaptableTabViewStyle() } }
extension TabViewStyle where Self == TabBarOnlyTabViewStyle { public static var tabBarOnly: TabBarOnlyTabViewStyle { TabBarOnlyTabViewStyle() } }
extension TabViewStyle where Self == GroupedTabViewStyle { public static var grouped: GroupedTabViewStyle { GroupedTabViewStyle() } }
public protocol IndexViewStyle {}
public struct PageIndexViewStyle: IndexViewStyle {
    public struct BackgroundDisplayMode: Hashable, Sendable { public static let automatic = BackgroundDisplayMode(), interactive = BackgroundDisplayMode(), always = BackgroundDisplayMode(), never = BackgroundDisplayMode() }
    public init(backgroundDisplayMode: BackgroundDisplayMode = .automatic) {}
}
extension IndexViewStyle where Self == PageIndexViewStyle {
    public static var page: PageIndexViewStyle { PageIndexViewStyle() }
    public static func page(backgroundDisplayMode: PageIndexViewStyle.BackgroundDisplayMode) -> PageIndexViewStyle { PageIndexViewStyle(backgroundDisplayMode: backgroundDisplayMode) }
}
public struct TabBarMinimizeBehavior: Hashable, Sendable { public static let automatic = TabBarMinimizeBehavior(), onScrollDown = TabBarMinimizeBehavior(), onScrollUp = TabBarMinimizeBehavior(), never = TabBarMinimizeBehavior() }
public struct TabViewBottomAccessoryPlacement: Hashable, Sendable { public static let inline = TabViewBottomAccessoryPlacement(), expanded = TabViewBottomAccessoryPlacement() }
extension EnvironmentValues {
    public var tabViewBottomAccessoryPlacement: TabViewBottomAccessoryPlacement? { nil }
}
extension View {
    public func tabViewStyle<S: TabViewStyle>(_ style: S) -> some View { self }
    public func indexViewStyle<S: IndexViewStyle>(_ style: S) -> some View { self }
    public func tabItem<V: View>(@ViewBuilder _ label: () -> V) -> some View { self }
    public func tabViewCustomization(_ customization: Binding<TabViewCustomization>?) -> some View { self }
    public func tabViewSidebarHeader<C: View>(@ViewBuilder content: () -> C) -> some View { self }
    public func tabViewSidebarFooter<C: View>(@ViewBuilder content: () -> C) -> some View { self }
    public func tabViewSidebarBottomBar<C: View>(@ViewBuilder content: () -> C) -> some View { self }
    public func tabBarMinimizeBehavior(_ behavior: TabBarMinimizeBehavior) -> some View { self }
    public func tabViewBottomAccessory<C: View>(@ViewBuilder content: () -> C) -> some View { self }
    public func tabViewBottomAccessory<C: View>(isEnabled: Bool, @ViewBuilder content: () -> C) -> some View { self }
    public func badge(_ count: Int) -> some View { self }
    public func badge(_ label: Text?) -> some View { self }
    public func badge(_ key: LocalizedStringKey?) -> some View { self }
    public func badge<S: StringProtocol>(_ label: S?) -> some View { self }
    public func badgeProminence(_ prominence: BadgeProminence) -> some View { self }
}
public struct BadgeProminence: Hashable, Sendable { public static let decreased = BadgeProminence(), standard = BadgeProminence(), increased = BadgeProminence() }

// MARK: List, Form, Section

public struct List<SelectionValue: Hashable, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(selection: Binding<Set<SelectionValue>>?, @ViewBuilder content: () -> Content) {}
    public init(selection: Binding<SelectionValue?>?, @ViewBuilder content: () -> Content) {}
    public init(selection: Binding<SelectionValue>?, @ViewBuilder content: () -> Content) {}
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<Set<SelectionValue>>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, ID, RowContent> {}
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, selection: Binding<SelectionValue?>?, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, ID, RowContent> {}
}
extension List where SelectionValue == Never {
    public init(@ViewBuilder content: () -> Content) {}
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, Data.Element.ID, RowContent>, Data.Element: Identifiable {}
    public init<Data: RandomAccessCollection, ID: Hashable, RowContent: View>(_ data: Data, id: KeyPath<Data.Element, ID>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == ForEach<Data, ID, RowContent> {}
    public init<RowContent: View>(_ data: Range<Int>, @ViewBuilder rowContent: @escaping (Int) -> RowContent) where Content == ForEach<Range<Int>, Int, RowContent> {}
    public init<Data: RandomAccessCollection, RowContent: View>(_ data: Data, children: KeyPath<Data.Element, Data?>, @ViewBuilder rowContent: @escaping (Data.Element) -> RowContent) where Content == OutlineGroup<Data, Data.Element.ID, RowContent, RowContent, DisclosureGroup<RowContent, OutlineSubgroupChildren>>, Data.Element: Identifiable {}
}
public struct OutlineGroup<Data: RandomAccessCollection, ID: Hashable, Parent: View, Leaf: View, Subgroup: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct OutlineSubgroupChildren: View { public typealias Body = Never; public var body: Never { return fatalError() } }

public struct Form<Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: () -> Content) {}
}
public protocol FormStyle {}
public struct AutomaticFormStyle: FormStyle { public init() {} }
public struct GroupedFormStyle: FormStyle { public init() {} }
public struct ColumnsFormStyle: FormStyle { public init() {} }
extension FormStyle where Self == AutomaticFormStyle { public static var automatic: AutomaticFormStyle { AutomaticFormStyle() } }
extension FormStyle where Self == GroupedFormStyle { public static var grouped: GroupedFormStyle { GroupedFormStyle() } }
extension FormStyle where Self == ColumnsFormStyle { public static var columns: ColumnsFormStyle { ColumnsFormStyle() } }

public struct Section<Parent, Content, Footer> {
    init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Section: View where Parent: View, Content: View, Footer: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent, @ViewBuilder footer: () -> Footer) { self.init() }
    public init(isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) where Footer == EmptyView { self.init() }
}
extension Section where Parent: View, Content: View, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder header: () -> Parent) { self.init() }
}
extension Section where Parent == EmptyView, Content: View, Footer: View {
    public init(@ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) { self.init() }
}
extension Section where Parent == EmptyView, Content: View, Footer == EmptyView {
    public init(@ViewBuilder content: () -> Content) { self.init() }
}
extension Section where Parent == Text, Content: View, Footer == EmptyView {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) { self.init() }
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) { self.init() }
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) { self.init() }
    public init<S: StringProtocol>(_ title: S, isExpanded: Binding<Bool>, @ViewBuilder content: () -> Content) { self.init() }
}
extension Section where Parent == Text, Content: View, Footer: View {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) { self.init() }
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content, @ViewBuilder footer: () -> Footer) { self.init() }
}
extension Section: TabContent where Parent: View, Content: TabContent, Footer: View {
    public typealias TabValue = Content.TabValue
    public init(@TabContentBuilder<Content.TabValue> content: () -> Content, @ViewBuilder header: () -> Parent) where Footer == EmptyView { self.init() }
    public init(_ titleKey: LocalizedStringKey, @TabContentBuilder<Content.TabValue> content: () -> Content) where Parent == Text, Footer == EmptyView { self.init() }
    public init<S: StringProtocol>(_ title: S, @TabContentBuilder<Content.TabValue> content: () -> Content) where Parent == Text, Footer == EmptyView { self.init() }
}

public protocol ListStyle {}
public struct DefaultListStyle: ListStyle { public init() {} }
public struct PlainListStyle: ListStyle { public init() {} }
public struct GroupedListStyle: ListStyle { public init() {} }
public struct InsetGroupedListStyle: ListStyle { public init() {} }
public struct InsetListStyle: ListStyle { public init() {} }
public struct SidebarListStyle: ListStyle { public init() {} }
extension ListStyle where Self == DefaultListStyle { public static var automatic: DefaultListStyle { DefaultListStyle() } }
extension ListStyle where Self == PlainListStyle { public static var plain: PlainListStyle { PlainListStyle() } }
extension ListStyle where Self == GroupedListStyle { public static var grouped: GroupedListStyle { GroupedListStyle() } }
extension ListStyle where Self == InsetGroupedListStyle { public static var insetGrouped: InsetGroupedListStyle { InsetGroupedListStyle() } }
extension ListStyle where Self == InsetListStyle { public static var inset: InsetListStyle { InsetListStyle() } }
extension ListStyle where Self == SidebarListStyle { public static var sidebar: SidebarListStyle { SidebarListStyle() } }
public struct ListItemTint: Sendable {
    public static let monochrome = ListItemTint()
    public static func fixed(_ tint: Color) -> ListItemTint { ListItemTint() }
    public static func preferred(_ tint: Color) -> ListItemTint { ListItemTint() }
}
public struct ListSectionSpacing: Sendable {
    public static let `default` = ListSectionSpacing(), compact = ListSectionSpacing()
    public static func custom(_ spacing: CGFloat) -> ListSectionSpacing { ListSectionSpacing() }
}
public struct ListSectionMargins: Sendable { }
public struct ListSectionIndexVisibility: Hashable, Sendable { public static let automatic = ListSectionIndexVisibility(), visible = ListSectionIndexVisibility(), hidden = ListSectionIndexVisibility() }
extension View {
    public func listStyle<S: ListStyle>(_ style: S) -> some View { self }
    public func formStyle<S: FormStyle>(_ style: S) -> some View { self }
    public func listRowBackground<V: View>(_ view: V?) -> some View { self }
    public func listRowInsets(_ insets: EdgeInsets?) -> some View { self }
    public func listRowSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
    public func listRowSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View { self }
    public func listSectionSeparator(_ visibility: Visibility, edges: VerticalEdge.Set = .all) -> some View { self }
    public func listSectionSeparatorTint(_ color: Color?, edges: VerticalEdge.Set = .all) -> some View { self }
    public func listSectionSpacing(_ spacing: ListSectionSpacing) -> some View { self }
    public func listSectionSpacing(_ spacing: CGFloat) -> some View { self }
    public func listSectionMargins(_ edges: Edge.Set = .all, _ length: CGFloat? = nil) -> some View { self }
    public func listSectionIndexVisibility(_ visibility: ListSectionIndexVisibility) -> some View { self }
    public func listRowSpacing(_ spacing: CGFloat?) -> some View { self }
    public func listItemTint(_ tint: Color?) -> some View { self }
    public func listItemTint(_ tint: ListItemTint?) -> some View { self }
    public func listRowHoverEffect(_ effect: HoverEffect?) -> some View { self }
    public func listRowHoverEffectDisabled(_ disabled: Bool = true) -> some View { self }
    public func swipeActions<T: View>(edge: HorizontalEdge = .trailing, allowsFullSwipe: Bool = true, @ViewBuilder content: () -> T) -> some View { self }
    public func refreshable(@_inheritActorContext action: @escaping @Sendable () async -> Void) -> some View { self }
    public func deleteDisabled(_ isDisabled: Bool) -> some View { self }
    public func moveDisabled(_ isDisabled: Bool) -> some View { self }
    public func selectionDisabled(_ isDisabled: Bool = true) -> some View { self }
    public func editMode(_ mode: Binding<EditMode>?) -> some View { self }
}
public struct EditButton: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}

// MARK: Search

public struct SearchFieldPlacement: Sendable {
    public static let automatic = SearchFieldPlacement(), toolbar = SearchFieldPlacement(), sidebar = SearchFieldPlacement(), navigationBarDrawer = SearchFieldPlacement()
    public static func navigationBarDrawer(displayMode: NavigationBarDrawerDisplayMode) -> SearchFieldPlacement { SearchFieldPlacement() }
    public struct NavigationBarDrawerDisplayMode: Sendable { public static let automatic = NavigationBarDrawerDisplayMode(), always = NavigationBarDrawerDisplayMode() }
}
public struct SearchSuggestionsPlacement: Equatable, Sendable {
    public static let automatic = SearchSuggestionsPlacement(), menu = SearchSuggestionsPlacement(), content = SearchSuggestionsPlacement()
    public struct Set: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let menu = Set(rawValue: 1), content = Set(rawValue: 2), all = Set(rawValue: 3) }
}
public struct SearchScopeActivation: Sendable { public static let automatic = SearchScopeActivation(), onTextEntry = SearchScopeActivation(), onSearchPresentation = SearchScopeActivation() }
public struct SearchPresentationToolbarBehavior: Sendable { public static let automatic = SearchPresentationToolbarBehavior(), avoidHidingContent = SearchPresentationToolbarBehavior() }
public struct SearchToolbarBehavior: Hashable, Sendable { public static let automatic = SearchToolbarBehavior(), minimize = SearchToolbarBehavior() }
public struct SearchUnavailableContent { }
extension View {
    public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View { self }
    public func searchable(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View { self }
    public func searchable<S: StringProtocol>(text: Binding<String>, placement: SearchFieldPlacement = .automatic, prompt: S) -> some View { self }
    public func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil) -> some View { self }
    public func searchable(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: LocalizedStringKey) -> some View { self }
    public func searchable<S: StringProtocol>(text: Binding<String>, isPresented: Binding<Bool>, placement: SearchFieldPlacement = .automatic, prompt: S) -> some View { self }
    public func searchable<C: Hashable & Identifiable, S: View>(text: Binding<String>, tokens: Binding<[C]>, placement: SearchFieldPlacement = .automatic, prompt: Text? = nil, @ViewBuilder token: @escaping (C) -> S) -> some View { self }
    public func searchSuggestions<S: View>(@ViewBuilder _ suggestions: () -> S) -> some View { self }
    public func searchSuggestions(_ visibility: Visibility, for placements: SearchSuggestionsPlacement.Set) -> some View { self }
    public func searchCompletion(_ completion: String) -> some View { self }
    public func searchCompletion<T: Identifiable>(_ token: T) -> some View { self }
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, @ViewBuilder scopes: () -> S) -> some View { self }
    public func searchScopes<V: Hashable, S: View>(_ scope: Binding<V>, activation: SearchScopeActivation, @ViewBuilder _ scopes: () -> S) -> some View { self }
    public func searchPresentationToolbarBehavior(_ behavior: SearchPresentationToolbarBehavior) -> some View { self }
    public func searchToolbarBehavior(_ behavior: SearchToolbarBehavior) -> some View { self }
    public func searchFocused(_ isSearchFocused: FocusState<Bool>.Binding) -> some View { self }
    public func searchDictationBehavior(_ dictationBehavior: TextInputDictationBehavior) -> some View { self }
}
public struct TextInputDictationBehavior: Sendable { public static let automatic = TextInputDictationBehavior(), inline = TextInputDictationBehavior(), preventDictation = TextInputDictationBehavior() }
