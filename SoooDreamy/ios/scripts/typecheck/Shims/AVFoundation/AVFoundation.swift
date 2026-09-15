// AVFoundation + CoreMedia stub — audio session, players, recorder, engine,
// capture (QR scanner), assets, export.
@_exported import Foundation
@_exported import UIKit

// MARK: CoreMedia

public struct CMTime: Equatable, Hashable, Sendable {
    public var value: Int64
    public var timescale: Int32
    public init() { value = 0; timescale = 1 }
    public init(value: Int64, timescale: Int32) { self.value = value; self.timescale = timescale }
    public init(seconds: Double, preferredTimescale: Int32) { value = Int64(seconds * Double(preferredTimescale)); timescale = preferredTimescale }
    public var seconds: Double { timescale == 0 ? 0 : Double(value) / Double(timescale) }
    public var isValid: Bool { true }
    public var isIndefinite: Bool { false }
    public var isNumeric: Bool { true }
    public static let zero = CMTime(), invalid = CMTime(), indefinite = CMTime(), positiveInfinity = CMTime()
    public static func + (lhs: CMTime, rhs: CMTime) -> CMTime { lhs }
    public static func - (lhs: CMTime, rhs: CMTime) -> CMTime { lhs }
}
public func CMTimeGetSeconds(_ time: CMTime) -> Double { time.seconds }
public func CMTimeMake(value: Int64, timescale: Int32) -> CMTime { CMTime(value: value, timescale: timescale) }
public func CMTimeMakeWithSeconds(_ seconds: Double, preferredTimescale: Int32) -> CMTime { CMTime(seconds: seconds, preferredTimescale: preferredTimescale) }
public struct CMTimeRange: Equatable, Sendable {
    public var start: CMTime, duration: CMTime
    public init(start: CMTime, duration: CMTime) { self.start = start; self.duration = duration }
    public init(start: CMTime, end: CMTime) { self.start = start; duration = end }
    public static let zero = CMTimeRange(start: .zero, duration: .zero)
}

// MARK: Audio session

public let AVFormatIDKey = "AVFormatIDKey"
public let AVSampleRateKey = "AVSampleRateKey"
public let AVNumberOfChannelsKey = "AVNumberOfChannelsKey"
public let AVEncoderAudioQualityKey = "AVEncoderAudioQualityKey"
public let AVEncoderBitRateKey = "AVEncoderBitRateKey"
public let AVLinearPCMBitDepthKey = "AVLinearPCMBitDepthKey"
public let kAudioFormatMPEG4AAC: UInt32 = 0x61616320
public let kAudioFormatLinearPCM: UInt32 = 0x6C70636D
public let kAudioFormatAppleLossless: UInt32 = 0x616C6163
public enum AVAudioQuality: Int { case min = 0, low = 0x20, medium = 0x40, high = 0x60, max = 0x7F }
public typealias AVAudioFrameCount = UInt32
public typealias AVAudioFramePosition = Int64
public typealias AVAudioChannelCount = UInt32

