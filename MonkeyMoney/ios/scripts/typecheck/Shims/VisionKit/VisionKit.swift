// VisionKit stub — DataScannerViewController (system barcode/text scanner).
@_exported import Foundation
@_exported import UIKit

/// Vision's barcode symbologies (VisionKit re-exports the ones it needs).
public struct VNBarcodeSymbology: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let qr = VNBarcodeSymbology(rawValue: "VNBarcodeSymbologyQR"), aztec = VNBarcodeSymbology(rawValue: "Aztec"), code128 = VNBarcodeSymbology(rawValue: "Code128"),
        code39 = VNBarcodeSymbology(rawValue: "Code39"), ean13 = VNBarcodeSymbology(rawValue: "EAN13"), ean8 = VNBarcodeSymbology(rawValue: "EAN8"), pdf417 = VNBarcodeSymbology(rawValue: "PDF417"),
        dataMatrix = VNBarcodeSymbology(rawValue: "DataMatrix"), upce = VNBarcodeSymbology(rawValue: "UPCE"), microQR = VNBarcodeSymbology(rawValue: "MicroQR")
}

public enum RecognizedItem: Identifiable, Sendable {
    public struct Bounds: Sendable { public var topLeft: CGPoint = .zero, topRight: CGPoint = .zero, bottomRight: CGPoint = .zero, bottomLeft: CGPoint = .zero }
    public struct Text: Sendable {
        public var transcript: String { "" }
        public var bounds: Bounds { Bounds() }
        public var id: UUID { UUID() }
    }
    public struct Barcode: Sendable {
        public var payloadStringValue: String? { nil }
        public var observation: AnyObject? { nil }
        public var bounds: Bounds { Bounds() }
        public var id: UUID { UUID() }
    }
    case text(RecognizedItem.Text)
    case barcode(RecognizedItem.Barcode)
    public var id: UUID { UUID() }
    public var bounds: Bounds { Bounds() }
}

@preconcurrency @MainActor public class DataScannerViewController: UIViewController {
    public enum RecognizedDataType: Hashable, Sendable {
        case barcodeType([VNBarcodeSymbology])
        case textType(String?, TextContentType?)
        public static func barcode(symbologies: [VNBarcodeSymbology] = []) -> RecognizedDataType { .barcodeType(symbologies) }
        public static func text(languages: [String] = [], textContentType: TextContentType? = nil) -> RecognizedDataType { .textType(languages.first, textContentType) }
    }
    public enum TextContentType: Hashable, Sendable { case URL, dateTimeDuration, emailAddress, flightNumber, fullStreetAddress, shipmentTrackingNumber, telephoneNumber, currency }
    public enum QualityLevel: Sendable { case balanced, fast, accurate }
    public enum ScanningUnavailable: Error, Sendable { case unsupported, cameraRestricted }

    public init(recognizedDataTypes: Set<RecognizedDataType>, qualityLevel: QualityLevel = .balanced, recognizesMultipleItems: Bool = false, isHighFrameRateTrackingEnabled: Bool = true, isPinchToZoomEnabled: Bool = true, isGuidanceEnabled: Bool = true, isHighlightingEnabled: Bool = false) { super.init() }
    public class var isSupported: Bool { true }
    public class var isAvailable: Bool { true }
    public class var supportedTextRecognitionLanguages: [String] { [] }
    public weak var delegate: (any DataScannerViewControllerDelegate)?
    public var isScanning: Bool { false }
    public var recognizedDataTypes: Set<RecognizedDataType> { [] }
    public var qualityLevel: QualityLevel { .balanced }
    public var recognizesMultipleItems: Bool { false }
    public var isHighFrameRateTrackingEnabled: Bool { true }
    public var isPinchToZoomEnabled: Bool { true }
    public var isGuidanceEnabled: Bool { true }
    public var isHighlightingEnabled: Bool { false }
    public var zoomFactor: Double = 1
    public var minZoomFactor: Double { 1 }
    public var maxZoomFactor: Double { 10 }
    public var regionOfInterest: CGRect?
    public var overlayContainerView: UIView { UIView() }
    public var recognizedItems: AsyncStream<[RecognizedItem]> { AsyncStream { $0.finish() } }
    public func startScanning() throws {}
    public func stopScanning() {}
    public func capturePhoto() async throws -> UIImage { UIImage() }
}

@preconcurrency @MainActor public protocol DataScannerViewControllerDelegate: AnyObject {
    func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem)
    func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem])
    func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable)
    func dataScanner(_ dataScanner: DataScannerViewController, didZoomTo zoomFactor: Double)
}
extension DataScannerViewControllerDelegate {
    public func dataScanner(_ dataScanner: DataScannerViewController, didTapOn item: RecognizedItem) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didUpdate updatedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didRemove removedItems: [RecognizedItem], allItems: [RecognizedItem]) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {}
    public func dataScanner(_ dataScanner: DataScannerViewController, didZoomTo zoomFactor: Double) {}
}
