// UserNotifications stub.
import Foundation

public struct UNAuthorizationOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let badge = UNAuthorizationOptions(rawValue: 1), sound = UNAuthorizationOptions(rawValue: 2), alert = UNAuthorizationOptions(rawValue: 4), carPlay = UNAuthorizationOptions(rawValue: 8), criticalAlert = UNAuthorizationOptions(rawValue: 16), providesAppNotificationSettings = UNAuthorizationOptions(rawValue: 32), provisional = UNAuthorizationOptions(rawValue: 64), timeSensitive = UNAuthorizationOptions(rawValue: 256)
}
public enum UNAuthorizationStatus: Int, Sendable { case notDetermined, denied, authorized, provisional, ephemeral }
public enum UNNotificationSetting: Int, Sendable { case notSupported, disabled, enabled }
public enum UNAlertStyle: Int, Sendable { case none, banner, alert }
public enum UNNotificationInterruptionLevel: UInt, Sendable { case passive, active, timeSensitive, critical }
public struct UNNotificationPresentationOptions: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let badge = UNNotificationPresentationOptions(rawValue: 1), sound = UNNotificationPresentationOptions(rawValue: 2), alert = UNNotificationPresentationOptions(rawValue: 4), list = UNNotificationPresentationOptions(rawValue: 8), banner = UNNotificationPresentationOptions(rawValue: 16)
}
public struct UNNotificationSoundName: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
}
open class UNNotificationSound: NSObject {
    public override init() { super.init() }
    open class var `default`: UNNotificationSound { UNNotificationSound() }
    open class var defaultCritical: UNNotificationSound { UNNotificationSound() }
    public convenience init(named name: UNNotificationSoundName) { self.init() }
    open class func ringtoneSoundNamed(_ name: UNNotificationSoundName) -> UNNotificationSound { UNNotificationSound() }
    open class func criticalSoundNamed(_ name: UNNotificationSoundName) -> UNNotificationSound { UNNotificationSound() }
    open class func criticalSoundNamed(_ name: UNNotificationSoundName, withAudioVolume volume: Float) -> UNNotificationSound { UNNotificationSound() }
}
open class UNNotificationSettings: NSObject {
    public override init() { super.init() }
    open var authorizationStatus: UNAuthorizationStatus { .authorized }
    open var soundSetting: UNNotificationSetting { .enabled }
    open var badgeSetting: UNNotificationSetting { .enabled }
    open var alertSetting: UNNotificationSetting { .enabled }
    open var notificationCenterSetting: UNNotificationSetting { .enabled }
    open var lockScreenSetting: UNNotificationSetting { .enabled }
    open var alertStyle: UNAlertStyle { .banner }
    open var timeSensitiveSetting: UNNotificationSetting { .enabled }
    open var providesAppNotificationSettings: Bool { false }
}
open class UNNotificationContent: NSObject {
    public override init() { super.init() }
    open var title: String { "" }
    open var subtitle: String { "" }
    open var body: String { "" }
    open var badge: NSNumber? { nil }
    open var sound: UNNotificationSound? { nil }
    open var categoryIdentifier: String { "" }
    open var threadIdentifier: String { "" }
    open var userInfo: [AnyHashable: Any] { [:] }
    open var attachments: [UNNotificationAttachment] { [] }
    open var targetContentIdentifier: String? { nil }
    open var interruptionLevel: UNNotificationInterruptionLevel { .active }
    open var relevanceScore: Double { 0 }
    open var filterCriteria: String? { nil }
    open override func mutableCopy() -> Any { UNMutableNotificationContent() }
}
open class UNMutableNotificationContent: UNNotificationContent {
    public override init() { super.init() }
    private var _title = "", _subtitle = "", _body = "", _category = "", _thread = ""
    private var _badge: NSNumber?, _sound: UNNotificationSound?, _userInfo: [AnyHashable: Any] = [:], _attachments: [UNNotificationAttachment] = []
    private var _level: UNNotificationInterruptionLevel = .active, _relevance: Double = 0, _target: String?
    open override var title: String { get { _title } set { _title = newValue } }
    open override var subtitle: String { get { _subtitle } set { _subtitle = newValue } }
    open override var body: String { get { _body } set { _body = newValue } }
    open override var badge: NSNumber? { get { _badge } set { _badge = newValue } }
    open override var sound: UNNotificationSound? { get { _sound } set { _sound = newValue } }
    open override var categoryIdentifier: String { get { _category } set { _category = newValue } }
    open override var threadIdentifier: String { get { _thread } set { _thread = newValue } }
    open override var userInfo: [AnyHashable: Any] { get { _userInfo } set { _userInfo = newValue } }
    open override var attachments: [UNNotificationAttachment] { get { _attachments } set { _attachments = newValue } }
    open override var interruptionLevel: UNNotificationInterruptionLevel { get { _level } set { _level = newValue } }
    open override var relevanceScore: Double { get { _relevance } set { _relevance = newValue } }
    open override var targetContentIdentifier: String? { get { _target } set { _target = newValue } }
}
open class UNNotificationAttachment: NSObject {
    public init(identifier: String, url URL: URL, options: [AnyHashable: Any]? = nil) throws { super.init() }
    open var identifier: String { "" }
    open var url: URL { URL(fileURLWithPath: "/") }
    open var type: String { "" }
}
open class UNNotificationTrigger: NSObject {
    public override init() { super.init() }
    open var repeats: Bool { false }
}
open class UNTimeIntervalNotificationTrigger: UNNotificationTrigger {
    public init(timeInterval: TimeInterval, repeats: Bool) { super.init() }
    open var timeInterval: TimeInterval { 0 }
    open func nextTriggerDate() -> Date? { nil }
}
open class UNCalendarNotificationTrigger: UNNotificationTrigger {
    public init(dateMatching dateComponents: DateComponents, repeats: Bool) { super.init() }
    open var dateComponents: DateComponents { DateComponents() }
    open func nextTriggerDate() -> Date? { nil }
}
open class UNPushNotificationTrigger: UNNotificationTrigger {}
open class UNNotificationRequest: NSObject {
    public init(identifier: String, content: UNNotificationContent, trigger: UNNotificationTrigger?) { self.identifier = identifier; self.content = content; self.trigger = trigger; super.init() }
    public let identifier: String
    public let content: UNNotificationContent
    public let trigger: UNNotificationTrigger?
}
open class UNNotification: NSObject {
    public override init() { super.init() }
    open var date: Date { Date() }
    open var request: UNNotificationRequest { UNNotificationRequest(identifier: "", content: UNNotificationContent(), trigger: nil) }
}
open class UNNotificationResponse: NSObject {
    public override init() { super.init() }
    open var notification: UNNotification { UNNotification() }
    open var actionIdentifier: String { UNNotificationDefaultActionIdentifier }
    open var targetScene: AnyObject? { nil }
}
open class UNTextInputNotificationResponse: UNNotificationResponse { open var userText: String { "" } }
public let UNNotificationDefaultActionIdentifier = "com.apple.UNNotificationDefaultActionIdentifier"
public let UNNotificationDismissActionIdentifier = "com.apple.UNNotificationDismissActionIdentifier"
open class UNNotificationAction: NSObject {
    public struct Options: OptionSet, Sendable { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let authenticationRequired = Options(rawValue: 1), destructive = Options(rawValue: 2), foreground = Options(rawValue: 4) }
    public init(identifier: String, title: String, options: Options = []) { super.init() }
    public init(identifier: String, title: String, options: Options = [], icon: UNNotificationActionIcon?) { super.init() }
    open var identifier: String { "" }
    open var title: String { "" }
}
open class UNTextInputNotificationAction: UNNotificationAction {
    public init(identifier: String, title: String, options: Options = [], textInputButtonTitle: String, textInputPlaceholder: String) { super.init(identifier: identifier, title: title, options: options) }
}
open class UNNotificationActionIcon: NSObject {
    public convenience init(templateImageName: String) { self.init() }
    public convenience init(systemImageName: String) { self.init() }
}
open class UNNotificationCategory: NSObject {
    public struct Options: OptionSet, Sendable { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let customDismissAction = Options(rawValue: 1), allowInCarPlay = Options(rawValue: 2), hiddenPreviewsShowTitle = Options(rawValue: 4), hiddenPreviewsShowSubtitle = Options(rawValue: 8) }
    public init(identifier: String, actions: [UNNotificationAction], intentIdentifiers: [String], options: Options = []) { super.init() }
    public init(identifier: String, actions: [UNNotificationAction], intentIdentifiers: [String], hiddenPreviewsBodyPlaceholder: String?, categorySummaryFormat: String?, options: Options = []) { super.init() }
}
public protocol UNUserNotificationCenterDelegate: NSObjectProtocol {
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void)
    func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?)
}
extension UNUserNotificationCenterDelegate {
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions { [] }
    public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) { completionHandler([]) }
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {}
    public func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) { completionHandler() }
    public func userNotificationCenter(_ center: UNUserNotificationCenter, openSettingsFor notification: UNNotification?) {}
}
open class UNUserNotificationCenter: NSObject {
    public override init() { super.init() }
    open class func current() -> UNUserNotificationCenter { UNUserNotificationCenter() }
    open weak var delegate: (any UNUserNotificationCenterDelegate)?
    open var supportsContentExtensions: Bool { true }
    open func requestAuthorization(options: UNAuthorizationOptions = []) async throws -> Bool { true }
    open func requestAuthorization(options: UNAuthorizationOptions = [], completionHandler: @escaping (Bool, Error?) -> Void) {}
    open func notificationSettings() async -> UNNotificationSettings { UNNotificationSettings() }
    open func getNotificationSettings(completionHandler: @escaping (UNNotificationSettings) -> Void) {}
    open func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
    open func notificationCategories() async -> Set<UNNotificationCategory> { [] }
    open func add(_ request: UNNotificationRequest) async throws {}
    open func add(_ request: UNNotificationRequest, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {}
    open func pendingNotificationRequests() async -> [UNNotificationRequest] { [] }
    open func getPendingNotificationRequests(completionHandler: @escaping ([UNNotificationRequest]) -> Void) {}
    open func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {}
    open func removeAllPendingNotificationRequests() {}
    open func deliveredNotifications() async -> [UNNotification] { [] }
    open func getDeliveredNotifications(completionHandler: @escaping ([UNNotification]) -> Void) {}
    open func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {}
    open func removeAllDeliveredNotifications() {}
    open func setBadgeCount(_ newBadgeCount: Int) async throws {}
    open func setBadgeCount(_ newBadgeCount: Int, withCompletionHandler completionHandler: ((Error?) -> Void)? = nil) {}
}
