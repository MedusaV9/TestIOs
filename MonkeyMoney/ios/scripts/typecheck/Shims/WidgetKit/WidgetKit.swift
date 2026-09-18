// WidgetKit stub — widgets, timelines, configurations, controls, and the
// Live Activity configuration/DynamicIsland surface (which lives in WidgetKit).
@_exported import Foundation
@_exported import SwiftUI
@_exported import AppIntents
import ActivityKit

// MARK: Widget & bundle

@MainActor @preconcurrency
public protocol Widget {
    associatedtype Body: WidgetConfiguration
    @MainActor @preconcurrency init()
    @MainActor @preconcurrency var body: Self.Body { get }
}
extension Widget {
    @MainActor public static func main() {}
}
@MainActor @preconcurrency
public protocol WidgetBundle {
    associatedtype Body: Widget
    @MainActor @preconcurrency init()
    @WidgetBundleBuilder @MainActor @preconcurrency var body: Self.Body { get }
}
extension WidgetBundle {
    @MainActor public static func main() {}
}
extension Never: Widget, WidgetConfiguration, ControlWidgetConfiguration, ControlWidget, ControlWidgetTemplate {
    public init() { fatalError() }
}
public struct _TupleWidget: Widget {
    public init() {}
    public var body: Never { return fatalError() }
}
public struct _ConditionalWidget<T: Widget, F: Widget>: Widget {
    public init() {}
    public var body: Never { return fatalError() }
}
extension Optional: Widget where Wrapped: Widget {
    public init() { self = nil }
    public var body: Never { return fatalError() }
}
@resultBuilder
public struct WidgetBundleBuilder {
    public static func buildBlock() -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C: Widget>(_ c: C) -> C { c }
    public static func buildBlock<C0: Widget, C1: Widget>(_ c0: C0, _ c1: C1) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget, C15: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14, _ c15: C15) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget, C15: Widget, C16: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14, _ c15: C15, _ c16: C16) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget, C15: Widget, C16: Widget, C17: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14, _ c15: C15, _ c16: C16, _ c17: C17) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget, C15: Widget, C16: Widget, C17: Widget, C18: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14, _ c15: C15, _ c16: C16, _ c17: C17, _ c18: C18) -> _TupleWidget { _TupleWidget() }
    public static func buildBlock<C0: Widget, C1: Widget, C2: Widget, C3: Widget, C4: Widget, C5: Widget, C6: Widget, C7: Widget, C8: Widget, C9: Widget, C10: Widget, C11: Widget, C12: Widget, C13: Widget, C14: Widget, C15: Widget, C16: Widget, C17: Widget, C18: Widget, C19: Widget>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4, _ c5: C5, _ c6: C6, _ c7: C7, _ c8: C8, _ c9: C9, _ c10: C10, _ c11: C11, _ c12: C12, _ c13: C13, _ c14: C14, _ c15: C15, _ c16: C16, _ c17: C17, _ c18: C18, _ c19: C19) -> _TupleWidget { _TupleWidget() }
    public static func buildOptional<C: Widget>(_ c: C?) -> C? { c }
    public static func buildEither<T: Widget, F: Widget>(first: T) -> _ConditionalWidget<T, F> { _ConditionalWidget() }
    public static func buildEither<T: Widget, F: Widget>(second: F) -> _ConditionalWidget<T, F> { _ConditionalWidget() }
    public static func buildLimitedAvailability<C: Widget>(_ c: C) -> _TupleWidget { _TupleWidget() }
}
extension WidgetBundleBuilder {
    public static func buildExpression<C: Widget>(_ widget: C) -> C { widget }
    public static func buildExpression<C: ControlWidget>(_ control: C) -> _ControlWidgetAsWidget<C> { _ControlWidgetAsWidget() }
}
public struct _ControlWidgetAsWidget<C: ControlWidget>: Widget {
    public init() {}
    public var body: Never { return fatalError() }
}

// MARK: Configurations

