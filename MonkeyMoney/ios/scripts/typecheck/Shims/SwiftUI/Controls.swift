// SwiftUI stub — controls and their styles.
import Foundation

// MARK: Button

public struct ButtonRole: Equatable, Sendable {
    public static let destructive = ButtonRole(), cancel = ButtonRole(), confirm = ButtonRole(), close = ButtonRole()
}
public struct Button<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ token: _StubInit) {}
    public init(action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
    public init(role: ButtonRole?, action: @escaping @MainActor () -> Void, @ViewBuilder label: () -> Label) {}
}
extension Button where Label == Text {
    public init(_ titleKey: LocalizedStringKey, action: @escaping @MainActor () -> Void) {}
    public init<S: StringProtocol>(_ title: S, action: @escaping @MainActor () -> Void) {}
    public init(_ titleKey: LocalizedStringKey, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
    public init<S: StringProtocol>(_ title: S, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
}
extension Button where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, action: @escaping @MainActor () -> Void) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, action: @escaping @MainActor () -> Void) {}
    public init(_ titleKey: LocalizedStringKey, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, role: ButtonRole?, action: @escaping @MainActor () -> Void) {}
    public init(_ titleKey: LocalizedStringKey, image: String, action: @escaping @MainActor () -> Void) {}
    public init<S: StringProtocol>(_ title: S, image: String, action: @escaping @MainActor () -> Void) {}
}
extension Button where Label == PrimitiveButtonStyleConfiguration.Label {
    public init(_ configuration: PrimitiveButtonStyleConfiguration) {}
}
extension Button where Label == DefaultButtonLabel {
    public init(role: ButtonRole, action: @escaping @MainActor () -> Void) {}
}
public struct DefaultButtonLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }

public protocol ButtonStyle {
    associatedtype Body: View
    typealias Configuration = ButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct ButtonStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public let role: ButtonRole? = nil
    public let label: Label = Label()
    public let isPressed: Bool = false
}
public protocol PrimitiveButtonStyle {
    associatedtype Body: View
    typealias Configuration = PrimitiveButtonStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct PrimitiveButtonStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public let role: ButtonRole? = nil
    public let label: Label = Label()
    public func trigger() {}
}
public struct DefaultButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct PlainButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct BorderlessButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct BorderedButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct BorderedProminentButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct GlassButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct GlassProminentButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct AccessoryBarButtonStyle: PrimitiveButtonStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
extension PrimitiveButtonStyle where Self == DefaultButtonStyle { public static var automatic: DefaultButtonStyle { DefaultButtonStyle() } }
extension PrimitiveButtonStyle where Self == PlainButtonStyle { public static var plain: PlainButtonStyle { PlainButtonStyle() } }
extension PrimitiveButtonStyle where Self == BorderlessButtonStyle { public static var borderless: BorderlessButtonStyle { BorderlessButtonStyle() } }
extension PrimitiveButtonStyle where Self == BorderedButtonStyle { public static var bordered: BorderedButtonStyle { BorderedButtonStyle() } }
extension PrimitiveButtonStyle where Self == BorderedProminentButtonStyle { public static var borderedProminent: BorderedProminentButtonStyle { BorderedProminentButtonStyle() } }
extension PrimitiveButtonStyle where Self == GlassButtonStyle {
    public static var glass: GlassButtonStyle { GlassButtonStyle() }
    public static func glass(_ glass: Glass) -> GlassButtonStyle { GlassButtonStyle() }
}
extension PrimitiveButtonStyle where Self == GlassProminentButtonStyle { public static var glassProminent: GlassProminentButtonStyle { GlassProminentButtonStyle() } }
public struct ButtonSizing: Hashable, Sendable { public static let automatic = ButtonSizing(), fitted = ButtonSizing(), flexible = ButtonSizing() }
extension View {
    public func buttonStyle<S: ButtonStyle>(_ style: S) -> some View { self }
    public func buttonStyle<S: PrimitiveButtonStyle>(_ style: S) -> some View { self }
    public func buttonBorderShape(_ shape: ButtonBorderShape) -> some View { self }
    public func buttonSizing(_ sizing: ButtonSizing) -> some View { self }
}

// MARK: Toggle

