// SwiftUI stub — Text, LocalizedStringKey, Label, text input, text modifiers.
import Foundation

public struct LocalizedStringKey: Equatable, ExpressibleByStringInterpolation, Sendable {
    public init(_ value: String) {}
    public init(stringLiteral value: String) {}
    public init(stringInterpolation: StringInterpolation) {}
    public struct StringInterpolation: StringInterpolationProtocol {
        public init(literalCapacity: Int, interpolationCount: Int) {}
        public mutating func appendLiteral(_ literal: String) {}
        public mutating func appendInterpolation(_ string: String) {}
        public mutating func appendInterpolation<Subject: ReferenceConvertible>(_ subject: Subject, formatter: Formatter? = nil) {}
        public mutating func appendInterpolation<Subject: NSObject>(_ subject: Subject, formatter: Formatter? = nil) {}
        public mutating func appendInterpolation<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatInput: Equatable, F.FormatOutput == String {}
        public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T) {}
        public mutating func appendInterpolation<T: _FormatSpecifiable>(_ value: T, specifier: String) {}
        public mutating func appendInterpolation(_ text: Text) {}
        public mutating func appendInterpolation(_ image: Image) {}
        public mutating func appendInterpolation(_ date: Date, style: Text.DateStyle) {}
        public mutating func appendInterpolation(_ dates: ClosedRange<Date>) {}
        public mutating func appendInterpolation(_ interval: DateInterval) {}
        public mutating func appendInterpolation(_ resource: LocalizedStringResource) {}
        public mutating func appendInterpolation<T>(_ value: T) {}
    }
}
public protocol _FormatSpecifiable {}
extension Int: _FormatSpecifiable {}
extension Int8: _FormatSpecifiable {}
extension Int16: _FormatSpecifiable {}
extension Int32: _FormatSpecifiable {}
extension Int64: _FormatSpecifiable {}
extension UInt: _FormatSpecifiable {}
extension UInt8: _FormatSpecifiable {}
extension UInt16: _FormatSpecifiable {}
extension UInt32: _FormatSpecifiable {}
extension UInt64: _FormatSpecifiable {}
extension Float: _FormatSpecifiable {}
extension Double: _FormatSpecifiable {}
extension CGFloat: _FormatSpecifiable {}

public struct Text: View, Equatable, Sendable {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(verbatim content: String) {}
    public init<S: StringProtocol>(_ content: S) {}
    public init(_ key: LocalizedStringKey, tableName: String? = nil, bundle: Bundle? = nil, comment: StaticString? = nil) {}
    public init(_ resource: LocalizedStringResource) {}
    public init(_ attributedContent: AttributedString) {}
    public init(_ image: Image) {}
    public init(_ date: Date, style: Text.DateStyle) {}
    public init(_ dates: ClosedRange<Date>) {}
    public init(_ interval: DateInterval) {}
    public init<F: FormatStyle>(_ input: F.FormatInput, format: F) where F.FormatOutput == String {}
    public init<Subject: ReferenceConvertible>(_ subject: Subject, formatter: Formatter) {}
    public init<Subject: NSObject>(_ subject: Subject, formatter: Formatter) {}
    public init(timerInterval: ClosedRange<Date>, pauseTime: Date? = nil, countsDown: Bool = true, showsHours: Bool = true) {}
    public init(_ date: Date, format: Date.FormatStyle) {}

