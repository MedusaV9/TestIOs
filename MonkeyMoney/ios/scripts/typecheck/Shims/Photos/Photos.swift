// Photos stub.
import Foundation

public enum PHAuthorizationStatus: Int, Sendable { case notDetermined, restricted, denied, authorized, limited }
public enum PHAccessLevel: Int, Sendable { case addOnly = 1, readWrite }
open class PHPhotoLibrary: NSObject {
    public override init() { super.init() }
    open class func shared() -> PHPhotoLibrary { PHPhotoLibrary() }
    open class func authorizationStatus(for accessLevel: PHAccessLevel) -> PHAuthorizationStatus { .authorized }
    open class func requestAuthorization(for accessLevel: PHAccessLevel) async -> PHAuthorizationStatus { .authorized }
    open class func requestAuthorization(for accessLevel: PHAccessLevel, handler: @escaping (PHAuthorizationStatus) -> Void) {}
    open func performChanges(_ changeBlock: @escaping () -> Void) async throws {}
    open func performChanges(_ changeBlock: @escaping () -> Void, completionHandler: ((Bool, Error?) -> Void)? = nil) {}
}
open class PHAsset: NSObject {}
open class PHAssetChangeRequest: NSObject {
    open class func creationRequestForAsset(from image: AnyObject) -> PHAssetChangeRequest { PHAssetChangeRequest() }
    open class func creationRequestForAssetFromImage(atFileURL fileURL: URL) -> PHAssetChangeRequest? { PHAssetChangeRequest() }
    open class func creationRequestForAssetFromVideo(atFileURL fileURL: URL) -> PHAssetChangeRequest? { PHAssetChangeRequest() }
}
