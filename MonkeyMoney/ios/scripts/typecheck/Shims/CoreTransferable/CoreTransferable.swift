import Foundation
@_exported import UniformTypeIdentifiers

public protocol TransferRepresentation<Item>: Sendable {
    associatedtype Item: Transferable
    associatedtype Body: TransferRepresentation
    var body: Body { get }
}

public protocol Transferable {
    associatedtype Representation: TransferRepresentation
    @TransferRepresentationBuilder<Self> static var transferRepresentation: Representation { get }
}

@resultBuilder
public struct TransferRepresentationBuilder<Item: Transferable> {
    public static func buildBlock<C: TransferRepresentation>(_ content: C) -> C where C.Item == Item { content }
    public static func buildBlock<C0: TransferRepresentation, C1: TransferRepresentation>(_ c0: C0, _ c1: C1) -> _CombinedRepresentation<Item> where C0.Item == Item, C1.Item == Item { _CombinedRepresentation() }
    public static func buildBlock<C0: TransferRepresentation, C1: TransferRepresentation, C2: TransferRepresentation>(_ c0: C0, _ c1: C1, _ c2: C2) -> _CombinedRepresentation<Item> where C0.Item == Item, C1.Item == Item, C2.Item == Item { _CombinedRepresentation() }
    public static func buildOptional<C: TransferRepresentation>(_ c: C?) -> C? where C.Item == Item { c }
}

public struct _CombinedRepresentation<Item: Transferable>: TransferRepresentation {
    public typealias Body = Never
    public var body: Never { fatalError() }
}
extension Optional: TransferRepresentation where Wrapped: TransferRepresentation {
    public typealias Item = Wrapped.Item
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Never: TransferRepresentation {
    public typealias Item = _NeverTransferable
    public var body: Never { fatalError() }
}
public struct _NeverTransferable: Transferable {
    public static var transferRepresentation: Never { return fatalError() }
}

public struct SentTransferredFile: Sendable {
    public let file: URL
    public let allowAccessingOriginalFile: Bool
    public init(_ file: URL, allowAccessingOriginalFile: Bool = false) { self.file = file; self.allowAccessingOriginalFile = allowAccessingOriginalFile }
}
public struct ReceivedTransferredFile: Sendable {
    public let file: URL
    public let isOriginalFile: Bool
    public init(file: URL, isOriginalFile: Bool = false) { self.file = file; self.isOriginalFile = isOriginalFile }
}

public struct FileRepresentation<Item: Transferable>: TransferRepresentation {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init(contentType: UTType, shouldAttemptToOpenInPlace: Bool = false,
                exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile,
                importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) {}
    public init(exportedContentType: UTType, shouldAllowToOpenInPlace: Bool = false,
                exporting: @escaping @Sendable (Item) async throws -> SentTransferredFile) {}
    public init(importedContentType: UTType, shouldAttemptToOpenInPlace: Bool = false,
                importing: @escaping @Sendable (ReceivedTransferredFile) async throws -> Item) {}
    public func suggestedFileName(_ name: String?) -> FileRepresentation<Item> { self }
    public func suggestedFileName(_ name: @escaping (Item) -> String?) -> FileRepresentation<Item> { self }
}

public struct DataRepresentation<Item: Transferable>: TransferRepresentation {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init(contentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data,
                importing: @escaping @Sendable (Data) async throws -> Item) {}
    public init(exportedContentType: UTType, exporting: @escaping @Sendable (Item) async throws -> Data) {}
    public init(importedContentType: UTType, importing: @escaping @Sendable (Data) async throws -> Item) {}
    public func suggestedFileName(_ name: String?) -> DataRepresentation<Item> { self }
}

public struct CodableRepresentation<Item: Transferable & Codable, Encoder: TopLevelEncoder, Decoder: TopLevelDecoder>: TransferRepresentation where Encoder.Output == Data, Decoder.Input == Data {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init(contentType: UTType, encoder: Encoder, decoder: Decoder) {}
}
extension CodableRepresentation where Encoder == JSONEncoder, Decoder == JSONDecoder {
    public init(contentType: UTType) {}
}
public protocol TopLevelEncoder { associatedtype Output; func encode<T: Encodable>(_ value: T) throws -> Output }
public protocol TopLevelDecoder { associatedtype Input; func decode<T: Decodable>(_ type: T.Type, from: Input) throws -> T }
extension JSONEncoder: TopLevelEncoder {}
extension JSONDecoder: TopLevelDecoder {}

public struct ProxyRepresentation<Item: Transferable, ProxyRepresentation: Transferable>: TransferRepresentation {
    public typealias Body = Never
    public var body: Never { fatalError() }
    public init(exporting: @escaping @Sendable (Item) async throws -> ProxyRepresentation,
                importing: @escaping @Sendable (ProxyRepresentation) async throws -> Item) {}
    public init(exporting: @escaping @Sendable (Item) async throws -> ProxyRepresentation) {}
    public init(importing: @escaping @Sendable (ProxyRepresentation) async throws -> Item) {}
}

extension Transferable {
    public func exported(as contentType: UTType) async throws -> Data { Data() }
}

extension Data: Transferable {
    public static var transferRepresentation: DataRepresentation<Data> { DataRepresentation(contentType: .data, exporting: { $0 }, importing: { $0 }) }
}
extension String: Transferable {
    public static var transferRepresentation: DataRepresentation<String> { DataRepresentation(contentType: .plainText, exporting: { Data($0.utf8) }, importing: { String(decoding: $0, as: UTF8.self) }) }
}
extension URL: Transferable {
    public static var transferRepresentation: DataRepresentation<URL> { DataRepresentation(contentType: .url, exporting: { Data($0.absoluteString.utf8) }, importing: { URL(string: String(decoding: $0, as: UTF8.self))! }) }
}