public struct Toggle<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(_ token: _StubInit) {}
    public init(isOn: Binding<Bool>, @ViewBuilder label: () -> Label) {}
    public init<C: RandomAccessCollection>(sources: C, isOn: KeyPath<C.Element, Binding<Bool>>, @ViewBuilder label: () -> Label) {}
}
extension Toggle where Label == Text {
    public init(_ titleKey: LocalizedStringKey, isOn: Binding<Bool>) {}
    public init<S: StringProtocol>(_ title: S, isOn: Binding<Bool>) {}
}
extension Toggle where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, isOn: Binding<Bool>) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, isOn: Binding<Bool>) {}
    public init(_ titleKey: LocalizedStringKey, image: String, isOn: Binding<Bool>) {}
}
extension Toggle where Label == ToggleStyleConfiguration.Label {
    public init(_ configuration: ToggleStyleConfiguration) {}
}
public protocol ToggleStyle {
    associatedtype Body: View
    typealias Configuration = ToggleStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct ToggleStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public let label: Label = Label()
    public var isOn: Bool { get { false } nonmutating set {} }
    public var isMixed: Bool { false }
}
public struct DefaultToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct SwitchToggleStyle: ToggleStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
public struct ButtonToggleStyle: ToggleStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.label } }
extension ToggleStyle where Self == DefaultToggleStyle { public static var automatic: DefaultToggleStyle { DefaultToggleStyle() } }
extension ToggleStyle where Self == SwitchToggleStyle { public static var `switch`: SwitchToggleStyle { SwitchToggleStyle() } }
extension ToggleStyle where Self == ButtonToggleStyle { public static var button: ButtonToggleStyle { ButtonToggleStyle() } }
extension View {
    public func toggleStyle<S: ToggleStyle>(_ style: S) -> some View { self }
}

// MARK: Picker

public struct Picker<Label: View, SelectionValue: Hashable, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public init<C: RandomAccessCollection>(sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> some View) {}
}
extension Picker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    public init<C: RandomAccessCollection>(_ titleKey: LocalizedStringKey, sources: C, selection: KeyPath<C.Element, Binding<SelectionValue>>, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder currentValueLabel: () -> some View) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content, @ViewBuilder currentValueLabel: () -> some View) {}
}
extension Picker where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, image: String, selection: Binding<SelectionValue>, @ViewBuilder content: () -> Content) {}
}
public protocol PickerStyle {}
public struct DefaultPickerStyle: PickerStyle { public init() {} }
public struct MenuPickerStyle: PickerStyle { public init() {} }
public struct SegmentedPickerStyle: PickerStyle { public init() {} }
public struct WheelPickerStyle: PickerStyle { public init() {} }
public struct InlinePickerStyle: PickerStyle { public init() {} }
public struct NavigationLinkPickerStyle: PickerStyle { public init() {} }
public struct PalettePickerStyle: PickerStyle { public init() {} }
extension PickerStyle where Self == DefaultPickerStyle { public static var automatic: DefaultPickerStyle { DefaultPickerStyle() } }
extension PickerStyle where Self == MenuPickerStyle { public static var menu: MenuPickerStyle { MenuPickerStyle() } }
extension PickerStyle where Self == SegmentedPickerStyle { public static var segmented: SegmentedPickerStyle { SegmentedPickerStyle() } }
extension PickerStyle where Self == WheelPickerStyle { public static var wheel: WheelPickerStyle { WheelPickerStyle() } }
extension PickerStyle where Self == InlinePickerStyle { public static var inline: InlinePickerStyle { InlinePickerStyle() } }
extension PickerStyle where Self == NavigationLinkPickerStyle { public static var navigationLink: NavigationLinkPickerStyle { NavigationLinkPickerStyle() } }
extension PickerStyle where Self == PalettePickerStyle { public static var palette: PalettePickerStyle { PalettePickerStyle() } }
extension View {
    public func pickerStyle<S: PickerStyle>(_ style: S) -> some View { self }
    public func paletteSelectionEffect(_ effect: PaletteSelectionEffect) -> some View { self }
    public func defaultWheelPickerItemHeight(_ height: CGFloat) -> some View { self }
}
public struct PaletteSelectionEffect: Hashable, Sendable {
    public static let automatic = PaletteSelectionEffect(), custom = PaletteSelectionEffect()
    public static func symbolVariant(_ variant: SymbolVariants) -> PaletteSelectionEffect { PaletteSelectionEffect() }
}