@MainActor @preconcurrency
public protocol WidgetConfiguration {
    associatedtype Body: WidgetConfiguration
    @MainActor @preconcurrency var body: Self.Body { get }
}
public struct _ModifiedWidgetConfiguration: WidgetConfiguration {
    public var body: Never { return fatalError() }
}
extension WidgetConfiguration {
    public func configurationDisplayName(_ displayNameKey: LocalizedStringKey) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func configurationDisplayName<S: StringProtocol>(_ displayName: S) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func configurationDisplayName(_ displayName: Text) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func description(_ descriptionKey: LocalizedStringKey) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func description<S: StringProtocol>(_ description: S) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func description(_ description: Text) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func supportedFamilies(_ families: [WidgetFamily]) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func contentMarginsDisabled() -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func containerBackgroundRemovable(_ isRemovable: Bool = true) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func supplementalActivityFamilies(_ families: [ActivityFamily]) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func disfavoredLocations(_ locations: [WidgetLocation], for families: [WidgetFamily]) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func promptsForUserConfiguration() -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func onBackgroundURLSessionEvents(matching matchingString: String? = nil, _ urlSessionEvent: @escaping (String, @escaping () -> Void) -> Void) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func backgroundTask<D, R>(_ task: BackgroundTask<D, R>, action: @escaping @Sendable (D) async -> R) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
    public func widgetAccentedRenderingMode(_ mode: WidgetAccentedRenderingMode?) -> some WidgetConfiguration { _ModifiedWidgetConfiguration() }
}
public enum WidgetLocation: Sendable { case homeScreen, lockScreen, standBy, iPhoneWidgetsOnMac }
public struct StaticConfiguration<Content: View>: WidgetConfiguration {
    public var body: Never { return fatalError() }
    public init<Provider: TimelineProvider>(kind: String, provider: Provider, @ViewBuilder content: @escaping (Provider.Entry) -> Content) {}
}
public struct AppIntentConfiguration<Intent: WidgetConfigurationIntent, Content: View>: WidgetConfiguration {
    public var body: Never { return fatalError() }
    public init<Provider: AppIntentTimelineProvider>(kind: String, intent: Intent.Type = Intent.self, provider: Provider, @ViewBuilder content: @escaping (Provider.Entry) -> Content) where Intent == Provider.Intent {}
}
public struct ActivityConfiguration<Attributes: ActivityAttributes>: WidgetConfiguration {
    public var body: Never { return fatalError() }
    public init<Content: View>(for attributesType: Attributes.Type = Attributes.self, @ViewBuilder content: @escaping (ActivityViewContext<Attributes>) -> Content, dynamicIsland: @escaping (ActivityViewContext<Attributes>) -> DynamicIsland) {}
    public init<Content: View, SupplementalContent: View>(for attributesType: Attributes.Type = Attributes.self, @ViewBuilder content: @escaping (ActivityViewContext<Attributes>) -> Content, dynamicIsland: @escaping (ActivityViewContext<Attributes>) -> DynamicIsland, @ViewBuilder supplementalActivityFamilies: @escaping (ActivityViewContext<Attributes>) -> SupplementalContent) {}
}
public struct ActivityViewContext<Attributes: ActivityAttributes> {
    public var attributes: Attributes { fatalError() }
    public var state: Attributes.ContentState { fatalError() }
    public var activityID: String { "" }
    public var isStale: Bool { false }
}

// MARK: Timeline

