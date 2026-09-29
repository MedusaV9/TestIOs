// SwiftUI stub — sheets, covers, popovers, alerts, confirmation dialogs,
// presentation modifiers, file importer/exporter.
import Foundation

public struct PresentationDetent: Hashable, Sendable {
    public static let medium = PresentationDetent(), large = PresentationDetent()
    public static func fraction(_ fraction: CGFloat) -> PresentationDetent { PresentationDetent() }
    public static func height(_ height: CGFloat) -> PresentationDetent { PresentationDetent() }
    public static func custom<D: CustomPresentationDetent>(_ type: D.Type) -> PresentationDetent { PresentationDetent() }
    public struct Context { public var maxDetentValue: CGFloat { 0 }; public subscript<T>(dynamicMember keyPath: KeyPath<EnvironmentValues, T>) -> T { EnvironmentValues()[keyPath: keyPath] } }
}
public protocol CustomPresentationDetent { static func height(in context: PresentationDetent.Context) -> CGFloat? }
public struct PresentationBackgroundInteraction: Sendable {
    public static let automatic = PresentationBackgroundInteraction(), enabled = PresentationBackgroundInteraction(), disabled = PresentationBackgroundInteraction()
    public static func enabled(upThrough detent: PresentationDetent) -> PresentationBackgroundInteraction { PresentationBackgroundInteraction() }
}
public struct PresentationContentInteraction: Sendable { public static let automatic = PresentationContentInteraction(), resizes = PresentationContentInteraction(), scrolls = PresentationContentInteraction() }
public struct PresentationAdaptation: Sendable { public static let automatic = PresentationAdaptation(), none = PresentationAdaptation(), popover = PresentationAdaptation(), sheet = PresentationAdaptation(), fullScreenCover = PresentationAdaptation() }
public protocol PresentationSizing {}
public struct AutomaticPresentationSizing: PresentationSizing { public init() {} }
public struct FittedPresentationSizing: PresentationSizing { public init() {} }
public struct FormPresentationSizing: PresentationSizing { public init() {} }
public struct PagePresentationSizing: PresentationSizing { public init() {} }
extension PresentationSizing where Self == AutomaticPresentationSizing { public static var automatic: AutomaticPresentationSizing { AutomaticPresentationSizing() } }
extension PresentationSizing where Self == FittedPresentationSizing { public static var fitted: FittedPresentationSizing { FittedPresentationSizing() } }
extension PresentationSizing where Self == FormPresentationSizing { public static var form: FormPresentationSizing { FormPresentationSizing() } }
extension PresentationSizing where Self == PagePresentationSizing { public static var page: PagePresentationSizing { PagePresentationSizing() } }
public struct PopoverAttachmentAnchor {
    public static func rect(_ anchor: Anchor<CGRect>.Source) -> PopoverAttachmentAnchor { PopoverAttachmentAnchor() }
    public static func point(_ point: UnitPoint) -> PopoverAttachmentAnchor { PopoverAttachmentAnchor() }
}

