// SwiftUI stub — Color, ShapeStyle, gradients, Font, shapes, Canvas, Image,
// visual-effect modifiers.
import Foundation

// MARK: Animatable

public protocol VectorArithmetic: AdditiveArithmetic {
    mutating func scale(by rhs: Double)
    var magnitudeSquared: Double { get }
}
extension Double: VectorArithmetic { public mutating func scale(by rhs: Double) { self *= rhs }; public var magnitudeSquared: Double { self * self } }
extension Float: VectorArithmetic { public mutating func scale(by rhs: Double) { self *= Float(rhs) }; public var magnitudeSquared: Double { Double(self * self) } }
extension CGFloat: VectorArithmetic { public mutating func scale(by rhs: Double) { self *= CGFloat(rhs) }; public var magnitudeSquared: Double { Double(self * self) } }
public struct AnimatablePair<First: VectorArithmetic, Second: VectorArithmetic>: VectorArithmetic {
    public var first: First, second: Second
    public init(_ first: First, _ second: Second) { self.first = first; self.second = second }
    public static var zero: AnimatablePair { AnimatablePair(.zero, .zero) }
    public static func + (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair { AnimatablePair(lhs.first + rhs.first, lhs.second + rhs.second) }
    public static func - (lhs: AnimatablePair, rhs: AnimatablePair) -> AnimatablePair { AnimatablePair(lhs.first - rhs.first, lhs.second - rhs.second) }
    public mutating func scale(by rhs: Double) { first.scale(by: rhs); second.scale(by: rhs) }
    public var magnitudeSquared: Double { first.magnitudeSquared + second.magnitudeSquared }
}
public protocol Animatable {
    associatedtype AnimatableData: VectorArithmetic = EmptyAnimatableData
    var animatableData: AnimatableData { get set }
}
extension Animatable where AnimatableData == EmptyAnimatableData {
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
extension CGPoint: Animatable { public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { AnimatablePair(x, y) } set { x = newValue.first; y = newValue.second } } }
extension CGSize: Animatable { public var animatableData: AnimatablePair<CGFloat, CGFloat> { get { AnimatablePair(width, height) } set { width = newValue.first; height = newValue.second } } }
extension CGRect: Animatable { public var animatableData: AnimatablePair<CGPoint.AnimatableData, CGSize.AnimatableData> { get { AnimatablePair(origin.animatableData, size.animatableData) } set { origin.animatableData = newValue.first; size.animatableData = newValue.second } } }

// MARK: ShapeStyle & Color

public protocol ShapeStyle: Sendable {
    associatedtype Resolved: ShapeStyle = Never
    func resolve(in environment: EnvironmentValues) -> Self.Resolved
}
extension ShapeStyle where Resolved == Never {
    public func resolve(in environment: EnvironmentValues) -> Never { return fatalError() }
}
extension Never: ShapeStyle {}

public struct Color: Hashable, Sendable, ShapeStyle, View, Codable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    private let tag: Int
    private init(tag: Int) { self.tag = tag }
    public enum RGBColorSpace: Hashable, Sendable { case sRGB, sRGBLinear, displayP3 }
    public init(_ colorSpace: RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) { tag = 0 }
    public init(_ colorSpace: RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) { tag = 0 }
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) { tag = 0 }
    public init(_ name: String, bundle: Bundle? = nil) { tag = 0 }
    public init(uiColor: UIColor) { tag = 0 }
    public init(cgColor: CGColor) { tag = 0 }
    public init(_ color: UIColor) { tag = 0 }
    public init(_ cgColor: CGColor) { tag = 0 }
    public init(_ resolved: Color.Resolved) { tag = 0 }
    public init(from decoder: any Decoder) throws { tag = 0 }
    public func encode(to encoder: any Encoder) throws {}
    public func opacity(_ opacity: Double) -> Color { self }
    public var gradient: AnyGradient { AnyGradient(Gradient(colors: [self])) }
    public func mix(with rhs: Color, by fraction: Double, in colorSpace: Gradient.ColorSpace = .perceptual) -> Color { self }
    public var cgColor: CGColor? { nil }
    public var description: String { "Color" }
    public func resolve(in environment: EnvironmentValues) -> Color.Resolved { Resolved(red: 0, green: 0, blue: 0, opacity: 1) }
    public struct Resolved: Hashable, Sendable, ShapeStyle, Codable {
        public var red: Float, green: Float, blue: Float, opacity: Float
        public init(red: Float, green: Float, blue: Float, opacity: Float = 1) { self.red = red; self.green = green; self.blue = blue; self.opacity = opacity }
        public init(colorSpace: RGBColorSpace = .sRGB, red: Float, green: Float, blue: Float, opacity: Float = 1) { self.red = red; self.green = green; self.blue = blue; self.opacity = opacity }
        public var cgColor: CGColor { CGColor() }
    }

    public static let clear = Color(tag: 1), black = Color(tag: 2), white = Color(tag: 3), gray = Color(tag: 4), red = Color(tag: 5), green = Color(tag: 6),
        blue = Color(tag: 7), orange = Color(tag: 8), yellow = Color(tag: 9), pink = Color(tag: 10), purple = Color(tag: 11), primary = Color(tag: 12),
        secondary = Color(tag: 13), accentColor = Color(tag: 14), mint = Color(tag: 15), teal = Color(tag: 16), cyan = Color(tag: 17), indigo = Color(tag: 18), brown = Color(tag: 19)
}
extension UIColor {
    public convenience init(_ color: Color) { self.init() }
}