// MARK: Slider & Stepper

public struct Slider<Label: View, ValueLabel: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, @ViewBuilder minimumValueLabel: () -> ValueLabel, @ViewBuilder maximumValueLabel: () -> ValueLabel, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
}
extension Slider where ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
}
extension Slider where Label == EmptyView, ValueLabel == EmptyView {
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V> = 0...1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
    public init<V: BinaryFloatingPoint>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where V.Stride: BinaryFloatingPoint {}
}
public struct Stepper<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder label: () -> Label, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<V: Strideable>(value: Binding<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<V: Strideable>(value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<F: FormatStyle>(value: Binding<F.FormatInput>, step: F.FormatInput.Stride = 1, format: F, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where F.FormatInput: Strideable, F.FormatOutput == String {}
    public init<F: FormatStyle>(value: Binding<F.FormatInput>, in bounds: ClosedRange<F.FormatInput>, step: F.FormatInput.Stride = 1, format: F, @ViewBuilder label: () -> Label, onEditingChanged: @escaping (Bool) -> Void = { _ in }) where F.FormatInput: Strideable, F.FormatOutput == String {}
}
extension Stepper where Label == Text {
    public init(_ titleKey: LocalizedStringKey, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<S: StringProtocol>(_ title: S, onIncrement: (() -> Void)?, onDecrement: (() -> Void)?, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<V: Strideable>(_ titleKey: LocalizedStringKey, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
    public init<S: StringProtocol, V: Strideable>(_ title: S, value: Binding<V>, in bounds: ClosedRange<V>, step: V.Stride = 1, onEditingChanged: @escaping (Bool) -> Void = { _ in }) {}
}

// MARK: DatePicker & ColorPicker

public struct DatePickerComponents: OptionSet, Sendable {
    public let rawValue: UInt
    public init(rawValue: UInt) { self.rawValue = rawValue }
    public static let hourAndMinute = DatePickerComponents(rawValue: 1), date = DatePickerComponents(rawValue: 2), hourMinuteAndSecond = DatePickerComponents(rawValue: 4)
}
public struct DatePicker<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public typealias Components = DatePickerComponents
    public init(selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date], @ViewBuilder label: () -> Label) {}
}
extension DatePicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: ClosedRange<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeFrom<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Date>, in range: PartialRangeThrough<Date>, displayedComponents: Components = [.hourAndMinute, .date]) {}
}
public protocol DatePickerStyle {}
public struct DefaultDatePickerStyle: DatePickerStyle { public init() {} }
public struct CompactDatePickerStyle: DatePickerStyle { public init() {} }
public struct GraphicalDatePickerStyle: DatePickerStyle { public init() {} }
public struct WheelDatePickerStyle: DatePickerStyle { public init() {} }
extension DatePickerStyle where Self == DefaultDatePickerStyle { public static var automatic: DefaultDatePickerStyle { DefaultDatePickerStyle() } }
extension DatePickerStyle where Self == CompactDatePickerStyle { public static var compact: CompactDatePickerStyle { CompactDatePickerStyle() } }
extension DatePickerStyle where Self == GraphicalDatePickerStyle { public static var graphical: GraphicalDatePickerStyle { GraphicalDatePickerStyle() } }
extension DatePickerStyle where Self == WheelDatePickerStyle { public static var wheel: WheelDatePickerStyle { WheelDatePickerStyle() } }
extension View {
    public func datePickerStyle<S: DatePickerStyle>(_ style: S) -> some View { self }
}
public struct ColorPicker<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(selection: Binding<Color>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<CGColor>, supportsOpacity: Bool = true, @ViewBuilder label: () -> Label) {}
}
extension ColorPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<Color>, supportsOpacity: Bool = true) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<Color>, supportsOpacity: Bool = true) {}
}

// MARK: ProgressView & Gauge

