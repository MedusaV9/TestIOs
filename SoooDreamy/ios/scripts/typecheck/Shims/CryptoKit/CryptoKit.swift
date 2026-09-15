// CryptoKit stub — hashing, HMAC, AES-GCM, symmetric keys.
import Foundation

public protocol Digest: Sequence, Hashable, CustomStringConvertible where Element == UInt8 {
    static var byteCount: Int { get }
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}
public protocol HashFunction {
    associatedtype Digest: CryptoKit.Digest
    static var blockByteCount: Int { get }
    init()
    mutating func update(bufferPointer: UnsafeRawBufferPointer)
    func finalize() -> Self.Digest
}
extension HashFunction {
    public static func hash<D: DataProtocol>(data: D) -> Self.Digest { var h = Self(); h.update(data: data); return h.finalize() }
    public mutating func update<D: DataProtocol>(data: D) { Data(data).withUnsafeBytes { update(bufferPointer: $0) } }
}
public struct _DigestImpl: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 32 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "digest" }
}
public struct SHA256: HashFunction {
    public typealias Digest = SHA256Digest
    public static var blockByteCount: Int { 64 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
    public func finalize() -> SHA256Digest { SHA256Digest(bytes: [UInt8](repeating: 0, count: 32)) }
}
public struct SHA256Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 32 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA256 digest" }
}
public struct SHA384: HashFunction {
    public typealias Digest = SHA384Digest
    public static var blockByteCount: Int { 128 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
    public func finalize() -> SHA384Digest { SHA384Digest(bytes: [UInt8](repeating: 0, count: 48)) }
}
public struct SHA384Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 48 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA384 digest" }
}
public struct SHA512: HashFunction {
    public typealias Digest = SHA512Digest
    public static var blockByteCount: Int { 128 }
    public init() {}
    public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
    public func finalize() -> SHA512Digest { SHA512Digest(bytes: [UInt8](repeating: 0, count: 64)) }
}
public struct SHA512Digest: Digest {
    let bytes: [UInt8]
    public static var byteCount: Int { 64 }
    public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    public var description: String { "SHA512 digest" }
}
public enum Insecure {
    public struct MD5: HashFunction {
        public typealias Digest = MD5Digest
        public static var blockByteCount: Int { 64 }
        public init() {}
        public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
        public func finalize() -> MD5Digest { MD5Digest(bytes: [UInt8](repeating: 0, count: 16)) }
    }
    public struct MD5Digest: Digest {
        let bytes: [UInt8]
        public static var byteCount: Int { 16 }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        public var description: String { "MD5 digest" }
    }
    public struct SHA1: HashFunction {
        public typealias Digest = SHA1Digest
        public static var blockByteCount: Int { 64 }
        public init() {}
        public mutating func update(bufferPointer: UnsafeRawBufferPointer) {}
        public func finalize() -> SHA1Digest { SHA1Digest(bytes: [UInt8](repeating: 0, count: 20)) }
    }
    public struct SHA1Digest: Digest {
        let bytes: [UInt8]
        public static var byteCount: Int { 20 }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        public var description: String { "SHA1 digest" }
    }
}