public struct AnyShapeStyle: ShapeStyle {
    public init<S: ShapeStyle>(_ style: S) {}
}
public struct AnyGradient: ShapeStyle, Hashable, Sendable {
    public init(_ gradient: Gradient) {}
    public func colorSpace(_ space: Gradient.ColorSpace) -> AnyGradient { self }
}
public struct Gradient: Hashable, Sendable, ShapeStyle {
    public struct Stop: Hashable, Sendable {
        public var color: Color
        public var location: CGFloat
        public init(color: Color, location: CGFloat) { self.color = color; self.location = location }
    }
    public struct ColorSpace: Hashable, Sendable { public static let device = ColorSpace(), perceptual = ColorSpace() }
    public var stops: [Stop]
    public init(colors: [Color]) { stops = colors.map { Stop(color: $0, location: 0) } }
    public init(stops: [Stop]) { self.stops = stops }
    public func colorSpace(_ space: ColorSpace) -> AnyGradient { AnyGradient(self) }
}
public struct LinearGradient: ShapeStyle, View, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) {}
    public init(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) {}
    public init(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) {}
}
public struct RadialGradient: ShapeStyle, View, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public init(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
    public init(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) {}
}
public struct AngularGradient: ShapeStyle, View, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(gradient: Gradient, center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    public init(colors: [Color], center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    public init(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle = .zero, endAngle: Angle = .zero) {}
    public init(gradient: Gradient, center: UnitPoint, angle: Angle = .zero) {}
    public init(colors: [Color], center: UnitPoint, angle: Angle = .zero) {}
    public init(stops: [Gradient.Stop], center: UnitPoint, angle: Angle = .zero) {}
}
public struct EllipticalGradient: ShapeStyle, View, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
    public init(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
    public init(stops: [Gradient.Stop], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) {}
}
public struct MeshGradient: ShapeStyle, View, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(width: Int, height: Int, points: [SIMD2<Float>], colors: [Color], background: Color = .clear, smoothsColors: Bool = true, colorSpace: Gradient.ColorSpace = .device) {}
}
public struct ImagePaint: ShapeStyle, Sendable {
    public init(image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) {}
}
public struct HierarchicalShapeStyle: ShapeStyle, Sendable {
    public static let primary = HierarchicalShapeStyle(), secondary = HierarchicalShapeStyle(), tertiary = HierarchicalShapeStyle(), quaternary = HierarchicalShapeStyle(), quinary = HierarchicalShapeStyle()
}
public struct ForegroundStyle: ShapeStyle, Sendable { public init() {} }
public struct BackgroundStyle: ShapeStyle, Sendable { public init() {} }
public struct TintShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct SeparatorShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct SelectionShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct FillShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct LinkShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct PlaceholderTextShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct WindowBackgroundShapeStyle: ShapeStyle, Sendable { public init() {} }
public struct Material: ShapeStyle, Sendable {
    public static let ultraThinMaterial = Material(), thinMaterial = Material(), regularMaterial = Material(), thickMaterial = Material(), ultraThickMaterial = Material(), bar = Material()
    public static let ultraThin = Material(), thin = Material(), regular = Material(), thick = Material(), ultraThick = Material()
}

