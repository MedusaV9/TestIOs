// ImageIO stub — thumbnail creation from image data.
@_exported import Foundation
@_exported import UIKit
@_exported import Security

public class CGImageSource {}
public class CGImageDestination {}
public typealias CGImageSourceStatus = Int32
public func CGImageSourceCreateWithData(_ data: CFData, _ options: CFDictionary?) -> CGImageSource? { CGImageSource() }
public func CGImageSourceCreateWithURL(_ url: NSURL, _ options: CFDictionary?) -> CGImageSource? { CGImageSource() }
public func CGImageSourceCreateThumbnailAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { CGImage() }
public func CGImageSourceCreateImageAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CGImage? { CGImage() }
public func CGImageSourceGetCount(_ isrc: CGImageSource) -> Int { 1 }
public func CGImageSourceCopyPropertiesAtIndex(_ isrc: CGImageSource, _ index: Int, _ options: CFDictionary?) -> CFDictionary? { nil }
public func CGImageSourceGetType(_ isrc: CGImageSource) -> CFString? { nil }
public func CGImageDestinationCreateWithData(_ data: NSMutableData, _ type: CFString, _ count: Int, _ options: CFDictionary?) -> CGImageDestination? { CGImageDestination() }
public func CGImageDestinationAddImage(_ idst: CGImageDestination, _ image: CGImage, _ properties: CFDictionary?) {}
public func CGImageDestinationFinalize(_ idst: CGImageDestination) -> Bool { true }
public let kCGImageSourceCreateThumbnailFromImageAlways: CFString = "kCGImageSourceCreateThumbnailFromImageAlways"
public let kCGImageSourceCreateThumbnailFromImageIfAbsent: CFString = "kCGImageSourceCreateThumbnailFromImageIfAbsent"
public let kCGImageSourceCreateThumbnailWithTransform: CFString = "kCGImageSourceCreateThumbnailWithTransform"
public let kCGImageSourceThumbnailMaxPixelSize: CFString = "kCGImageSourceThumbnailMaxPixelSize"
public let kCGImageSourceShouldCache: CFString = "kCGImageSourceShouldCache"
public let kCGImageSourceShouldCacheImmediately: CFString = "kCGImageSourceShouldCacheImmediately"
public let kCGImageSourceShouldAllowFloat: CFString = "kCGImageSourceShouldAllowFloat"
public let kCGImagePropertyPixelWidth: CFString = "PixelWidth"
public let kCGImagePropertyPixelHeight: CFString = "PixelHeight"
public let kCGImagePropertyOrientation: CFString = "Orientation"
public let kCGImageDestinationLossyCompressionQuality: CFString = "kCGImageDestinationLossyCompressionQuality"
