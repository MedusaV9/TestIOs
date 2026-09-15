// AppIntents stub — intents, entities, enums, parameters, shortcuts.
@_exported import Foundation
import SwiftUI

public struct IntentDescription: Sendable {
    public init(_ descriptionText: LocalizedStringResource, categoryName: LocalizedStringResource? = nil, searchKeywords: [LocalizedStringResource] = [], resultValueName: LocalizedStringResource? = nil) {}
    public init(stringLiteral value: String) {}
}
extension IntentDescription: ExpressibleByStringLiteral {}

public struct IntentDialog: ExpressibleByStringInterpolation, Sendable {
    public init(_ full: LocalizedStringResource) {}
    public init(full: LocalizedStringResource, supporting: LocalizedStringResource) {}
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: LocalizedStringResource.StringInterpolation) {}
    public typealias StringInterpolation = LocalizedStringResource.StringInterpolation
}

public struct DisplayRepresentation: Sendable, Hashable {
    public struct Image: Sendable, Hashable {
        public init(named name: String, isTemplate: Bool? = nil) {}
        public init(systemName: String) {}
        public init(systemName: String, isTemplate: Bool?) {}
        public init(data: Data, isTemplate: Bool? = nil) {}
        public init(url: URL, isTemplate: Bool? = nil) {}
    }
    public var title: LocalizedStringResource
    public var subtitle: LocalizedStringResource?
    public var image: Image?
    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image? = nil) { self.title = title; self.subtitle = subtitle; self.image = image }
    public init(title: LocalizedStringResource, subtitle: LocalizedStringResource? = nil, image: Image? = nil, synonyms: [LocalizedStringResource]) { self.title = title; self.subtitle = subtitle; self.image = image }
    public init(stringLiteral value: String) { title = LocalizedStringResource(stringLiteral: value) }
}
extension DisplayRepresentation: ExpressibleByStringLiteral {}
public struct TypeDisplayRepresentation: Sendable {
    public init(name: LocalizedStringResource) {}
    public init(name: LocalizedStringResource, numericFormat: LocalizedStringResource) {}
    public init(name: LocalizedStringResource, numericFormat: LocalizedStringResource, synonyms: [LocalizedStringResource]) {}
    public init(name: LocalizedStringResource, synonyms: [LocalizedStringResource]) {}
    public init(stringLiteral value: String) {}
}
extension TypeDisplayRepresentation: ExpressibleByStringLiteral {}

// MARK: Results

public protocol IntentResult: Sendable {}
public protocol ProvidesDialog: IntentResult { var dialog: IntentDialog { get } }
public protocol OpensIntent: IntentResult { associatedtype OpensIntentType: AppIntent; var opensIntent: Self.OpensIntentType { get } }
public protocol ReturnsValue<Value>: IntentResult { associatedtype Value; var value: Self.Value { get } }
public protocol ShowsSnippetView: IntentResult { associatedtype SnippetView: View; var view: Self.SnippetView { get } }
public protocol ShowsSnippetIntent: IntentResult {}
public struct IntentResultContainer<Value, OpensIntentType, SnippetView, SnippetIntent>: IntentResult, ProvidesDialog, ReturnsValue, ShowsSnippetIntent {
    public var dialog: IntentDialog { IntentDialog(stringLiteral: "") }
    public var value: Value { fatalError() }
}
extension IntentResultContainer: OpensIntent where OpensIntentType: AppIntent {
    public var opensIntent: OpensIntentType { fatalError() }
}
extension IntentResultContainer: ShowsSnippetView where SnippetView: View {
    public var view: SnippetView { fatalError() }
}
extension IntentResult where Self == IntentResultContainer<Never, Never, Never, Never> {
    public static func result() -> Self { Self() }
    public static func result(dialog: IntentDialog) -> Self { Self() }
}
extension IntentResult {
    public static func result<V: Sendable>(value: V) -> IntentResultContainer<V, Never, Never, Never> where Self == IntentResultContainer<V, Never, Never, Never> { IntentResultContainer() }
    public static func result<V: Sendable>(value: V, dialog: IntentDialog) -> IntentResultContainer<V, Never, Never, Never> where Self == IntentResultContainer<V, Never, Never, Never> { IntentResultContainer() }
    public static func result<I: AppIntent>(opensIntent: I) -> IntentResultContainer<Never, I, Never, Never> where Self == IntentResultContainer<Never, I, Never, Never> { IntentResultContainer() }
    public static func result<I: AppIntent>(opensIntent: I, dialog: IntentDialog) -> IntentResultContainer<Never, I, Never, Never> where Self == IntentResultContainer<Never, I, Never, Never> { IntentResultContainer() }
    public static func result<V: View>(dialog: IntentDialog, @ViewBuilder view: () -> V) -> IntentResultContainer<Never, Never, V, Never> where Self == IntentResultContainer<Never, Never, V, Never> { IntentResultContainer() }
    public static func result<V: View>(@ViewBuilder view: () -> V) -> IntentResultContainer<Never, Never, V, Never> where Self == IntentResultContainer<Never, Never, V, Never> { IntentResultContainer() }
    public static func result<Val: Sendable, V: View>(value: Val, dialog: IntentDialog, @ViewBuilder view: () -> V) -> IntentResultContainer<Val, Never, V, Never> where Self == IntentResultContainer<Val, Never, V, Never> { IntentResultContainer() }
}

