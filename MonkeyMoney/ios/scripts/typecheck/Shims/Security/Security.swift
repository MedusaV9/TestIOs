// Security stub — Keychain item API, random bytes, access control.
// CoreFoundation bridge types are aliased to their Foundation twins so the
// app's `as CFDictionary` casts type-check on Linux.
import Foundation

public typealias CFTypeRef = AnyObject
public typealias CFDictionary = NSDictionary
public typealias CFMutableDictionary = NSMutableDictionary
public typealias CFData = NSData
public typealias CFString = NSString
public typealias CFNumber = NSNumber
public typealias CFBoolean = NSNumber
public typealias CFArray = NSArray
public typealias CFError = NSError
public typealias CFAllocator = AnyObject

public let kCFBooleanTrue: CFBoolean = NSNumber(value: true)
public let kCFBooleanFalse: CFBoolean = NSNumber(value: false)
public let kCFAllocatorDefault: CFAllocator? = nil

public let errSecSuccess: OSStatus = 0
public let errSecUnimplemented: OSStatus = -4
public let errSecParam: OSStatus = -50
public let errSecAllocate: OSStatus = -108
public let errSecNotAvailable: OSStatus = -25291
public let errSecDuplicateItem: OSStatus = -25299
public let errSecItemNotFound: OSStatus = -25300
public let errSecInteractionNotAllowed: OSStatus = -25308
public let errSecDecode: OSStatus = -26275
public let errSecAuthFailed: OSStatus = -25293
public let errSecUserCanceled: OSStatus = -128
public let errSecMissingEntitlement: OSStatus = -34018

public let kSecClass: CFString = "class"
public let kSecClassGenericPassword: CFString = "genp"
public let kSecClassInternetPassword: CFString = "inet"
public let kSecClassKey: CFString = "keys"
public let kSecAttrService: CFString = "svce"
public let kSecAttrAccount: CFString = "acct"
public let kSecAttrGeneric: CFString = "gena"
public let kSecAttrLabel: CFString = "labl"
public let kSecAttrAccessGroup: CFString = "agrp"
public let kSecAttrAccessible: CFString = "pdmn"
public let kSecAttrAccessControl: CFString = "accc"
public let kSecAttrSynchronizable: CFString = "sync"
public let kSecAttrSynchronizableAny: CFString = "syna"
public let kSecAttrAccessibleWhenUnlocked: CFString = "ak"
public let kSecAttrAccessibleAfterFirstUnlock: CFString = "ck"
public let kSecAttrAccessibleWhenUnlockedThisDeviceOnly: CFString = "aku"
public let kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly: CFString = "cku"
public let kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly: CFString = "akpu"
public let kSecValueData: CFString = "v_Data"
public let kSecValueRef: CFString = "v_Ref"
public let kSecReturnData: CFString = "r_Data"
public let kSecReturnAttributes: CFString = "r_Attributes"
public let kSecReturnRef: CFString = "r_Ref"
public let kSecReturnPersistentRef: CFString = "r_PersistentRef"
public let kSecMatchLimit: CFString = "m_Limit"
public let kSecMatchLimitOne: CFString = "m_LimitOne"
public let kSecMatchLimitAll: CFString = "m_LimitAll"
public let kSecUseAuthenticationUI: CFString = "u_AuthUI"
public let kSecUseAuthenticationUIAllow: CFString = "u_AuthUIA"
public let kSecUseAuthenticationUIFail: CFString = "u_AuthUIF"
public let kSecUseAuthenticationUISkip: CFString = "u_AuthUIS"
public let kSecUseOperationPrompt: CFString = "u_OpPrompt"
public let kSecUseAuthenticationContext: CFString = "u_AuthCtx"
public let kSecUseDataProtectionKeychain: CFString = "u_DataProtect"
public let kSecAttrKeyType: CFString = "type"
public let kSecAttrKeySizeInBits: CFString = "bsiz"
public let kSecAttrKeyTypeECSECPrimeRandom: CFString = "73"
public let kSecAttrTokenID: CFString = "tkid"
public let kSecAttrTokenIDSecureEnclave: CFString = "com.apple.setoken"
public let kSecPrivateKeyAttrs: CFString = "private"
public let kSecAttrIsPermanent: CFString = "perm"
public let kSecAttrApplicationTag: CFString = "atag"

public func SecItemAdd(_ attributes: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecSuccess }
public func SecItemCopyMatching(_ query: CFDictionary, _ result: UnsafeMutablePointer<CFTypeRef?>?) -> OSStatus { errSecItemNotFound }
public func SecItemUpdate(_ query: CFDictionary, _ attributesToUpdate: CFDictionary) -> OSStatus { errSecSuccess }
public func SecItemDelete(_ query: CFDictionary) -> OSStatus { errSecSuccess }

public struct SecRandomRef {}
public let kSecRandomDefault: SecRandomRef? = nil
public func SecRandomCopyBytes(_ rnd: SecRandomRef?, _ count: Int, _ bytes: UnsafeMutableRawPointer) -> Int32 { 0 }

public class SecAccessControl {}
public struct SecAccessControlCreateFlags: OptionSet {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let userPresence = SecAccessControlCreateFlags(rawValue: 1 << 0)
    public static let biometryAny = SecAccessControlCreateFlags(rawValue: 1 << 1)
    public static let biometryCurrentSet = SecAccessControlCreateFlags(rawValue: 1 << 3)
    public static let devicePasscode = SecAccessControlCreateFlags(rawValue: 1 << 4)
    public static let watch = SecAccessControlCreateFlags(rawValue: 1 << 5)
    public static let or = SecAccessControlCreateFlags(rawValue: 1 << 14)
    public static let and = SecAccessControlCreateFlags(rawValue: 1 << 15)
    public static let privateKeyUsage = SecAccessControlCreateFlags(rawValue: 1 << 30)
    public static let applicationPassword = SecAccessControlCreateFlags(rawValue: 1 << 31)
}
public func SecAccessControlCreateWithFlags(_ allocator: CFAllocator?, _ protection: CFTypeRef, _ flags: SecAccessControlCreateFlags, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecAccessControl? { SecAccessControl() }

public class SecKey {}
public class SecTrust {}
public class SecCertificate {}
public func SecKeyCreateRandomKey(_ parameters: CFDictionary, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> SecKey? { SecKey() }
public func SecKeyCopyPublicKey(_ key: SecKey) -> SecKey? { key }
public func SecKeyCopyExternalRepresentation(_ key: SecKey, _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?) -> CFData? { NSData() }
public func SecTrustCopyCertificateChain(_ trust: SecTrust) -> CFArray? { nil }
public func SecCertificateCopyData(_ certificate: SecCertificate) -> CFData { NSData() }
public func SecTrustEvaluateWithError(_ trust: SecTrust, _ error: UnsafeMutablePointer<CFError?>?) -> Bool { true }
extension URLProtectionSpace {
    public var serverTrust: SecTrust? { nil }
}
