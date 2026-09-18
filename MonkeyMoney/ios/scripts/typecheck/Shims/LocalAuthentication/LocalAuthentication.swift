// LocalAuthentication stub.
import Foundation

public enum LAPolicy: Int { case deviceOwnerAuthenticationWithBiometrics = 1, deviceOwnerAuthentication = 2, deviceOwnerAuthenticationWithCompanion = 3, deviceOwnerAuthenticationWithBiometricsOrCompanion = 4 }
public enum LABiometryType: Int { case none, touchID, faceID, opticID }
public struct LAError: Error, Equatable {
    public enum Code: Int { case authenticationFailed = -1, userCancel = -2, userFallback = -3, systemCancel = -4, passcodeNotSet = -5, biometryNotAvailable = -6, biometryNotEnrolled = -7, biometryLockout = -8, appCancel = -9, invalidContext = -10, notInteractive = -1004, watchNotAvailable = -11, companionNotAvailable = -12, biometryDisconnected = -13, invalidDimensions = -14 }
    public let code: Code
    public init(_ code: Code) { self.code = code }
    public static var errorDomain: String { "com.apple.LocalAuthentication" }
}
open class LAContext: NSObject {
    public override init() { super.init() }
    open var localizedCancelTitle: String?
    open var localizedFallbackTitle: String?
    open var localizedReason: String = ""
    open var touchIDAuthenticationAllowableReuseDuration: TimeInterval = 0
    open var interactionNotAllowed: Bool = false
    open var biometryType: LABiometryType { .faceID }
    open var evaluatedPolicyDomainState: Data? { nil }
    open func canEvaluatePolicy(_ policy: LAPolicy, error: NSErrorPointer) -> Bool { true }
    open func evaluatePolicy(_ policy: LAPolicy, localizedReason: String, reply: @escaping (Bool, Error?) -> Void) {}
    open func evaluatePolicy(_ policy: LAPolicy, localizedReason: String) async throws -> Bool { true }
    open func invalidate() {}
}