open class AVAudioSession: NSObject {
    public override init() { super.init() }
    open class func sharedInstance() -> AVAudioSession { AVAudioSession() }
    public struct Category: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let ambient = Category(rawValue: "ambient"), soloAmbient = Category(rawValue: "soloAmbient"), playback = Category(rawValue: "playback"), record = Category(rawValue: "record"), playAndRecord = Category(rawValue: "playAndRecord"), multiRoute = Category(rawValue: "multiRoute") }
    public struct Mode: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let `default` = Mode(rawValue: "default"), voiceChat = Mode(rawValue: "voiceChat"), videoChat = Mode(rawValue: "videoChat"), spokenAudio = Mode(rawValue: "spokenAudio"), measurement = Mode(rawValue: "measurement"), moviePlayback = Mode(rawValue: "moviePlayback"), videoRecording = Mode(rawValue: "videoRecording") }
    public struct CategoryOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }
        public static let mixWithOthers = CategoryOptions(rawValue: 1), duckOthers = CategoryOptions(rawValue: 2), allowBluetooth = CategoryOptions(rawValue: 4), defaultToSpeaker = CategoryOptions(rawValue: 8), interruptSpokenAudioAndMixWithOthers = CategoryOptions(rawValue: 0x11), allowBluetoothA2DP = CategoryOptions(rawValue: 0x20), allowAirPlay = CategoryOptions(rawValue: 0x40), allowBluetoothHFP = CategoryOptions(rawValue: 4) }
    public struct SetActiveOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let notifyOthersOnDeactivation = SetActiveOptions(rawValue: 1) }
    public enum RecordPermission: Int { case undetermined = 1970168948, denied = 1684369017, granted = 1735552628 }
    public enum InterruptionType: UInt { case began = 1, ended = 0 }
    public struct InterruptionOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let shouldResume = InterruptionOptions(rawValue: 1) }
    public enum RouteChangeReason: UInt { case unknown, newDeviceAvailable, oldDeviceUnavailable, categoryChange, override, wakeFromSleep = 6, noSuitableRouteForCategory, routeConfigurationChange }
    public enum PortOverride: UInt { case none = 0, speaker = 1936747378 }
    open var category: Category { .ambient }
    open var categoryOptions: CategoryOptions { [] }
    open var mode: Mode { .default }
    open var outputVolume: Float { 1 }
    open var isOtherAudioPlaying: Bool { false }
    open var secondaryAudioShouldBeSilencedHint: Bool { false }
    open var recordPermission: RecordPermission { .granted }
    open var sampleRate: Double { 44100 }
    open var outputLatency: TimeInterval { 0 }
    open var currentRoute: AVAudioSessionRouteDescription { AVAudioSessionRouteDescription() }
    open func setCategory(_ category: Category) throws {}
    open func setCategory(_ category: Category, options: CategoryOptions) throws {}
    open func setCategory(_ category: Category, mode: Mode, options: CategoryOptions) throws {}
    open func setCategory(_ category: Category, mode: Mode, policy: RouteSharingPolicy, options: CategoryOptions) throws {}
    open func setMode(_ mode: Mode) throws {}
    open func setActive(_ active: Bool) throws {}
    open func setActive(_ active: Bool, options: SetActiveOptions) throws {}
    open func overrideOutputAudioPort(_ portOverride: PortOverride) throws {}
    open func requestRecordPermission(_ response: @escaping (Bool) -> Void) {}
    open func setPreferredSampleRate(_ sampleRate: Double) throws {}
    open func setPreferredIOBufferDuration(_ duration: TimeInterval) throws {}
    public enum RouteSharingPolicy: UInt { case `default`, longFormAudio, independent, longFormVideo }
    public static let interruptionNotification = Notification.Name("AVAudioSessionInterruption")
    public static let routeChangeNotification = Notification.Name("AVAudioSessionRouteChange")
    public static let mediaServicesWereResetNotification = Notification.Name("AVAudioSessionMediaServicesWereReset")
    public static let interruptionTypeKey = "AVAudioSessionInterruptionTypeKey"
    public static let interruptionOptionKey = "AVAudioSessionInterruptionOptionKey"
    public static let routeChangeReasonKey = "AVAudioSessionRouteChangeReasonKey"
}
open class AVAudioSessionRouteDescription: NSObject { public override init() { super.init() }; open var outputs: [AVAudioSessionPortDescription] { [] }; open var inputs: [AVAudioSessionPortDescription] { [] } }
open class AVAudioSessionPortDescription: NSObject { public override init() { super.init() }; open var portType: AVAudioSession.Port { .builtInSpeaker }; open var portName: String { "" } }
extension AVAudioSession { public struct Port: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
    public static let builtInSpeaker = Port(rawValue: "Speaker"), builtInReceiver = Port(rawValue: "Receiver"), headphones = Port(rawValue: "Headphones"), bluetoothA2DP = Port(rawValue: "BluetoothA2DPOutput"), bluetoothHFP = Port(rawValue: "BluetoothHFP"), airPlay = Port(rawValue: "AirPlay"), builtInMic = Port(rawValue: "MicrophoneBuiltIn") } }

open class AVAudioApplication: NSObject {
    public override init() { super.init() }
    open class var shared: AVAudioApplication { AVAudioApplication() }
    public enum recordPermission: Int { case undetermined, denied, granted }
    open var recordPermission: AVAudioApplication.recordPermission { .granted }
    open class func requestRecordPermission() async -> Bool { true }
    open class func requestRecordPermission(completionHandler response: @escaping (Bool) -> Void) {}
}

// MARK: Players & recorder

public protocol AVAudioPlayerDelegate: NSObjectProtocol {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool)
    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?)
}
extension AVAudioPlayerDelegate {
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {}
    public func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {}
}
open class AVAudioPlayer: NSObject {
    public init(contentsOf url: URL) throws { super.init() }
    public init(data: Data) throws { super.init() }
    public init(contentsOf url: URL, fileTypeHint utiString: String?) throws { super.init() }
    open weak var delegate: (any AVAudioPlayerDelegate)?
    open var isPlaying: Bool { false }
    open var duration: TimeInterval { 0 }
    open var currentTime: TimeInterval = 0
    open var volume: Float = 1
    open var rate: Float = 1
    open var enableRate: Bool = false
    open var numberOfLoops: Int = 0
    open var isMeteringEnabled: Bool = false
    open var pan: Float = 0
    open var url: URL? { nil }
    @discardableResult open func prepareToPlay() -> Bool { true }
    @discardableResult open func play() -> Bool { true }
    @discardableResult open func play(atTime time: TimeInterval) -> Bool { true }
    open func pause() {}
    open func stop() {}
    open func setVolume(_ volume: Float, fadeDuration duration: TimeInterval) {}
    open func updateMeters() {}
    open func averagePower(forChannel channelNumber: Int) -> Float { -160 }
    open func peakPower(forChannel channelNumber: Int) -> Float { -160 }
}
public protocol AVAudioRecorderDelegate: NSObjectProtocol {
    func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool)
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?)
}
extension AVAudioRecorderDelegate {
    public func audioRecorderDidFinishRecording(_ recorder: AVAudioRecorder, successfully flag: Bool) {}
    public func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {}
}
open class AVAudioRecorder: NSObject {
    public init(url: URL, settings: [String: Any]) throws { super.init() }
    public init(url: URL, format: AVAudioFormat) throws { super.init() }
    open weak var delegate: (any AVAudioRecorderDelegate)?
    open var isRecording: Bool { false }
    open var url: URL { URL(fileURLWithPath: "/") }
    open var currentTime: TimeInterval { 0 }
    open var isMeteringEnabled: Bool = false
    open var settings: [String: Any] { [:] }
    @discardableResult open func prepareToRecord() -> Bool { true }
    @discardableResult open func record() -> Bool { true }
    @discardableResult open func record(forDuration duration: TimeInterval) -> Bool { true }
    open func pause() {}
    open func stop() {}
    @discardableResult open func deleteRecording() -> Bool { true }
    open func updateMeters() {}
    open func averagePower(forChannel channelNumber: Int) -> Float { -160 }
    open func peakPower(forChannel channelNumber: Int) -> Float { -160 }
}