public protocol TimelineEntry {
    var date: Date { get }
    var relevance: TimelineEntryRelevance? { get }
}
extension TimelineEntry { public var relevance: TimelineEntryRelevance? { nil } }
public struct TimelineEntryRelevance: Codable, Hashable, Sendable {
    public var score: Float
    public var duration: TimeInterval
    public init(score: Float, duration: TimeInterval = 0) { self.score = score; self.duration = duration }
}
public enum TimelineReloadPolicy: Sendable {
    case atEnd
    case never
    case after(Date)
}
public struct Timeline<EntryType: TimelineEntry> {
    public let entries: [EntryType]
    public let policy: TimelineReloadPolicy
    public init(entries: [EntryType], policy: TimelineReloadPolicy) { self.entries = entries; self.policy = policy }
}
public struct TimelineProviderContext {
    public struct EnvironmentVariants { public subscript<K: EnvironmentKey>(key: K.Type) -> [K.Value]? { nil }; public subscript<T>(keyPath: WritableKeyPath<EnvironmentValues, T>) -> [T]? { nil } }
    public var environmentVariants: EnvironmentVariants { EnvironmentVariants() }
    public var family: WidgetFamily { .systemSmall }
    public var isPreview: Bool { false }
    public var displaySize: CGSize { .zero }
    public var isLuminanceReduced: Bool { false }
}
public protocol TimelineProvider {
    associatedtype Entry: TimelineEntry
    typealias Context = TimelineProviderContext
    func placeholder(in context: Self.Context) -> Self.Entry
    func getSnapshot(in context: Self.Context, completion: @escaping (Self.Entry) -> Void)
    func getTimeline(in context: Self.Context, completion: @escaping (Timeline<Self.Entry>) -> Void)
    func relevance() async -> WidgetRelevance<Void>
}
extension TimelineProvider { public func relevance() async -> WidgetRelevance<Void> { WidgetRelevance([]) } }
public protocol AppIntentTimelineProvider {
    associatedtype Entry: TimelineEntry
    associatedtype Intent: WidgetConfigurationIntent
    typealias Context = TimelineProviderContext
    func placeholder(in context: Self.Context) -> Self.Entry
    func snapshot(for configuration: Self.Intent, in context: Self.Context) async -> Self.Entry
    func timeline(for configuration: Self.Intent, in context: Self.Context) async -> Timeline<Self.Entry>
    func recommendations() -> [AppIntentRecommendation<Self.Intent>]
    func relevances() async -> WidgetRelevances<Self.Intent>
}
extension AppIntentTimelineProvider {
    public func recommendations() -> [AppIntentRecommendation<Self.Intent>] { [] }
    public func relevances() async -> WidgetRelevances<Self.Intent> { WidgetRelevances([]) }
}
public struct AppIntentRecommendation<Intent: WidgetConfigurationIntent> {
    public init(intent: Intent, description: Text) {}
    public init(intent: Intent, description: LocalizedStringKey) {}
    public init<S: StringProtocol>(intent: Intent, description: S) {}
}
public struct WidgetRelevance<Configuration> {
    public init(_ attributes: [WidgetRelevanceAttribute<Configuration>]) {}
}
public typealias WidgetRelevances<Intent> = WidgetRelevance<Intent>
public struct WidgetRelevanceAttribute<Configuration> {
    public init(configuration: Configuration, context: RelevantContext) {}
    public init(context: RelevantContext) where Configuration == Void {}
}
public struct RelevantContext: Sendable {
    public static func date(_ date: Date, kind: RelevantContext.DateKind = .scheduled) -> RelevantContext { RelevantContext() }
    public static func date(from: Date, to: Date) -> RelevantContext { RelevantContext() }
    public static func date(interval: DateInterval, kind: RelevantContext.DateKind = .scheduled) -> RelevantContext { RelevantContext() }
    public static func location(region: AnyObject) -> RelevantContext { RelevantContext() }
    public static func sleep(_ sleep: RelevantContext.Sleep) -> RelevantContext { RelevantContext() }
    public static func fitness(_ fitness: RelevantContext.Fitness) -> RelevantContext { RelevantContext() }
    public static func alarm(_ alarm: RelevantContext.Alarm) -> RelevantContext { RelevantContext() }
    public struct DateKind: Sendable { public static let scheduled = DateKind(), informational = DateKind() }
    public enum Sleep: Sendable { case bedtime, wakeup }
    public enum Fitness: Sendable { case workout }
    public enum Alarm: Sendable { case alarm }
}

// MARK: Families & center