extension View {
    public func sheet<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View { self }
    public func sheet<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View { self }
    public func fullScreenCover<Content: View>(isPresented: Binding<Bool>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) -> some View { self }
    public func fullScreenCover<Item: Identifiable, Content: View>(item: Binding<Item?>, onDismiss: (() -> Void)? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View { self }
    public func popover<Content: View>(isPresented: Binding<Bool>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge? = nil, @ViewBuilder content: @escaping () -> Content) -> some View { self }
    public func popover<Item: Identifiable, Content: View>(item: Binding<Item?>, attachmentAnchor: PopoverAttachmentAnchor = .rect(.bounds), arrowEdge: Edge? = nil, @ViewBuilder content: @escaping (Item) -> Content) -> some View { self }
    public func presentationDetents(_ detents: Set<PresentationDetent>) -> some View { self }
    public func presentationDetents(_ detents: Set<PresentationDetent>, selection: Binding<PresentationDetent>) -> some View { self }
    public func presentationDragIndicator(_ visibility: Visibility) -> some View { self }
    public func presentationBackground<S: ShapeStyle>(_ style: S) -> some View { self }
    public func presentationBackground<V: View>(alignment: Alignment = .center, @ViewBuilder content: () -> V) -> some View { self }
    public func presentationBackgroundInteraction(_ interaction: PresentationBackgroundInteraction) -> some View { self }
    public func presentationContentInteraction(_ behavior: PresentationContentInteraction) -> some View { self }
    public func presentationCornerRadius(_ cornerRadius: CGFloat?) -> some View { self }
    public func presentationCompactAdaptation(_ adaptation: PresentationAdaptation) -> some View { self }
    public func presentationCompactAdaptation(horizontal: PresentationAdaptation, vertical: PresentationAdaptation) -> some View { self }
    public func presentationSizing(_ sizing: some PresentationSizing) -> some View { self }
    public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View { self }

    public func alert<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View { self }
    public func alert<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View { self }
    public func alert<A: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A) -> some View { self }
    public func alert<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func alert<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func alert<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func alert<A: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func alert<S: StringProtocol, A: View, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func alert<A: View, T>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func alert<A: View, M: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func alert<S: StringProtocol, A: View, M: View, T>(_ title: S, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func alert<A: View, M: View, T>(_ title: Text, isPresented: Binding<Bool>, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func alert<E: LocalizedError, A: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: () -> A) -> some View { self }
    public func alert<E: LocalizedError, A: View, M: View>(isPresented: Binding<Bool>, error: E?, @ViewBuilder actions: (E) -> A, @ViewBuilder message: (E) -> M) -> some View { self }

    public func confirmationDialog<A: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View { self }
    public func confirmationDialog<S: StringProtocol, A: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View { self }
    public func confirmationDialog<A: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A) -> some View { self }
    public func confirmationDialog<A: View, M: View>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func confirmationDialog<S: StringProtocol, A: View, M: View>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func confirmationDialog<A: View, M: View>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, @ViewBuilder actions: () -> A, @ViewBuilder message: () -> M) -> some View { self }
    public func confirmationDialog<A: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func confirmationDialog<S: StringProtocol, A: View, T>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func confirmationDialog<A: View, T>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A) -> some View { self }
    public func confirmationDialog<A: View, M: View, T>(_ titleKey: LocalizedStringKey, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func confirmationDialog<S: StringProtocol, A: View, M: View, T>(_ title: S, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func confirmationDialog<A: View, M: View, T>(_ title: Text, isPresented: Binding<Bool>, titleVisibility: Visibility = .automatic, presenting data: T?, @ViewBuilder actions: (T) -> A, @ViewBuilder message: (T) -> M) -> some View { self }
    public func dialogIcon(_ icon: Image?) -> some View { self }
    public func dialogSeverity(_ severity: DialogSeverity) -> some View { self }
    public func dialogSuppressionToggle(isSuppressed: Binding<Bool>) -> some View { self }
    public func dialogSuppressionToggle(_ titleKey: LocalizedStringKey, isSuppressed: Binding<Bool>) -> some View { self }

    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, onCompletion: @escaping (Result<[URL], Error>) -> Void) -> some View { self }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View { self }
    public func fileImporter(isPresented: Binding<Bool>, allowedContentTypes: [UTType], allowsMultipleSelection: Bool, onCompletion: @escaping (Result<[URL], Error>) -> Void, onCancellation: @escaping () -> Void) -> some View { self }
    public func fileExporter<D: FileDocument>(isPresented: Binding<Bool>, document: D?, contentType: UTType, defaultFilename: String? = nil, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View { self }
    public func fileExporter<T: Transferable>(isPresented: Binding<Bool>, item: T?, contentTypes: [UTType] = [], defaultFilename: String? = nil, onCompletion: @escaping (Result<URL, Error>) -> Void, onCancellation: @escaping () -> Void = {}) -> some View { self }
    public func fileMover(isPresented: Binding<Bool>, file: URL?, onCompletion: @escaping (Result<URL, Error>) -> Void) -> some View { self }
    public func fileDialogConfirmationLabel(_ labelKey: LocalizedStringKey) -> some View { self }
}
public struct DialogSeverity: Hashable, Sendable { public static let automatic = DialogSeverity(), standard = DialogSeverity(), critical = DialogSeverity() }
public protocol FileDocument {
    static var readableContentTypes: [UTType] { get }
    static var writableContentTypes: [UTType] { get }
    init(configuration: FileDocumentReadConfiguration) throws
    func fileWrapper(configuration: FileDocumentWriteConfiguration) throws -> FileWrapper
}
extension FileDocument { public static var writableContentTypes: [UTType] { readableContentTypes } }
public struct FileDocumentReadConfiguration { public let contentType: UTType; public let file: FileWrapper }
public struct FileDocumentWriteConfiguration { public let contentType: UTType; public let existingFile: FileWrapper? }
