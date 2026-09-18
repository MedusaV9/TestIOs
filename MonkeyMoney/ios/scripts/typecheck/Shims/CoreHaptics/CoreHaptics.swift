// CoreHaptics stub.
import Foundation

public let CHHapticTimeImmediate: TimeInterval = 0

public class CHHapticEventParameter: NSObject {
    public struct ParameterID: RawRepresentable, Hashable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticIntensity = ParameterID(rawValue: "HapticIntensity"), hapticSharpness = ParameterID(rawValue: "HapticSharpness"), attackTime = ParameterID(rawValue: "AttackTime"), decayTime = ParameterID(rawValue: "DecayTime"), releaseTime = ParameterID(rawValue: "ReleaseTime"), sustained = ParameterID(rawValue: "Sustained"), audioVolume = ParameterID(rawValue: "AudioVolume"), audioPitch = ParameterID(rawValue: "AudioPitch"), audioPan = ParameterID(rawValue: "AudioPan"), audioBrightness = ParameterID(rawValue: "AudioBrightness") }
    public var parameterID: ParameterID
    public var value: Float
    public init(parameterID: ParameterID, value: Float) { self.parameterID = parameterID; self.value = value }
}
public class CHHapticDynamicParameter: NSObject {
    public struct ID: RawRepresentable, Hashable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticIntensityControl = ID(rawValue: "HapticIntensityControl"), hapticSharpnessControl = ID(rawValue: "HapticSharpnessControl"), audioVolumeControl = ID(rawValue: "AudioVolumeControl") }
    public init(parameterID: ID, value: Float, relativeTime time: TimeInterval) {}
}
public class CHHapticParameterCurve: NSObject {
    public class ControlPoint: NSObject { public init(relativeTime time: TimeInterval, value: Float) {} }
    public init(parameterID: CHHapticDynamicParameter.ID, controlPoints: [ControlPoint], relativeTime: TimeInterval) {}
}
public class CHHapticEvent: NSObject {
    public struct EventType: RawRepresentable, Hashable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let hapticTransient = EventType(rawValue: "HapticTransient"), hapticContinuous = EventType(rawValue: "HapticContinuous"), audioContinuous = EventType(rawValue: "AudioContinuous"), audioCustom = EventType(rawValue: "AudioCustom") }
    public var type: EventType
    public var eventParameters: [CHHapticEventParameter]
    public var relativeTime: TimeInterval
    public var duration: TimeInterval
    public init(eventType type: EventType, parameters eventParams: [CHHapticEventParameter], relativeTime time: TimeInterval) { self.type = type; eventParameters = eventParams; relativeTime = time; duration = 0 }
    public init(eventType type: EventType, parameters eventParams: [CHHapticEventParameter], relativeTime time: TimeInterval, duration: TimeInterval) { self.type = type; eventParameters = eventParams; relativeTime = time; self.duration = duration }
}
public class CHHapticPattern: NSObject {
    public init(events: [CHHapticEvent], parameters: [CHHapticDynamicParameter]) throws {}
    public init(events: [CHHapticEvent], parameterCurves: [CHHapticParameterCurve]) throws {}
    public init(dictionary patternDict: [CHHapticPattern.Key: Any]) throws {}
    public var duration: TimeInterval { 0 }
    public struct Key: RawRepresentable, Hashable, Sendable { public let rawValue: String; public init(rawValue: String) { self.rawValue = rawValue }
        public static let pattern = Key(rawValue: "Pattern"), event = Key(rawValue: "Event"), eventType = Key(rawValue: "EventType"), time = Key(rawValue: "Time"), eventDuration = Key(rawValue: "EventDuration"), eventParameters = Key(rawValue: "EventParameters"), parameterID = Key(rawValue: "ParameterID"), parameterValue = Key(rawValue: "ParameterValue") }
}
public protocol CHHapticPatternPlayer {
    func start(atTime time: TimeInterval) throws
    func stop(atTime time: TimeInterval) throws
    func sendParameters(_ parameters: [CHHapticDynamicParameter], atTime time: TimeInterval) throws
    func scheduleParameterCurve(_ parameterCurve: CHHapticParameterCurve, atTime time: TimeInterval) throws
    func cancel() throws
    var isMuted: Bool { get set }
}
public protocol CHHapticAdvancedPatternPlayer: CHHapticPatternPlayer {
    func pause(atTime time: TimeInterval) throws
    func resume(atTime time: TimeInterval) throws
    func seek(toOffset offset: TimeInterval) throws
    var loopEnabled: Bool { get set }
    var loopEnd: TimeInterval { get set }
    var playbackRate: Float { get set }
    var completionHandler: (Error?) -> Void { get set }
}
public class CHHapticEngine {
    public struct Capabilities { public var supportsHaptics: Bool { true }; public var supportsAudio: Bool { true } }
    public class func capabilitiesForHardware() -> Capabilities { Capabilities() }
    public init() throws {}
    public init(audioSession: AnyObject?) throws {}
    public var resetHandler: () -> Void = {}
    public var stoppedHandler: (StoppedReason) -> Void = { _ in }
    public var playsHapticsOnly: Bool = false
    public var isMutedForHaptics: Bool = false
    public var isMutedForAudio: Bool = false
    public var isAutoShutdownEnabled: Bool = false
    public var currentTime: TimeInterval { 0 }
    public func start() throws {}
    public func start(completionHandler: ((Error?) -> Void)?) {}
    public func stop(completionHandler: ((Error?) -> Void)? = nil) {}
    public func stop() async throws {}
    public func notifyWhenPlayersFinished(finishedHandler: @escaping (Error?) -> FinishedAction) {}
    public func makePlayer(with pattern: CHHapticPattern) throws -> any CHHapticPatternPlayer { Player() }
    public func makeAdvancedPlayer(with pattern: CHHapticPattern) throws -> any CHHapticAdvancedPatternPlayer { Player() }
    public func playPattern(from url: URL) throws {}
    public func playPattern(from data: Data) throws {}
    public enum StoppedReason: Int { case audioSessionInterrupt = 1, applicationSuspended, idleTimeout, notifyWhenFinished, engineDestroyed, gameControllerDisconnect, systemError = -1 }
    public enum FinishedAction: Int { case stopEngine = 1, leaveEngineRunning }
    final class Player: CHHapticAdvancedPatternPlayer {
        func start(atTime time: TimeInterval) throws {}
        func stop(atTime time: TimeInterval) throws {}
        func sendParameters(_ parameters: [CHHapticDynamicParameter], atTime time: TimeInterval) throws {}
        func scheduleParameterCurve(_ parameterCurve: CHHapticParameterCurve, atTime time: TimeInterval) throws {}
        func cancel() throws {}
        var isMuted: Bool = false
        func pause(atTime time: TimeInterval) throws {}
        func resume(atTime time: TimeInterval) throws {}
        func seek(toOffset offset: TimeInterval) throws {}
        var loopEnabled: Bool = false
        var loopEnd: TimeInterval = 0
        var playbackRate: Float = 1
        var completionHandler: (Error?) -> Void = { _ in }
    }
}
public struct CHHapticError: Error { public enum Code: Int { case engineNotRunning = -4805, operationNotPermitted = -4806, engineStartTimeout = -4808, notSupported = -4809, serverInitFailed = -4810, serverInterrupted = -4811, invalidPatternPlayer = -4820, invalidPatternData = -4821, invalidPatternDictionary = -4822, invalidAudioSession = -4823, invalidParameterType = -4824, invalidEventType = -4830, invalidEventTime = -4831, invalidEventDuration = -4832, invalidAudioResource = -4833, resourceNotAvailable = -4834, badEventEntry = -4840, badParameterEntry = -4841, invalidTime = -4842, fileNotFound = -4851, insufficientPower = -4852, unknownError = -4853, memoryError = -4899 }; public let code: Code }
