// Combine stub — the app only consumes publishers through SwiftUI's
// `.onReceive`, so this models the protocol plus the two publisher sources
// it uses (NotificationCenter, Timer).
import Foundation

public protocol Publisher<Output, Failure> {
    associatedtype Output
    associatedtype Failure: Error
}

public protocol Cancellable {
    func cancel()
}

public final class AnyCancellable: Cancellable, Hashable {
    public init(_ cancel: @escaping () -> Void) {}
    public init<C: Cancellable>(_ canceller: C) {}
    public func cancel() {}
    public func store(in set: inout Set<AnyCancellable>) {}
    public func store<C: RangeReplaceableCollection>(in collection: inout C) where C.Element == AnyCancellable {}
    public static func == (lhs: AnyCancellable, rhs: AnyCancellable) -> Bool { lhs === rhs }
    public func hash(into hasher: inout Hasher) { hasher.combine(ObjectIdentifier(self)) }
}

public struct AnyPublisher<Output, Failure: Error>: Publisher {
    public init<P: Publisher>(_ publisher: P) where P.Output == Output, P.Failure == Failure {}
}

public struct Just<Output>: Publisher {
    public typealias Failure = Never
    public let output: Output
    public init(_ output: Output) { self.output = output }
}

public final class PassthroughSubject<Output, Failure: Error>: Publisher {
    public init() {}
    public func send(_ value: Output) {}
    public func send() where Output == Void {}
}

public final class CurrentValueSubject<Output, Failure: Error>: Publisher {
    public var value: Output
    public init(_ value: Output) { self.value = value }
    public func send(_ value: Output) { self.value = value }
}