extension ShapeStyle where Self == Color {
    public static var clear: Color { .clear }
    public static var black: Color { .black }
    public static var white: Color { .white }
    public static var gray: Color { .gray }
    public static var red: Color { .red }
    public static var green: Color { .green }
    public static var blue: Color { .blue }
    public static var orange: Color { .orange }
    public static var yellow: Color { .yellow }
    public static var pink: Color { .pink }
    public static var purple: Color { .purple }
    public static var mint: Color { .mint }
    public static var teal: Color { .teal }
    public static var cyan: Color { .cyan }
    public static var indigo: Color { .indigo }
    public static var brown: Color { .brown }
    public static var accentColor: Color { .accentColor }
}
extension ShapeStyle where Self == HierarchicalShapeStyle {
    public static var primary: HierarchicalShapeStyle { .primary }
    public static var secondary: HierarchicalShapeStyle { .secondary }
    public static var tertiary: HierarchicalShapeStyle { .tertiary }
    public static var quaternary: HierarchicalShapeStyle { .quaternary }
    public static var quinary: HierarchicalShapeStyle { .quinary }
}
extension ShapeStyle where Self == ForegroundStyle { public static var foreground: ForegroundStyle { ForegroundStyle() } }
extension ShapeStyle where Self == BackgroundStyle { public static var background: BackgroundStyle { BackgroundStyle() } }
extension ShapeStyle where Self == TintShapeStyle { public static var tint: TintShapeStyle { TintShapeStyle() } }
extension ShapeStyle where Self == SeparatorShapeStyle { public static var separator: SeparatorShapeStyle { SeparatorShapeStyle() } }
extension ShapeStyle where Self == SelectionShapeStyle { public static var selection: SelectionShapeStyle { SelectionShapeStyle() } }
extension ShapeStyle where Self == FillShapeStyle { public static var fill: FillShapeStyle { FillShapeStyle() } }
extension ShapeStyle where Self == LinkShapeStyle { public static var link: LinkShapeStyle { LinkShapeStyle() } }
extension ShapeStyle where Self == PlaceholderTextShapeStyle { public static var placeholder: PlaceholderTextShapeStyle { PlaceholderTextShapeStyle() } }
extension ShapeStyle where Self == WindowBackgroundShapeStyle { public static var windowBackground: WindowBackgroundShapeStyle { WindowBackgroundShapeStyle() } }
extension ShapeStyle where Self == Material {
    public static var ultraThinMaterial: Material { .ultraThinMaterial }
    public static var thinMaterial: Material { .thinMaterial }
    public static var regularMaterial: Material { .regularMaterial }
    public static var thickMaterial: Material { .thickMaterial }
    public static var ultraThickMaterial: Material { .ultraThickMaterial }
    public static var bar: Material { .bar }
}
extension ShapeStyle where Self == LinearGradient {
    public static func linearGradient(_ gradient: Gradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(gradient: gradient, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(_ gradient: AnyGradient, startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(colors: [], startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(colors: [Color], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(colors: colors, startPoint: startPoint, endPoint: endPoint) }
    public static func linearGradient(stops: [Gradient.Stop], startPoint: UnitPoint, endPoint: UnitPoint) -> LinearGradient { LinearGradient(stops: stops, startPoint: startPoint, endPoint: endPoint) }
}
extension ShapeStyle where Self == RadialGradient {
    public static func radialGradient(_ gradient: Gradient, center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(gradient: gradient, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(_ gradient: AnyGradient, center: UnitPoint = .center, startRadius: CGFloat = 0, endRadius: CGFloat) -> RadialGradient { RadialGradient(colors: [], center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(colors: [Color], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(colors: colors, center: center, startRadius: startRadius, endRadius: endRadius) }
    public static func radialGradient(stops: [Gradient.Stop], center: UnitPoint, startRadius: CGFloat, endRadius: CGFloat) -> RadialGradient { RadialGradient(stops: stops, center: center, startRadius: startRadius, endRadius: endRadius) }
}
extension ShapeStyle where Self == AngularGradient {
    public static func angularGradient(_ gradient: Gradient, center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(gradient: gradient, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func angularGradient(colors: [Color], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(colors: colors, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func angularGradient(stops: [Gradient.Stop], center: UnitPoint, startAngle: Angle, endAngle: Angle) -> AngularGradient { AngularGradient(stops: stops, center: center, startAngle: startAngle, endAngle: endAngle) }
    public static func conicGradient(_ gradient: Gradient, center: UnitPoint, angle: Angle = .zero) -> AngularGradient { AngularGradient(gradient: gradient, center: center, angle: angle) }
    public static func conicGradient(colors: [Color], center: UnitPoint, angle: Angle = .zero) -> AngularGradient { AngularGradient(colors: colors, center: center, angle: angle) }
}
extension ShapeStyle where Self == EllipticalGradient {
    public static func ellipticalGradient(_ gradient: Gradient, center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient { EllipticalGradient(gradient: gradient, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction) }
    public static func ellipticalGradient(colors: [Color], center: UnitPoint = .center, startRadiusFraction: CGFloat = 0, endRadiusFraction: CGFloat = 0.5) -> EllipticalGradient { EllipticalGradient(colors: colors, center: center, startRadiusFraction: startRadiusFraction, endRadiusFraction: endRadiusFraction) }
}
extension ShapeStyle where Self == ImagePaint {
    public static func image(_ image: Image, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> ImagePaint { ImagePaint(image: image, sourceRect: sourceRect, scale: scale) }
}
extension ShapeStyle {
    public func opacity(_ opacity: Double) -> some ShapeStyle { self }
    public func blendMode(_ mode: BlendMode) -> some ShapeStyle { self }
    public func shadow(_ style: ShadowStyle) -> some ShapeStyle { self }
    public static func hierarchical<S: ShapeStyle>(_ style: S) -> some ShapeStyle { style }
}
public struct ShadowStyle: Hashable, Sendable {
    public static func drop(color: Color = .init(.sRGB, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle { ShadowStyle() }
    public static func inner(color: Color = .init(.sRGB, white: 0, opacity: 0.55), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> ShadowStyle { ShadowStyle() }
}
public enum BlendMode: Hashable, Sendable {
    case normal, multiply, screen, overlay, darken, lighten, colorDodge, colorBurn, softLight, hardLight, difference, exclusion, hue, saturation, color, luminosity,
         sourceAtop, destinationOver, destinationOut, plusDarker, plusLighter
}
public enum ColorRenderingMode: Hashable, Sendable { case nonLinear, linear, extendedLinear }

// MARK: Font

public struct Font: Hashable, Sendable {
    private let tag: String
    private init(_ tag: String) { self.tag = tag }
    public enum TextStyle: CaseIterable, Hashable, Sendable { case largeTitle, extraLargeTitle, extraLargeTitle2, title, title2, title3, headline, subheadline, body, callout, footnote, caption, caption2 }
    public enum Design: Hashable, Sendable { case `default`, serif, rounded, monospaced }
    public struct Weight: Hashable, Sendable {
        private let v: Int
        public static let ultraLight = Weight(v: 1), thin = Weight(v: 2), light = Weight(v: 3), regular = Weight(v: 4), medium = Weight(v: 5), semibold = Weight(v: 6), bold = Weight(v: 7), heavy = Weight(v: 8), black = Weight(v: 9)
    }
    public struct Width: Hashable, Sendable {
        public var value: CGFloat
        public init(_ value: CGFloat) { self.value = value }
        public static let compressed = Width(-0.3), condensed = Width(-0.2), standard = Width(0), expanded = Width(0.2)
    }
    public enum Leading: Hashable, Sendable { case standard, tight, loose }
    public static let largeTitle = Font("largeTitle"), extraLargeTitle = Font("xlt"), extraLargeTitle2 = Font("xlt2"), title = Font("title"), title2 = Font("title2"), title3 = Font("title3"),
        headline = Font("headline"), subheadline = Font("subheadline"), body = Font("body"), callout = Font("callout"), footnote = Font("footnote"), caption = Font("caption"), caption2 = Font("caption2")
    public static func system(_ style: TextStyle, design: Design? = nil, weight: Weight? = nil) -> Font { Font("s") }
    public static func system(size: CGFloat, weight: Weight? = nil, design: Design? = nil) -> Font { Font("s") }
    public static func custom(_ name: String, size: CGFloat) -> Font { Font(name) }
    public static func custom(_ name: String, size: CGFloat, relativeTo textStyle: TextStyle) -> Font { Font(name) }
    public static func custom(_ name: String, fixedSize: CGFloat) -> Font { Font(name) }
    public init(_ font: UIFont) { tag = "ui" }
    public func weight(_ weight: Weight) -> Font { self }
    public func width(_ width: Width) -> Font { self }
    public func bold() -> Font { self }
    public func italic() -> Font { self }
    public func monospaced() -> Font { self }
    public func monospacedDigit() -> Font { self }
    public func smallCaps() -> Font { self }
    public func lowercaseSmallCaps() -> Font { self }
    public func uppercaseSmallCaps() -> Font { self }
    public func leading(_ leading: Leading) -> Font { self }
}

// MARK: Shapes

public enum ShapeRole: Hashable, Sendable { case fill, stroke, separator }
public struct FillStyle: Equatable, Sendable {
    public var isEOFilled: Bool
    public var isAntialiased: Bool
    public init(eoFill: Bool = false, antialiased: Bool = true) { isEOFilled = eoFill; isAntialiased = antialiased }
}
public struct StrokeStyle: Equatable, Sendable, Animatable {
    public var lineWidth: CGFloat, lineCap: CGLineCap, lineJoin: CGLineJoin, miterLimit: CGFloat, dash: [CGFloat], dashPhase: CGFloat
    public init(lineWidth: CGFloat = 1, lineCap: CGLineCap = .butt, lineJoin: CGLineJoin = .miter, miterLimit: CGFloat = 10, dash: [CGFloat] = [], dashPhase: CGFloat = 0) {
        self.lineWidth = lineWidth; self.lineCap = lineCap; self.lineJoin = lineJoin; self.miterLimit = miterLimit; self.dash = dash; self.dashPhase = dashPhase
    }
    public var animatableData: CGFloat { get { lineWidth } set { lineWidth = newValue } }
}
public enum RoundedCornerStyle: Hashable, Sendable { case circular, continuous }

public protocol Shape: Sendable, Animatable, View {
    func path(in rect: CGRect) -> Path
    static var role: ShapeRole { get }
    var layoutDirectionBehavior: LayoutDirectionBehavior { get }
    func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize
}
extension Shape {
    public static var role: ShapeRole { .fill }
    public var layoutDirectionBehavior: LayoutDirectionBehavior { .mirrors }
    public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { proposal.replacingUnspecifiedDimensions() }
    public var body: _ShapeView<Self, ForegroundStyle> { _ShapeView() }
}
public struct _ShapeView<Content: Shape, Style: ShapeStyle>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public protocol ShapeView: View {
    associatedtype Content: Shape
    var shape: Content { get }
}
public struct FillShapeView<Content: Shape, Style: ShapeStyle, Background: View>: ShapeView {
    public var shape: Content
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct StrokeShapeView<Content: Shape, Style: ShapeStyle, Background: View>: ShapeView {
    public var shape: Content
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
public struct StrokeBorderShapeView<Content: InsettableShape, Style: ShapeStyle, Background: View>: ShapeView {
    public var shape: Content
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension ShapeView {
    public func fill<S: ShapeStyle>(_ content: S = .foreground, style: FillStyle = FillStyle()) -> FillShapeView<Content, S, Self> { FillShapeView(shape: shape) }
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Content, S, Self> { StrokeShapeView(shape: shape) }
    public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Content, S, Self> { StrokeShapeView(shape: shape) }
}
extension ShapeView where Content: InsettableShape {
    public func strokeBorder<S: ShapeStyle>(_ content: S = .foreground, style: StrokeStyle, antialiased: Bool = true) -> StrokeBorderShapeView<Content, S, Self> { StrokeBorderShapeView(shape: shape) }
    public func strokeBorder<S: ShapeStyle>(_ content: S = .foreground, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeBorderShapeView<Content, S, Self> { StrokeBorderShapeView(shape: shape) }
}
extension Shape {
    public func fill<S: ShapeStyle>(_ content: S, style: FillStyle = FillStyle()) -> FillShapeView<Self, S, EmptyView> { FillShapeView(shape: self) }
    public func fill(style: FillStyle = FillStyle()) -> FillShapeView<Self, ForegroundStyle, EmptyView> { FillShapeView(shape: self) }
    public func stroke<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> { StrokeShapeView(shape: self) }
    public func stroke<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeShapeView<Self, S, EmptyView> { StrokeShapeView(shape: self) }
    public func stroke(style: StrokeStyle) -> StrokeShapeView<Self, ForegroundStyle, EmptyView> { StrokeShapeView(shape: self) }
    public func stroke(lineWidth: CGFloat = 1) -> StrokeShapeView<Self, ForegroundStyle, EmptyView> { StrokeShapeView(shape: self) }
    public func trim(from startFraction: CGFloat = 0, to endFraction: CGFloat = 1) -> some Shape { self }
    public func offset(_ offset: CGSize) -> OffsetShape<Self> { OffsetShape(shape: self) }
    public func offset(_ offset: CGPoint) -> OffsetShape<Self> { OffsetShape(shape: self) }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> OffsetShape<Self> { OffsetShape(shape: self) }
    public func scale(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self) }
    public func scale(_ scale: CGFloat, anchor: UnitPoint = .center) -> ScaledShape<Self> { ScaledShape(shape: self) }
    public func rotation(_ angle: Angle, anchor: UnitPoint = .center) -> RotatedShape<Self> { RotatedShape(shape: self) }
    public func transform(_ transform: CGAffineTransform) -> TransformedShape<Self> { TransformedShape(shape: self) }
    public func size(_ size: CGSize) -> some Shape { self }
    public func size(width: CGFloat, height: CGFloat) -> some Shape { self }
    public func intersection<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
    public func union<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
    public func subtracting<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
    public func symmetricDifference<T: Shape>(_ other: T, eoFill: Bool = false) -> some Shape { self }
}
public struct OffsetShape<Content: Shape>: Shape { public var shape: Content; public func path(in rect: CGRect) -> Path { Path() }; public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} } }
public struct ScaledShape<Content: Shape>: Shape { public var shape: Content; public func path(in rect: CGRect) -> Path { Path() }; public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} } }
public struct RotatedShape<Content: Shape>: Shape { public var shape: Content; public func path(in rect: CGRect) -> Path { Path() }; public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} } }
public struct TransformedShape<Content: Shape>: Shape { public var shape: Content; public func path(in rect: CGRect) -> Path { Path() }; public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} } }
extension OffsetShape: InsettableShape where Content: InsettableShape { public func inset(by amount: CGFloat) -> OffsetShape<Content.InsetShape> { OffsetShape<Content.InsetShape>(shape: shape.inset(by: amount)) } }
extension ScaledShape: InsettableShape where Content: InsettableShape { public func inset(by amount: CGFloat) -> ScaledShape<Content.InsetShape> { ScaledShape<Content.InsetShape>(shape: shape.inset(by: amount)) } }
extension RotatedShape: InsettableShape where Content: InsettableShape { public func inset(by amount: CGFloat) -> RotatedShape<Content.InsetShape> { RotatedShape<Content.InsetShape>(shape: shape.inset(by: amount)) } }

public protocol InsettableShape: Shape {
    associatedtype InsetShape: InsettableShape
    func inset(by amount: CGFloat) -> InsetShape
}
extension InsettableShape {
    public func strokeBorder<S: ShapeStyle>(_ content: S, style: StrokeStyle, antialiased: Bool = true) -> StrokeBorderShapeView<Self, S, EmptyView> { StrokeBorderShapeView(shape: self) }
    public func strokeBorder<S: ShapeStyle>(_ content: S, lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeBorderShapeView<Self, S, EmptyView> { StrokeBorderShapeView(shape: self) }
    public func strokeBorder(style: StrokeStyle, antialiased: Bool = true) -> StrokeBorderShapeView<Self, ForegroundStyle, EmptyView> { StrokeBorderShapeView(shape: self) }
    public func strokeBorder(lineWidth: CGFloat = 1, antialiased: Bool = true) -> StrokeBorderShapeView<Self, ForegroundStyle, EmptyView> { StrokeBorderShapeView(shape: self) }
}

public struct Rectangle: InsettableShape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> Rectangle { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct RoundedRectangle: InsettableShape {
    public var cornerSize: CGSize
    public var style: RoundedCornerStyle
    public init(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) { self.cornerSize = cornerSize; self.style = style }
    public init(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) { cornerSize = CGSize(width: cornerRadius, height: cornerRadius); self.style = style }
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> RoundedRectangle { self }
    public var animatableData: CGSize.AnimatableData { get { cornerSize.animatableData } set { cornerSize.animatableData = newValue } }
}
public struct RectangleCornerRadii: Equatable, Sendable, Animatable {
    public var topLeading: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat, topTrailing: CGFloat
    public init(topLeading: CGFloat = 0, bottomLeading: CGFloat = 0, bottomTrailing: CGFloat = 0, topTrailing: CGFloat = 0) { self.topLeading = topLeading; self.bottomLeading = bottomLeading; self.bottomTrailing = bottomTrailing; self.topTrailing = topTrailing }
    public var animatableData: CGFloat { get { topLeading } set { topLeading = newValue } }
}
public struct UnevenRoundedRectangle: InsettableShape {
    public var cornerRadii: RectangleCornerRadii
    public var style: RoundedCornerStyle
    public init(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) { self.cornerRadii = cornerRadii; self.style = style }
    public init(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) {
        cornerRadii = RectangleCornerRadii(topLeading: topLeadingRadius, bottomLeading: bottomLeadingRadius, bottomTrailing: bottomTrailingRadius, topTrailing: topTrailingRadius); self.style = style
    }
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> UnevenRoundedRectangle { self }
    public var animatableData: CGFloat { get { 0 } set {} }
}
public struct Capsule: InsettableShape {
    public var style: RoundedCornerStyle
    public init(style: RoundedCornerStyle = .continuous) { self.style = style }
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> Capsule { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct Circle: InsettableShape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(ellipseIn: rect) }
    public func inset(by amount: CGFloat) -> Circle { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct Ellipse: InsettableShape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(ellipseIn: rect) }
    public func inset(by amount: CGFloat) -> Ellipse { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct ContainerRelativeShape: InsettableShape {
    public init() {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> ContainerRelativeShape { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct ConcentricRectangle: InsettableShape {
    public init(corners: ConcentricRectangle.Corners = .concentric(), isUniform: Bool = false) {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> ConcentricRectangle { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
    public struct Corners: Sendable {
        public static func concentric(minimum: CGFloat? = nil) -> Corners { Corners() }
        public static func fixed(_ radius: CGFloat) -> Corners { Corners() }
        public static func concentric(minimum: ConcentricRectangle.CornerRadius) -> Corners { Corners() }
    }
    public struct CornerRadius: Sendable { public static let capsule = CornerRadius(); public static func fixed(_ radius: CGFloat) -> CornerRadius { CornerRadius() } }
}
public struct ButtonBorderShape: InsettableShape, Hashable, Sendable {
    public static let automatic = ButtonBorderShape(), capsule = ButtonBorderShape(), roundedRectangle = ButtonBorderShape(), circle = ButtonBorderShape(), buttonBorder = ButtonBorderShape()
    public static func roundedRectangle(radius: CGFloat) -> ButtonBorderShape { ButtonBorderShape() }
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public func inset(by amount: CGFloat) -> ButtonBorderShape { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
public struct AnyShape: Shape {
    public init<S: Shape>(_ shape: S) {}
    public func path(in rect: CGRect) -> Path { Path(rect) }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
}
extension Shape where Self == Rectangle { public static var rect: Rectangle { Rectangle() } }
extension Shape where Self == RoundedRectangle {
    public static func rect(cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) -> RoundedRectangle { RoundedRectangle(cornerRadius: cornerRadius, style: style) }
    public static func rect(cornerSize: CGSize, style: RoundedCornerStyle = .continuous) -> RoundedRectangle { RoundedRectangle(cornerSize: cornerSize, style: style) }
}
extension Shape where Self == UnevenRoundedRectangle {
    public static func rect(cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) -> UnevenRoundedRectangle { UnevenRoundedRectangle(cornerRadii: cornerRadii, style: style) }
    public static func rect(topLeadingRadius: CGFloat = 0, bottomLeadingRadius: CGFloat = 0, bottomTrailingRadius: CGFloat = 0, topTrailingRadius: CGFloat = 0, style: RoundedCornerStyle = .continuous) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(topLeadingRadius: topLeadingRadius, bottomLeadingRadius: bottomLeadingRadius, bottomTrailingRadius: bottomTrailingRadius, topTrailingRadius: topTrailingRadius, style: style)
    }
}
extension Shape where Self == Circle { public static var circle: Circle { Circle() } }
extension Shape where Self == Capsule { public static var capsule: Capsule { Capsule() }; public static func capsule(style: RoundedCornerStyle) -> Capsule { Capsule(style: style) } }
extension Shape where Self == Ellipse { public static var ellipse: Ellipse { Ellipse() } }
extension Shape where Self == ButtonBorderShape { public static var buttonBorder: ButtonBorderShape { ButtonBorderShape() } }
extension Shape where Self == ContainerRelativeShape { public static var containerRelative: ContainerRelativeShape { ContainerRelativeShape() } }
extension Shape where Self == ConcentricRectangle {
    public static var containerConcentric: ConcentricRectangle { ConcentricRectangle() }
    public static func rect(corners: ConcentricRectangle.Corners, isUniform: Bool = false) -> ConcentricRectangle { ConcentricRectangle(corners: corners, isUniform: isUniform) }
}

public struct Path: Equatable, Shape, LosslessStringConvertible {
    public init() {}
    public init(_ rect: CGRect) {}
    public init(roundedRect rect: CGRect, cornerRadius: CGFloat, style: RoundedCornerStyle = .continuous) {}
    public init(roundedRect rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous) {}
    public init(roundedRect rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous) {}
    public init(ellipseIn rect: CGRect) {}
    public init(_ callback: (inout Path) -> Void) { callback(&self) }
    public init?(_ string: String) {}
    public var description: String { "Path" }
    public var isEmpty: Bool { true }
    public var boundingRect: CGRect { .zero }
    public var currentPoint: CGPoint? { nil }
    public func path(in rect: CGRect) -> Path { self }
    public func contains(_ p: CGPoint, eoFill: Bool = false) -> Bool { false }
    public mutating func move(to end: CGPoint) {}
    public mutating func addLine(to end: CGPoint) {}
    public mutating func addQuadCurve(to end: CGPoint, control: CGPoint) {}
    public mutating func addCurve(to end: CGPoint, control1: CGPoint, control2: CGPoint) {}
    public mutating func closeSubpath() {}
    public mutating func addRect(_ rect: CGRect, transform: CGAffineTransform = .identity) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerSize: CGSize, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
    public mutating func addRoundedRect(in rect: CGRect, cornerRadii: RectangleCornerRadii, style: RoundedCornerStyle = .continuous, transform: CGAffineTransform = .identity) {}
    public mutating func addEllipse(in rect: CGRect, transform: CGAffineTransform = .identity) {}
    public mutating func addRects(_ rects: [CGRect], transform: CGAffineTransform = .identity) {}
    public mutating func addLines(_ lines: [CGPoint]) {}
    public mutating func addRelativeArc(center: CGPoint, radius: CGFloat, startAngle: Angle, delta: Angle, transform: CGAffineTransform = .identity) {}
    public mutating func addArc(center: CGPoint, radius: CGFloat, startAngle: Angle, endAngle: Angle, clockwise: Bool, transform: CGAffineTransform = .identity) {}
    public mutating func addArc(tangent1End: CGPoint, tangent2End: CGPoint, radius: CGFloat, transform: CGAffineTransform = .identity) {}
    public mutating func addPath(_ path: Path, transform: CGAffineTransform = .identity) {}
    public func applying(_ transform: CGAffineTransform) -> Path { self }
    public func offsetBy(dx: CGFloat, dy: CGFloat) -> Path { self }
    public func trimmedPath(from: CGFloat, to: CGFloat) -> Path { self }
    public func strokedPath(_ style: StrokeStyle) -> Path { self }
    public func intersection(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func union(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func subtracting(_ other: Path, eoFill: Bool = false) -> Path { self }
    public func normalized(eoFill: Bool = false) -> Path { self }
    public var animatableData: EmptyAnimatableData { get { EmptyAnimatableData() } set {} }
    public static func == (lhs: Path, rhs: Path) -> Bool { true }
}

// MARK: Canvas

public struct Canvas<Symbols: View>: View {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext, CGSize) -> Void, @ViewBuilder symbols: () -> Symbols) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Canvas where Symbols == EmptyView {
    public init(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, rendersAsynchronously: Bool = false, renderer: @escaping (inout GraphicsContext, CGSize) -> Void) {}
}
public struct GraphicsContext {
    public struct Shading: Sendable {
        public static var backdrop: Shading { Shading() }
        public static var foreground: Shading { Shading() }
        public static func color(_ color: Color) -> Shading { Shading() }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, red: Double, green: Double, blue: Double, opacity: Double = 1) -> Shading { Shading() }
        public static func color(_ colorSpace: Color.RGBColorSpace = .sRGB, white: Double, opacity: Double = 1) -> Shading { Shading() }
        public static func style<S: ShapeStyle>(_ style: S) -> Shading { Shading() }
        public static func linearGradient(_ gradient: Gradient, startPoint: CGPoint, endPoint: CGPoint, options: GradientOptions = GradientOptions()) -> Shading { Shading() }
        public static func radialGradient(_ gradient: Gradient, center: CGPoint, startRadius: CGFloat, endRadius: CGFloat, options: GradientOptions = GradientOptions()) -> Shading { Shading() }
        public static func conicGradient(_ gradient: Gradient, center: CGPoint, angle: Angle = Angle(), options: GradientOptions = GradientOptions()) -> Shading { Shading() }
        public static func tiledImage(_ image: Image, origin: CGPoint = .zero, sourceRect: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1), scale: CGFloat = 1) -> Shading { Shading() }
        public static func palette(_ array: [Shading]) -> Shading { Shading() }
    }
    public struct GradientOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public init() { rawValue = 0 }
        public static let `repeat` = GradientOptions(rawValue: 1), mirror = GradientOptions(rawValue: 2), linearColor = GradientOptions(rawValue: 4) }
    public struct ClipOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let inverse = ClipOptions(rawValue: 1) }
    public struct BlurOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let opaque = BlurOptions(rawValue: 1), dithersResult = BlurOptions(rawValue: 2) }
    public struct ShadowOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let shadowAbove = ShadowOptions(rawValue: 1), shadowOnly = ShadowOptions(rawValue: 2), invertsAlpha = ShadowOptions(rawValue: 4), disablesGroup = ShadowOptions(rawValue: 8) }
    public struct FilterOptions: OptionSet, Sendable { public let rawValue: UInt32; public init(rawValue: UInt32) { self.rawValue = rawValue }; public static let linearColor = FilterOptions(rawValue: 1) }
    public struct Filter: Sendable {
        public static func blur(radius: CGFloat, options: BlurOptions = BlurOptions()) -> Filter { Filter() }
        public static func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0, blendMode: BlendMode = .normal, options: ShadowOptions = ShadowOptions()) -> Filter { Filter() }
        public static func colorMultiply(_ color: Color) -> Filter { Filter() }
        public static func saturation(_ amount: Double) -> Filter { Filter() }
        public static func brightness(_ amount: Double) -> Filter { Filter() }
        public static func contrast(_ amount: Double) -> Filter { Filter() }
        public static func grayscale(_ amount: Double) -> Filter { Filter() }
        public static func hueRotation(_ angle: Angle) -> Filter { Filter() }
        public static func alphaThreshold(min: Double, max: Double = 1, color: Color = .black) -> Filter { Filter() }
        public static var luminanceToAlpha: Filter { Filter() }
        public static var colorInvert: Filter { Filter() }
        public static func colorInvert(_ amount: Double = 1) -> Filter { Filter() }
        public static func projectionTransform(_ matrix: ProjectionTransform) -> Filter { Filter() }
    }
    public struct ResolvedImage { public var size: CGSize { .zero }; public var baseline: CGFloat { 0 }; public var shading: Shading? }
    public struct ResolvedText { public var shading: Shading = .foreground; public func measure(in size: CGSize) -> CGSize { .zero }; public func firstBaseline(in size: CGSize) -> CGFloat { 0 }; public func lastBaseline(in size: CGSize) -> CGFloat { 0 } }
    public struct ResolvedSymbol { public var size: CGSize { .zero } }

    public var opacity: Double = 1
    public var blendMode: BlendMode = .normal
    public var environment: EnvironmentValues { EnvironmentValues() }
    public var transform: CGAffineTransform = .identity
    public var clipBoundingRect: CGRect { .zero }
    public mutating func scaleBy(x: CGFloat, y: CGFloat) {}
    public mutating func translateBy(x: CGFloat, y: CGFloat) {}
    public mutating func rotate(by angle: Angle) {}
    public mutating func concatenate(_ matrix: CGAffineTransform) {}
    public mutating func clip(to path: Path, style: FillStyle = FillStyle(), options: ClipOptions = ClipOptions()) {}
    public mutating func clipToLayer(opacity: Double = 1, options: ClipOptions = ClipOptions(), content: (inout GraphicsContext) throws -> Void) rethrows {}
    public mutating func addFilter(_ filter: Filter, options: FilterOptions = FilterOptions()) {}
    public func drawLayer(content: (inout GraphicsContext) throws -> Void) rethrows {}
    public func fill(_ path: Path, with shading: Shading, style: FillStyle = FillStyle()) {}
    public func stroke(_ path: Path, with shading: Shading, style: StrokeStyle) {}
    public func stroke(_ path: Path, with shading: Shading, lineWidth: CGFloat = 1) {}
    public func resolve(_ image: Image) -> ResolvedImage { ResolvedImage() }
    public func draw(_ image: ResolvedImage, in rect: CGRect, style: FillStyle = FillStyle()) {}
    public func draw(_ image: ResolvedImage, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func draw(_ image: Image, in rect: CGRect, style: FillStyle = FillStyle()) {}
    public func draw(_ image: Image, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func resolve(_ text: Text) -> ResolvedText { ResolvedText() }
    public func draw(_ text: ResolvedText, in rect: CGRect) {}
    public func draw(_ text: ResolvedText, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func draw(_ text: Text, in rect: CGRect) {}
    public func draw(_ text: Text, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func resolveSymbol<ID: Hashable>(id: ID) -> ResolvedSymbol? { nil }
    public func draw(_ symbol: ResolvedSymbol, in rect: CGRect) {}
    public func draw(_ symbol: ResolvedSymbol, at point: CGPoint, anchor: UnitPoint = .center) {}
    public func withCGContext(content: (CGContext) throws -> Void) rethrows {}
}

// MARK: Image

public struct Image: View, Equatable, Hashable, Sendable, Transferable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ name: String, bundle: Bundle? = nil) {}
    public init(_ name: String, bundle: Bundle? = nil, label: Text) {}
    public init(_ name: String, variableValue: Double?, bundle: Bundle? = nil) {}
    public init(decorative name: String, bundle: Bundle? = nil) {}
    public init(systemName: String) {}
    public init(systemName: String, variableValue: Double?) {}
    public init(uiImage: UIImage) {}
    public init(_ cgImage: CGImage, scale: CGFloat, orientation: Image.Orientation = .up, label: Text) {}
    public init(decorative cgImage: CGImage, scale: CGFloat, orientation: Image.Orientation = .up) {}
    public init(size: CGSize, label: Text? = nil, opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear, renderer: @escaping (inout GraphicsContext) -> Void) {}
    public enum Orientation: UInt8, CaseIterable, Hashable, Sendable { case up, upMirrored, down, downMirrored, left, leftMirrored, right, rightMirrored }
    public enum ResizingMode: Hashable, Sendable { case tile, stretch }
    public enum Interpolation: Hashable, Sendable { case none, low, medium, high }
    public enum TemplateRenderingMode: Hashable, Sendable { case template, original }
    public enum Scale: Hashable, Sendable, CaseIterable { case small, medium, large }
    public enum DynamicRange: Hashable, Sendable { case standard, constrainedHigh, high }
    public func resizable(capInsets: EdgeInsets = EdgeInsets(), resizingMode: ResizingMode = .stretch) -> Image { self }
    public func renderingMode(_ renderingMode: TemplateRenderingMode?) -> Image { self }
    public func interpolation(_ interpolation: Interpolation) -> Image { self }
    public func antialiased(_ isAntialiased: Bool) -> Image { self }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> Image { self }
    public func allowedDynamicRange(_ range: DynamicRange?) -> Image { self }
    public static var transferRepresentation: DataRepresentation<Image> { DataRepresentation<Image>(exportedContentType: .image, exporting: { _ in Data() }) }
    public static func == (lhs: Image, rhs: Image) -> Bool { true }
    public func hash(into hasher: inout Hasher) {}
}
public struct SymbolRenderingMode: Hashable, Sendable {
    public static let monochrome = SymbolRenderingMode(), multicolor = SymbolRenderingMode(), hierarchical = SymbolRenderingMode(), palette = SymbolRenderingMode()
}
public struct SymbolVariants: Hashable, Sendable {
    public static let none = SymbolVariants(), circle = SymbolVariants(), square = SymbolVariants(), rectangle = SymbolVariants(), fill = SymbolVariants(), slash = SymbolVariants()
    public var circle: SymbolVariants { self }
    public var square: SymbolVariants { self }
    public var rectangle: SymbolVariants { self }
    public var fill: SymbolVariants { self }
    public var slash: SymbolVariants { self }
    public func contains(_ other: SymbolVariants) -> Bool { true }
}
public struct SymbolColorRenderingMode: Hashable, Sendable { public static let flat = SymbolColorRenderingMode(), gradient = SymbolColorRenderingMode() }
public struct SymbolVariableValueMode: Hashable, Sendable { public static let color = SymbolVariableValueMode(), draw = SymbolVariableValueMode() }

@MainActor public final class ImageRenderer<Content: View>: ObservableObject {
    public init(content: Content) { self.content = content }
    public var content: Content
    public var label: Text?
    public var proposedSize: ProposedViewSize = .unspecified
    public var scale: CGFloat = 1
    public var isOpaque: Bool = false
    public var colorMode: ColorRenderingMode = .nonLinear
    public var cgImage: CGImage? { nil }
    public var uiImage: UIImage? { nil }
    public func render(rasterizationScale: CGFloat = 1, renderer: (CGSize, (CGContext) -> Void) -> Void) {}
}

// MARK: Geometry effects

public struct ProjectionTransform: Equatable, Sendable {
    public var m11: CGFloat = 1, m12: CGFloat = 0, m13: CGFloat = 0, m21: CGFloat = 0, m22: CGFloat = 1, m23: CGFloat = 0, m31: CGFloat = 0, m32: CGFloat = 0, m33: CGFloat = 1
    public init() {}
    public init(_ m: CGAffineTransform) {}
    public var isIdentity: Bool { true }
    public var isAffine: Bool { true }
    public mutating func invert() -> Bool { true }
    public func inverted() -> ProjectionTransform { self }
    public func concatenating(_ rhs: ProjectionTransform) -> ProjectionTransform { self }
}
extension CGPoint { public func applying(_ m: ProjectionTransform) -> CGPoint { self } }
public protocol GeometryEffect: Animatable, ViewModifier where Body == Never {
    func effectValue(size: CGSize) -> ProjectionTransform
}
extension GeometryEffect {
    public func body(content: Content) -> Never { return fatalError() }
    public func ignoredByLayout() -> _IgnoredByLayoutEffect<Self> { _IgnoredByLayoutEffect() }
}
public struct _IgnoredByLayoutEffect<Effect: GeometryEffect>: ViewModifier {
    public func body(content: Content) -> Never { return fatalError() }
}
extension View {
    public func modifier<E: GeometryEffect>(_ effect: E) -> ModifiedContent<Self, E> { ModifiedContent(content: self, modifier: effect) }
    public func transformEffect(_ transform: CGAffineTransform) -> some View { self }
    public func projectionEffect(_ transform: ProjectionTransform) -> some View { self }
}

// MARK: Visual modifiers

extension View {
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some View { self }
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle>(_ primary: S1, _ secondary: S2) -> some View { self }
    public func foregroundStyle<S1: ShapeStyle, S2: ShapeStyle, S3: ShapeStyle>(_ primary: S1, _ secondary: S2, _ tertiary: S3) -> some View { self }
    public func foregroundColor(_ color: Color?) -> some View { self }
    public func tint(_ tint: Color?) -> some View { self }
    public func tint<S: ShapeStyle>(_ tint: S?) -> some View { self }
    public func opacity(_ opacity: Double) -> some View { self }
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some View { self }
    public func clipped(antialiased: Bool = false) -> some View { self }
    public func cornerRadius(_ radius: CGFloat, antialiased: Bool = true) -> some View { self }
    public func mask<M: View>(alignment: Alignment = .center, @ViewBuilder _ mask: () -> M) -> some View { self }
    public func mask<M: View>(_ mask: M) -> some View { self }
    public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some View { self }
    public func blur(radius: CGFloat, opaque: Bool = false) -> some View { self }
    public func brightness(_ amount: Double) -> some View { self }
    public func contrast(_ amount: Double) -> some View { self }
    public func saturation(_ amount: Double) -> some View { self }
    public func grayscale(_ amount: Double) -> some View { self }
    public func hueRotation(_ angle: Angle) -> some View { self }
    public func colorInvert() -> some View { self }
    public func colorMultiply(_ color: Color) -> some View { self }
    public func luminanceToAlpha() -> some View { self }
    public func blendMode(_ blendMode: BlendMode) -> some View { self }
    public func compositingGroup() -> some View { self }
    public func drawingGroup(opaque: Bool = false, colorMode: ColorRenderingMode = .nonLinear) -> some View { self }
    public func scaleEffect(_ scale: CGSize, anchor: UnitPoint = .center) -> some View { self }
    public func scaleEffect(_ s: CGFloat, anchor: UnitPoint = .center) -> some View { self }
    public func scaleEffect(x: CGFloat = 1, y: CGFloat = 1, anchor: UnitPoint = .center) -> some View { self }
    public func rotationEffect(_ angle: Angle, anchor: UnitPoint = .center) -> some View { self }
    public func rotation3DEffect(_ angle: Angle, axis: (x: CGFloat, y: CGFloat, z: CGFloat), anchor: UnitPoint = .center, anchorZ: CGFloat = 0, perspective: CGFloat = 1) -> some View { self }
    public func border<S: ShapeStyle>(_ content: S, width: CGFloat = 1) -> some View { self }
    public func imageScale(_ scale: Image.Scale) -> some View { self }
    public func symbolRenderingMode(_ mode: SymbolRenderingMode?) -> some View { self }
    public func symbolVariant(_ variant: SymbolVariants) -> some View { self }
    public func symbolColorRenderingMode(_ mode: SymbolColorRenderingMode?) -> some View { self }
    public func symbolVariableValueMode(_ mode: SymbolVariableValueMode?) -> some View { self }
    public func allowedDynamicRange(_ range: Image.DynamicRange?) -> some View { self }
    public func visualEffect(_ effect: @escaping @Sendable (EmptyVisualEffect, GeometryProxy) -> some VisualEffect) -> some View { self }
    public func colorEffect(_ shader: Shader, isEnabled: Bool = true) -> some View { self }
    public func distortionEffect(_ shader: Shader, maxSampleOffset: CGSize, isEnabled: Bool = true) -> some View { self }
    public func layerEffect(_ shader: Shader, maxSampleOffset: CGSize, isEnabled: Bool = true) -> some View { self }
}
public struct Shader: Equatable, Sendable {
    public struct Argument: Equatable, Sendable {
        public static func float(_ x: Double) -> Argument { Argument() }
        public static func float2(_ x: Double, _ y: Double) -> Argument { Argument() }
        public static func float2(_ size: CGSize) -> Argument { Argument() }
        public static func color(_ color: Color) -> Argument { Argument() }
        public static func boundingRect() -> Argument { Argument() }
        public static func image(_ image: Image) -> Argument { Argument() }
    }
    public init(function: ShaderFunction, arguments: [Argument]) {}
}
public struct ShaderFunction: Equatable, Sendable {
    public init(library: ShaderLibrary, name: String) {}
    public func callAsFunction(_ arguments: Shader.Argument...) -> Shader { Shader(function: self, arguments: arguments) }
}
@dynamicMemberLookup public struct ShaderLibrary: Equatable, Sendable {
    public static let `default` = ShaderLibrary()
    public static func bundle(_ bundle: Bundle) -> ShaderLibrary { ShaderLibrary() }
    public subscript(dynamicMember name: String) -> ShaderFunction { ShaderFunction(library: self, name: name) }
    public static subscript(dynamicMember name: String) -> ShaderFunction { ShaderFunction(library: .default, name: name) }
}

// MARK: AsyncImage

public enum AsyncImagePhase: Sendable {
    case empty
    case success(Image)
    case failure(any Error)
    public var image: Image? { if case .success(let i) = self { return i } else { return nil } }
    public var error: (any Error)? { if case .failure(let e) = self { return e } else { return nil } }
}
public struct AsyncImage<Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(url: URL?, scale: CGFloat = 1) where Content == Image {}
    public init<I: View, P: View>(url: URL?, scale: CGFloat = 1, @ViewBuilder content: @escaping (Image) -> I, @ViewBuilder placeholder: @escaping () -> P) where Content == _ConditionalContent<I, P> {}
    public init(url: URL?, scale: CGFloat = 1, transaction: Transaction = Transaction(), @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {}
}