    public struct DateStyle: Equatable, Sendable {
        public static let time = DateStyle(), date = DateStyle(), relative = DateStyle(), offset = DateStyle(), timer = DateStyle()
    }
    public enum Case: Hashable, Sendable { case uppercase, lowercase }
    public enum TruncationMode: Hashable, Sendable { case head, tail, middle }
    public enum LineStyle: Hashable, Sendable {
        case single, thick, double, patternDot, patternDash, patternDashDot, patternDashDotDot, byWord
        public struct Pattern: Hashable, Sendable { public static let solid = Pattern(), dot = Pattern(), dash = Pattern(), dashDot = Pattern(), dashDotDot = Pattern() }
        public init(pattern: Pattern = .solid, color: Color? = nil) { self = .single }
    }
    public enum Scale: Hashable, Sendable { case `default`, secondary }
    public struct Layout: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue } }
    public struct WritingDirectionStrategy: Hashable, Sendable { public static let automatic = WritingDirectionStrategy(), environment = WritingDirectionStrategy() }
    public struct AlignmentStrategy: Hashable, Sendable { public static let automatic = AlignmentStrategy(), environment = AlignmentStrategy() }

    public func font(_ font: Font?) -> Text { self }
    public func fontWeight(_ weight: Font.Weight?) -> Text { self }
    public func fontDesign(_ design: Font.Design?) -> Text { self }
    public func fontWidth(_ width: Font.Width?) -> Text { self }
    public func foregroundColor(_ color: Color?) -> Text { self }
    public func foregroundStyle<S: ShapeStyle>(_ style: S) -> Text { self }
    public func bold() -> Text { self }
    public func bold(_ isActive: Bool) -> Text { self }
    public func italic() -> Text { self }
    public func italic(_ isActive: Bool) -> Text { self }
    public func monospaced(_ isActive: Bool = true) -> Text { self }
    public func monospacedDigit() -> Text { self }
    public func strikethrough(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> Text { self }
    public func underline(_ isActive: Bool = true, color: Color? = nil) -> Text { self }
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern, color: Color? = nil) -> Text { self }
    public func kerning(_ kerning: CGFloat) -> Text { self }
    public func tracking(_ tracking: CGFloat) -> Text { self }
    public func baselineOffset(_ baselineOffset: CGFloat) -> Text { self }
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> Text { self }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> Text { self }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> Text { self }
    public func speechAdjustedPitch(_ value: Double) -> Text { self }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> Text { self }
    public func accessibilityLabel(_ label: Text) -> Text { self }
    public func accessibilityLabel(_ labelKey: LocalizedStringKey) -> Text { self }
    public func accessibilityLabel<S: StringProtocol>(_ label: S) -> Text { self }
    public func accessibilityTextContentType(_ value: AccessibilityTextContentType) -> Text { self }
    public func accessibilityHeading(_ level: AccessibilityHeadingLevel) -> Text { self }
    public func textVariant(_ preference: Text.Layout) -> Text { self }
    public func customAttribute<T: TextAttribute>(_ attribute: T) -> Text { self }
    public static func + (lhs: Text, rhs: Text) -> Text { lhs }
    public static func == (lhs: Text, rhs: Text) -> Bool { true }
}
public protocol TextAttribute {}
public struct AccessibilityTextContentType: Hashable, Sendable { public static let plain = AccessibilityTextContentType(), console = AccessibilityTextContentType(), fileSystem = AccessibilityTextContentType(), messaging = AccessibilityTextContentType(), narrative = AccessibilityTextContentType(), sourceCode = AccessibilityTextContentType(), spreadsheet = AccessibilityTextContentType(), wordProcessing = AccessibilityTextContentType() }
public enum AccessibilityHeadingLevel: UInt, Hashable, Sendable { case unspecified, h1, h2, h3, h4, h5, h6 }

public enum TextAlignment: Hashable, CaseIterable, Sendable { case leading, center, trailing }

// MARK: Label

public struct Label<Title: View, Icon: View>: View {
    public init(@ViewBuilder title: () -> Title, @ViewBuilder icon: () -> Icon) {}
    public typealias Body = Never
    public var body: Never { return fatalError() }
}
extension Label where Title == Text, Icon == Image {
    public init(_ titleKey: LocalizedStringKey, image name: String) {}
    public init<S: StringProtocol>(_ title: S, image name: String) {}
    public init(_ titleKey: LocalizedStringKey, systemImage name: String) {}
    public init<S: StringProtocol>(_ title: S, systemImage name: String) {}
    public init(_ title: Text, systemImage name: String) {}
    public init(_ title: Text, image name: String) {}
}
public protocol LabelStyle {
    associatedtype Body: View
    typealias Configuration = LabelStyleConfiguration
    @ViewBuilder func makeBody(configuration: Self.Configuration) -> Self.Body
}
public struct LabelStyleConfiguration {
    public struct Title: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public struct Icon: View { public typealias Body = Never; public var body: Never { return fatalError() } }
    public var title: Title { Title() }
    public var icon: Icon { Icon() }
}
public struct DefaultLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.title } }
public struct IconOnlyLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.icon } }
public struct TitleOnlyLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.title } }
public struct TitleAndIconLabelStyle: LabelStyle { public init() {}; public func makeBody(configuration: Configuration) -> some View { configuration.title } }
extension LabelStyle where Self == DefaultLabelStyle { public static var automatic: DefaultLabelStyle { DefaultLabelStyle() } }
extension LabelStyle where Self == IconOnlyLabelStyle { public static var iconOnly: IconOnlyLabelStyle { IconOnlyLabelStyle() } }
extension LabelStyle where Self == TitleOnlyLabelStyle { public static var titleOnly: TitleOnlyLabelStyle { TitleOnlyLabelStyle() } }
extension LabelStyle where Self == TitleAndIconLabelStyle { public static var titleAndIcon: TitleAndIconLabelStyle { TitleAndIconLabelStyle() } }
extension View {
    public func labelStyle<S: LabelStyle>(_ style: S) -> some View { self }
}