// MARK: Audio engine

open class AVAudioFormat: NSObject {
    public override init() { super.init() }
    public init?(standardFormatWithSampleRate sampleRate: Double, channels: AVAudioChannelCount) { super.init() }
    public init?(commonFormat format: AVAudioCommonFormat, sampleRate: Double, channels: AVAudioChannelCount, interleaved: Bool) { super.init() }
    public init?(settings: [String: Any]) { super.init() }
    open var sampleRate: Double { 44100 }
    open var channelCount: AVAudioChannelCount { 2 }
    open var commonFormat: AVAudioCommonFormat { .pcmFormatFloat32 }
    open var isInterleaved: Bool { false }
    open var isStandard: Bool { true }
    open var settings: [String: Any] { [:] }
}
public enum AVAudioCommonFormat: UInt { case otherFormat, pcmFormatFloat32, pcmFormatFloat64, pcmFormatInt16, pcmFormatInt32 }
open class AVAudioBuffer: NSObject {
    public override init() { super.init() }
    open var format: AVAudioFormat { AVAudioFormat() }
}
open class AVAudioPCMBuffer: AVAudioBuffer {
    public init?(pcmFormat format: AVAudioFormat, frameCapacity: AVAudioFrameCount) { super.init() }
    open var frameLength: AVAudioFrameCount = 0
    open var frameCapacity: AVAudioFrameCount { 0 }
    open var stride: Int { 1 }
    open var floatChannelData: UnsafePointer<UnsafeMutablePointer<Float>>? { nil }
    open var int16ChannelData: UnsafePointer<UnsafeMutablePointer<Int16>>? { nil }
    open var int32ChannelData: UnsafePointer<UnsafeMutablePointer<Int32>>? { nil }
}
open class AVAudioNode: NSObject {
    public override init() { super.init() }
    open var engine: AVAudioEngine? { nil }
    open var numberOfInputs: Int { 1 }
    open var numberOfOutputs: Int { 1 }
    open var lastRenderTime: AVAudioTime? { nil }
    open func inputFormat(forBus bus: Int) -> AVAudioFormat { AVAudioFormat() }
    open func outputFormat(forBus bus: Int) -> AVAudioFormat { AVAudioFormat() }
    open func reset() {}
    open func installTap(onBus bus: Int, bufferSize: AVAudioFrameCount, format: AVAudioFormat?, block tapBlock: @escaping (AVAudioPCMBuffer, AVAudioTime) -> Void) {}
    open func removeTap(onBus bus: Int) {}
}
open class AVAudioTime: NSObject {
    public override init() { super.init() }
    public init(sampleTime: AVAudioFramePosition, atRate sampleRate: Double) { super.init() }
    public init(hostTime: UInt64) { super.init() }
    open var sampleTime: AVAudioFramePosition { 0 }
    open var sampleRate: Double { 44100 }
    open var hostTime: UInt64 { 0 }
    open var isSampleTimeValid: Bool { true }
    open class func hostTime(forSeconds seconds: TimeInterval) -> UInt64 { 0 }
    open class func seconds(forHostTime hostTime: UInt64) -> TimeInterval { 0 }
}
open class AVAudioMixing: AVAudioNode {}
open class AVAudioMixerNode: AVAudioNode {
    public override init() { super.init() }
    open var outputVolume: Float = 1
    open var nextAvailableInputBus: Int { 0 }
}
open class AVAudioOutputNode: AVAudioNode { public override init() { super.init() } }
open class AVAudioInputNode: AVAudioNode { public override init() { super.init() }; open var isVoiceProcessingEnabled: Bool { false }; open func setVoiceProcessingEnabled(_ enabled: Bool) throws {} }
open class AVAudioPlayerNode: AVAudioNode {
    public override init() { super.init() }
    open var isPlaying: Bool { false }
    open var volume: Float = 1
    open var pan: Float = 0
    open var rate: Float = 1
    public struct BufferOptions: OptionSet { public let rawValue: UInt; public init(rawValue: UInt) { self.rawValue = rawValue }; public static let loops = BufferOptions(rawValue: 1), interrupts = BufferOptions(rawValue: 2), interruptsAtLoop = BufferOptions(rawValue: 4) }
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, completionHandler: (() -> Void)? = nil) {}
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, options: BufferOptions = [], completionHandler: (() -> Void)? = nil) {}
    open func scheduleBuffer(_ buffer: AVAudioPCMBuffer, at when: AVAudioTime?, options: BufferOptions = [], completionCallbackType: AVAudioPlayerNodeCompletionCallbackType, completionHandler: ((AVAudioPlayerNodeCompletionCallbackType) -> Void)? = nil) {}
    open func scheduleFile(_ file: AVAudioFile, at when: AVAudioTime?, completionHandler: (() -> Void)? = nil) {}
    open func play() {}
    open func play(at when: AVAudioTime?) {}
    open func pause() {}
    open func stop() {}
    open func nodeTime(forPlayerTime playerTime: AVAudioTime) -> AVAudioTime? { nil }
    open func playerTime(forNodeTime nodeTime: AVAudioTime) -> AVAudioTime? { nil }
}
public enum AVAudioPlayerNodeCompletionCallbackType: Int { case dataConsumed, dataRendered, dataPlayedBack }
open class AVAudioFile: NSObject {
    public init(forReading fileURL: URL) throws { super.init() }
    public init(forWriting fileURL: URL, settings: [String: Any]) throws { super.init() }
    open var length: AVAudioFramePosition { 0 }
    open var processingFormat: AVAudioFormat { AVAudioFormat() }
    open var fileFormat: AVAudioFormat { AVAudioFormat() }
    open var framePosition: AVAudioFramePosition = 0
    open func read(into buffer: AVAudioPCMBuffer) throws {}
    open func write(from buffer: AVAudioPCMBuffer) throws {}
}
open class AVAudioUnit: AVAudioNode {}
open class AVAudioUnitEffect: AVAudioUnit { open var bypass: Bool = false }
open class AVAudioUnitTimeEffect: AVAudioUnit { open var bypass: Bool = false }
open class AVAudioUnitReverb: AVAudioUnitEffect { public override init() { super.init() }; open var wetDryMix: Float = 0; open func loadFactoryPreset(_ preset: AVAudioUnitReverbPreset) {} }
public enum AVAudioUnitReverbPreset: Int { case smallRoom, mediumRoom, largeRoom, mediumHall, largeHall, plate, mediumChamber, largeChamber, cathedral, largeRoom2, mediumHall2, mediumHall3, largeHall2 }
open class AVAudioUnitTimePitch: AVAudioUnitTimeEffect { public override init() { super.init() }; open var rate: Float = 1; open var pitch: Float = 0; open var overlap: Float = 8 }
open class AVAudioUnitDistortion: AVAudioUnitEffect { public override init() { super.init() }; open var preGain: Float = 0; open var wetDryMix: Float = 0 }
open class AVAudioUnitEQ: AVAudioUnitEffect { public init(numberOfBands: Int) { super.init() }; open var globalGain: Float = 0 }
open class AVAudioEngine: NSObject {
    public override init() { super.init() }
    open var mainMixerNode: AVAudioMixerNode { AVAudioMixerNode() }
    open var outputNode: AVAudioOutputNode { AVAudioOutputNode() }
    open var inputNode: AVAudioInputNode { AVAudioInputNode() }
    open var isRunning: Bool { false }
    open var isAutoShutdownEnabled: Bool = false
    open func attach(_ node: AVAudioNode) {}
    open func detach(_ node: AVAudioNode) {}
    open func connect(_ node1: AVAudioNode, to node2: AVAudioNode, format: AVAudioFormat?) {}
    open func connect(_ node1: AVAudioNode, to node2: AVAudioNode, fromBus bus1: Int, toBus bus2: Int, format: AVAudioFormat?) {}
    open func disconnectNodeInput(_ node: AVAudioNode) {}
    open func disconnectNodeOutput(_ node: AVAudioNode) {}
    open func prepare() {}
    open func start() throws {}
    open func pause() {}
    open func stop() {}
    open func reset() {}
    public static let configurationChangeNotification = Notification.Name("AVAudioEngineConfigurationChange")
}

