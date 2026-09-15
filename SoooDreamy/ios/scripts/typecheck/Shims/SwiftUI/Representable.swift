// SwiftUI stub — UIKit bridging protocols.
import Foundation

@MainActor @preconcurrency
public protocol UIViewControllerRepresentable: View where Body == Never {
    associatedtype UIViewControllerType: UIViewController
    associatedtype Coordinator = Void
    typealias Context = UIViewControllerRepresentableContext<Self>
    @MainActor @preconcurrency func makeUIViewController(context: Self.Context) -> Self.UIViewControllerType
    @MainActor @preconcurrency func updateUIViewController(_ uiViewController: Self.UIViewControllerType, context: Self.Context)
    @MainActor @preconcurrency static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator)
    @MainActor @preconcurrency func makeCoordinator() -> Self.Coordinator
    @MainActor @preconcurrency func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize?
}
extension UIViewControllerRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void {}
}
extension UIViewControllerRepresentable {
    public static func dismantleUIViewController(_ uiViewController: Self.UIViewControllerType, coordinator: Self.Coordinator) {}
    public func sizeThatFits(_ proposal: ProposedViewSize, uiViewController: Self.UIViewControllerType, context: Self.Context) -> CGSize? { nil }
    public var body: Never { return fatalError() }
}
public struct UIViewControllerRepresentableContext<Representable: UIViewControllerRepresentable> {
    public let coordinator: Representable.Coordinator
    public var transaction: Transaction { Transaction() }
    public var environment: EnvironmentValues { EnvironmentValues() }
}

@MainActor @preconcurrency
public protocol UIViewRepresentable: View where Body == Never {
    associatedtype UIViewType: UIView
    associatedtype Coordinator = Void
    typealias Context = UIViewRepresentableContext<Self>
    @MainActor @preconcurrency func makeUIView(context: Self.Context) -> Self.UIViewType
    @MainActor @preconcurrency func updateUIView(_ uiView: Self.UIViewType, context: Self.Context)
    @MainActor @preconcurrency static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator)
    @MainActor @preconcurrency func makeCoordinator() -> Self.Coordinator
    @MainActor @preconcurrency func sizeThatFits(_ proposal: ProposedViewSize, uiView: Self.UIViewType, context: Self.Context) -> CGSize?
}
extension UIViewRepresentable where Coordinator == Void {
    public func makeCoordinator() -> Void {}
}
extension UIViewRepresentable {
    public static func dismantleUIView(_ uiView: Self.UIViewType, coordinator: Self.Coordinator) {}
    public func sizeThatFits(_ proposal: ProposedViewSize, uiView: Self.UIViewType, context: Self.Context) -> CGSize? { nil }
    public var body: Never { return fatalError() }
}
public struct UIViewRepresentableContext<Representable: UIViewRepresentable> {
    public let coordinator: Representable.Coordinator
    public var transaction: Transaction { Transaction() }
    public var environment: EnvironmentValues { EnvironmentValues() }
}

@preconcurrency @MainActor open class UIHostingController<Content: View>: UIViewController {
    public init(rootView: Content) { super.init() }
    open var rootView: Content { get { fatalError() } set {} }
    open var sizingOptions: UIHostingControllerSizingOptions = []
    open var safeAreaRegions: SafeAreaRegions = .all
    open func sizeThatFits(in size: CGSize) -> CGSize { size }
}
public struct UIHostingControllerSizingOptions: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    public static let preferredContentSize = UIHostingControllerSizingOptions(rawValue: 1), intrinsicContentSize = UIHostingControllerSizingOptions(rawValue: 2)
}
