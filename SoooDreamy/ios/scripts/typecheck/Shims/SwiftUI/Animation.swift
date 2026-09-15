// SwiftUI stub — animations, transitions, lifecycle & change observers,
// timeline views, symbol effects, matched geometry.
import Foundation

public struct Animation: Equatable, Sendable {
    public static let `default` = Animation()
    public static var linear: Animation { Animation() }
    public static func linear(duration: TimeInterval) -> Animation { Animation() }
    public static var easeIn: Animation { Animation() }
    public static func easeIn(duration: TimeInterval) -> Animation { Animation() }
    public static var easeOut: Animation { Animation() }
    public static func easeOut(duration: TimeInterval) -> Animation { Animation() }
    public static var easeInOut: Animation { Animation() }
    public static func easeInOut(duration: TimeInterval) -> Animation { Animation() }
    public static var spring: Animation { Animation() }
    public static func spring(duration: TimeInterval = 0.5, bounce: Double = 0.0, blendDuration: TimeInterval = 0) -> Animation { Animation() }
    public static func spring(_ spring: Spring, blendDuration: TimeInterval = 0.0) -> Animation { Animation() }
    public static func spring(response: Double = 0.5, dampingFraction: Double = 0.825, blendDuration: TimeInterval = 0) -> Animation { Animation() }
    public static func interactiveSpring(response: Double = 0.15, dampingFraction: Double = 0.86, blendDuration: TimeInterval = 0.25) -> Animation { Animation() }
    public static var interactiveSpring: Animation { Animation() }
    public static func interactiveSpring(duration: TimeInterval = 0.15, extraBounce: Double = 0.0, blendDuration: TimeInterval = 0.25) -> Animation { Animation() }
    public static func interpolatingSpring(mass: Double = 1.0, stiffness: Double, damping: Double, initialVelocity: Double = 0.0) -> Animation { Animation() }
    public static func interpolatingSpring(duration: TimeInterval = 0.5, bounce: Double = 0.0, initialVelocity: Double = 0.0) -> Animation { Animation() }
    public static var interpolatingSpring: Animation { Animation() }
    public static var smooth: Animation { Animation() }
    public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }
    public static var snappy: Animation { Animation() }
    public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }
    public static var bouncy: Animation { Animation() }
    public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Animation { Animation() }
    public static func timingCurve(_ c0x: Double, _ c0y: Double, _ c1x: Double, _ c1y: Double, duration: TimeInterval = 0.35) -> Animation { Animation() }
    public static func timingCurve(_ curve: UnitCurve, duration: TimeInterval) -> Animation { Animation() }
    public init<A: CustomAnimation>(_ base: A) {}
    public func delay(_ delay: TimeInterval) -> Animation { self }
    public func speed(_ speed: Double) -> Animation { self }
    public func repeatCount(_ repeatCount: Int, autoreverses: Bool = true) -> Animation { self }
    public func repeatForever(autoreverses: Bool = true) -> Animation { self }
    public func logicallyComplete(after duration: TimeInterval) -> Animation { self }
    private init() {}
}
public protocol CustomAnimation: Hashable, Sendable {}
public struct Spring: Hashable, Sendable {
    public init(duration: TimeInterval = 0.5, bounce: Double = 0.0) {}
    public init(response: Double, dampingRatio: Double) {}
    public init(mass: Double = 1.0, stiffness: Double, damping: Double, allowOverDamping: Bool = false) {}
    public init(settlingDuration: TimeInterval, dampingRatio: Double, epsilon: Double = 0.001) {}
    public static var smooth: Spring { Spring() }
    public static func smooth(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
    public static var snappy: Spring { Spring() }
    public static func snappy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
    public static var bouncy: Spring { Spring() }
    public static func bouncy(duration: TimeInterval = 0.5, extraBounce: Double = 0.0) -> Spring { Spring() }
    public var duration: TimeInterval { 0.5 }
    public var bounce: Double { 0 }
    public var response: Double { 0.5 }
    public var dampingRatio: Double { 1 }
    public var mass: Double { 1 }
    public var stiffness: Double { 100 }
    public var damping: Double { 10 }
    public var settlingDuration: TimeInterval { 0.5 }
}
public struct UnitCurve: Hashable, Sendable {
    public static let linear = UnitCurve(), easeIn = UnitCurve(), easeOut = UnitCurve(), easeInOut = UnitCurve(), circularEaseIn = UnitCurve(), circularEaseOut = UnitCurve(), circularEaseInOut = UnitCurve()
    public static func bezier(startControlPoint: UnitPoint, endControlPoint: UnitPoint) -> UnitCurve { UnitCurve() }
    public func value(at progress: Double) -> Double { progress }
    public func velocity(at progress: Double) -> Double { 1 }
    public var inverse: UnitCurve { self }
}
public struct Transaction {
    public init() {}
    public init(animation: Animation?) { self.animation = animation }
    public var animation: Animation?
    public var disablesAnimations: Bool = false
    public var isContinuous: Bool = false
    public var tracksVelocity: Bool = false
    public var animationCompletionCriteria: AnimationCompletionCriteria = .logicallyComplete
    public subscript<K: TransactionKey>(key: K.Type) -> K.Value { get { K.defaultValue } set {} }
    public mutating func addAnimationCompletion(criteria: AnimationCompletionCriteria = .logicallyComplete, _ completion: @escaping () -> Void) {}
}
public protocol TransactionKey { associatedtype Value; static var defaultValue: Value { get } }
public enum AnimationCompletionCriteria: Hashable, Sendable { case logicallyComplete, removed }

public func withAnimation<Result>(_ animation: Animation? = .default, _ body: () throws -> Result) rethrows -> Result { try body() }
public func withAnimation<Result>(_ animation: Animation? = .default, completionCriteria: AnimationCompletionCriteria = .logicallyComplete, _ body: () throws -> Result, completion: @escaping () -> Void) rethrows -> Result { try body() }
public func withTransaction<Result>(_ transaction: Transaction, _ body: () throws -> Result) rethrows -> Result { try body() }
public func withTransaction<R, V>(_ keyPath: WritableKeyPath<Transaction, V>, _ value: V, _ body: () throws -> R) rethrows -> R { try body() }

// MARK: Transitions

public protocol Transition {
    associatedtype Body: View
    @ViewBuilder func body(content: Self.Content, phase: TransitionPhase) -> Self.Body
    static var properties: TransitionProperties { get }
    typealias Content = PlaceholderContentView<Self>
}
extension Transition { public static var properties: TransitionProperties { TransitionProperties() } }
public struct PlaceholderContentView<Value>: View { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct TransitionProperties: Sendable { public init(hasMotion: Bool = true) {}; public var hasMotion: Bool { true } }
public enum TransitionPhase: Hashable, Sendable {
    case willAppear, identity, didDisappear
    public var isIdentity: Bool { self == .identity }
    public var value: Double { self == .identity ? 0 : (self == .willAppear ? -1 : 1) }
}
public struct AnyTransition: Sendable {
    public init<T: Transition>(_ transition: T) {}
    public static let identity = AnyTransition(IdentityTransition()), opacity = AnyTransition(OpacityTransition()), slide = AnyTransition(SlideTransition()), scale = AnyTransition(ScaleTransition())
    public static func scale(scale: CGFloat, anchor: UnitPoint = .center) -> AnyTransition { .scale }
    public static func move(edge: Edge) -> AnyTransition { .identity }
    public static func offset(_ offset: CGSize) -> AnyTransition { .identity }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> AnyTransition { .identity }
    public static func push(from edge: Edge) -> AnyTransition { .identity }
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition { insertion }
    public static func modifier<E: ViewModifier>(active: E, identity: E) -> AnyTransition { .identity }
    public static var blurReplace: AnyTransition { .identity }
    public static func blurReplace(_ config: BlurReplaceTransition.Configuration) -> AnyTransition { .identity }
    public static var symbolEffect: AnyTransition { .identity }
    public static func symbolEffect<T: SymbolEffect & TransitionSymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default) -> AnyTransition { .identity }
    public func combined(with other: AnyTransition) -> AnyTransition { self }
    public func animation(_ animation: Animation?) -> AnyTransition { self }
}
public struct IdentityTransition: Transition { public init() {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct OpacityTransition: Transition { public init() {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct SlideTransition: Transition { public init() {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct ScaleTransition: Transition { public init(_ scale: Double = 0, anchor: UnitPoint = .center) {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct MoveTransition: Transition { public init(edge: Edge) {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct OffsetTransition: Transition { public init(_ offset: CGSize) {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct PushTransition: Transition { public init(edge: Edge) {}; public func body(content: Content, phase: TransitionPhase) -> some View { content } }
public struct BlurReplaceTransition: Transition {
    public struct Configuration: Sendable { public static let downUp = Configuration(), upUp = Configuration() }
    public init(configuration: Configuration = .downUp) {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct AsymmetricTransition<Insertion: Transition, Removal: Transition>: Transition {
    public init(insertion: Insertion, removal: Removal) {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
public struct SymbolEffectTransition: Transition {
    public init<T: SymbolEffect & TransitionSymbolEffect>(effect: T, options: SymbolEffectOptions = .default) {}
    public func body(content: Content, phase: TransitionPhase) -> some View { content }
}
extension Transition where Self == IdentityTransition { public static var identity: IdentityTransition { IdentityTransition() } }
extension Transition where Self == OpacityTransition { public static var opacity: OpacityTransition { OpacityTransition() } }
extension Transition where Self == SlideTransition { public static var slide: SlideTransition { SlideTransition() } }
extension Transition where Self == ScaleTransition {
    public static var scale: ScaleTransition { ScaleTransition() }
    public static func scale(_ scale: Double, anchor: UnitPoint = .center) -> ScaleTransition { ScaleTransition(scale, anchor: anchor) }
}
extension Transition where Self == MoveTransition { public static func move(edge: Edge) -> MoveTransition { MoveTransition(edge: edge) } }
extension Transition where Self == OffsetTransition {
    public static func offset(_ offset: CGSize) -> OffsetTransition { OffsetTransition(offset) }
    public static func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetTransition { OffsetTransition(CGSize(width: x, height: y)) }
}
extension Transition where Self == PushTransition { public static func push(from edge: Edge) -> PushTransition { PushTransition(edge: edge) } }
extension Transition where Self == BlurReplaceTransition {
    public static var blurReplace: BlurReplaceTransition { BlurReplaceTransition() }
    public static func blurReplace(_ config: BlurReplaceTransition.Configuration) -> BlurReplaceTransition { BlurReplaceTransition(configuration: config) }
}
extension Transition where Self == SymbolEffectTransition {
    public static var symbolEffect: SymbolEffectTransition { SymbolEffectTransition(effect: AppearSymbolEffect()) }
    public static func symbolEffect<T: SymbolEffect & TransitionSymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default) -> SymbolEffectTransition { SymbolEffectTransition(effect: effect, options: options) }
}
extension Transition {
    public func combined<T: Transition>(with other: T) -> some Transition { self }
    public func animation(_ animation: Animation?) -> some Transition { self }
    public func apply<V: View>(content: V, phase: TransitionPhase) -> some View { content }
}
public struct ContentTransition: Equatable, Sendable {
    public static let identity = ContentTransition(), opacity = ContentTransition(), interpolate = ContentTransition(), numericText = ContentTransition(), symbolEffect = ContentTransition()
    public static func numericText(countsDown: Bool = false) -> ContentTransition { ContentTransition() }
    public static func numericText(value: Double) -> ContentTransition { ContentTransition() }
    public static func symbolEffect<T: SymbolEffect & ContentTransitionSymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default) -> ContentTransition { ContentTransition() }
}

// MARK: Symbol effects

public protocol SymbolEffect: Hashable, Sendable {}
public protocol IndefiniteSymbolEffect {}
public protocol DiscreteSymbolEffect {}
public protocol TransitionSymbolEffect {}
public protocol ContentTransitionSymbolEffect {}
public struct SymbolEffectOptions: Hashable, Sendable {
    public static let `default` = SymbolEffectOptions()
    public static var repeating: SymbolEffectOptions { SymbolEffectOptions() }
    public static func `repeat`(_ count: Int?) -> SymbolEffectOptions { SymbolEffectOptions() }
    public static func `repeat`(_ behavior: RepeatBehavior) -> SymbolEffectOptions { SymbolEffectOptions() }
    public static var nonRepeating: SymbolEffectOptions { SymbolEffectOptions() }
    public static func speed(_ speed: Double) -> SymbolEffectOptions { SymbolEffectOptions() }
    public func `repeat`(_ count: Int?) -> SymbolEffectOptions { self }
    public func `repeat`(_ behavior: RepeatBehavior) -> SymbolEffectOptions { self }
    public var repeating: SymbolEffectOptions { self }
    public var nonRepeating: SymbolEffectOptions { self }
    public func speed(_ speed: Double) -> SymbolEffectOptions { self }
    public struct RepeatBehavior: Hashable, Sendable {
        public static var periodic: RepeatBehavior { RepeatBehavior() }
        public static func periodic(_ count: Int? = nil, delay: Double? = nil) -> RepeatBehavior { RepeatBehavior() }
        public static var continuous: RepeatBehavior { RepeatBehavior() }
    }
}
public struct AppearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect { public init() {}; public var up: AppearSymbolEffect { self }; public var down: AppearSymbolEffect { self }; public var byLayer: AppearSymbolEffect { self }; public var wholeSymbol: AppearSymbolEffect { self } }
public struct DisappearSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect { public init() {}; public var up: DisappearSymbolEffect { self }; public var down: DisappearSymbolEffect { self }; public var byLayer: DisappearSymbolEffect { self }; public var wholeSymbol: DisappearSymbolEffect { self } }
public struct BounceSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var up: BounceSymbolEffect { self }; public var down: BounceSymbolEffect { self }; public var byLayer: BounceSymbolEffect { self }; public var wholeSymbol: BounceSymbolEffect { self } }
public struct PulseSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var byLayer: PulseSymbolEffect { self }; public var wholeSymbol: PulseSymbolEffect { self } }
public struct VariableColorSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var iterative: VariableColorSymbolEffect { self }; public var cumulative: VariableColorSymbolEffect { self }; public var reversing: VariableColorSymbolEffect { self }; public var nonReversing: VariableColorSymbolEffect { self }; public var hideInactiveLayers: VariableColorSymbolEffect { self }; public var dimInactiveLayers: VariableColorSymbolEffect { self } }
public struct ScaleSymbolEffect: SymbolEffect, IndefiniteSymbolEffect { public init() {}; public var up: ScaleSymbolEffect { self }; public var down: ScaleSymbolEffect { self }; public var byLayer: ScaleSymbolEffect { self }; public var wholeSymbol: ScaleSymbolEffect { self } }
public struct ReplaceSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect { public init() {}; public var downUp: ReplaceSymbolEffect { self }; public var upUp: ReplaceSymbolEffect { self }; public var offUp: ReplaceSymbolEffect { self }; public var byLayer: ReplaceSymbolEffect { self }; public var wholeSymbol: ReplaceSymbolEffect { self }; public var magic: ReplaceSymbolEffect { self }; public func magic(fallback: ReplaceSymbolEffect) -> ReplaceSymbolEffect { self } }
public struct AutomaticSymbolEffect: SymbolEffect, ContentTransitionSymbolEffect, TransitionSymbolEffect { public init() {} }
public struct WiggleSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var clockwise: WiggleSymbolEffect { self }; public var counterClockwise: WiggleSymbolEffect { self }; public var up: WiggleSymbolEffect { self }; public var down: WiggleSymbolEffect { self }; public var left: WiggleSymbolEffect { self }; public var right: WiggleSymbolEffect { self }; public var byLayer: WiggleSymbolEffect { self }; public var wholeSymbol: WiggleSymbolEffect { self }; public func custom(angle: Double) -> WiggleSymbolEffect { self } }
public struct RotateSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var clockwise: RotateSymbolEffect { self }; public var counterClockwise: RotateSymbolEffect { self }; public var byLayer: RotateSymbolEffect { self }; public var wholeSymbol: RotateSymbolEffect { self } }
public struct BreatheSymbolEffect: SymbolEffect, DiscreteSymbolEffect, IndefiniteSymbolEffect { public init() {}; public var plain: BreatheSymbolEffect { self }; public var pulse: BreatheSymbolEffect { self }; public var byLayer: BreatheSymbolEffect { self }; public var wholeSymbol: BreatheSymbolEffect { self } }
public struct DrawOnSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect { public init() {}; public var byLayer: DrawOnSymbolEffect { self }; public var wholeSymbol: DrawOnSymbolEffect { self }; public var individually: DrawOnSymbolEffect { self } }
public struct DrawOffSymbolEffect: SymbolEffect, IndefiniteSymbolEffect, TransitionSymbolEffect { public init() {}; public var byLayer: DrawOffSymbolEffect { self }; public var wholeSymbol: DrawOffSymbolEffect { self }; public var individually: DrawOffSymbolEffect { self } }
extension SymbolEffect where Self == AppearSymbolEffect { public static var appear: AppearSymbolEffect { AppearSymbolEffect() } }
extension SymbolEffect where Self == DisappearSymbolEffect { public static var disappear: DisappearSymbolEffect { DisappearSymbolEffect() } }
extension SymbolEffect where Self == BounceSymbolEffect { public static var bounce: BounceSymbolEffect { BounceSymbolEffect() } }
extension SymbolEffect where Self == PulseSymbolEffect { public static var pulse: PulseSymbolEffect { PulseSymbolEffect() } }
extension SymbolEffect where Self == VariableColorSymbolEffect { public static var variableColor: VariableColorSymbolEffect { VariableColorSymbolEffect() } }
extension SymbolEffect where Self == ScaleSymbolEffect { public static var scale: ScaleSymbolEffect { ScaleSymbolEffect() } }
extension SymbolEffect where Self == ReplaceSymbolEffect { public static var replace: ReplaceSymbolEffect { ReplaceSymbolEffect() } }
extension SymbolEffect where Self == AutomaticSymbolEffect { public static var automatic: AutomaticSymbolEffect { AutomaticSymbolEffect() } }
extension SymbolEffect where Self == WiggleSymbolEffect { public static var wiggle: WiggleSymbolEffect { WiggleSymbolEffect() } }
extension SymbolEffect where Self == RotateSymbolEffect { public static var rotate: RotateSymbolEffect { RotateSymbolEffect() } }
extension SymbolEffect where Self == BreatheSymbolEffect { public static var breathe: BreatheSymbolEffect { BreatheSymbolEffect() } }
extension SymbolEffect where Self == DrawOnSymbolEffect { public static var drawOn: DrawOnSymbolEffect { DrawOnSymbolEffect() } }
extension SymbolEffect where Self == DrawOffSymbolEffect { public static var drawOff: DrawOffSymbolEffect { DrawOffSymbolEffect() } }

extension View {
    public func transition(_ t: AnyTransition) -> some View { self }
    public func transition<T: Transition>(_ transition: T) -> some View { self }
    public func contentTransition(_ transition: ContentTransition) -> some View { self }
    public func animation(_ animation: Animation?) -> some View { self }
    public func animation<V: Equatable>(_ animation: Animation?, value: V) -> some View { self }
    public func animation<V: View>(_ animation: Animation?, @ViewBuilder body: (PlaceholderContentView<Self>) -> V) -> some View { self }
    public func transaction(_ transform: @escaping (inout Transaction) -> Void) -> some View { self }
    public func transaction<V: Equatable>(value: V, _ transform: @escaping (inout Transaction) -> Void) -> some View { self }
    public func transaction<V: View>(_ transform: @escaping (inout Transaction) -> Void, @ViewBuilder body: (PlaceholderContentView<Self>) -> V) -> some View { self }
    public func matchedGeometryEffect<ID: Hashable>(id: ID, in namespace: Namespace.ID, properties: MatchedGeometryProperties = .frame, anchor: UnitPoint = .center, isSource: Bool = true) -> some View { self }
    public func symbolEffect<T: IndefiniteSymbolEffect & SymbolEffect>(_ effect: T, options: SymbolEffectOptions = .default, isActive: Bool = true) -> some View { self }
    public func symbolEffect<T: DiscreteSymbolEffect & SymbolEffect, U: Equatable>(_ effect: T, options: SymbolEffectOptions = .default, value: U) -> some View { self }
    public func symbolEffectsRemoved(_ isEnabled: Bool = true) -> some View { self }
    public func phaseAnimator<Phase: Equatable, C: View>(_ phases: some Sequence<Phase>, @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> C, animation: @escaping (Phase) -> Animation? = { _ in .default }) -> some View { self }
    public func phaseAnimator<Phase: Equatable, C: View, T: Equatable>(_ phases: some Sequence<Phase>, trigger: T, @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Phase) -> C, animation: @escaping (Phase) -> Animation? = { _ in .default }) -> some View { self }
    public func keyframeAnimator<Value, C: View, KP: Keyframes>(initialValue: Value, repeating: Bool = true, @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> C, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KP) -> some View where KP.Value == Value { self }
    public func keyframeAnimator<Value, C: View, KP: Keyframes, T: Equatable>(initialValue: Value, trigger: T, @ViewBuilder content: @escaping (PlaceholderContentView<Self>, Value) -> C, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KP) -> some View where KP.Value == Value { self }
}
public struct MatchedGeometryProperties: OptionSet, Sendable {
    public let rawValue: UInt32
    public init(rawValue: UInt32) { self.rawValue = rawValue }
    public static let position = MatchedGeometryProperties(rawValue: 1), size = MatchedGeometryProperties(rawValue: 2), frame = MatchedGeometryProperties(rawValue: 3)
}
public protocol Keyframes<Value> { associatedtype Value }
@resultBuilder public struct KeyframesBuilder<Value> {
    public static func buildBlock<K: Keyframes>(_ k: K) -> K where K.Value == Value { k }
    public static func buildBlock<K0: Keyframes, K1: Keyframes>(_ k0: K0, _ k1: K1) -> _AnyKeyframes<Value> { _AnyKeyframes() }
    public static func buildBlock<K0: Keyframes, K1: Keyframes, K2: Keyframes>(_ k0: K0, _ k1: K1, _ k2: K2) -> _AnyKeyframes<Value> { _AnyKeyframes() }
}
public struct _AnyKeyframes<Value>: Keyframes {}
public struct KeyframeTrack<Root, Value, Content>: Keyframes {
    public init(_ keyPath: WritableKeyPath<Root, Value>, @KeyframeTrackContentBuilder<Value> content: () -> Content) {}
    public init(@KeyframeTrackContentBuilder<Root> content: () -> Content) where Root == Value {}
}
@resultBuilder public struct KeyframeTrackContentBuilder<Value> {
    public static func buildBlock<C>(_ c: C) -> C { c }
    public static func buildBlock<C0, C1>(_ c0: C0, _ c1: C1) -> (C0, C1) { (c0, c1) }
    public static func buildBlock<C0, C1, C2>(_ c0: C0, _ c1: C1, _ c2: C2) -> (C0, C1, C2) { (c0, c1, c2) }
    public static func buildBlock<C0, C1, C2, C3>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> (C0, C1, C2, C3) { (c0, c1, c2, c3) }
}
public struct LinearKeyframe<Value> { public init(_ to: Value, duration: TimeInterval, timingCurve: UnitCurve = .linear) {} }
public struct SpringKeyframe<Value> { public init(_ to: Value, duration: TimeInterval? = nil, spring: Spring = Spring(), startVelocity: Value? = nil) {} }
public struct CubicKeyframe<Value> { public init(_ to: Value, duration: TimeInterval, startVelocity: Value? = nil, endVelocity: Value? = nil) {} }
public struct MoveKeyframe<Value> { public init(_ to: Value) {} }
public struct PhaseAnimator<Phase: Equatable, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ phases: some Sequence<Phase>, @ViewBuilder content: @escaping (Phase) -> Content, animation: @escaping (Phase) -> Animation? = { _ in .default }) {}
    public init<T: Equatable>(_ phases: some Sequence<Phase>, trigger: T, @ViewBuilder content: @escaping (Phase) -> Content, animation: @escaping (Phase) -> Animation? = { _ in .default }) {}
}
public struct KeyframeAnimator<Value, KeyframePath: Keyframes, Content: View>: View where KeyframePath.Value == Value {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(initialValue: Value, repeating: Bool = true, @ViewBuilder content: @escaping (Value) -> Content, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {}
    public init<T: Equatable>(initialValue: Value, trigger: T, @ViewBuilder content: @escaping (Value) -> Content, @KeyframesBuilder<Value> keyframes: @escaping (Value) -> KeyframePath) {}
}

// MARK: Lifecycle & observation

extension View {
    public func onAppear(perform action: (() -> Void)? = nil) -> some View { self }
    public func onDisappear(perform action: (() -> Void)? = nil) -> some View { self }
    public func task(priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View { self }
    public func task<T: Equatable>(id value: T, priority: TaskPriority = .userInitiated, @_inheritActorContext _ action: @escaping @Sendable () async -> Void) -> some View { self }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping (V, V) -> Void) -> some View { self }
    public func onChange<V: Equatable>(of value: V, initial: Bool = false, _ action: @escaping () -> Void) -> some View { self }
    public func onReceive<P: Publisher>(_ publisher: P, perform action: @escaping (P.Output) -> Void) -> some View where P.Failure == Never { self }
    public func onTapGesture(count: Int = 1, perform action: @escaping () -> Void) -> some View { self }
    public func onTapGesture(count: Int = 1, coordinateSpace: some CoordinateSpaceProtocol = .local, perform action: @escaping (CGPoint) -> Void) -> some View { self }
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, perform action: @escaping () -> Void, onPressingChanged: ((Bool) -> Void)? = nil) -> some View { self }
    public func onLongPressGesture(minimumDuration: Double = 0.5, maximumDistance: CGFloat = 10, pressing: ((Bool) -> Void)? = nil, perform action: @escaping () -> Void) -> some View { self }
    public func onHover(perform action: @escaping (Bool) -> Void) -> some View { self }
    public func onKeyPress(_ key: KeyEquivalent, action: @escaping () -> KeyPress.Result) -> some View { self }
    public func onKeyPress(phases: KeyPress.Phases = .down, action: @escaping (KeyPress) -> KeyPress.Result) -> some View { self }
    public func onPreferenceChange<K: PreferenceKey>(_ key: K.Type = K.self, perform action: @escaping (K.Value) -> Void) -> some View where K.Value: Equatable { self }
    public func preference<K: PreferenceKey>(key: K.Type = K.self, value: K.Value) -> some View { self }
    public func transformPreference<K: PreferenceKey>(_ key: K.Type = K.self, _ callback: @escaping (inout K.Value) -> Void) -> some View { self }
    public func anchorPreference<A, K: PreferenceKey>(key: K.Type = K.self, value: Anchor<A>.Source, transform: @escaping (Anchor<A>) -> K.Value) -> some View { self }
    public func backgroundPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View { self }
    public func overlayPreferenceValue<K: PreferenceKey, V: View>(_ key: K.Type = K.self, @ViewBuilder _ transform: @escaping (K.Value) -> V) -> some View { self }
    public func onDrag(_ data: @escaping () -> NSItemProvider) -> some View { self }
    public func draggable<T: Transferable>(_ payload: @autoclosure @escaping () -> T) -> some View { self }
    public func draggable<T: Transferable, V: View>(_ payload: @autoclosure @escaping () -> T, @ViewBuilder preview: () -> V) -> some View { self }
    public func dropDestination<T: Transferable>(for payloadType: T.Type = T.self, action: @escaping ([T], CGPoint) -> Bool, isTargeted: @escaping (Bool) -> Void = { _ in }) -> some View { self }
}
public protocol PreferenceKey {
    associatedtype Value
    static var defaultValue: Value { get }
    static func reduce(value: inout Value, nextValue: () -> Value)
}
extension PreferenceKey where Value: ExpressibleByNilLiteral { public static var defaultValue: Value { nil } }
public struct KeyPress: Sendable {
    public let phase: Phases = .down
    public let key: KeyEquivalent = .space
    public let characters: String = ""
    public let modifiers: EventModifiers = []
    public enum Result: Sendable { case handled, ignored }
    public struct Phases: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let down = Phases(rawValue: 1), `repeat` = Phases(rawValue: 2), up = Phases(rawValue: 4), all = Phases(rawValue: 7) }
}
public final class NSItemProvider: NSObject {
    public override init() { super.init() }
    public init(object: NSObject) { super.init() }
}

// MARK: TimelineView

public protocol TimelineSchedule {
    associatedtype Entries: Sequence where Entries.Element == Date
    func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries
}
public enum TimelineScheduleMode: Hashable, Sendable { case normal, lowFrequency }
public struct PeriodicTimelineSchedule: TimelineSchedule, Sendable {
    public struct Entries: Sequence, IteratorProtocol, Sendable { public mutating func next() -> Date? { nil } }
    public init(from startDate: Date, by interval: TimeInterval) {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { Entries() }
}
public struct EveryMinuteTimelineSchedule: TimelineSchedule, Sendable {
    public struct Entries: Sequence, IteratorProtocol, Sendable { public mutating func next() -> Date? { nil } }
    public init() {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { Entries() }
}
public struct AnimationTimelineSchedule: TimelineSchedule, Sendable {
    public struct Entries: Sequence, IteratorProtocol, Sendable { public mutating func next() -> Date? { nil } }
    public init(minimumInterval: Double? = nil, paused: Bool = false) {}
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { Entries() }
}
public struct ExplicitTimelineSchedule<Entries: Sequence>: TimelineSchedule where Entries.Element == Date {
    public init(_ dates: Entries) { self.dates = dates }
    let dates: Entries
    public func entries(from startDate: Date, mode: TimelineScheduleMode) -> Entries { dates }
}
extension TimelineSchedule where Self == PeriodicTimelineSchedule {
    public static func periodic(from startDate: Date, by interval: TimeInterval) -> PeriodicTimelineSchedule { PeriodicTimelineSchedule(from: startDate, by: interval) }
}
extension TimelineSchedule where Self == EveryMinuteTimelineSchedule { public static var everyMinute: EveryMinuteTimelineSchedule { EveryMinuteTimelineSchedule() } }
extension TimelineSchedule where Self == AnimationTimelineSchedule {
    public static var animation: AnimationTimelineSchedule { AnimationTimelineSchedule() }
    public static func animation(minimumInterval: Double? = nil, paused: Bool = false) -> AnimationTimelineSchedule { AnimationTimelineSchedule(minimumInterval: minimumInterval, paused: paused) }
}
extension TimelineSchedule {
    public static func explicit<S: Sequence>(_ dates: S) -> ExplicitTimelineSchedule<S> where Self == ExplicitTimelineSchedule<S>, S.Element == Date { ExplicitTimelineSchedule(dates) }
}
public struct TimelineViewDefaultContext {
    public let date: Date = Date()
    public let cadence: Cadence = .live
    public enum Cadence: Comparable, Hashable, Sendable { case live, seconds, minutes }
}
public struct TimelineView<Schedule: TimelineSchedule, Content: View>: View {
    public typealias Context = TimelineViewDefaultContext
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ schedule: Schedule, @ViewBuilder content: @escaping (TimelineViewDefaultContext) -> Content) {}
}
