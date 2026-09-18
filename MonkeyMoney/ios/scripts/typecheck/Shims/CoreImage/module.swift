// CoreImage stub — Swift overlay on top of the clang module map in ./clang
// (which exists only so `import CoreImage.CIFilterBuiltins` resolves).
@_exported import Foundation
@_exported import UIKit

open class CIImage: NSObject {
    public override init() { super.init() }
    public init?(image: UIImage) { super.init() }
    public init(cgImage: CGImage) { super.init() }
    public init?(data: Data) { super.init() }
    public init?(contentsOf url: URL) { super.init() }
    public init(color: CIColor) { super.init() }
    open var extent: CGRect { .zero }
    open var cgImage: CGImage? { nil }
    open func transformed(by matrix: CGAffineTransform) -> CIImage { self }
    open func cropped(to rect: CGRect) -> CIImage { self }
    open func applyingFilter(_ filterName: String, parameters params: [String: Any]) -> CIImage { self }
    open func applyingFilter(_ filterName: String) -> CIImage { self }
    open func composited(over dest: CIImage) -> CIImage { self }
    open func oriented(_ orientation: CGImagePropertyOrientation) -> CIImage { self }
    open func clampedToExtent() -> CIImage { self }
    open func settingAlphaOne(in extent: CGRect) -> CIImage { self }
    open class var empty: CIImage { CIImage() }
}
public enum CGImagePropertyOrientation: UInt32 { case up = 1, upMirrored, down, downMirrored, leftMirrored, right, rightMirrored, left }
open class CIColor: NSObject {
    public init(red r: CGFloat, green g: CGFloat, blue b: CGFloat) { super.init() }
    public init(red r: CGFloat, green g: CGFloat, blue b: CGFloat, alpha a: CGFloat) { super.init() }
    public init(color: UIColor) { super.init() }
    open class var black: CIColor { CIColor(red: 0, green: 0, blue: 0) }
    open class var white: CIColor { CIColor(red: 1, green: 1, blue: 1) }
    open class var clear: CIColor { CIColor(red: 0, green: 0, blue: 0, alpha: 0) }
}
open class CIContext: NSObject {
    public override init() { super.init() }
    public init(options: [CIContextOption: Any]?) { super.init() }
    open func createCGImage(_ image: CIImage, from fromRect: CGRect) -> CGImage? { CGImage() }
    open func jpegRepresentation(of image: CIImage, colorSpace: CGColorSpace, options: [CIImageRepresentationOption: Any] = [:]) -> Data? { nil }
    open func pngRepresentation(of image: CIImage, format: CIFormat, colorSpace: CGColorSpace, options: [CIImageRepresentationOption: Any] = [:]) -> Data? { nil }
}
public struct CIContextOption: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }; public static let useSoftwareRenderer = CIContextOption(rawValue: "software"), cacheIntermediates = CIContextOption(rawValue: "cache") }
public struct CIImageRepresentationOption: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue } }
public struct CIFormat: RawRepresentable, Hashable { public let rawValue: Int32; public init(rawValue: Int32) { self.rawValue = rawValue }; public static let RGBA8 = CIFormat(rawValue: 24), ARGB8 = CIFormat(rawValue: 23) }
public let kCIInputImageKey = "inputImage"
public let kCIInputScaleKey = "inputScale"
public let kCIInputRadiusKey = "inputRadius"
public let kCIInputIntensityKey = "inputIntensity"
public let kCIOutputImageKey = "outputImage"
open class CIFilter: NSObject {
    public override init() { super.init() }
    public convenience init?(name: String) { self.init() }
    public convenience init?(name: String, parameters: [String: Any]?) { self.init() }
    open var outputImage: CIImage? { nil }
    open var name: String { "" }
    open var inputKeys: [String] { [] }
    open func setValue(_ value: Any?, forKey key: String) {}
    open func value(forKey key: String) -> Any? { nil }
    open func setDefaults() {}
    // CIFilterBuiltins
    open class func qrCodeGenerator() -> CIFilter & CIQRCodeGenerator { CIQRCodeGeneratorFilter() }
    open class func gaussianBlur() -> CIFilter & CIGaussianBlur { CIGaussianBlurFilter() }
    open class func colorControls() -> CIFilter & CIColorControls { CIColorControlsFilter() }
    open class func sepiaTone() -> CIFilter & CISepiaTone { CISepiaToneFilter() }
    open class func photoEffectNoir() -> CIFilter & CIPhotoEffect { CIPhotoEffectFilter() }
    open class func photoEffectMono() -> CIFilter & CIPhotoEffect { CIPhotoEffectFilter() }
    open class func pixellate() -> CIFilter & CIPixellate { CIPixellateFilter() }
}
public protocol CIFilterProtocol: AnyObject { var outputImage: CIImage? { get } }
public protocol CIQRCodeGenerator: CIFilterProtocol { var message: Data { get set }; var correctionLevel: String { get set } }
public protocol CIGaussianBlur: CIFilterProtocol { var inputImage: CIImage? { get set }; var radius: Float { get set } }
public protocol CIColorControls: CIFilterProtocol { var inputImage: CIImage? { get set }; var saturation: Float { get set }; var brightness: Float { get set }; var contrast: Float { get set } }
public protocol CISepiaTone: CIFilterProtocol { var inputImage: CIImage? { get set }; var intensity: Float { get set } }
public protocol CIPhotoEffect: CIFilterProtocol { var inputImage: CIImage? { get set } }
public protocol CIPixellate: CIFilterProtocol { var inputImage: CIImage? { get set }; var center: CGPoint { get set }; var scale: Float { get set } }
final class CIQRCodeGeneratorFilter: CIFilter, CIQRCodeGenerator { var message = Data(); var correctionLevel = "M" }
final class CIGaussianBlurFilter: CIFilter, CIGaussianBlur { var inputImage: CIImage?; var radius: Float = 10 }
final class CIColorControlsFilter: CIFilter, CIColorControls { var inputImage: CIImage?; var saturation: Float = 1; var brightness: Float = 0; var contrast: Float = 1 }
final class CISepiaToneFilter: CIFilter, CISepiaTone { var inputImage: CIImage?; var intensity: Float = 1 }
final class CIPhotoEffectFilter: CIFilter, CIPhotoEffect { var inputImage: CIImage? }
final class CIPixellateFilter: CIFilter, CIPixellate { var inputImage: CIImage?; var center: CGPoint = .zero; var scale: Float = 8 }