extension Publisher {
    public func eraseToAnyPublisher() -> AnyPublisher<Output, Failure> { AnyPublisher(self) }
    public func sink(receiveValue: @escaping (Output) -> Void) -> AnyCancellable where Failure == Never { AnyCancellable {} }
    public func sink(receiveCompletion: @escaping (Subscribers.Completion<Failure>) -> Void,
                     receiveValue: @escaping (Output) -> Void) -> AnyCancellable { AnyCancellable {} }
    public func map<T>(_ transform: @escaping (Output) -> T) -> Publishers.Map<Self, T> { Publishers.Map() }
    public func receive<S: Scheduler>(on scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.ReceiveOn<Self, S> { Publishers.ReceiveOn() }
    public func debounce<S: Scheduler>(for dueTime: S.SchedulerTimeType.Stride, scheduler: S, options: S.SchedulerOptions? = nil) -> Publishers.Debounce<Self, S> { Publishers.Debounce() }
    public func removeDuplicates() -> Publishers.RemoveDuplicates<Self> where Output: Equatable { Publishers.RemoveDuplicates() }
    public func compactMap<T>(_ transform: @escaping (Output) -> T?) -> Publishers.CompactMap<Self, T> { Publishers.CompactMap() }
    public func filter(_ isIncluded: @escaping (Output) -> Bool) -> Publishers.Filter<Self> { Publishers.Filter() }
    public func dropFirst(_ count: Int = 1) -> Publishers.Drop<Self> { Publishers.Drop() }
    public func first() -> Publishers.First<Self> { Publishers.First() }
    public func throttle<S: Scheduler>(for interval: S.SchedulerTimeType.Stride, scheduler: S, latest: Bool) -> Publishers.Throttle<Self, S> { Publishers.Throttle() }
    public func merge<P: Publisher>(with other: P) -> Publishers.Merge<Self, P> where P.Output == Output, P.Failure == Failure { Publishers.Merge() }
    public func assign<Root: AnyObject>(to keyPath: ReferenceWritableKeyPath<Root, Output>, on object: Root) -> AnyCancellable where Failure == Never { AnyCancellable {} }
}

public enum Subscribers {
    public enum Completion<Failure: Error> {
        case finished
        case failure(Failure)
    }
}

public enum Publishers {
    public struct Map<Upstream: Publisher, Output>: Publisher { public typealias Failure = Upstream.Failure; init() {} }
    public struct CompactMap<Upstream: Publisher, Output>: Publisher { public typealias Failure = Upstream.Failure; init() {} }
    public struct Filter<Upstream: Publisher>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct Drop<Upstream: Publisher>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct First<Upstream: Publisher>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct RemoveDuplicates<Upstream: Publisher>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct ReceiveOn<Upstream: Publisher, Context: Scheduler>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct Debounce<Upstream: Publisher, Context: Scheduler>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct Throttle<Upstream: Publisher, Context: Scheduler>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
    public struct Merge<A: Publisher, B: Publisher>: Publisher where A.Output == B.Output, A.Failure == B.Failure { public typealias Output = A.Output; public typealias Failure = A.Failure; init() {} }
    public struct Autoconnect<Upstream: ConnectablePublisher>: Publisher { public typealias Output = Upstream.Output; public typealias Failure = Upstream.Failure; init() {} }
}

public protocol ConnectablePublisher: Publisher {
    func connect() -> Cancellable
}
extension ConnectablePublisher {
    public func autoconnect() -> Publishers.Autoconnect<Self> { Publishers.Autoconnect() }
}

public protocol Scheduler {
    associatedtype SchedulerTimeType: Strideable where SchedulerTimeType.Stride: SchedulerTimeIntervalConvertible
    associatedtype SchedulerOptions
}
public protocol SchedulerTimeIntervalConvertible {
    static func seconds(_ s: Int) -> Self
    static func seconds(_ s: Double) -> Self
    static func milliseconds(_ ms: Int) -> Self
}

extension DispatchQueue: Scheduler {
    public struct SchedulerTimeType: Strideable {
        public struct Stride: Comparable, SchedulerTimeIntervalConvertible, SignedNumeric {
            public var magnitude: Double = 0
            public init?<T: BinaryInteger>(exactly source: T) { magnitude = Double(source) }
            public init(integerLiteral value: Int) { magnitude = Double(value) }
            public static func < (lhs: Stride, rhs: Stride) -> Bool { lhs.magnitude < rhs.magnitude }
            public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func += (lhs: inout Stride, rhs: Stride) {}
            public static func -= (lhs: inout Stride, rhs: Stride) {}
            public static func *= (lhs: inout Stride, rhs: Stride) {}
            public static func seconds(_ s: Int) -> Stride { Stride(integerLiteral: s) }
            public static func seconds(_ s: Double) -> Stride { Stride(integerLiteral: Int(s)) }
            public static func milliseconds(_ ms: Int) -> Stride { Stride(integerLiteral: ms) }
        }
        public var value: Double = 0
        public func distance(to other: SchedulerTimeType) -> Stride { Stride(integerLiteral: 0) }
        public func advanced(by n: Stride) -> SchedulerTimeType { self }
    }
    public struct SchedulerOptions {}
}

extension RunLoop: Scheduler {
    public struct SchedulerTimeType: Strideable {
        public struct Stride: Comparable, SchedulerTimeIntervalConvertible, SignedNumeric {
            public var magnitude: Double = 0
            public init?<T: BinaryInteger>(exactly source: T) { magnitude = Double(source) }
            public init(integerLiteral value: Int) { magnitude = Double(value) }
            public static func < (lhs: Stride, rhs: Stride) -> Bool { lhs.magnitude < rhs.magnitude }
            public static func + (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func - (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func * (lhs: Stride, rhs: Stride) -> Stride { lhs }
            public static func += (lhs: inout Stride, rhs: Stride) {}
            public static func -= (lhs: inout Stride, rhs: Stride) {}
            public static func *= (lhs: inout Stride, rhs: Stride) {}
            public static func seconds(_ s: Int) -> Stride { Stride(integerLiteral: s) }
            public static func seconds(_ s: Double) -> Stride { Stride(integerLiteral: Int(s)) }
            public static func milliseconds(_ ms: Int) -> Stride { Stride(integerLiteral: ms) }
        }
        public var value: Double = 0
        public func distance(to other: SchedulerTimeType) -> Stride { Stride(integerLiteral: 0) }
        public func advanced(by n: Stride) -> SchedulerTimeType { self }
    }
    public struct SchedulerOptions {}
}

// MARK: Foundation publishers

extension NotificationCenter {
    public struct Publisher: Combine.Publisher {
        public typealias Output = Notification
        public typealias Failure = Never
        public init(center: NotificationCenter, name: Notification.Name, object: AnyObject? = nil) {}
    }
    public func publisher(for name: Notification.Name, object: AnyObject? = nil) -> NotificationCenter.Publisher {
        Publisher(center: self, name: name, object: object)
    }
}

extension Timer {
    public final class TimerPublisher: ConnectablePublisher {
        public typealias Output = Date
        public typealias Failure = Never
        public init(interval: TimeInterval, tolerance: TimeInterval? = nil, runLoop: RunLoop, mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) {}
        public func connect() -> Cancellable { AnyCancellable {} }
    }
    public static func publish(every interval: TimeInterval, tolerance: TimeInterval? = nil, on runLoop: RunLoop, in mode: RunLoop.Mode, options: RunLoop.SchedulerOptions? = nil) -> Timer.TimerPublisher {
        TimerPublisher(interval: interval, tolerance: tolerance, runLoop: runLoop, mode: mode, options: options)
    }
}

// MARK: ObservableObject (legacy model objects)

public protocol ObservableObject: AnyObject {
    associatedtype ObjectWillChangePublisher: Publisher = ObservableObjectPublisher where ObjectWillChangePublisher.Failure == Never
    var objectWillChange: ObjectWillChangePublisher { get }
}
public final class ObservableObjectPublisher: Publisher {
    public typealias Output = Void
    public typealias Failure = Never
    public init() {}
    public func send() {}
}
extension ObservableObject where ObjectWillChangePublisher == ObservableObjectPublisher {
    public var objectWillChange: ObservableObjectPublisher { ObservableObjectPublisher() }
}

@propertyWrapper
public struct Published<Value> {
    public init(wrappedValue: Value) { self.storage = wrappedValue }
    public init(initialValue: Value) { self.storage = initialValue }
    private var storage: Value
    public var wrappedValue: Value {
        get { storage }
        set { storage = newValue }
    }
    public struct Publisher: Combine.Publisher {
        public typealias Output = Value
        public typealias Failure = Never
    }
    public var projectedValue: Publisher { Publisher() }
}