public struct SymmetricKeySize: Sendable {
    public let bitCount: Int
    public init(bitCount: Int) { self.bitCount = bitCount }
    public static let bits128 = SymmetricKeySize(bitCount: 128), bits192 = SymmetricKeySize(bitCount: 192), bits256 = SymmetricKeySize(bitCount: 256)
}
public protocol ContiguousBytes {
    func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R
}
extension Data: ContiguousBytes {}
extension Array: ContiguousBytes where Element == UInt8 {}
public struct SymmetricKey: ContiguousBytes, Hashable, Sendable {
    let data: Data
    public init(size: SymmetricKeySize) { data = Data(count: size.bitCount / 8) }
    public init<D: ContiguousBytes>(data: D) { self.data = data.withUnsafeBytes { Data($0) } }
    public var bitCount: Int { data.count * 8 }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try data.withUnsafeBytes(body) }
}
public struct HMAC<H: HashFunction> {
    public struct MAC: Sequence, ContiguousBytes, Hashable {
        let bytes: [UInt8]
        public var byteCount: Int { bytes.count }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    }
    public init(key: SymmetricKey) {}
    public mutating func update<D: DataProtocol>(data: D) {}
    public func finalize() -> MAC { MAC(bytes: [UInt8](repeating: 0, count: H.Digest.byteCount)) }
    public static func authenticationCode<D: DataProtocol>(for data: D, using key: SymmetricKey) -> MAC { MAC(bytes: [UInt8](repeating: 0, count: H.Digest.byteCount)) }
    public static func isValidAuthenticationCode<D: DataProtocol>(_ mac: MAC, authenticating data: D, using key: SymmetricKey) -> Bool { true }
    public static func isValidAuthenticationCode<C: ContiguousBytes, D: DataProtocol>(_ authenticationCode: C, authenticating authenticatedData: D, using key: SymmetricKey) -> Bool { true }
}
public struct HKDF<H: HashFunction> {
    public static func deriveKey<Salt: DataProtocol, Info: DataProtocol>(inputKeyMaterial: SymmetricKey, salt: Salt, info: Info, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
    public static func deriveKey<Info: DataProtocol>(inputKeyMaterial: SymmetricKey, info: Info, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
    public static func deriveKey<Salt: DataProtocol>(inputKeyMaterial: SymmetricKey, salt: Salt, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
    public static func deriveKey(inputKeyMaterial: SymmetricKey, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
}
public enum CryptoKitError: Error {
    case incorrectKeySize, incorrectParameterSize, authenticationFailure, underlyingCoreCryptoError(error: Int32), wrapFailure, unwrapFailure, invalidParameter
}
public enum AES {
    public enum GCM {
        public struct Nonce: ContiguousBytes, Sequence {
            let bytes: [UInt8]
            public init() { bytes = [UInt8](repeating: 0, count: 12) }
            public init<D: DataProtocol>(data: D) throws { bytes = Array(data) }
            public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
            public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
        }
        public struct SealedBox {
            public let nonce: Nonce
            public let ciphertext: Data
            public let tag: Data
            public var combined: Data? { nonce.withUnsafeBytes { Data($0) } + ciphertext + tag }
            public init<D: DataProtocol>(combined: D) throws { nonce = Nonce(); ciphertext = Data(combined); tag = Data() }
            public init<C: DataProtocol, T: DataProtocol>(nonce: Nonce, ciphertext: C, tag: T) throws { self.nonce = nonce; self.ciphertext = Data(ciphertext); self.tag = Data(tag) }
        }
        public static func seal<Plaintext: DataProtocol>(_ message: Plaintext, using key: SymmetricKey, nonce: Nonce? = nil) throws -> SealedBox { try SealedBox(nonce: nonce ?? Nonce(), ciphertext: Data(message), tag: Data(count: 16)) }
        public static func seal<Plaintext: DataProtocol, AuthenticatedData: DataProtocol>(_ message: Plaintext, using key: SymmetricKey, nonce: Nonce? = nil, authenticating authenticatedData: AuthenticatedData) throws -> SealedBox { try SealedBox(nonce: nonce ?? Nonce(), ciphertext: Data(message), tag: Data(count: 16)) }
        public static func open(_ sealedBox: SealedBox, using key: SymmetricKey) throws -> Data { sealedBox.ciphertext }
        public static func open<AuthenticatedData: DataProtocol>(_ sealedBox: SealedBox, using key: SymmetricKey, authenticating authenticatedData: AuthenticatedData) throws -> Data { sealedBox.ciphertext }
    }
}
public enum ChaChaPoly {
    public struct Nonce: ContiguousBytes, Sequence {
        let bytes: [UInt8]
        public init() { bytes = [UInt8](repeating: 0, count: 12) }
        public init<D: DataProtocol>(data: D) throws { bytes = Array(data) }
        public func makeIterator() -> IndexingIterator<[UInt8]> { bytes.makeIterator() }
        public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try bytes.withUnsafeBytes(body) }
    }
    public struct SealedBox {
        public let nonce: Nonce
        public let ciphertext: Data
        public let tag: Data
        public var combined: Data { ciphertext + tag }
        public init<D: DataProtocol>(combined: D) throws { nonce = Nonce(); ciphertext = Data(combined); tag = Data() }
        public init<C: DataProtocol, T: DataProtocol>(nonce: Nonce, ciphertext: C, tag: T) throws { self.nonce = nonce; self.ciphertext = Data(ciphertext); self.tag = Data(tag) }
    }
    public static func seal<Plaintext: DataProtocol>(_ message: Plaintext, using key: SymmetricKey, nonce: Nonce? = nil) throws -> SealedBox { try SealedBox(nonce: nonce ?? Nonce(), ciphertext: Data(message), tag: Data(count: 16)) }
    public static func open(_ sealedBox: SealedBox, using key: SymmetricKey) throws -> Data { sealedBox.ciphertext }
}
public enum Curve25519 {
    public enum KeyAgreement {
        public struct PrivateKey: Sendable {
            public init() {}
            public init<D: ContiguousBytes>(rawRepresentation: D) throws {}
            public var publicKey: PublicKey { PublicKey() }
            public var rawRepresentation: Data { Data(count: 32) }
            public func sharedSecretFromKeyAgreement(with publicKeyShare: PublicKey) throws -> SharedSecret { SharedSecret() }
        }
        public struct PublicKey: Sendable {
            public init() {}
            public init<D: ContiguousBytes>(rawRepresentation: D) throws {}
            public var rawRepresentation: Data { Data(count: 32) }
        }
    }
    public enum Signing {
        public struct PrivateKey: Sendable {
            public init() {}
            public init<D: ContiguousBytes>(rawRepresentation: D) throws {}
            public var publicKey: PublicKey { PublicKey() }
            public var rawRepresentation: Data { Data(count: 32) }
            public func signature<D: DataProtocol>(for data: D) throws -> Data { Data(count: 64) }
        }
        public struct PublicKey: Sendable {
            public init() {}
            public init<D: ContiguousBytes>(rawRepresentation: D) throws {}
            public var rawRepresentation: Data { Data(count: 32) }
            public func isValidSignature<S: DataProtocol, D: DataProtocol>(_ signature: S, for data: D) -> Bool { true }
        }
    }
}
public struct SharedSecret: ContiguousBytes, Sequence {
    public func makeIterator() -> IndexingIterator<[UInt8]> { [UInt8]().makeIterator() }
    public func withUnsafeBytes<R>(_ body: (UnsafeRawBufferPointer) throws -> R) rethrows -> R { try [UInt8]().withUnsafeBytes(body) }
    public func hkdfDerivedSymmetricKey<H: HashFunction, Salt: DataProtocol, SI: DataProtocol>(using hashFunction: H.Type, salt: Salt, sharedInfo: SI, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
    public func x963DerivedSymmetricKey<H: HashFunction, SI: DataProtocol>(using hashFunction: H.Type, sharedInfo: SI, outputByteCount: Int) -> SymmetricKey { SymmetricKey(size: .bits256) }
}
