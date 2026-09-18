// CloudKit stub — private database record round-trip used by the backup.
import Foundation

public enum CKAccountStatus: Int, Sendable { case couldNotDetermine, available, restricted, noAccount, temporarilyUnavailable }
public protocol CKRecordValueProtocol {}
extension NSData: CKRecordValueProtocol {}
extension NSDate: CKRecordValueProtocol {}
extension NSString: CKRecordValueProtocol {}
extension NSNumber: CKRecordValueProtocol {}
extension NSArray: CKRecordValueProtocol {}
extension Data: CKRecordValueProtocol {}
extension Date: CKRecordValueProtocol {}
extension String: CKRecordValueProtocol {}
extension Int: CKRecordValueProtocol {}
extension Int64: CKRecordValueProtocol {}
extension Double: CKRecordValueProtocol {}
extension Bool: CKRecordValueProtocol {}
extension Array: CKRecordValueProtocol where Element: CKRecordValueProtocol {}
extension CKAsset: CKRecordValueProtocol {}
extension CKRecord.Reference: CKRecordValueProtocol {}

open class CKRecordZone: NSObject {
    public init(zoneName: String) { super.init() }
    public init(zoneID: CKRecordZone.ID) { super.init() }
    open var zoneID: CKRecordZone.ID { CKRecordZone.ID(zoneName: "_defaultZone") }
    open class func `default`() -> CKRecordZone { CKRecordZone(zoneName: "_defaultZone") }
    open class ID: NSObject {
        public init(zoneName: String = "_defaultZone", ownerName: String = "__defaultOwner__") { super.init() }
        open var zoneName: String { "_defaultZone" }
        open var ownerName: String { "__defaultOwner__" }
        public static let `default` = ID()
    }
}
open class CKRecord: NSObject {
    public typealias RecordType = String
    public typealias FieldKey = String
    open class ID: NSObject {
        public init(recordName: String) { self.recordName = recordName; super.init() }
        public init(recordName: String, zoneID: CKRecordZone.ID) { self.recordName = recordName; super.init() }
        public let recordName: String
        open var zoneID: CKRecordZone.ID { CKRecordZone.ID() }
    }
    open class Reference: NSObject {
        public enum Action: UInt, Sendable { case none, deleteSelf }
        public init(recordID: CKRecord.ID, action: Action) { super.init() }
        public init(record: CKRecord, action: Action) { super.init() }
        open var recordID: CKRecord.ID { CKRecord.ID(recordName: "") }
    }
    public init(recordType: RecordType) { self.recordType = recordType; recordID = ID(recordName: UUID().uuidString); super.init() }
    public init(recordType: RecordType, recordID: CKRecord.ID) { self.recordType = recordType; self.recordID = recordID; super.init() }
    public let recordType: RecordType
    public let recordID: CKRecord.ID
    open var recordChangeTag: String? { nil }
    open var creationDate: Date? { nil }
    open var modificationDate: Date? { nil }
    private var storage: [String: any CKRecordValueProtocol] = [:]
    open subscript(key: FieldKey) -> (any CKRecordValueProtocol)? {
        get { storage[key] }
        set { storage[key] = newValue }
    }
    open subscript<T: CKRecordValueProtocol>(key: FieldKey) -> T? {
        get { storage[key] as? T }
        set { storage[key] = newValue }
    }
    open func allKeys() -> [FieldKey] { Array(storage.keys) }
    open func setValue(_ value: Any?, forKey key: String) {}
    open func value(forKey key: String) -> Any? { storage[key] }
    open func encodeSystemFields(with coder: NSCoder) {}
}
open class CKAsset: NSObject {
    public init(fileURL: URL) { self.fileURL = fileURL; super.init() }
    public let fileURL: URL?
}
public struct CKError: Error, Equatable {
    public enum Code: Int, Sendable {
        case internalError = 1, partialFailure, networkUnavailable, networkFailure, badContainer, serviceUnavailable, requestRateLimited, missingEntitlement, notAuthenticated, permissionFailure, unknownItem, invalidArguments, resultsTruncated, serverRecordChanged, serverRejectedRequest, assetFileNotFound, assetFileModified, incompatibleVersion, constraintViolation, operationCancelled, changeTokenExpired, batchRequestFailed, zoneBusy, badDatabase, quotaExceeded, zoneNotFound, limitExceeded, userDeletedZone, tooManyParticipants, alreadyShared, referenceViolation, managedAccountRestricted, participantMayNeedVerification, serverResponseLost, assetNotAvailable, accountTemporarilyUnavailable
    }
    public let code: Code
    public init(_ code: Code, userInfo: [String: Any] = [:]) { self.code = code }
    public var errorCode: Int { code.rawValue }
    public var localizedDescription: String { "CKError \(code)" }
    public var retryAfterSeconds: TimeInterval? { nil }
    public var partialErrorsByItemID: [AnyHashable: Error]? { nil }
    public var serverRecord: CKRecord? { nil }
    public var clientRecord: CKRecord? { nil }
    public static var errorDomain: String { "CKErrorDomain" }
}
public enum CKDatabase {
    public enum Scope: Int, Sendable { case `public` = 1, `private`, shared }
}
open class CKDatabaseImpl: NSObject {
    public override init() { super.init() }
    open var databaseScope: CKDatabase.Scope { .private }
    open func record(for recordID: CKRecord.ID) async throws -> CKRecord { throw CKError(.unknownItem) }
    open func records(for ids: [CKRecord.ID], desiredKeys: [CKRecord.FieldKey]? = nil) async throws -> [CKRecord.ID: Result<CKRecord, Error>] { [:] }
    open func save(_ record: CKRecord) async throws -> CKRecord { record }
    open func deleteRecord(withID recordID: CKRecord.ID) async throws -> CKRecord.ID { recordID }
    open func modifyRecords(saving recordsToSave: [CKRecord], deleting recordIDsToDelete: [CKRecord.ID], savePolicy: CKModifyRecordsOperation.RecordSavePolicy = .ifServerRecordUnchanged, atomically: Bool = true) async throws -> (saveResults: [CKRecord.ID: Result<CKRecord, Error>], deleteResults: [CKRecord.ID: Result<Void, Error>]) { ([:], [:]) }
    open func records(matching query: CKQuery, inZoneWith zoneID: CKRecordZone.ID? = nil, desiredKeys: [CKRecord.FieldKey]? = nil, resultsLimit: Int = 100) async throws -> (matchResults: [(CKRecord.ID, Result<CKRecord, Error>)], queryCursor: CKQueryOperation.Cursor?) { ([], nil) }
    open func fetch(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord?, Error?) -> Void) {}
    open func save(_ record: CKRecord, completionHandler: @escaping (CKRecord?, Error?) -> Void) {}
    open func delete(withRecordID recordID: CKRecord.ID, completionHandler: @escaping (CKRecord.ID?, Error?) -> Void) {}
    open func add(_ operation: CKDatabaseOperation) {}
    open func saveZone(_ zone: CKRecordZone) async throws -> CKRecordZone { zone }
}
open class CKOperation: NSObject { public override init() { super.init() }; open var qualityOfService: QualityOfService = .default }
open class CKDatabaseOperation: CKOperation { open var database: CKDatabaseImpl? }
open class CKModifyRecordsOperation: CKDatabaseOperation {
    public enum RecordSavePolicy: Int, Sendable { case ifServerRecordUnchanged, changedKeys, allKeys }
    public init(recordsToSave: [CKRecord]?, recordIDsToDelete: [CKRecord.ID]?) { super.init() }
    open var savePolicy: RecordSavePolicy = .ifServerRecordUnchanged
    open var modifyRecordsResultBlock: ((Result<Void, Error>) -> Void)?
}
open class CKQueryOperation: CKDatabaseOperation {
    open class Cursor: NSObject {}
}
open class CKQuery: NSObject {
    public init(recordType: CKRecord.RecordType, predicate: NSPredicate) { super.init() }
    open var sortDescriptors: [NSSortDescriptor]?
}
open class CKContainer: NSObject {
    public init(identifier containerIdentifier: String) { super.init() }
    open class func `default`() -> CKContainer { CKContainer(identifier: "iCloud.default") }
    open var containerIdentifier: String? { nil }
    open var privateCloudDatabase: CKDatabaseImpl { CKDatabaseImpl() }
    open var publicCloudDatabase: CKDatabaseImpl { CKDatabaseImpl() }
    open var sharedCloudDatabase: CKDatabaseImpl { CKDatabaseImpl() }
    open func database(with databaseScope: CKDatabase.Scope) -> CKDatabaseImpl { CKDatabaseImpl() }
    open func accountStatus() async throws -> CKAccountStatus { .available }
    open func accountStatus(completionHandler: @escaping (CKAccountStatus, Error?) -> Void) {}
    open func userRecordID() async throws -> CKRecord.ID { CKRecord.ID(recordName: "_user") }
    public static let accountChangedNotification = Notification.Name("CKAccountChanged")
}
