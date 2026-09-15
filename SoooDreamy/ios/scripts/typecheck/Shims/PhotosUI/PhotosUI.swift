// PhotosUI stub — PhotosPicker and the SwiftUI photosPicker modifier.
@_exported import Foundation
@_exported import SwiftUI
@_exported import Photos

public struct PHPickerFilter: Equatable, Sendable {
    public static let images = PHPickerFilter(), videos = PHPickerFilter(), livePhotos = PHPickerFilter(), screenshots = PHPickerFilter(), panoramas = PHPickerFilter(), depthEffectPhotos = PHPickerFilter(), bursts = PHPickerFilter(), slomoVideos = PHPickerFilter(), timelapseVideos = PHPickerFilter(), cinematicVideos = PHPickerFilter(), screenRecordings = PHPickerFilter(), spatialMedia = PHPickerFilter()
    public static func any(of subfilters: [PHPickerFilter]) -> PHPickerFilter { PHPickerFilter() }
    public static func all(of subfilters: [PHPickerFilter]) -> PHPickerFilter { PHPickerFilter() }
    public static func not(_ filter: PHPickerFilter) -> PHPickerFilter { PHPickerFilter() }
}
public struct PhotosPickerItem: Equatable, Hashable, Sendable {
    public struct EncodingDisambiguationPolicy: Hashable, Sendable { public static let automatic = EncodingDisambiguationPolicy(), current = EncodingDisambiguationPolicy(), compatible = EncodingDisambiguationPolicy() }
    public init(itemIdentifier: String) {}
    public init(itemIdentifier: String, supportedContentTypes: [UTType]) {}
    public var itemIdentifier: String? { nil }
    public var supportedContentTypes: [UTType] { [] }
    public func loadTransferable<T: Transferable>(type: T.Type) async throws -> T? { nil }
    public func loadTransferable<T: Transferable>(type: T.Type, completionHandler: @escaping (Result<T?, Error>) -> Void) -> Progress { Progress(totalUnitCount: 1) }
}
public struct PhotosPickerSelectionBehavior: Equatable, Sendable { public static let `default` = PhotosPickerSelectionBehavior(), ordered = PhotosPickerSelectionBehavior(), continuous = PhotosPickerSelectionBehavior(), continuousAndOrdered = PhotosPickerSelectionBehavior() }
public struct PhotosPickerStyle: Equatable, Sendable { public static let presentation = PhotosPickerStyle(), inline = PhotosPickerStyle(), compact = PhotosPickerStyle() }
public struct PhotosPickerAccessoryVisibility: Equatable, Sendable { public static let automatic = PhotosPickerAccessoryVisibility(), visible = PhotosPickerAccessoryVisibility(), hidden = PhotosPickerAccessoryVisibility() }
public struct PhotosPickerAccessory: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let navigation = PhotosPickerAccessory(rawValue: 1), toolbar = PhotosPickerAccessory(rawValue: 2), all = PhotosPickerAccessory(rawValue: 3) }
public struct PhotosPicker<Label: View>: View {
    public typealias Body = Never
    public var body: Never { return fatalError() }
    public init(selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, photoLibrary: PHPhotoLibrary, @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, @ViewBuilder label: () -> Label) {}
    public init(selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, photoLibrary: PHPhotoLibrary, @ViewBuilder label: () -> Label) {}
}
extension PhotosPicker where Label == Text {
    public init(_ titleKey: LocalizedStringKey, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {}
    public init(_ titleKey: LocalizedStringKey, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {}
    public init<S: StringProtocol>(_ title: S, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) {}
}
extension View {
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) -> some View { self }
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<PhotosPickerItem?>, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, photoLibrary: PHPhotoLibrary) -> some View { self }
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic) -> some View { self }
    public func photosPicker(isPresented: Binding<Bool>, selection: Binding<[PhotosPickerItem]>, maxSelectionCount: Int? = nil, selectionBehavior: PhotosPickerSelectionBehavior = .default, matching filter: PHPickerFilter? = nil, preferredItemEncoding: PhotosPickerItem.EncodingDisambiguationPolicy = .automatic, photoLibrary: PHPhotoLibrary) -> some View { self }
    public func photosPickerStyle(_ style: PhotosPickerStyle) -> some View { self }
    public func photosPickerAccessoryVisibility(_ visibility: PhotosPickerAccessoryVisibility, edges: Edge.Set = .all) -> some View { self }
    public func photosPickerDisabledCapabilities(_ disabledCapabilities: PHPickerCapabilities) -> some View { self }
}
public struct PHPickerCapabilities: OptionSet, Sendable { public let rawValue: Int; public init(rawValue: Int) { self.rawValue = rawValue }; public static let search = PHPickerCapabilities(rawValue: 1), stagingArea = PHPickerCapabilities(rawValue: 2), collectionNavigation = PHPickerCapabilities(rawValue: 4), selectionActions = PHPickerCapabilities(rawValue: 8), sensitivityAnalysisIntervention = PHPickerCapabilities(rawValue: 16) }
