// ActivityKit stub — Live Activity lifecycle from the app side.
@_exported import Foundation

public protocol ActivityAttributes: Codable, Sendable {
    associatedtype ContentState: Codable & Hashable & Sendable
}
public struct ActivityContent<State: Codable & Hashable & Sendable>: Sendable {
    public var state: State
    public var staleDate: Date?
    public var relevanceScore: Double
    public init(state: State, staleDate: Date?, relevanceScore: Double = 0) { self.state = state; self.staleDate = staleDate; self.relevanceScore = relevanceScore }
}
public enum ActivityState: Sendable, Hashable, Codable { case active, ended, dismissed, stale, pending }
public enum ActivityUIDismissalPolicy: Sendable, Hashable {
    case `default`
    case immediate
    case after(Date)
}
public struct ActivityAuthorizationInfo: Sendable {
    public init() {}
    public var areActivitiesEnabled: Bool { true }
    public var frequentPushesEnabled: Bool { true }
    public var activityEnablementUpdates: AsyncStream<Bool> { AsyncStream { $0.finish() } }
    public var frequentPushEnablementUpdates: AsyncStream<Bool> { AsyncStream { $0.finish() } }
}
public struct ActivityAuthorizationError: Error, Sendable, Hashable {
    public static let unsupported = ActivityAuthorizationError(), denied = ActivityAuthorizationError(), attributesTooLarge = ActivityAuthorizationError(), visibility = ActivityAuthorizationError(), globalMaximumExceeded = ActivityAuthorizationError(), targetMaximumExceeded = ActivityAuthorizationError(), unsupportedTarget = ActivityAuthorizationError(), persistenceFailure = ActivityAuthorizationError(), malformedActivityIdentifier = ActivityAuthorizationError(), reconnectNotPermitted = ActivityAuthorizationError(), missingProcessIdentifier = ActivityAuthorizationError()
}
public struct ActivityStyle: Sendable, Hashable { public static let standard = ActivityStyle(), transient = ActivityStyle() }
public struct ActivityAlertConfiguration: Sendable {
    public init(title: LocalizedStringResource, body: LocalizedStringResource, sound: AlertSound) {}
    public struct AlertSound: Sendable { public static let `default` = AlertSound(); public static func named(_ name: String) -> AlertSound { AlertSound() } }
}
public final class Activity<Attributes: ActivityAttributes>: Identifiable, @unchecked Sendable {
    public enum PushType: Sendable { case token, channel(String) }
    public let id: String = UUID().uuidString
    public let attributes: Attributes
    public var content: ActivityContent<Attributes.ContentState> { _content }
    public var contentState: Attributes.ContentState { _content.state }
    public var activityState: ActivityState { .active }
    public var pushToken: Data? { nil }
    public var activityStateUpdates: AsyncStream<ActivityState> { AsyncStream { $0.finish() } }
    public var contentUpdates: AsyncStream<ActivityContent<Attributes.ContentState>> { AsyncStream { $0.finish() } }
    public var pushTokenUpdates: AsyncStream<Data> { AsyncStream { $0.finish() } }
    private var _content: ActivityContent<Attributes.ContentState>
    init(attributes: Attributes, content: ActivityContent<Attributes.ContentState>) { self.attributes = attributes; _content = content }

    public static var activities: [Activity<Attributes>] { [] }
    public static var activityUpdates: AsyncStream<Activity<Attributes>> { AsyncStream { $0.finish() } }
    public static var pushToStartToken: Data? { nil }
    public static var pushToStartTokenUpdates: AsyncStream<Data> { AsyncStream { $0.finish() } }

    public static func request(attributes: Attributes, content: ActivityContent<Attributes.ContentState>, pushType: PushType? = nil) throws -> Activity<Attributes> { Activity(attributes: attributes, content: content) }
    public static func request(attributes: Attributes, content: ActivityContent<Attributes.ContentState>, pushType: PushType? = nil, style: ActivityStyle) throws -> Activity<Attributes> { Activity(attributes: attributes, content: content) }
    public static func request(attributes: Attributes, contentState: Attributes.ContentState, pushType: PushType? = nil) throws -> Activity<Attributes> { Activity(attributes: attributes, content: ActivityContent(state: contentState, staleDate: nil)) }
    public func update(_ content: ActivityContent<Attributes.ContentState>) async { _content = content }
    public func update(_ content: ActivityContent<Attributes.ContentState>, alertConfiguration: ActivityAlertConfiguration?) async { _content = content }
    public func update(_ content: ActivityContent<Attributes.ContentState>, alertConfiguration: ActivityAlertConfiguration? = nil, timestamp: Date) async { _content = content }
    public func update(using contentState: Attributes.ContentState) async { _content.state = contentState }
    public func end(_ content: ActivityContent<Attributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {}
    public func end(_ content: ActivityContent<Attributes.ContentState>?, dismissalPolicy: ActivityUIDismissalPolicy = .default, timestamp: Date) async {}
    public func end(using contentState: Attributes.ContentState? = nil, dismissalPolicy: ActivityUIDismissalPolicy = .default) async {}
}