// MARK: Assets & players

public let AVURLAssetHTTPHeaderFieldsKey = "AVURLAssetHTTPHeaderFieldsKey"
public let AVURLAssetPreferPreciseDurationAndTimingKey = "AVURLAssetPreferPreciseDurationAndTimingKey"
public struct AVMediaType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let video = AVMediaType("vide"), audio = AVMediaType("soun"), text = AVMediaType("text"), subtitle = AVMediaType("sbtl"), metadata = AVMediaType("meta")
}
public struct AVFileType: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(_ rawValue: String) { self.rawValue = rawValue }
    public static let mp4 = AVFileType("public.mpeg-4"), mov = AVFileType("com.apple.quicktime-movie"), m4a = AVFileType("com.apple.m4a-audio"), m4v = AVFileType("com.apple.m4v-video"), wav = AVFileType("com.microsoft.waveform-audio"), caf = AVFileType("com.apple.coreaudio-format"), aiff = AVFileType("public.aiff-audio"), jpg = AVFileType("public.jpeg"), heic = AVFileType("public.heic")
}
public struct AVAsyncProperty<Root, Value> {
    public static var duration: AVAsyncProperty<AVAsset, CMTime> { AVAsyncProperty<AVAsset, CMTime>() }
    public static var tracks: AVAsyncProperty<AVAsset, [AVAssetTrack]> { AVAsyncProperty<AVAsset, [AVAssetTrack]>() }
    public static var isPlayable: AVAsyncProperty<AVAsset, Bool> { AVAsyncProperty<AVAsset, Bool>() }
    public static var isExportable: AVAsyncProperty<AVAsset, Bool> { AVAsyncProperty<AVAsset, Bool>() }
    public static var naturalSize: AVAsyncProperty<AVAssetTrack, CGSize> { AVAsyncProperty<AVAssetTrack, CGSize>() }
    public static var preferredTransform: AVAsyncProperty<AVAssetTrack, CGAffineTransform> { AVAsyncProperty<AVAssetTrack, CGAffineTransform>() }
    public static var nominalFrameRate: AVAsyncProperty<AVAssetTrack, Float> { AVAsyncProperty<AVAssetTrack, Float>() }
    public static var estimatedDataRate: AVAsyncProperty<AVAssetTrack, Float> { AVAsyncProperty<AVAssetTrack, Float>() }
    public static var timeRange: AVAsyncProperty<AVAssetTrack, CMTimeRange> { AVAsyncProperty<AVAssetTrack, CMTimeRange>() }
    public static var formatDescriptions: AVAsyncProperty<AVAssetTrack, [AnyObject]> { AVAsyncProperty<AVAssetTrack, [AnyObject]>() }
}
open class AVAsset: NSObject {
    public override init() { super.init() }
    open var duration: CMTime { .zero }
    open var tracks: [AVAssetTrack] { [] }
    open var isPlayable: Bool { true }
    open var isExportable: Bool { true }
    open func load<T>(_ property: AVAsyncProperty<AVAsset, T>) async throws -> T { fatalError() }
    open func load<A, B>(_ propertyA: AVAsyncProperty<AVAsset, A>, _ propertyB: AVAsyncProperty<AVAsset, B>) async throws -> (A, B) { fatalError() }
    open func loadTracks(withMediaType mediaType: AVMediaType) async throws -> [AVAssetTrack] { [] }
    open func tracks(withMediaType mediaType: AVMediaType) -> [AVAssetTrack] { [] }
    open func loadValuesAsynchronously(forKeys keys: [String], completionHandler handler: (() -> Void)? = nil) {}
    open class func assetWithURL(_ url: URL) -> AVAsset { AVURLAsset(url: url) }
}
open class AVURLAsset: AVAsset {
    public init(url URL: URL) { super.init() }
    public init(url URL: URL, options: [String: Any]?) { super.init() }
    open var url: URL { URL(fileURLWithPath: "/") }
}
open class AVAssetTrack: NSObject {
    public override init() { super.init() }
    open var naturalSize: CGSize { .zero }
    open var preferredTransform: CGAffineTransform { .identity }
    open var mediaType: AVMediaType { .video }
    open var nominalFrameRate: Float { 30 }
    open var estimatedDataRate: Float { 0 }
    open var timeRange: CMTimeRange { .zero }
    open func load<T>(_ property: AVAsyncProperty<AVAssetTrack, T>) async throws -> T { fatalError() }
    open func load<A, B>(_ propertyA: AVAsyncProperty<AVAssetTrack, A>, _ propertyB: AVAsyncProperty<AVAssetTrack, B>) async throws -> (A, B) { fatalError() }
}
open class AVPlayerItem: NSObject {
    public init(asset: AVAsset) { super.init() }
    public init(url: URL) { super.init() }
    open var asset: AVAsset { AVAsset() }
    open var duration: CMTime { .zero }
    open func currentTime() -> CMTime { .zero }
    open var status: Status { .unknown }
    open var error: Error? { nil }
    open var isPlaybackLikelyToKeepUp: Bool { true }
    open var isPlaybackBufferEmpty: Bool { false }
    open var preferredForwardBufferDuration: TimeInterval = 0
    open var audioTimePitchAlgorithm: AVAudioTimePitchAlgorithm = .timeDomain
    open var loadedTimeRanges: [NSValue] { [] }
    open var seekableTimeRanges: [NSValue] { [] }
    open var videoComposition: AnyObject?
    public enum Status: Int { case unknown, readyToPlay, failed }
    public static let didPlayToEndTimeNotification = Notification.Name("AVPlayerItemDidPlayToEndTime")
    public static let failedToPlayToEndTimeNotification = Notification.Name("AVPlayerItemFailedToPlayToEndTime")
    public static let playbackStalledNotification = Notification.Name("AVPlayerItemPlaybackStalled")
    public static let timeJumpedNotification = Notification.Name("AVPlayerItemTimeJumped")
}
public struct AVAudioTimePitchAlgorithm: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
    public static let lowQualityZeroLatency = AVAudioTimePitchAlgorithm(rawValue: "lq"), timeDomain = AVAudioTimePitchAlgorithm(rawValue: "td"), spectral = AVAudioTimePitchAlgorithm(rawValue: "sp"), varispeed = AVAudioTimePitchAlgorithm(rawValue: "vs") }
