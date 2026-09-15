// Swift Charts stub — bar/line marks and the chart modifiers the stats use.
@_exported import Foundation
@_exported import SwiftUI

public protocol Plottable { associatedtype PrimitivePlottable: PrimitivePlottableProtocol; var primitivePlottable: PrimitivePlottable { get }; init?(primitivePlottable: PrimitivePlottable) }
public protocol PrimitivePlottableProtocol {}
extension Int: Plottable { public typealias PrimitivePlottable = Int; public var primitivePlottable: Int { self }; public init?(primitivePlottable: Int) { self = primitivePlottable } }
extension Double: Plottable { public typealias PrimitivePlottable = Double; public var primitivePlottable: Double { self }; public init?(primitivePlottable: Double) { self = primitivePlottable } }
extension Float: Plottable { public typealias PrimitivePlottable = Float; public var primitivePlottable: Float { self }; public init?(primitivePlottable: Float) { self = primitivePlottable } }
extension CGFloat: Plottable { public typealias PrimitivePlottable = CGFloat; public var primitivePlottable: CGFloat { self }; public init?(primitivePlottable: CGFloat) { self = primitivePlottable } }
extension String: Plottable { public typealias PrimitivePlottable = String; public var primitivePlottable: String { self }; public init?(primitivePlottable: String) { self = primitivePlottable } }
extension Date: Plottable { public typealias PrimitivePlottable = Date; public var primitivePlottable: Date { self }; public init?(primitivePlottable: Date) { self = primitivePlottable } }
extension Int: PrimitivePlottableProtocol {}
extension Double: PrimitivePlottableProtocol {}
extension Float: PrimitivePlottableProtocol {}
extension CGFloat: PrimitivePlottableProtocol {}
extension String: PrimitivePlottableProtocol {}
extension Date: PrimitivePlottableProtocol {}

public struct PlottableValue<Value: Plottable> {
    public static func value(_ label: String, _ value: Value) -> PlottableValue<Value> { PlottableValue() }
    public static func value<S: StringProtocol>(_ labelKey: S, _ value: Value) -> PlottableValue<Value> { PlottableValue() }
    public static func value(_ label: Text, _ value: Value) -> PlottableValue<Value> { PlottableValue() }
    public static func value(_ labelKey: LocalizedStringKey, _ value: Value) -> PlottableValue<Value> { PlottableValue() }
    public static func value(_ label: String, _ value: Value, unit: Calendar.Component) -> PlottableValue<Value> where Value == Date { PlottableValue() }
}