// MARK: Intents

public protocol PersistentlyIdentifiable { static var persistentIdentifier: String { get } }
extension PersistentlyIdentifiable { public static var persistentIdentifier: String { String(describing: Self.self) } }
public protocol AppIntent: PersistentlyIdentifiable, Sendable {
    associatedtype PerformResult: IntentResult
    static var title: LocalizedStringResource { get }
    static var description: IntentDescription? { get }
    static var openAppWhenRun: Bool { get }
    static var isDiscoverable: Bool { get }
    static var authenticationPolicy: IntentAuthenticationPolicy { get }
    static var supportedModes: IntentModes { get }
    init()
    func perform() async throws -> Self.PerformResult
}
extension AppIntent {
    public static var description: IntentDescription? { nil }
    public static var openAppWhenRun: Bool { false }
    public static var isDiscoverable: Bool { true }
    public static var authenticationPolicy: IntentAuthenticationPolicy { .requiresAuthentication }
    public static var supportedModes: IntentModes { .foreground }
    public static var parameterSummary: some ParameterSummary { _EmptyParameterSummary() }
    public static var systemImageName: String { "" }
}
public struct IntentModes: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let background = IntentModes(rawValue: 1), foreground = IntentModes(rawValue: 2) }
public enum IntentAuthenticationPolicy: Sendable { case alwaysAllowed, requiresAuthentication, requiresLocalDeviceAuthentication }
public protocol ParameterSummary {}
public struct _EmptyParameterSummary: ParameterSummary {}
public struct Summary: ParameterSummary { public init(_ text: LocalizedStringResource) {} }
public protocol LiveActivityIntent: AppIntent {}
public protocol WidgetConfigurationIntent: AppIntent {}
extension WidgetConfigurationIntent {
    public func perform() async throws -> some IntentResult { .result() }
}
public protocol ControlConfigurationIntent: WidgetConfigurationIntent {}
public protocol SetValueIntent: AppIntent { associatedtype ValueType; var value: ValueType { get set } }
public protocol AudioPlaybackIntent: AppIntent {}
public protocol ForegroundContinuableIntent: AppIntent {}
public protocol SystemIntent: AppIntent {}
public protocol OpenIntent: AppIntent { associatedtype Target: AppEntity; var target: Target { get } }
public protocol AppEntity: PersistentlyIdentifiable, Identifiable, CustomStringConvertible, Sendable where ID: EntityIdentifierConvertible {
    associatedtype DefaultQuery: EntityQuery where DefaultQuery.Entity == Self
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    static var defaultQuery: DefaultQuery { get }
    var displayRepresentation: DisplayRepresentation { get }
}
extension AppEntity { public var description: String { String(describing: displayRepresentation) } }
public protocol EntityIdentifierConvertible: Sendable {}
extension String: EntityIdentifierConvertible {}
extension Int: EntityIdentifierConvertible {}
extension UUID: EntityIdentifierConvertible {}
public protocol EntityQuery: Sendable {
    associatedtype Entity: AppEntity
    init()
    func entities(for identifiers: [Entity.ID]) async throws -> [Entity]
    func suggestedEntities() async throws -> [Entity]
    func defaultResult() async -> Entity?
}
extension EntityQuery {
    public func suggestedEntities() async throws -> [Entity] { [] }
    public func defaultResult() async -> Entity? { nil }
}
public protocol EntityStringQuery: EntityQuery { func entities(matching string: String) async throws -> [Entity] }
public protocol AppEnum: RawRepresentable, CaseIterable, Sendable, Hashable where RawValue: Hashable {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { get }
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] { get }
}
public struct OpenURLIntent: AppIntent, SystemIntent {
    public static var title: LocalizedStringResource { "Open URL" }
    public init() {}
    public init(_ url: URL) {}
    public init(_ url: URL, target: AppIntentTarget) {}
    public func perform() async throws -> some IntentResult { .result() }
}
public struct AppIntentTarget: Sendable { public static let currentApp = AppIntentTarget() }

