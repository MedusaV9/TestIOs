// CommonCrypto stub — PBKDF2 entry point used by VaultCrypto.
import Foundation

public typealias CCPBKDFAlgorithm = UInt32
public typealias CCPseudoRandomAlgorithm = UInt32
public typealias CCCryptorStatus = Int32
public let kCCPBKDF2: Int32 = 2
public let kCCPRFHmacAlgSHA1: Int32 = 1
public let kCCPRFHmacAlgSHA224: Int32 = 2
public let kCCPRFHmacAlgSHA256: Int32 = 3
public let kCCPRFHmacAlgSHA384: Int32 = 4
public let kCCPRFHmacAlgSHA512: Int32 = 5
public let kCCSuccess: Int32 = 0
public let kCCParamError: Int32 = -4300
public let kCCBufferTooSmall: Int32 = -4301
public let kCCMemoryFailure: Int32 = -4302
public let kCCAlignmentError: Int32 = -4303
public let kCCDecodeError: Int32 = -4304
public let kCCUnimplemented: Int32 = -4305
public let CC_SHA256_DIGEST_LENGTH: Int32 = 32

public func CCKeyDerivationPBKDF(_ algorithm: CCPBKDFAlgorithm, _ password: UnsafePointer<Int8>?, _ passwordLen: Int,
                                 _ salt: UnsafePointer<UInt8>?, _ saltLen: Int, _ prf: CCPseudoRandomAlgorithm,
                                 _ rounds: UInt32, _ derivedKey: UnsafeMutablePointer<UInt8>?, _ derivedKeyLen: Int) -> Int32 { 0 }
public func CCCalibratePBKDF(_ algorithm: CCPBKDFAlgorithm, _ passwordLen: Int, _ saltLen: Int, _ prf: CCPseudoRandomAlgorithm, _ derivedKeyLen: Int, _ msec: UInt32) -> UInt32 { 1 }
public func CC_SHA256(_ data: UnsafeRawPointer?, _ len: UInt32, _ md: UnsafeMutablePointer<UInt8>?) -> UnsafeMutablePointer<UInt8>? { md }
