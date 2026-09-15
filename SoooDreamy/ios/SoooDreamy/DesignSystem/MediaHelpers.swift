import AVFoundation
import Photos
import SwiftUI
import UIKit

/// Downscale a bitmap so the longest side is at most `maxDimension` device pixels.
enum ImageScaler {
    static func downscaled(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        let maxSide = max(pixelWidth, pixelHeight)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        guard maxSide > maxDimension else {
            guard image.scale != 1 else { return image }
            let size = CGSize(width: pixelWidth, height: pixelHeight)
            return UIGraphicsImageRenderer(size: size, format: format).image { _ in
                image.draw(in: CGRect(origin: .zero, size: size))
            }
        }
        let factor = maxDimension / maxSide
        let size = CGSize(width: floor(pixelWidth * factor), height: floor(pixelHeight * factor))
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}

/// Photos-library write helpers. UIKit callbacks need an Obj-C target that
/// stays alive until the save finishes.
enum PhotoLibrarySaver {
    static func saveImage(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        ImageSaveTarget.save(image, completion: completion)
    }

    static func saveVideo(path: String, completion: @escaping (Bool) -> Void) {
        VideoSaveTarget.save(path: path, completion: completion)
    }
}

private final class ImageSaveTarget: NSObject {
    private static var active: [ImageSaveTarget] = []
    private var completion: ((Bool) -> Void)?

    static func save(_ image: UIImage, completion: @escaping (Bool) -> Void) {
        let saver = ImageSaveTarget()
        saver.completion = completion
        active.append(saver)
        UIImageWriteToSavedPhotosAlbum(
            image, saver,
            #selector(ImageSaveTarget.image(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func image(_ image: UIImage,
                             didFinishSavingWithError error: Error?,
                             contextInfo: UnsafeRawPointer) {
        let ok = error == nil
        DispatchQueue.main.async {
            self.completion?(ok)
            Self.active.removeAll { $0 === self }
        }
    }
}

private final class VideoSaveTarget: NSObject {
    private static var active: [VideoSaveTarget] = []
    private var completion: ((Bool) -> Void)?

    static func save(path: String, completion: @escaping (Bool) -> Void) {
        guard UIVideoAtPathIsCompatibleWithSavedPhotosAlbum(path) else {
            completion(false)
            return
        }
        let saver = VideoSaveTarget()
        saver.completion = completion
        active.append(saver)
        UISaveVideoAtPathToSavedPhotosAlbum(
            path, saver,
            #selector(VideoSaveTarget.video(_:didFinishSavingWithError:contextInfo:)), nil)
    }

    @objc private func video(_ videoPath: String,
                             didFinishSavingWithError error: Error?,
                             contextInfo: UnsafeRawPointer) {
        let ok = error == nil
        DispatchQueue.main.async {
            self.completion?(ok)
            Self.active.removeAll { $0 === self }
        }
    }
}

/// Client-side compression: 720p H.264/MP4 via AVAssetExportSession keeps
/// uploads under the server's 100 MB cap. Also extracts dimensions, duration
/// and a poster frame (first ~0.5 s).
enum VideoTranscoder {
    struct Result {
        let data: Data
        let fileURL: URL
        let poster: UIImage?
        let width: Int?
        let height: Int?
        let duration: Double?
    }

    static func compress(sourceURL: URL) async throws -> Result {
        let asset = AVURLAsset(url: sourceURL)
        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("upload-\(UUID().uuidString).mp4")

        guard let session = AVAssetExportSession(asset: asset,
                                                 presetName: AVAssetExportPreset1280x720) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        session.shouldOptimizeForNetworkUse = true
        try await session.export(to: outURL, as: .mp4)

        let data = try Data(contentsOf: outURL)
        let exported = AVURLAsset(url: outURL)
        let seconds = (try? await exported.load(.duration).seconds) ?? nil

        var width: Int?
        var height: Int?
        if let track = try? await exported.loadTracks(withMediaType: .video).first,
           let loaded = try? await track.load(.naturalSize, .preferredTransform) {
            let rect = CGRect(origin: .zero, size: loaded.0).applying(loaded.1)
            width = Int(abs(rect.width).rounded())
            height = Int(abs(rect.height).rounded())
        }

        let generator = AVAssetImageGenerator(asset: exported)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 640, height: 640)
        let posterTime = CMTime(seconds: min(0.5, (seconds ?? 1) / 2), preferredTimescale: 600)
        let poster = (try? await generator.image(at: posterTime).image).map { UIImage(cgImage: $0) }

        return Result(data: data, fileURL: outURL, poster: poster,
                      width: width, height: height, duration: seconds)
    }
}