@propertyWrapper
public struct IntentParameter<Value>: @unchecked Sendable {
    public init(title: LocalizedStringResource) {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value? = nil, requestValueDialog: IntentDialog? = nil) {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value, requestValueDialog: IntentDialog? = nil) {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value? = nil, inputOptions: String.IntentInputOptions? = nil, requestValueDialog: IntentDialog? = nil) where Value == String {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value? = nil, inclusiveRange: (Int, Int)? = nil, requestValueDialog: IntentDialog? = nil) where Value == Int {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value? = nil, inclusiveRange: (Double, Double)? = nil, requestValueDialog: IntentDialog? = nil) where Value == Double {}
    public init(title: LocalizedStringResource, description: LocalizedStringResource? = nil, default: Value? = nil, kind: DateParameterKind? = nil, requestValueDialog: IntentDialog? = nil) where Value == Date {}
    public var wrappedValue: Value { get { fatalError() } nonmutating set {} }
    public var projectedValue: IntentParameter<Value> { self }
}
public typealias Parameter = IntentParameter
public enum DateParameterKind: Sendable { case date, dateTime, time }
extension String { public struct IntentInputOptions: Sendable { public init(keyboardType: Int = 0, capitalizationType: Int = 0, multiline: Bool = false, autocorrect: Bool = true, smartQuotes: Bool = true, smartDashes: Bool = true) {} } }
@propertyWrapper
public struct IntentDependency<Value> {
    public init() {}
    public init(key: String) {}
    public var wrappedValue: Value { fatalError() }
}
public typealias Dependency = IntentDependency
public struct AppDependencyManager: Sendable {
    public static let shared = AppDependencyManager()
    public func add<T>(dependency: @autoclosure @escaping () -> T) {}
    public func add<T>(key: String, dependency: @autoclosure @escaping () -> T) {}
}

// MARK: Shortcuts

public struct AppShortcutPhrase<Intent: AppIntent>: ExpressibleByStringInterpolation, Sendable {
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: StringInterpolation) {}
    public struct StringInterpolation: StringInterpolationProtocol, Sendable {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation(_ token: AppShortcutPhraseToken) {}
        public mutating func appendInterpolation<V>(_ parameter: IntentParameter<V>) {}
        public mutating func appendInterpolation<V>(_ parameter: IntentParameter<V?>) {}
    }
}
public struct AppShortcutPhraseToken: Sendable { public static let applicationName = AppShortcutPhraseToken() }
public struct AppShortcut: Sendable {
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>], shortTitle: LocalizedStringResource, systemImageName: String) {}
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>], shortTitle: LocalizedStringResource, systemImageName: String, parameterPresentation: ParameterPresentation) {}
    public init<I: AppIntent>(intent: I, phrases: [AppShortcutPhrase<I>]) {}
}
public struct ParameterPresentation: Sendable { public init<T>(for: T.Type, summary: Summary, optionsCollections: () -> Never) {} }
@resultBuilder
public struct AppShortcutsBuilder {
    public static func buildBlock(_ components: AppShortcut...) -> [AppShortcut] { components }
}
public protocol AppShortcutsProvider {
    @AppShortcutsBuilder static var appShortcuts: [AppShortcut] { get }
    static var shortcutTileColor: ShortcutTileColor { get }
}
extension AppShortcutsProvider {
    public static var shortcutTileColor: ShortcutTileColor { .grayBlue }
    public static func updateAppShortcutParameters() {}
}
public enum ShortcutTileColor: Sendable { case red, orange, yellow, green, teal, lightBlue, blue, navy, grayBlue, purple, pink, grape, tangerine, lime, grayGreen, grayBrown }

// MARK: SwiftUI cross-import overlay (_AppIntents_SwiftUI)

extension Button {
    public init<I: AppIntent>(intent: I, @ViewBuilder label: () -> Label) { self.init(_StubInit()) }
}
extension Button where Label == Text {
    public init<I: AppIntent>(_ titleKey: LocalizedStringKey, intent: I) { self.init(_StubInit()) }
    public init<S: StringProtocol, I: AppIntent>(_ title: S, intent: I) { self.init(_StubInit()) }
}
extension Button where Label == SwiftUI.Label<Text, Image> {
    public init<I: AppIntent>(_ titleKey: LocalizedStringKey, systemImage: String, intent: I) { self.init(_StubInit()) }
    public init<S: StringProtocol, I: AppIntent>(_ title: S, systemImage: String, intent: I) { self.init(_StubInit()) }
}
extension Toggle {
    public init<I: SetValueIntent>(isOn: Bool, intent: I, @ViewBuilder label: () -> Label) where I.ValueType == Bool { self.init(_StubInit()) }
}
extension Toggle where Label == Text {
    public init<I: SetValueIntent>(_ titleKey: LocalizedStringKey, isOn: Bool, intent: I) where I.ValueType == Bool { self.init(_StubInit()) }
    public init<S: StringProtocol, I: SetValueIntent>(_ title: S, isOn: Bool, intent: I) where I.ValueType == Bool { self.init(_StubInit()) }
}
extension Toggle where Label == SwiftUI.Label<Text, Image> {
    public init<I: SetValueIntent>(_ titleKey: LocalizedStringKey, systemImage: String, isOn: Bool, intent: I) where I.ValueType == Bool { self.init(_StubInit()) }
}
extension View {
    public func widgetConfigurationIntent<I: WidgetConfigurationIntent>(_ intent: I?) -> some View { self }
}