public protocol ChartContent {
    associatedtype Body: ChartContent
    @ChartContentBuilder var body: Self.Body { get }
}
extension Never: ChartContent {}
public struct _TupleChartContent: ChartContent { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct _ConditionalChartContent<T: ChartContent, F: ChartContent>: ChartContent { public typealias Body = Never; public var body: Never { return fatalError() } }
extension Optional: ChartContent where Wrapped: ChartContent { public typealias Body = Never; public var body: Never { return fatalError() } }
public struct AnyChartContent: ChartContent {
    public init<C: ChartContent>(_ content: C) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
@resultBuilder
public struct ChartContentBuilder {
    public static func buildBlock() -> _TupleChartContent { _TupleChartContent() }
    public static func buildBlock<C: ChartContent>(_ c: C) -> C { c }
    public static func buildBlock<C0: ChartContent, C1: ChartContent>(_ c0: C0, _ c1: C1) -> _TupleChartContent { _TupleChartContent() }
    public static func buildBlock<C0: ChartContent, C1: ChartContent, C2: ChartContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleChartContent { _TupleChartContent() }
    public static func buildBlock<C0: ChartContent, C1: ChartContent, C2: ChartContent, C3: ChartContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3) -> _TupleChartContent { _TupleChartContent() }
    public static func buildBlock<C0: ChartContent, C1: ChartContent, C2: ChartContent, C3: ChartContent, C4: ChartContent>(_ c0: C0, _ c1: C1, _ c2: C2, _ c3: C3, _ c4: C4) -> _TupleChartContent { _TupleChartContent() }
    public static func buildExpression<C: ChartContent>(_ content: C) -> C { content }
    public static func buildIf<C: ChartContent>(_ content: C?) -> C? { content }
    public static func buildEither<T: ChartContent, F: ChartContent>(first: T) -> _ConditionalChartContent<T, F> { _ConditionalChartContent() }
    public static func buildEither<T: ChartContent, F: ChartContent>(second: F) -> _ConditionalChartContent<T, F> { _ConditionalChartContent() }
}
extension ForEach: ChartContent where Content: ChartContent {
    public init(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> Content) where ID == Data.Element.ID, Data.Element: Identifiable { self.init(data: data, content: content) }
    public init(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> Content) { self.init(data: data, content: content) }
}

public struct MarkDimension: Sendable {
    public static let automatic = MarkDimension()
    public static func fixed(_ length: CGFloat) -> MarkDimension { MarkDimension() }
    public static func ratio(_ ratio: CGFloat) -> MarkDimension { MarkDimension() }
    public static func inset(_ inset: CGFloat) -> MarkDimension { MarkDimension() }
}
public enum MarkStackingMethod: Sendable { case standard, normalized, center, unstacked }
public struct BarMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) {}
    public init<X: Plottable>(x: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil, width: MarkDimension = .automatic) {}
    public init<Y: Plottable>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, y: PlottableValue<Y>, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>, width: MarkDimension = .automatic) {}
    public init<X: Plottable>(x: PlottableValue<X>, width: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) {}
    public init<Y: Plottable>(y: PlottableValue<Y>, height: MarkDimension = .automatic, stacking: MarkStackingMethod = .standard) {}
}
public struct LineMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable, S: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>) {}
}
public struct PointMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>) {}
}
public struct AreaMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, stacking: MarkStackingMethod = .standard) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable, S: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, series: PlottableValue<S>, stacking: MarkStackingMethod = .standard) {}
}
public struct RuleMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable>(x: PlottableValue<X>, yStart: CGFloat? = nil, yEnd: CGFloat? = nil) {}
    public init<Y: Plottable>(xStart: CGFloat? = nil, xEnd: CGFloat? = nil, y: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, y: PlottableValue<Y>) {}
}
public struct RectangleMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<X: Plottable, Y: Plottable>(x: PlottableValue<X>, y: PlottableValue<Y>, width: MarkDimension = .automatic, height: MarkDimension = .automatic) {}
    public init<X: Plottable, Y: Plottable>(xStart: PlottableValue<X>, xEnd: PlottableValue<X>, yStart: PlottableValue<Y>, yEnd: PlottableValue<Y>) {}
}
public struct SectorMark: ChartContent {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<A: Plottable>(angle: PlottableValue<A>, innerRadius: MarkDimension = .automatic, outerRadius: MarkDimension = .automatic, angularInset: CGFloat? = nil) {}
}
public enum InterpolationMethod: Sendable { case linear, cardinal, catmullRom, monotone, stepStart, stepCenter, stepEnd }
public enum ChartSymbolShapeStyle { }
public protocol ChartSymbolShape {}
public struct BasicChartSymbolShape: ChartSymbolShape { public static let circle = BasicChartSymbolShape(), square = BasicChartSymbolShape(), triangle = BasicChartSymbolShape(), diamond = BasicChartSymbolShape(), pentagon = BasicChartSymbolShape(), plus = BasicChartSymbolShape(), cross = BasicChartSymbolShape(), asterisk = BasicChartSymbolShape() }
extension ChartSymbolShape where Self == BasicChartSymbolShape { public static var circle: BasicChartSymbolShape { .circle }; public static var square: BasicChartSymbolShape { .square } }
public enum AnnotationPosition: Sendable { case automatic, overlay, top, bottom, leading, trailing, topLeading, topTrailing, bottomLeading, bottomTrailing }
public struct AnnotationOverflowResolution: Sendable { public static let automatic = AnnotationOverflowResolution() }
extension ChartContent {
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some ChartContent { self }
    public func foregroundStyle<D: Plottable>(by value: PlottableValue<D>) -> some ChartContent { self }
    public func symbol<D: Plottable>(by value: PlottableValue<D>) -> some ChartContent { self }
    public func symbol<S: ChartSymbolShape>(_ shape: S) -> some ChartContent { self }
    public func symbol<V: View>(@ViewBuilder symbol: () -> V) -> some ChartContent { self }
    public func symbolSize(_ size: CGSize) -> some ChartContent { self }
    public func symbolSize(_ area: CGFloat) -> some ChartContent { self }
    public func symbolSize<D: Plottable>(by value: PlottableValue<D>) -> some ChartContent { self }
    public func lineStyle(_ style: StrokeStyle) -> some ChartContent { self }
    public func lineStyle<D: Plottable>(by value: PlottableValue<D>) -> some ChartContent { self }
    public func position<D: Plottable>(by value: PlottableValue<D>, axis: Axis? = nil, span: MarkDimension = .automatic) -> some ChartContent { self }
    public func position(x: CGFloat? = nil, y: CGFloat? = nil) -> some ChartContent { self }
    public func cornerRadius(_ radius: CGFloat, style: RoundedCornerStyle = .continuous) -> some ChartContent { self }
    public func clipShape<S: Shape>(_ shape: S, style: FillStyle = FillStyle()) -> some ChartContent { self }
    public func opacity(_ opacity: Double) -> some ChartContent { self }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some ChartContent { self }
    public func offset(_ offset: CGSize) -> some ChartContent { self }
    public func interpolationMethod(_ method: InterpolationMethod) -> some ChartContent { self }
    public func annotation<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some ChartContent { self }
    public func annotation<C: View>(position: AnnotationPosition = .automatic, alignment: Alignment = .center, spacing: CGFloat? = nil, @ViewBuilder content: (AnnotationContext) -> C) -> some ChartContent { self }
    public func accessibilityLabel(_ label: Text) -> some ChartContent { self }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> some ChartContent { self }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> some ChartContent { self }
    public func accessibilityValue(_ value: Text) -> some ChartContent { self }
    public func accessibilityValue<S: StringProtocol>(_ value: S) -> some ChartContent { self }
    public func accessibilityHidden(_ hidden: Bool) -> some ChartContent { self }
    public func accessibilityIdentifier(_ identifier: String) -> some ChartContent { self }
    public func mask<C: ChartContent>(@ChartContentBuilder content: () -> C) -> some ChartContent { self }
    public func shadow(color: Color = Color(.sRGBLinear, white: 0, opacity: 0.33), radius: CGFloat, x: CGFloat = 0, y: CGFloat = 0) -> some ChartContent { self }
    public func blur(radius: CGFloat) -> some ChartContent { self }
    public func zIndex(_ value: Double) -> some ChartContent { self }
    public func alignsMarkStylesWithPlotArea(_ aligns: Bool = true) -> some ChartContent { self }
}
public struct AnnotationContext { public var targetSize: CGSize { .zero } }