public struct ProgressView<Label: View, CurrentValueLabel: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {}
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) {}
}
extension ProgressView where CurrentValueLabel == EmptyView {
    public init(@ViewBuilder label: () -> Label) {}
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0, @ViewBuilder label: () -> Label) {}
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true, @ViewBuilder label: () -> Label) {}
}
extension ProgressView where Label == EmptyView, CurrentValueLabel == EmptyView {
    public init() {}
    public init<V: BinaryFloatingPoint>(value: V?, total: V = 1.0) {}
}
extension ProgressView where Label == Text, CurrentValueLabel == EmptyView {
    public init(_ titleKey: LocalizedStringKey) {}
    public init<S: StringProtocol>(_ title: S) {}
    public init<V: BinaryFloatingPoint>(_ titleKey: LocalizedStringKey, value: V?, total: V = 1.0) {}
    public init<S: StringProtocol, V: BinaryFloatingPoint>(_ title: S, value: V?, total: V = 1.0) {}
}
extension ProgressView where Label == EmptyView, CurrentValueLabel == DefaultDateProgressLabel {
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true) {}
}
extension ProgressView where CurrentValueLabel == DefaultDateProgressLabel {
    public init(timerInterval: ClosedRange<Date>, countsDown: Bool = true, @ViewBuilder label: () -> Label) {}
}
public struct DefaultDateProgressLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
extension ProgressView where Label == ProgressViewStyleConfiguration.Label, CurrentValueLabel == ProgressViewStyleConfiguration.CurrentValueLabel {
    public init(_ configuration: ProgressViewStyleConfiguration) {}
}
public protocol ProgressViewStyle {
    associatedtype Body: View
    typealias Configuration = ProgressViewStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct ProgressViewStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct CurrentValueLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public let fractionCompleted: Double? = nil
    public var label: Label? { nil }
    public var currentValueLabel: CurrentValueLabel? { nil }
}
public struct DefaultProgressViewStyle: ProgressViewStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct CircularProgressViewStyle: ProgressViewStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct LinearProgressViewStyle: ProgressViewStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension ProgressViewStyle where Self == DefaultProgressViewStyle { public static var automatic: DefaultProgressViewStyle { DefaultProgressViewStyle() } }
extension ProgressViewStyle where Self == CircularProgressViewStyle { public static var circular: CircularProgressViewStyle { CircularProgressViewStyle() } }
extension ProgressViewStyle where Self == LinearProgressViewStyle { public static var linear: LinearProgressViewStyle { LinearProgressViewStyle() } }
extension View {
    public func progressViewStyle<S: ProgressViewStyle>(_ style: S) -> some View { self }
}

