// AVKit stub — VideoPlayer.
@_exported import Foundation
@_exported import SwiftUI
@_exported import AVFoundation

public struct VideoPlayer<VideoOverlay: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(player: AVPlayer?, @ViewBuilder videoOverlay: () -> VideoOverlay) {}
}
extension VideoPlayer where VideoOverlay == EmptyView {
    public init(player: AVPlayer?) {}
}
@preconcurrency @MainActor open class AVPlayerViewController: UIViewController {
    public override init() { super.init() }
    open var player: AVPlayer?
    open var showsPlaybackControls: Bool = true
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    open var allowsPictureInPicturePlayback: Bool = true
    open var entersFullScreenWhenPlaybackBegins: Bool = false
    open var exitsFullScreenWhenPlaybackEnds: Bool = false
}