public struct Chart<Content: ChartContent>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ChartContentBuilder content: () -> Content) {}
    public init<Data: RandomAccessCollection, C: ChartContent>(_ data: Data, @ChartContentBuilder content: @escaping (Data.Element) -> C) where Content == ForEach<Data, Data.Element.ID, C>, Data.Element: Identifiable {}
    public init<Data: RandomAccessCollection, ID: Hashable, C: ChartContent>(_ data: Data, id: KeyPath<Data.Element, ID>, @ChartContentBuilder content: @escaping (Data.Element) -> C) where Content == ForEach<Data, ID, C> {}
}

// MARK: Axes, scales, legend

public protocol AxisContent {}
public protocol AxisMark {}
public struct AxisMarkValues {
    public static let automatic = AxisMarkValues()
    public static func automatic(desiredCount: Int? = nil, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { AxisMarkValues() }
    public static func automatic(minimumStride: Double, desiredCount: Int? = nil, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { AxisMarkValues() }
    public static func stride<T: BinaryFloatingPoint>(by stride: T, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil) -> AxisMarkValues { AxisMarkValues() }
    public static func stride(by component: Calendar.Component, count: Int = 1, roundLowerBound: Bool? = nil, roundUpperBound: Bool? = nil, calendar: Calendar? = nil) -> AxisMarkValues { AxisMarkValues() }
    public static func values<S: Sequence>(_ values: S) -> AxisMarkValues where S.Element: Plottable { AxisMarkValues() }
}
public struct AxisMarkPosition { public static let automatic = AxisMarkPosition(), leading = AxisMarkPosition(), trailing = AxisMarkPosition(), top = AxisMarkPosition(), bottom = AxisMarkPosition() }
public struct AxisMarkPreset { public static let automatic = AxisMarkPreset(), aligned = AxisMarkPreset(), extended = AxisMarkPreset(), inset = AxisMarkPreset() }
public struct AxisValue {
    public var index: Int { 0 }
    public var count: Int { 0 }
    public func `as`<P: Plottable>(_ type: P.Type) -> P? { nil }
}
public struct AxisMarks<Content: AxisMark>: AxisContent {
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, stroke: StrokeStyle? = nil) where Content == _DefaultAxisMarks {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @AxisMarkBuilder content: () -> Content) {}
    public init(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic, @AxisMarkBuilder content: @escaping (AxisValue) -> Content) {}
    public init<S: Sequence>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: S, @AxisMarkBuilder content: @escaping (AxisValue) -> Content) where S.Element: Plottable {}
    public init<S: Sequence>(preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: S, stroke: StrokeStyle? = nil) where S.Element: Plottable, Content == _DefaultAxisMarks {}
    public init(format: some FormatStyle, preset: AxisMarkPreset = .automatic, position: AxisMarkPosition = .automatic, values: AxisMarkValues = .automatic) where Content == _DefaultAxisMarks {}
}
public struct _DefaultAxisMarks: AxisMark {}
public struct _TupleAxisMark: AxisMark {}
public struct _ConditionalAxisMark<T: AxisMark, F: AxisMark>: AxisMark {}
extension Optional: AxisMark where Wrapped: AxisMark {}
@resultBuilder
public struct AxisMarkBuilder {
    public static func buildBlock<C: AxisMark>(_ c: C) -> C { c }
    public static func buildBlock<C0: AxisMark, C1: AxisMark>(_ c0: C0, _ c1: C1) -> _TupleAxisMark { _TupleAxisMark() }
    public static func buildBlock<C0: AxisMark, C1: AxisMark, C2: AxisMark>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleAxisMark { _TupleAxisMark() }
    public static func buildIf<C: AxisMark>(_ c: C?) -> C? { c }
    public static func buildEither<T: AxisMark, F: AxisMark>(first: T) -> _ConditionalAxisMark<T, F> { _ConditionalAxisMark() }
    public static func buildEither<T: AxisMark, F: AxisMark>(second: F) -> _ConditionalAxisMark<T, F> { _ConditionalAxisMark() }
}
@resultBuilder
public struct AxisContentBuilder {
    public static func buildBlock<C: AxisContent>(_ c: C) -> C { c }
    public static func buildBlock<C0: AxisContent, C1: AxisContent>(_ c0: C0, _ c1: C1) -> _TupleAxisContent { _TupleAxisContent() }
    public static func buildBlock<C0: AxisContent, C1: AxisContent, C2: AxisContent>(_ c0: C0, _ c1: C1, _ c2: C2) -> _TupleAxisContent { _TupleAxisContent() }
}
public struct _TupleAxisContent: AxisContent {}
public struct AxisValueLabel<Content: View>: AxisMark {
    public init(centered: Bool = false, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool = false, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil, @ViewBuilder content: () -> Content) {}
    public init(centered: Bool = false, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool = false, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Never {}
    public init(_ label: LocalizedStringKey, centered: Bool = false, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool = false, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Text {}
    public init<S: StringProtocol>(_ label: S, centered: Bool = false, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool = false, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Text {}
    public init<F: FormatStyle>(format: F, centered: Bool = false, anchor: UnitPoint? = nil, multiLabelAlignment: Alignment? = nil, collisionResolution: AxisValueLabelCollisionResolution = .automatic, offsetsMarks: Bool = false, orientation: AxisValueLabelOrientation = .automatic, horizontalSpacing: CGFloat? = nil, verticalSpacing: CGFloat? = nil) where Content == Never, F.FormatOutput == String {}
}
public struct AxisValueLabelCollisionResolution { public static let automatic = AxisValueLabelCollisionResolution(), greedy = AxisValueLabelCollisionResolution(), truncate = AxisValueLabelCollisionResolution(), disabled = AxisValueLabelCollisionResolution() }
public struct AxisValueLabelOrientation { public static let automatic = AxisValueLabelOrientation(), horizontal = AxisValueLabelOrientation(), vertical = AxisValueLabelOrientation(), verticalReversed = AxisValueLabelOrientation() }
public struct AxisGridLine: AxisMark {
    public init(centered: Bool = false, stroke: StrokeStyle? = nil) {}
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> AxisGridLine { self }
}
public struct AxisTick: AxisMark {
    public init(centered: Bool = false, length: AxisTickLength = .automatic, stroke: StrokeStyle? = nil) {}
    public struct AxisTickLength { public static let automatic = AxisTickLength(), label = AxisTickLength(), longestLabel = AxisTickLength(); public static func length(_ l: CGFloat) -> AxisTickLength { AxisTickLength() } }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> AxisTick { self }
}
extension AxisMark {
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> some AxisMark { self }
    public func font(_ font: Font?) -> some AxisMark { self }
    public func offset(x: CGFloat = 0, y: CGFloat = 0) -> some AxisMark { self }
}
public struct ScaleType: Sendable { public static let linear = ScaleType(), log = ScaleType(), date = ScaleType(), category = ScaleType(), squareRoot = ScaleType(), symmetricLog = ScaleType() }
public struct ScaleDomain { }
public protocol ScaleDomainProtocol {}
public struct AutomaticScaleDomain: ScaleDomainProtocol {
    public static let automatic = AutomaticScaleDomain()
    public static func automatic(includesZero: Bool? = nil, reversed: Bool? = nil, dataType: (any Plottable.Type)? = nil) -> AutomaticScaleDomain { AutomaticScaleDomain() }
}
extension ScaleDomainProtocol where Self == AutomaticScaleDomain {
    public static var automatic: AutomaticScaleDomain { AutomaticScaleDomain() }
    public static func automatic(includesZero: Bool? = nil, reversed: Bool? = nil) -> AutomaticScaleDomain { AutomaticScaleDomain() }
}
extension ClosedRange: ScaleDomainProtocol where Bound: Plottable {}
extension Array: ScaleDomainProtocol where Element: Plottable {}
public struct ScaleRange { }
public protocol PositionScaleRange {}
public struct PlotDimensionScaleRange: PositionScaleRange { public static let plotDimension = PlotDimensionScaleRange(); public static func plotDimension(padding: CGFloat) -> PlotDimensionScaleRange { PlotDimensionScaleRange() }; public static func plotDimension(startPadding: CGFloat = 0, endPadding: CGFloat = 0) -> PlotDimensionScaleRange { PlotDimensionScaleRange() } }
extension PositionScaleRange where Self == PlotDimensionScaleRange { public static var plotDimension: PlotDimensionScaleRange { PlotDimensionScaleRange() }; public static func plotDimension(padding: CGFloat) -> PlotDimensionScaleRange { PlotDimensionScaleRange() } }
public struct ChartLegendPosition { public static let automatic = ChartLegendPosition(), top = ChartLegendPosition(), bottom = ChartLegendPosition(), leading = ChartLegendPosition(), trailing = ChartLegendPosition(), topLeading = ChartLegendPosition(), topTrailing = ChartLegendPosition(), bottomLeading = ChartLegendPosition(), bottomTrailing = ChartLegendPosition(), overlay = ChartLegendPosition() }
public struct ChartProxy {
    public var plotSize: CGSize { .zero }
    public var plotAreaSize: CGSize { .zero }
    public var plotFrame: Anchor<CGRect>? { nil }
    public func position<X: Plottable>(forX value: X) -> CGFloat? { nil }
    public func position<Y: Plottable>(forY value: Y) -> CGFloat? { nil }
    public func position<X: Plottable, Y: Plottable>(for point: (x: X, y: Y)) -> CGPoint? { nil }
    public func value<X: Plottable>(atX position: CGFloat, as: X.Type = X.self) -> X? { nil }
    public func value<Y: Plottable>(atY position: CGFloat, as: Y.Type = Y.self) -> Y? { nil }
    public func value<X: Plottable, Y: Plottable>(at position: CGPoint, as: (X, Y).Type = (X, Y).self) -> (x: X, y: Y)? { nil }
}
public struct ChartScrollTargetBehavior { }
public protocol ChartScrollTargetBehaviorProtocol {}
public struct ValueAlignedChartScrollTargetBehavior: ChartScrollTargetBehaviorProtocol {}
extension ChartScrollTargetBehaviorProtocol where Self == ValueAlignedChartScrollTargetBehavior {
    public static var valueAligned: ValueAlignedChartScrollTargetBehavior { ValueAlignedChartScrollTargetBehavior() }
    public static func valueAligned(unit: Int, majorAlignment: Int? = nil, limitBehavior: ViewAlignedScrollTargetBehavior.LimitBehavior = .automatic) -> ValueAlignedChartScrollTargetBehavior { ValueAlignedChartScrollTargetBehavior() }
}
public struct ChartScrollPosition { }

extension View {
    public func chartXAxis(_ visibility: Visibility) -> some View { self }
    public func chartYAxis(_ visibility: Visibility) -> some View { self }
    public func chartXAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> some View { self }
    public func chartYAxis<C: AxisContent>(@AxisContentBuilder content: () -> C) -> some View { self }
    public func chartXAxisLabel(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View { self }
    public func chartYAxisLabel(position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> some View) -> some View { self }
    public func chartXAxisLabel(_ labelKey: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { self }
    public func chartYAxisLabel(_ labelKey: LocalizedStringKey, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { self }
    public func chartXAxisLabel<S: StringProtocol>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { self }
    public func chartYAxisLabel<S: StringProtocol>(_ label: S, position: AnnotationPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { self }
    public func chartXScale<D: ScaleDomainProtocol>(domain: D, type: ScaleType? = nil) -> some View { self }
    public func chartYScale<D: ScaleDomainProtocol>(domain: D, type: ScaleType? = nil) -> some View { self }
    public func chartXScale<D: ScaleDomainProtocol, R: PositionScaleRange>(domain: D, range: R, type: ScaleType? = nil) -> some View { self }
    public func chartYScale<D: ScaleDomainProtocol, R: PositionScaleRange>(domain: D, range: R, type: ScaleType? = nil) -> some View { self }
    public func chartXScale<R: PositionScaleRange>(range: R, type: ScaleType? = nil) -> some View { self }
    public func chartYScale<R: PositionScaleRange>(range: R, type: ScaleType? = nil) -> some View { self }
    public func chartXScale(type: ScaleType?) -> some View { self }
    public func chartYScale(type: ScaleType?) -> some View { self }
    public func chartForegroundStyleScale<D: Plottable, S: ShapeStyle>(_ mapping: KeyValuePairs<D, S>) -> some View { self }
    public func chartForegroundStyleScale<D: Plottable & Hashable, S: ShapeStyle>(_ mapping: [D: S]) -> some View { self }
    public func chartForegroundStyleScale<Domain: ScaleDomainProtocol, Range: Sequence>(domain: Domain, range: Range, type: ScaleType? = nil) -> some View where Range.Element: ShapeStyle { self }
    public func chartForegroundStyleScale<Range: Sequence>(range: Range, type: ScaleType? = nil) -> some View where Range.Element: ShapeStyle { self }
    public func chartForegroundStyleScale<D: Plottable, S: ShapeStyle>(mapping: @escaping (D) -> S) -> some View { self }
    public func chartForegroundStyleScale<Domain: ScaleDomainProtocol, D: Plottable, S: ShapeStyle>(domain: Domain, mapping: @escaping (D) -> S) -> some View { self }
    public func chartSymbolScale<D: Plottable, S: ChartSymbolShape>(_ mapping: KeyValuePairs<D, S>) -> some View { self }
    public func chartLegend(_ visibility: Visibility) -> some View { self }
    public func chartLegend(position: ChartLegendPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil) -> some View { self }
    public func chartLegend<C: View>(position: ChartLegendPosition = .automatic, alignment: Alignment? = nil, spacing: CGFloat? = nil, @ViewBuilder content: () -> C) -> some View { self }
    public func chartPlotStyle<C: View>(@ViewBuilder content: @escaping (ChartPlotContent) -> C) -> some View { self }
    public func chartBackground<C: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> C) -> some View { self }
    public func chartOverlay<C: View>(alignment: Alignment = .center, @ViewBuilder content: @escaping (ChartProxy) -> C) -> some View { self }
    public func chartXSelection<P: Plottable>(value: Binding<P?>) -> some View { self }
    public func chartYSelection<P: Plottable>(value: Binding<P?>) -> some View { self }
    public func chartXSelection<P: Plottable>(range: Binding<ClosedRange<P>?>) -> some View { self }
    public func chartAngleSelection<P: Plottable>(value: Binding<P?>) -> some View { self }
    public func chartGesture(_ gesture: @escaping (ChartProxy) -> some Gesture) -> some View { self }
    public func chartScrollableAxes(_ axes: Axis.Set) -> some View { self }
    public func chartScrollPosition<P: Plottable>(x: Binding<P>) -> some View { self }
    public func chartScrollPosition<P: Plottable>(y: Binding<P>) -> some View { self }
    public func chartScrollPosition(initialX: some Plottable) -> some View { self }
    public func chartScrollPosition(initialY: some Plottable) -> some View { self }
    public func chartScrollTargetBehavior(_ behavior: some ChartScrollTargetBehaviorProtocol) -> some View { self }
    public func chartXVisibleDomain<P: Plottable>(length: P) -> some View { self }
    public func chartYVisibleDomain<P: Plottable>(length: P) -> some View { self }
}
public struct ChartPlotContent: View { public typealias Body = Never; public var body: Never { return fatalError() } }