// MARK: Text input

public struct TextField<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(text: Binding<String>, prompt: Text? = nil, axis: Axis = .horizontal, @ViewBuilder label: () -> Label) {}
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
    public init<F: ParseableFormatStyle>(value: Binding<F.FormatInput>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F.FormatOutput == String {}
    public init<F: ParseableFormatStyle>(value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil, @ViewBuilder label: () -> Label) where F.FormatOutput == String {}
}
extension TextField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, axis: Axis) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, axis: Axis) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?, axis: Axis) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?, axis: Axis) {}
    public init<F: ParseableFormatStyle>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F.FormatOutput == String {}
    public init<S: StringProtocol, F: ParseableFormatStyle>(_ title: S, value: Binding<F.FormatInput>, format: F, prompt: Text? = nil) where F.FormatOutput == String {}
    public init<F: ParseableFormatStyle>(_ titleKey: LocalizedStringKey, value: Binding<F.FormatInput?>, format: F, prompt: Text? = nil) where F.FormatOutput == String {}
    public init<T>(_ titleKey: LocalizedStringKey, value: Binding<T>, formatter: Formatter, prompt: Text? = nil) {}
    public init<S: StringProtocol, T>(_ title: S, value: Binding<T>, formatter: Formatter, prompt: Text? = nil) {}
    public init<T>(_ titleKey: LocalizedStringKey, value: Binding<T>, formatter: Formatter) {}
}
public struct SecureField<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(text: Binding<String>, prompt: Text? = nil, @ViewBuilder label: () -> Label) {}
}
extension SecureField where Label == Text {
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, prompt: Text?) {}
    public init<S: StringProtocol>(_ title: S, text: Binding<String>, prompt: Text?) {}
    public init(_ titleKey: LocalizedStringKey, text: Binding<String>, onCommit: @escaping () -> Void) {}
}
public struct TextEditor: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(text: Binding<String>) {}
    public init(text: Binding<AttributedString>) {}
    public init(text: Binding<AttributedString>, selection: Binding<AttributedTextSelection?>) {}
}
public struct AttributedTextSelection: Equatable, Sendable {}
public protocol TextFieldStyle {}
public struct DefaultTextFieldStyle: TextFieldStyle { public init() {} }
public struct PlainTextFieldStyle: TextFieldStyle { public init() {} }
public struct RoundedBorderTextFieldStyle: TextFieldStyle { public init() {} }
extension TextFieldStyle where Self == DefaultTextFieldStyle { public static var automatic: DefaultTextFieldStyle { DefaultTextFieldStyle() } }
extension TextFieldStyle where Self == PlainTextFieldStyle { public static var plain: PlainTextFieldStyle { PlainTextFieldStyle() } }
extension TextFieldStyle where Self == RoundedBorderTextFieldStyle { public static var roundedBorder: RoundedBorderTextFieldStyle { RoundedBorderTextFieldStyle() } }

public enum SubmitLabel: Hashable, Sendable { case done, go, send, join, route, search, `return`, next, `continue` }
public struct SubmitTriggers: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let text = SubmitTriggers(rawValue: 1), search = SubmitTriggers(rawValue: 2)
}
public struct TextInputAutocapitalization: Sendable {
    public static let never = TextInputAutocapitalization(), words = TextInputAutocapitalization(), sentences = TextInputAutocapitalization(), characters = TextInputAutocapitalization()
    public init?(_ type: UITextAutocapitalizationType) {}
    private init() {}
}
public struct TextSelectability { }
public protocol TextSelectabilityProtocol { static var allowsSelection: Bool { get } }
public struct EnabledTextSelectability: TextSelectabilityProtocol { public static var allowsSelection: Bool { true } }
public struct DisabledTextSelectability: TextSelectabilityProtocol { public static var allowsSelection: Bool { false } }
extension TextSelectabilityProtocol where Self == EnabledTextSelectability { public static var enabled: EnabledTextSelectability { EnabledTextSelectability() } }
extension TextSelectabilityProtocol where Self == DisabledTextSelectability { public static var disabled: DisabledTextSelectability { DisabledTextSelectability() } }
public struct TextInputDictationActivation: Hashable, Sendable { public static let onLook = TextInputDictationActivation(), onSelect = TextInputDictationActivation() }
public struct TextInputFormattingControlPlacement { public struct Set: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let contextMenu = Set(rawValue: 1), inputAssistant = Set(rawValue: 2), all = Set(rawValue: 3) } }
public struct WritingToolsBehavior: Hashable, Sendable { public static let automatic = WritingToolsBehavior(), complete = WritingToolsBehavior(), limited = WritingToolsBehavior(), disabled = WritingToolsBehavior() }

