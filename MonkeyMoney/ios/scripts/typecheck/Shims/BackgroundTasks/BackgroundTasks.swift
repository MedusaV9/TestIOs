// BackgroundTasks stub.
import Foundation

open class BGTaskRequest: NSObject {
    public init(identifier: String) { self.identifier = identifier; super.init() }
    public let identifier: String
    open var earliestBeginDate: Date?
}
open class BGAppRefreshTaskRequest: BGTaskRequest {
    public override init(identifier: String) { super.init(identifier: identifier) }
}
open class BGProcessingTaskRequest: BGTaskRequest {
    public override init(identifier: String) { super.init(identifier: identifier) }
    open var requiresNetworkConnectivity: Bool = false
    open var requiresExternalPower: Bool = false
}
open class BGTask: NSObject {
    public override init() { super.init() }
    open var identifier: String { "" }
    open var expirationHandler: (() -> Void)?
    open func setTaskCompleted(success: Bool) {}
}
open class BGAppRefreshTask: BGTask {}
open class BGProcessingTask: BGTask {}
open class BGTaskScheduler: NSObject {
    public override init() { super.init() }
    open class var shared: BGTaskScheduler { BGTaskScheduler() }
    open func register(forTaskWithIdentifier identifier: String, using queue: DispatchQueue?, launchHandler: @escaping (BGTask) -> Void) -> Bool { true }
    open func submit(_ taskRequest: BGTaskRequest) throws {}
    open func cancel(taskRequestWithIdentifier identifier: String) {}
    open func cancelAllTaskRequests() {}
    open func pendingTaskRequests() async -> [BGTaskRequest] { [] }
    open func getPendingTaskRequests(completionHandler: @escaping ([BGTaskRequest]) -> Void) {}
    public struct Error: Swift.Error { public enum Code: Int { case unavailable = 1, tooManyPendingTaskRequests, notPermitted }; public let code: Code }
}