public struct Gauge<Label: View, CurrentValueLabel: View, BoundsLabel: View, MarkedValueLabels: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label) where CurrentValueLabel == EmptyView, BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {}
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel) where BoundsLabel == EmptyView, MarkedValueLabels == EmptyView {}
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel, @ViewBuilder minimumValueLabel: () -> BoundsLabel, @ViewBuilder maximumValueLabel: () -> BoundsLabel) where MarkedValueLabels == EmptyView {}
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel, @ViewBuilder markedValueLabels: () -> MarkedValueLabels) where BoundsLabel == EmptyView {}
    public init<V: BinaryFloatingPoint>(value: V, in bounds: ClosedRange<V> = 0...1, @ViewBuilder label: () -> Label, @ViewBuilder currentValueLabel: () -> CurrentValueLabel, @ViewBuilder minimumValueLabel: () -> BoundsLabel, @ViewBuilder maximumValueLabel: () -> BoundsLabel, @ViewBuilder markedValueLabels: () -> MarkedValueLabels) {}
}
public protocol GaugeStyle {
    associatedtype Body: View
    typealias Configuration = GaugeStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct GaugeStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct CurrentValueLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct MinimumValueLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct MaximumValueLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public var value: Double = 0
    public var label: Label = Label()
    public var currentValueLabel: CurrentValueLabel? = nil
    public var minimumValueLabel: MinimumValueLabel? = nil
    public var maximumValueLabel: MaximumValueLabel? = nil
}
public struct DefaultGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct CircularGaugeStyle: GaugeStyle { public init() {}; public init(tint: Color) {}; public init<G: ShapeStyle>(tint: G) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryCircularGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryCircularCapacityGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct LinearGaugeStyle: GaugeStyle { public init() {}; public init(tint: Color) {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryLinearGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
public struct AccessoryLinearCapacityGaugeStyle: GaugeStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { EmptyView() } }
extension GaugeStyle where Self == DefaultGaugeStyle { public static var automatic: DefaultGaugeStyle { DefaultGaugeStyle() } }
extension GaugeStyle where Self == CircularGaugeStyle { public static var circular: CircularGaugeStyle { CircularGaugeStyle() } }
extension GaugeStyle where Self == AccessoryCircularGaugeStyle { public static var accessoryCircular: AccessoryCircularGaugeStyle { AccessoryCircularGaugeStyle() } }
extension GaugeStyle where Self == AccessoryCircularCapacityGaugeStyle { public static var accessoryCircularCapacity: AccessoryCircularCapacityGaugeStyle { AccessoryCircularCapacityGaugeStyle() } }
extension GaugeStyle where Self == LinearGaugeStyle { public static var linear: LinearGaugeStyle { LinearGaugeStyle() } }
extension GaugeStyle where Self == AccessoryLinearGaugeStyle { public static var accessoryLinear: AccessoryLinearGaugeStyle { AccessoryLinearGaugeStyle() } }
extension GaugeStyle where Self == AccessoryLinearCapacityGaugeStyle { public static var accessoryLinearCapacity: AccessoryLinearCapacityGaugeStyle { AccessoryLinearCapacityGaugeStyle() } }
extension View {
    public func gaugeStyle<S: GaugeStyle>(_ style: S) -> some View { self }
}

// MARK: Link, ShareLink

public struct Link<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(destination: URL, @ViewBuilder label: () -> Label) {}
}
extension Link where Label == Text {
    public init(_ titleKey: LocalizedStringKey, destination: URL) {}
    public init<S: StringProtocol>(_ title: S, destination: URL) {}
}
public struct SharePreview<Image: Transferable, Icon: Transferable> {
    public init(_ title: Text, image: Image, icon: Icon) {}
    public init(_ titleKey: LocalizedStringKey, image: Image, icon: Icon) {}
    public init<S: StringProtocol>(_ title: S, image: Image, icon: Icon) {}
}
extension SharePreview where Icon == Never {
    public init(_ title: Text, image: Image) {}
    public init(_ titleKey: LocalizedStringKey, image: Image) {}
    public init<S: StringProtocol>(_ title: S, image: Image) {}
}
extension SharePreview where Image == Never {
    public init(_ title: Text, icon: Icon) {}
    public init(_ titleKey: LocalizedStringKey, icon: Icon) {}
    public init<S: StringProtocol>(_ title: S, icon: Icon) {}
}
extension SharePreview where Image == Never, Icon == Never {
    public init(_ title: Text) {}
    public init(_ titleKey: LocalizedStringKey) {}
    public init<S: StringProtocol>(_ title: S) {}
}
extension Never: Transferable {
    public static var transferRepresentation: Never { return fatalError() }
}
public struct ShareLink<Data: RandomAccessCollection, PreviewImage, PreviewIcon, Label: View>: View where Data.Element: Transferable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(items: Data, subject: Text? = nil, message: Text? = nil, preview: @escaping (Data.Element) -> SharePreview<PreviewImage, PreviewIcon>, @ViewBuilder label: () -> Label) where PreviewImage: Transferable, PreviewIcon: Transferable {}
    public init<I: Transferable>(item: I, subject: Text? = nil, message: Text? = nil, preview: SharePreview<PreviewImage, PreviewIcon>, @ViewBuilder label: () -> Label) where Data == CollectionOfOne<I>, PreviewImage: Transferable, PreviewIcon: Transferable {}
}
extension ShareLink where PreviewImage == Never, PreviewIcon == Never {
    public init(items: Data, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) where Data.Element == String {}
    public init(items: Data, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) where Data.Element == URL {}
    public init(item: String, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) where Data == CollectionOfOne<String> {}
    public init(item: URL, subject: Text? = nil, message: Text? = nil, @ViewBuilder label: () -> Label) where Data == CollectionOfOne<URL> {}
}
extension ShareLink where Label == DefaultShareLinkLabel {
    public init(items: Data, subject: Text? = nil, message: Text? = nil, preview: @escaping (Data.Element) -> SharePreview<PreviewImage, PreviewIcon>) where PreviewImage: Transferable, PreviewIcon: Transferable {}
    public init<I: Transferable>(item: I, subject: Text? = nil, message: Text? = nil, preview: SharePreview<PreviewImage, PreviewIcon>) where Data == CollectionOfOne<I>, PreviewImage: Transferable, PreviewIcon: Transferable {}
    public init<I: Transferable>(_ titleKey: LocalizedStringKey, item: I, subject: Text? = nil, message: Text? = nil, preview: SharePreview<PreviewImage, PreviewIcon>) where Data == CollectionOfOne<I>, PreviewImage: Transferable, PreviewIcon: Transferable {}
    public init<S: StringProtocol, I: Transferable>(_ title: S, item: I, subject: Text? = nil, message: Text? = nil, preview: SharePreview<PreviewImage, PreviewIcon>) where Data == CollectionOfOne<I>, PreviewImage: Transferable, PreviewIcon: Transferable {}
}
extension ShareLink where Label == DefaultShareLinkLabel, PreviewImage == Never, PreviewIcon == Never {
    public init(items: Data, subject: Text? = nil, message: Text? = nil) where Data.Element == String {}
    public init(items: Data, subject: Text? = nil, message: Text? = nil) where Data.Element == URL {}
    public init(item: String, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<String> {}
    public init(item: URL, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<URL> {}
    public init(_ titleKey: LocalizedStringKey, item: String, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<String> {}
    public init(_ titleKey: LocalizedStringKey, item: URL, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<URL> {}
    public init<S: StringProtocol>(_ title: S, item: String, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<String> {}
    public init<S: StringProtocol>(_ title: S, item: URL, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<URL> {}
    public init(_ title: Text, item: String, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<String> {}
    public init(_ title: Text, item: URL, subject: Text? = nil, message: Text? = nil) where Data == CollectionOfOne<URL> {}
}
public struct DefaultShareLinkLabel: View { public typealias Body = Never; public var body: Never { return fatalError() } }

// MARK: Menu

public struct Menu<Label: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label, primaryAction: @escaping () -> Void) {}
}
extension Menu where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {}
}
extension Menu where Label == SwiftUI.Label<Text, Image> {
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, systemImage: String, @ViewBuilder content: () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, systemImage: String, @ViewBuilder content: () -> Content, primaryAction: @escaping () -> Void) {}
    public init(_ titleKey: LocalizedStringKey, image: String, @ViewBuilder content: () -> Content) {}
}
public protocol MenuStyle {}
public struct DefaultMenuStyle: MenuStyle { public init() {} }
public struct ButtonMenuStyle: MenuStyle { public init() {} }
extension MenuStyle where Self == DefaultMenuStyle { public static var automatic: DefaultMenuStyle { DefaultMenuStyle() } }
extension MenuStyle where Self == ButtonMenuStyle { public static var button: ButtonMenuStyle { ButtonMenuStyle() } }
extension View {
    public func menuStyle<S: MenuStyle>(_ style: S) -> some View { self }
    public func contextMenu<MenuItems: View>(@ViewBuilder menuItems: () -> MenuItems) -> some View { self }
    public func contextMenu<M: View, P: View>(@ViewBuilder menuItems: () -> M, @ViewBuilder preview: () -> P) -> some View { self }
    public func contextMenu<I: Hashable, M: View>(forSelectionType itemType: I.Type = I.self, @ViewBuilder menu: @escaping (Set<I>) -> M, primaryAction: ((Set<I>) -> Void)? = nil) -> some View { self }
}

// MARK: ContentUnavailableView, LabeledContent, GroupBox, DisclosureGroup

public struct ContentUnavailableView<Label: View, Description: View, Actions: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder label: () -> Label, @ViewBuilder description: () -> Description = { EmptyView() }, @ViewBuilder actions: () -> Actions = { EmptyView() }) {}
}
extension ContentUnavailableView where Label == SwiftUI.Label<Text, Image>, Description == Text?, Actions == EmptyView {
    public init(_ title: LocalizedStringKey, systemImage name: String, description: Text? = nil) {}
    public init<S: StringProtocol>(_ title: S, systemImage name: String, description: Text? = nil) {}
    public init(_ title: LocalizedStringKey, image name: String, description: Text? = nil) {}
    public init<S: StringProtocol>(_ title: S, image name: String, description: Text? = nil) {}
    public static var search: ContentUnavailableView<Label, Description, Actions> { ContentUnavailableView("Search", systemImage: "magnifyingglass") }
    public static func search(text: String) -> ContentUnavailableView<Label, Description, Actions> { ContentUnavailableView("Search", systemImage: "magnifyingglass") }
}

public struct LabeledContent<Label: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
}
extension LabeledContent where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}
extension LabeledContent where Label == Text, Content == Text {
    public init<S: StringProtocol>(_ titleKey: LocalizedStringKey, value: S) {}
    public init<S1: StringProtocol, S2: StringProtocol>(_ title: S1, value: S2) {}
    public init<F: FormatStyle>(_ titleKey: LocalizedStringKey, value: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {}
    public init<S: StringProtocol, F: FormatStyle>(_ title: S, value: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {}
}
extension LabeledContent where Label == LabeledContentStyleConfiguration.Label, Content == LabeledContentStyleConfiguration.Content {
    public init(_ configuration: LabeledContentStyleConfiguration) {}
}
public protocol LabeledContentStyle {
    associatedtype Body: View
    typealias Configuration = LabeledContentStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct LabeledContentStyleConfiguration {
    public struct Label: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct Content: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public let label: Label = Label()
    public let content: Content = Content()
}
public struct AutomaticLabeledContentStyle: LabeledContentStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.content } }
extension LabeledContentStyle where Self == AutomaticLabeledContentStyle { public static var automatic: AutomaticLabeledContentStyle { AutomaticLabeledContentStyle() } }
extension View {
    public func labeledContentStyle<S: LabeledContentStyle>(_ style: S) -> some View { self }
}

public struct GroupBox<Label: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: () -> Content, @ViewBuilder label: () -> Label) {}
}
extension GroupBox where Label == EmptyView {
    public init(@ViewBuilder content: () -> Content) {}
}
extension GroupBox where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) {}
    public init<S: StringProtocol>(_ title: S, @ViewBuilder content: () -> Content) {}
}
public protocol GroupBoxStyle {}
public struct DefaultGroupBoxStyle: GroupBoxStyle { public init() {} }
extension GroupBoxStyle where Self == DefaultGroupBoxStyle { public static var automatic: DefaultGroupBoxStyle { DefaultGroupBoxStyle() } }
extension View { public func groupBoxStyle<S: GroupBoxStyle>(_ style: S) -> some View { self } }