extension NSNotification.Name {
    public static let AVPlayerItemDidPlayToEndTime = Notification.Name("AVPlayerItemDidPlayToEndTime")
    public static let AVPlayerItemFailedToPlayToEndTime = Notification.Name("AVPlayerItemFailedToPlayToEndTime")
    public static let AVPlayerItemPlaybackStalled = Notification.Name("AVPlayerItemPlaybackStalled")
    public static let AVPlayerItemTimeJumped = Notification.Name("AVPlayerItemTimeJumped")
    public static let AVPlayerItemNewErrorLogEntry = Notification.Name("AVPlayerItemNewErrorLogEntry")
}
open class AVPlayer: NSObject {
    public override init() { super.init() }
    public init(url URL: URL) { super.init() }
    public init(playerItem item: AVPlayerItem?) { super.init() }
    open var currentItem: AVPlayerItem? { nil }
    open var rate: Float = 0
    open var defaultRate: Float = 1
    open var volume: Float = 1
    open var isMuted: Bool = false
    open var status: Status { .unknown }
    open var error: Error? { nil }
    open var timeControlStatus: TimeControlStatus { .paused }
    open var actionAtItemEnd: ActionAtItemEnd = .pause
    open var automaticallyWaitsToMinimizeStalling: Bool = true
    open var allowsExternalPlayback: Bool = true
    open var preventsDisplaySleepDuringVideoPlayback: Bool = true
    open var audiovisualBackgroundPlaybackPolicy: AVPlayerAudiovisualBackgroundPlaybackPolicy = .automatic
    open func play() {}
    open func pause() {}
    open func playImmediately(atRate rate: Float) {}
    open func currentTime() -> CMTime { .zero }
    open func seek(to time: CMTime) {}
    open func seek(to time: CMTime, completionHandler: @escaping (Bool) -> Void) {}
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) {}
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime, completionHandler: @escaping (Bool) -> Void) {}
    open func seek(to time: CMTime) async -> Bool { true }
    open func seek(to time: CMTime, toleranceBefore: CMTime, toleranceAfter: CMTime) async -> Bool { true }
    open func seek(to date: Date) {}
    open func replaceCurrentItem(with item: AVPlayerItem?) {}
    open func addPeriodicTimeObserver(forInterval interval: CMTime, queue: DispatchQueue?, using block: @escaping (CMTime) -> Void) -> Any { NSObject() }
    open func addBoundaryTimeObserver(forTimes times: [NSValue], queue: DispatchQueue?, using block: @escaping () -> Void) -> Any { NSObject() }
    open func removeTimeObserver(_ observer: Any) {}
    public enum Status: Int { case unknown, readyToPlay, failed }
    public enum TimeControlStatus: Int { case paused, waitingToPlayAtSpecifiedRate, playing }
    public enum ActionAtItemEnd: Int { case advance, pause, none }
    public static let rateDidChangeNotification = Notification.Name("AVPlayerRateDidChange")
}
public enum AVPlayerAudiovisualBackgroundPlaybackPolicy: Int { case automatic = 1, pauses, continuesIfPossible }
open class AVQueuePlayer: AVPlayer {
    public override init() { super.init() }
    public init(items: [AVPlayerItem]) { super.init() }
    open func items() -> [AVPlayerItem] { [] }
    open func advanceToNextItem() {}
    open func insert(_ item: AVPlayerItem, after afterItem: AVPlayerItem?) {}
    open func remove(_ item: AVPlayerItem) {}
    open func removeAllItems() {}
}
open class AVPlayerLooper: NSObject {
    public init(player: AVQueuePlayer, templateItem itemToLoop: AVPlayerItem) { super.init() }
    open func disableLooping() {}
}
open class AVPlayerLayer: CALayer {
    public override init() { super.init() }
    public init(player: AVPlayer?) { super.init() }
    open var player: AVPlayer?
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    open var isReadyForDisplay: Bool { true }
}
public struct AVLayerVideoGravity: RawRepresentable, Hashable, Sendable {
    public let rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public static let resizeAspect = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspect"), resizeAspectFill = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResizeAspectFill"), resize = AVLayerVideoGravity(rawValue: "AVLayerVideoGravityResize")
}