public enum WidgetFamily: Int, CaseIterable, Hashable, Sendable, CustomDebugStringConvertible {
    case systemSmall, systemMedium, systemLarge, systemExtraLarge, accessoryCircular, accessoryRectangular, accessoryInline, accessoryCorner, systemExtraLargePortrait
    public var debugDescription: String { "\(self)" }
    public var description: String { "\(self)" }
}
public enum ActivityFamily: Hashable, Sendable, CaseIterable { case small, medium }
public enum WidgetRenderingMode: Hashable, Sendable { case fullColor, accented, vibrant }
public enum WidgetAccentedRenderingMode: Hashable, Sendable { case accented, accentedDesaturated, desaturated, fullColor, monochrome }
public struct WidgetContentMargins: Equatable, Sendable { public var leading: CGFloat = 0, trailing: CGFloat = 0, top: CGFloat = 0, bottom: CGFloat = 0 }
extension EnvironmentValues {
    public var widgetFamily: WidgetFamily { .systemSmall }
    public var widgetRenderingMode: WidgetRenderingMode { .fullColor }
    public var showsWidgetContainerBackground: Bool { true }
    public var widgetContentMargins: EdgeInsets { EdgeInsets() }
    public var isActivityFullscreen: Bool { false }
    public var activityFamily: ActivityFamily { .medium }
    public var showsWidgetLabel: Bool { false }
    public var widgetRelevance: WidgetRelevanceAttribute<Void>? { nil }
}
public struct WidgetInfo: Hashable, Sendable {
    public let kind: String
    public let family: WidgetFamily
    public func widgetConfigurationIntent<Intent: WidgetConfigurationIntent>(of intentType: Intent.Type = Intent.self) -> Intent? { nil }
}
public final class WidgetCenter: Sendable {
    public static let shared = WidgetCenter()
    public func reloadAllTimelines() {}
    public func reloadTimelines(ofKind kind: String) {}
    public func getCurrentConfigurations(_ completion: @escaping (Result<[WidgetInfo], Error>) -> Void) {}
    public func currentConfigurations() async throws -> [WidgetInfo] { [] }
    public func invalidateConfigurationRecommendations() {}
    public func invalidateRelevance(ofKind kind: String) {}
}
public struct AccessoryWidgetBackground: View {
    public init() {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension View {
    public func widgetAccentable(_ accentable: Bool = true) -> some View { self }
    public func widgetAccentedRenderingMode(_ mode: WidgetAccentedRenderingMode?) -> some View { self }
    public func widgetLabel<L: View>(@ViewBuilder label: () -> L) -> some View { self }
    public func widgetLabel(_ labelKey: LocalizedStringKey) -> some View { self }
    public func widgetLabel<S: StringProtocol>(_ label: S) -> some View { self }
    public func widgetCurvesContent(_ curvesContent: Bool = true) -> some View { self }
    public func invalidatableContent(_ invalidatable: Bool = true) -> some View { self }
    public func activityBackgroundTint(_ color: Color?) -> some View { self }
    public func activitySystemActionForegroundColor(_ color: Color?) -> some View { self }
    public func dynamicIsland(verticalPlacement: DynamicIslandExpandedRegionVerticalPlacement) -> some View { self }
    public func keylineTint(_ color: Color?) -> some View { self }
    public func supplementalActivityFamilies(_ families: [ActivityFamily]) -> some View { self }
    public func widgetRelevance(_ relevance: WidgetRelevanceAttribute<Void>?) -> some View { self }
}
public struct WidgetPreviewContext {
    public init(family: WidgetFamily) {}
}
extension View {
    public func previewContext(_ value: WidgetPreviewContext) -> some View { self }
}

// MARK: Dynamic Island

public enum DynamicIslandExpandedRegionPosition: Hashable, Sendable { case leading, trailing, center, bottom }
public enum DynamicIslandExpandedRegionVerticalPlacement: Hashable, Sendable { case belowIfTooWide }
public struct DynamicIslandExpandedRegion<Content: View>: DynamicIslandExpandedContent {
    public init(_ position: DynamicIslandExpandedRegionPosition, priority: Double = 0, @ViewBuilder content: () -> Content) {}
}
public protocol DynamicIslandExpandedContent {}
public struct _TupleDynamicIslandExpandedContent: DynamicIslandExpandedContent {}
public struct _ConditionalDynamicIslandExpandedContent<T: DynamicIslandExpandedContent, F: DynamicIslandExpandedContent>: DynamicIslandExpandedContent {}
extension Optional: DynamicIslandExpandedContent where Wrapped: DynamicIslandExpandedContent {}
@resultBuilder
public struct DynamicIslandExpandedContentBuilder {
    public static func buildBlock<C: DynamicIslandExpandedContent>(_ c: C) -> C { c }
    public static func buildBlock<C0: DynamicIslandExpandedContent, C1: DynamicIslandExpandedContent>(_ c0: C0, _ c1: C1) -> _TupleDynamicIslandExpandedContent { _TupleDynamicIslandExpandedContent() }
    public static func buildBlock<C0: DynamicIslandExpandedContent, C1: DynamicIslandExpandedContent, C2: DynamicIslandExpandedContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleDynamicIslandExpandedContent { _TupleDynamicIslandExpandedContent() }
    public static func buildBlock<C0: DynamicIslandExpandedContent, C1: DynamicIslandExpandedContent, C2: DynamicIslandExpandedContent, C3: DynamicIslandExpandedContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleDynamicIslandExpandedContent { _TupleDynamicIslandExpandedContent() }
    public static func buildIf<C: DynamicIslandExpandedContent>(_ c: C?) -> C? { c }
    public static func buildEither<T: DynamicIslandExpandedContent, F: DynamicIslandExpandedContent>(first: T) -> _ConditionalDynamicIslandExpandedContent<T, F> { _ConditionalDynamicIslandExpandedContent() }
    public static func buildEither<T: DynamicIslandExpandedContent, F: DynamicIslandExpandedContent>(second: F) -> _ConditionalDynamicIslandExpandedContent<T, F> { _ConditionalDynamicIslandExpandedContent() }
}
public struct DynamicIsland {
    public init<Expanded: DynamicIslandExpandedContent, CompactLeading: View, CompactTrailing: View, Minimal: View>(
        @DynamicIslandExpandedContentBuilder expanded: () -> Expanded,
        @ViewBuilder compactLeading: () -> CompactLeading,
        @ViewBuilder compactTrailing: () -> CompactTrailing,
        @ViewBuilder minimal: () -> Minimal) {}
    public func keylineTint(_ color: Color?) -> DynamicIsland { self }
    public func contentMargins(_ edges: Edge.Set = .all, _ length: CGFloat?, for placement: DynamicIslandContentMarginPlacement = .automatic) -> DynamicIsland { self }
    public func contentMargins(_ edges: Edge.Set = .all, _ insets: EdgeInsets, for placement: DynamicIslandContentMarginPlacement = .automatic) -> DynamicIsland { self }
}
public struct DynamicIslandContentMarginPlacement: Sendable { public static let automatic = DynamicIslandContentMarginPlacement(), expanded = DynamicIslandContentMarginPlacement(), compactLeading = DynamicIslandContentMarginPlacement(), compactTrailing = DynamicIslandContentMarginPlacement(), minimal = DynamicIslandContentMarginPlacement() }
public enum ActivityPreviewViewKind: Sendable { case content, dynamicIsland(DynamicIslandPreviewKind) }
public enum DynamicIslandPreviewKind: Sendable { case compact, minimal, expanded }
extension View {
    public func previewContext<A: ActivityAttributes>(_ attributes: A, viewKind: ActivityPreviewViewKind) -> some View { self }
}

// MARK: Controls (iOS 18)

@MainActor @preconcurrency
public protocol ControlWidget {
    associatedtype Body: ControlWidgetConfiguration
    @MainActor @preconcurrency init()
    @MainActor @preconcurrency var body: Self.Body { get }
}
@MainActor @preconcurrency
public protocol ControlWidgetConfiguration {
    associatedtype Body: ControlWidgetConfiguration
    @MainActor @preconcurrency var body: Self.Body { get }
}
public struct _ModifiedControlWidgetConfiguration: ControlWidgetConfiguration {
    public var body: Never { return fatalError() }
}
extension ControlWidgetConfiguration {
    public func displayName(_ displayNameKey: LocalizedStringKey) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func displayName<S: StringProtocol>(_ displayName: S) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func displayName(_ displayName: Text) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func description(_ descriptionKey: LocalizedStringKey) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func description<S: StringProtocol>(_ description: S) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func description(_ description: Text) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func promptsForUserConfiguration() -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
    public func pushHandler(_ pushHandler: (any ControlPushHandler.Type)) -> some ControlWidgetConfiguration { _ModifiedControlWidgetConfiguration() }
}
public protocol ControlPushHandler { init(); func pushTokensDidChange(controls: [ControlInfo]) }
public struct ControlInfo: Sendable { public let kind: String; public let pushInfo: ControlPushInfo? }
public struct ControlPushInfo: Sendable { public let token: Data }
@MainActor @preconcurrency
public protocol ControlWidgetTemplate {
    associatedtype Body: ControlWidgetTemplate
    @MainActor @preconcurrency var body: Self.Body { get }
}
public struct StaticControlConfiguration<Content: ControlWidgetTemplate>: ControlWidgetConfiguration {
    public var body: Never { return fatalError() }
    public init(kind: String, @ControlWidgetTemplateBuilder content: @escaping () -> Content) {}
    public init<Provider: ControlValueProvider>(kind: String, provider: Provider, @ControlWidgetTemplateBuilder content: @escaping (Provider.Value) -> Content) {}
}
public struct AppIntentControlConfiguration<Configuration: ControlConfigurationIntent, Content: ControlWidgetTemplate>: ControlWidgetConfiguration {
    public var body: Never { return fatalError() }
    public init(kind: String, intent: Configuration.Type = Configuration.self, @ControlWidgetTemplateBuilder content: @escaping (Configuration) -> Content) {}
    public init<Provider: AppIntentControlValueProvider>(kind: String, provider: Provider, @ControlWidgetTemplateBuilder content: @escaping (Provider.Value) -> Content) where Configuration == Provider.Configuration {}
}
public protocol ControlValueProvider {
    associatedtype Value: Sendable
    var previewValue: Self.Value { get }
    func currentValue() async throws -> Self.Value
}
public protocol AppIntentControlValueProvider {
    associatedtype Configuration: ControlConfigurationIntent
    associatedtype Value: Sendable
    func previewValue(configuration: Self.Configuration) -> Self.Value
    func currentValue(configuration: Self.Configuration) async throws -> Self.Value
}
@resultBuilder
public struct ControlWidgetTemplateBuilder {
    public static func buildBlock<C: ControlWidgetTemplate>(_ c: C) -> C { c }
}
public struct ControlWidgetButton<Label: View, ActionLabel: View>: ControlWidgetTemplate {
    public var body: Never { return fatalError() }
    public init<I: AppIntent>(action: I, @ViewBuilder label: () -> Label, @ViewBuilder actionLabel: @escaping (Bool) -> ActionLabel) {}
    public init<I: AppIntent>(action: I, @ViewBuilder label: () -> Label) where ActionLabel == EmptyView {}
    public init<I: AppIntent>(_ titleKey: LocalizedStringKey, action: I) where Label == Text, ActionLabel == EmptyView {}
    public init<S: StringProtocol, I: AppIntent>(_ title: S, action: I) where Label == Text, ActionLabel == EmptyView {}
    public init<I: AppIntent>(_ titleKey: LocalizedStringKey, action: I, @ViewBuilder actionLabel: @escaping (Bool) -> ActionLabel) where Label == Text {}
}
public struct ControlWidgetToggle<Label: View, ValueLabel: View>: ControlWidgetTemplate {
    public var body: Never { return fatalError() }
    public init<I: SetValueIntent>(isOn: Bool, action: I, @ViewBuilder label: () -> Label, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) where I.ValueType == Bool {}
    public init<I: SetValueIntent>(isOn: Bool, action: I, @ViewBuilder label: () -> Label) where ValueLabel == EmptyView, I.ValueType == Bool {}
    public init<I: SetValueIntent>(_ titleKey: LocalizedStringKey, isOn: Bool, action: I, @ViewBuilder valueLabel: @escaping (Bool) -> ValueLabel) where Label == Text, I.ValueType == Bool {}
    public init<I: SetValueIntent>(_ titleKey: LocalizedStringKey, isOn: Bool, action: I) where Label == Text, ValueLabel == EmptyView, I.ValueType == Bool {}
    public init<S: StringProtocol, I: SetValueIntent>(_ title: S, isOn: Bool, action: I) where Label == Text, ValueLabel == EmptyView, I.ValueType == Bool {}
}
extension ControlWidgetTemplate {
    public func tint(_ tint: Color?) -> some ControlWidgetTemplate { self }
    public func controlWidgetActionHint(_ hintKey: LocalizedStringKey) -> some ControlWidgetTemplate { self }
    public func controlWidgetActionHint<S: StringProtocol>(_ hint: S) -> some ControlWidgetTemplate { self }
    public func controlWidgetActionHint(_ hint: Text) -> some ControlWidgetTemplate { self }
    public func controlWidgetStatus(_ statusKey: LocalizedStringKey) -> some ControlWidgetTemplate { self }
    public func controlWidgetStatus<S: StringProtocol>(_ status: S) -> some ControlWidgetTemplate { self }
    public func controlWidgetStatus(_ status: Text) -> some ControlWidgetTemplate { self }
}
public struct ControlCenter: Sendable {
    public static let shared = ControlCenter()
    public func reloadAllControls() {}
    public func reloadControls(ofKind kind: String) {}
    public func currentControls() async throws -> [ControlInfo] { [] }
}