public struct DisclosureGroup<Label: View, Content: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(@ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
    public init(isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content, @ViewBuilder label: () -> Label) {}
}
extension DisclosureGroup where Label == Text {
    public init(_ titleKey: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {}
    public init(_ titleKey: LocalizedStringKey, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {}
    public init<S: StringProtocol>(_ label: S, @ViewBuilder content: @escaping () -> Content) {}
    public init<S: StringProtocol>(_ label: S, isExpanded: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) {}
}
public protocol DisclosureGroupStyle {}
public struct AutomaticDisclosureGroupStyle: DisclosureGroupStyle { public init() {} }
extension DisclosureGroupStyle where Self == AutomaticDisclosureGroupStyle { public static var automatic: AutomaticDisclosureGroupStyle { AutomaticDisclosureGroupStyle() } }
extension View { public func disclosureGroupStyle<S: DisclosureGroupStyle>(_ style: S) -> some View { self } }

// MARK: Sensory feedback

public struct SensoryFeedback: Equatable, Sendable {
    public static let success = SensoryFeedback(), warning = SensoryFeedback(), error = SensoryFeedback(), selection = SensoryFeedback(),
        increase = SensoryFeedback(), decrease = SensoryFeedback(), start = SensoryFeedback(), stop = SensoryFeedback(),
        alignment = SensoryFeedback(), levelChange = SensoryFeedback(), pathComplete = SensoryFeedback(), impact = SensoryFeedback()
    public static func impact(weight: Weight = .medium, intensity: Double = 1.0) -> SensoryFeedback { SensoryFeedback() }
    public static func impact(flexibility: Flexibility, intensity: Double = 1.0) -> SensoryFeedback { SensoryFeedback() }
    public enum Weight: Hashable, Sendable { case light, medium, heavy }
    public enum Flexibility: Hashable, Sendable { case rigid, solid, soft }
}
extension View {
    public func sensoryFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T) -> some View { self }
    public func sensoryFeedback<T: Equatable>(_ feedback: SensoryFeedback, trigger: T, condition: @escaping (T, T) -> Bool) -> some View { self }
    public func sensoryFeedback<T: Equatable>(trigger: T, _ feedback: @escaping (T, T) -> SensoryFeedback?) -> some View { self }
}