// MARK: Image generation & export

open class AVAssetImageGenerator: NSObject {
    public init(asset: AVAsset) { super.init() }
    open var appliesPreferredTrackTransform: Bool = false
    open var maximumSize: CGSize = .zero
    open var requestedTimeToleranceBefore: CMTime = .positiveInfinity
    open var requestedTimeToleranceAfter: CMTime = .positiveInfinity
    open var apertureMode: ApertureMode?
    public struct ApertureMode: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }; public static let cleanAperture = ApertureMode(rawValue: "clean"), productionAperture = ApertureMode(rawValue: "production"), encodedPixels = ApertureMode(rawValue: "encoded") }
    open func copyCGImage(at requestedTime: CMTime, actualTime: UnsafeMutablePointer<CMTime>?) throws -> CGImage { CGImage() }
    open func image(at requestedTime: CMTime) async throws -> (image: CGImage, actualTime: CMTime) { (CGImage(), requestedTime) }
    open func generateCGImagesAsynchronously(forTimes requestedTimes: [NSValue], completionHandler handler: @escaping (CMTime, CGImage?, CMTime, Result, Error?) -> Void) {}
    open func cancelAllCGImageGeneration() {}
    public enum Result: Int { case succeeded, failed, cancelled }
}
public let AVAssetExportPresetLowQuality = "AVAssetExportPresetLowQuality"
public let AVAssetExportPresetMediumQuality = "AVAssetExportPresetMediumQuality"
public let AVAssetExportPresetHighestQuality = "AVAssetExportPresetHighestQuality"
public let AVAssetExportPreset640x480 = "AVAssetExportPreset640x480"
public let AVAssetExportPreset960x540 = "AVAssetExportPreset960x540"
public let AVAssetExportPreset1280x720 = "AVAssetExportPreset1280x720"
public let AVAssetExportPreset1920x1080 = "AVAssetExportPreset1920x1080"
public let AVAssetExportPreset3840x2160 = "AVAssetExportPreset3840x2160"
public let AVAssetExportPresetHEVC1920x1080 = "AVAssetExportPresetHEVC1920x1080"
public let AVAssetExportPresetPassthrough = "AVAssetExportPresetPassthrough"
public let AVAssetExportPresetAppleM4A = "AVAssetExportPresetAppleM4A"
open class AVAssetExportSession: NSObject {
    public init?(asset: AVAsset, presetName: String) { super.init() }
    open var outputURL: URL?
    open var outputFileType: AVFileType?
    open var shouldOptimizeForNetworkUse: Bool = false
    open var timeRange: CMTimeRange = .zero
    open var status: Status { .unknown }
    open var error: Error? { nil }
    open var progress: Float { 0 }
    open var fileLengthLimit: Int64 = 0
    open var videoComposition: AnyObject?
    open var audioMix: AnyObject?
    open var metadata: [AnyObject]?
    open var estimatedOutputFileLengthInBytes: Int64 { 0 }
    open func exportAsynchronously(completionHandler handler: @escaping () -> Void) {}
    open func export() async {}
    open func export(to url: URL, as fileType: AVFileType) async throws {}
    open func cancelExport() {}
    open func estimateOutputFileLength() async throws -> Int64 { 0 }
    open class func allExportPresets() -> [String] { [] }
    open class func exportPresets(compatibleWith asset: AVAsset) -> [String] { [] }
    public enum Status: Int { case unknown, waiting, exporting, completed, failed, cancelled }
    public struct States: AsyncSequence {
        public typealias Element = AVAssetExportSession.State
        public struct AsyncIterator: AsyncIteratorProtocol { public mutating func next() async -> Element? { nil } }
        public func makeAsyncIterator() -> AsyncIterator { AsyncIterator() }
    }
    public enum State { case pending, waiting, exporting(progress: Progress) }
    open func states(updateInterval: TimeInterval = 0.5) -> States { States() }
}