extension View {
    public func font(_ font: Font?) -> some View { self }
    public func fontWeight(_ weight: Font.Weight?) -> some View { self }
    public func fontDesign(_ design: Font.Design?) -> some View { self }
    public func fontWidth(_ width: Font.Width?) -> some View { self }
    public func bold(_ isActive: Bool = true) -> some View { self }
    public func italic(_ isActive: Bool = true) -> some View { self }
    public func monospaced(_ isActive: Bool = true) -> some View { self }
    public func monospacedDigit() -> some View { self }
    public func strikethrough(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View { self }
    public func underline(_ isActive: Bool = true, pattern: Text.LineStyle.Pattern = .solid, color: Color? = nil) -> some View { self }
    public func kerning(_ kerning: CGFloat) -> some View { self }
    public func tracking(_ tracking: CGFloat) -> some View { self }
    public func baselineOffset(_ baselineOffset: CGFloat) -> some View { self }
    public func textScale(_ scale: Text.Scale, isEnabled: Bool = true) -> some View { self }
    public func lineLimit(_ number: Int?) -> some View { self }
    public func lineLimit(_ limit: PartialRangeFrom<Int>) -> some View { self }
    public func lineLimit(_ limit: PartialRangeThrough<Int>) -> some View { self }
    public func lineLimit(_ limit: ClosedRange<Int>) -> some View { self }
    public func lineLimit(_ limit: Int, reservesSpace: Bool) -> some View { self }
    public func lineSpacing(_ lineSpacing: CGFloat) -> some View { self }
    public func multilineTextAlignment(_ alignment: TextAlignment) -> some View { self }
    public func minimumScaleFactor(_ factor: CGFloat) -> some View { self }
    public func truncationMode(_ mode: Text.TruncationMode) -> some View { self }
    public func allowsTightening(_ flag: Bool) -> some View { self }
    public func textCase(_ textCase: Text.Case?) -> some View { self }
    public func textSelection<S: TextSelectabilityProtocol>(_ selectability: S) -> some View { self }
    public func textFieldStyle<S: TextFieldStyle>(_ style: S) -> some View { self }
    public func keyboardType(_ type: UIKeyboardType) -> some View { self }
    public func textContentType(_ textContentType: UITextContentType?) -> some View { self }
    public func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization?) -> some View { self }
    public func autocorrectionDisabled(_ disable: Bool = true) -> some View { self }
    public func submitLabel(_ submitLabel: SubmitLabel) -> some View { self }
    public func submitScope(_ isBlocking: Bool = true) -> some View { self }
    public func onSubmit(of triggers: SubmitTriggers = .text, _ action: @escaping () -> Void) -> some View { self }
    public func focused(_ condition: FocusState<Bool>.Binding) -> some View { self }
    public func focused<Value: Hashable>(_ binding: FocusState<Value>.Binding, equals value: Value) -> some View { self }
    public func textInputSuggestions<S: View>(@ViewBuilder _ suggestions: () -> S) -> some View { self }
    public func writingToolsBehavior(_ behavior: WritingToolsBehavior) -> some View { self }
    public func textInputFormattingControlVisibility(_ visibility: Visibility, for placements: TextInputFormattingControlPlacement.Set) -> some View { self }
    public func findNavigator(isPresented: Binding<Bool>) -> some View { self }
    public func findDisabled(_ isDisabled: Bool = true) -> some View { self }
    public func replaceDisabled(_ isDisabled: Bool = true) -> some View { self }
    public func speechAlwaysIncludesPunctuation(_ value: Bool = true) -> some View { self }
    public func speechSpellsOutCharacters(_ value: Bool = true) -> some View { self }
    public func speechAdjustedPitch(_ value: Double) -> some View { self }
    public func speechAnnouncementsQueued(_ value: Bool = true) -> some View { self }
    public func textRenderer<T: TextRenderer>(_ renderer: T) -> some View { self }
}
public protocol TextRenderer: Animatable {
    func draw(layout: Text.Layout, in context: inout GraphicsContext)
    func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize
    var displayPadding: EdgeInsets { get }
}
extension TextRenderer {
    public func sizeThatFits(proposal: ProposedViewSize, text: TextProxy) -> CGSize { text.sizeThatFits(proposal) }
    public var displayPadding: EdgeInsets { EdgeInsets() }
}
public struct TextProxy { public func sizeThatFits(_ proposal: ProposedViewSize) -> CGSize { .zero } }