// MARK: Capture (QR scanning)

open class AVCaptureSession: NSObject {
    public override init() { super.init() }
    open var isRunning: Bool { false }
    open var sessionPreset: Preset = .high
    public struct Preset: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let photo = Preset(rawValue: "photo"), high = Preset(rawValue: "high"), medium = Preset(rawValue: "medium"), low = Preset(rawValue: "low"), hd1280x720 = Preset(rawValue: "720p"), hd1920x1080 = Preset(rawValue: "1080p") }
    open func canAddInput(_ input: AVCaptureInput) -> Bool { true }
    open func addInput(_ input: AVCaptureInput) {}
    open func removeInput(_ input: AVCaptureInput) {}
    open func canAddOutput(_ output: AVCaptureOutput) -> Bool { true }
    open func addOutput(_ output: AVCaptureOutput) {}
    open func removeOutput(_ output: AVCaptureOutput) {}
    open func beginConfiguration() {}
    open func commitConfiguration() {}
    open func startRunning() {}
    open func stopRunning() {}
    open var inputs: [AVCaptureInput] { [] }
    open var outputs: [AVCaptureOutput] { [] }
    public static let runtimeErrorNotification = Notification.Name("AVCaptureSessionRuntimeError")
    public static let wasInterruptedNotification = Notification.Name("AVCaptureSessionWasInterrupted")
    public static let interruptionEndedNotification = Notification.Name("AVCaptureSessionInterruptionEnded")
}
open class AVCaptureInput: NSObject { public override init() { super.init() } }
open class AVCaptureOutput: NSObject { public override init() { super.init() }; open var connections: [AVCaptureConnection] { [] }; open func connection(with mediaType: AVMediaType) -> AVCaptureConnection? { nil } }
open class AVCaptureConnection: NSObject { public override init() { super.init() }; open var isEnabled: Bool = true; open var isVideoMirrored: Bool = false; open var videoRotationAngle: CGFloat = 0 }
open class AVCaptureDevice: NSObject {
    public override init() { super.init() }
    open class func `default`(for mediaType: AVMediaType) -> AVCaptureDevice? { nil }
    open class func `default`(_ deviceType: DeviceType, for mediaType: AVMediaType?, position: Position) -> AVCaptureDevice? { nil }
    open class func authorizationStatus(for mediaType: AVMediaType) -> AuthorizationStatus { .authorized }
    open class func requestAccess(for mediaType: AVMediaType, completionHandler handler: @escaping (Bool) -> Void) {}
    open class func requestAccess(for mediaType: AVMediaType) async -> Bool { true }
    open var hasTorch: Bool { false }
    open var torchMode: TorchMode = .off
    open var isTorchAvailable: Bool { false }
    open var position: Position { .back }
    open var localizedName: String { "Camera" }
    open var uniqueID: String { "cam" }
    open func lockForConfiguration() throws {}
    open func unlockForConfiguration() {}
    open func setTorchModeOn(level torchLevel: Float) throws {}
    public struct DeviceType: RawRepresentable, Hashable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let builtInWideAngleCamera = DeviceType(rawValue: "wide"), builtInUltraWideCamera = DeviceType(rawValue: "ultrawide"), builtInTelephotoCamera = DeviceType(rawValue: "tele"), builtInDualCamera = DeviceType(rawValue: "dual"), builtInTripleCamera = DeviceType(rawValue: "triple"), builtInTrueDepthCamera = DeviceType(rawValue: "truedepth"), microphone = DeviceType(rawValue: "mic"), builtInMicrophone = DeviceType(rawValue: "mic") }
    public enum Position: Int { case unspecified, back, front }
    public enum AuthorizationStatus: Int { case notDetermined, restricted, denied, authorized }
    public enum TorchMode: Int { case off, on, auto }
    public enum FlashMode: Int { case off, on, auto }
}
open class AVCaptureDeviceInput: AVCaptureInput {
    public init(device: AVCaptureDevice) throws { super.init() }
    open var device: AVCaptureDevice { AVCaptureDevice() }
}
open class AVMetadataObject: NSObject {
    public override init() { super.init() }
    open var type: ObjectType { .qr }
    open var bounds: CGRect { .zero }
    open var time: CMTime { .zero }
    public struct ObjectType: RawRepresentable, Hashable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let qr = ObjectType(rawValue: "org.iso.QRCode"), ean13 = ObjectType(rawValue: "org.gs1.EAN-13"), ean8 = ObjectType(rawValue: "org.gs1.EAN-8"), code128 = ObjectType(rawValue: "org.iso.Code128"), code39 = ObjectType(rawValue: "org.iso.Code39"), upce = ObjectType(rawValue: "org.gs1.UPC-E"), pdf417 = ObjectType(rawValue: "org.iso.PDF417"), aztec = ObjectType(rawValue: "org.iso.Aztec"), dataMatrix = ObjectType(rawValue: "org.iso.DataMatrix"), face = ObjectType(rawValue: "face"), humanBody = ObjectType(rawValue: "humanBody") }
}
open class AVMetadataMachineReadableCodeObject: AVMetadataObject {
    public override init() { super.init() }
    open var stringValue: String? { nil }
    open var corners: [CGPoint] { [] }
}
public protocol AVCaptureMetadataOutputObjectsDelegate: NSObjectProtocol {
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection)
}
extension AVCaptureMetadataOutputObjectsDelegate {
    public func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {}
}
open class AVCaptureMetadataOutput: AVCaptureOutput {
    public override init() { super.init() }
    open var metadataObjectTypes: [AVMetadataObject.ObjectType] = []
    open var availableMetadataObjectTypes: [AVMetadataObject.ObjectType] { [.qr] }
    open var rectOfInterest: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    open func setMetadataObjectsDelegate(_ objectsDelegate: (any AVCaptureMetadataOutputObjectsDelegate)?, queue objectsCallbackQueue: DispatchQueue?) {}
}
open class AVCaptureVideoPreviewLayer: CALayer {
    public override init() { super.init() }
    public init(session: AVCaptureSession) { super.init() }
    open var session: AVCaptureSession?
    open var videoGravity: AVLayerVideoGravity = .resizeAspect
    open var connection: AVCaptureConnection? { nil }
    open func metadataOutputRectConverted(fromLayerRect rectInLayerCoordinates: CGRect) -> CGRect { rectInLayerCoordinates }
    open func layerRectConverted(fromMetadataOutputRect rectInMetadataOutputCoordinates: CGRect) -> CGRect { rectInMetadataOutputCoordinates }
    open func transformedMetadataObject(for metadataObject: AVMetadataObject) -> AVMetadataObject? { metadataObject }
}
