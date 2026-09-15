import Foundation

public struct UTType: Hashable, Sendable {
    public let identifier: String
    public init?(_ identifier: String) { self.identifier = identifier }
    public init?(filenameExtension: String) { identifier = "public.\(filenameExtension)" }
    public init?(filenameExtension: String, conformingTo supertype: UTType) { identifier = "public.\(filenameExtension)" }
    public init?(mimeType: String) { identifier = mimeType }
    public init(exportedAs identifier: String) { self.identifier = identifier }
    public init(exportedAs identifier: String, conformingTo parentType: UTType?) { self.identifier = identifier }
    public init(importedAs identifier: String) { self.identifier = identifier }
    public init(importedAs identifier: String, conformingTo parentType: UTType?) { self.identifier = identifier }
    public var preferredFilenameExtension: String? { nil }
    public var preferredMIMEType: String? { nil }
    public var localizedDescription: String? { nil }
    public func conforms(to type: UTType) -> Bool { true }

    public static let item = UTType(exportedAs: "public.item"), content = UTType(exportedAs: "public.content"), data = UTType(exportedAs: "public.data"),
        directory = UTType(exportedAs: "public.directory"), folder = UTType(exportedAs: "public.folder"), text = UTType(exportedAs: "public.text"),
        plainText = UTType(exportedAs: "public.plain-text"), utf8PlainText = UTType(exportedAs: "public.utf8-plain-text"), json = UTType(exportedAs: "public.json"),
        image = UTType(exportedAs: "public.image"), jpeg = UTType(exportedAs: "public.jpeg"), png = UTType(exportedAs: "public.png"), heic = UTType(exportedAs: "public.heic"),
        gif = UTType(exportedAs: "com.compuserve.gif"), movie = UTType(exportedAs: "public.movie"), video = UTType(exportedAs: "public.video"),
        mpeg4Movie = UTType(exportedAs: "public.mpeg-4"), quickTimeMovie = UTType(exportedAs: "com.apple.quicktime-movie"), audio = UTType(exportedAs: "public.audio"),
        mp3 = UTType(exportedAs: "public.mp3"), mpeg4Audio = UTType(exportedAs: "public.mpeg-4-audio"), wav = UTType(exportedAs: "com.microsoft.waveform-audio"),
        pdf = UTType(exportedAs: "com.adobe.pdf"), url = UTType(exportedAs: "public.url"), fileURL = UTType(exportedAs: "public.file-url"),
        zip = UTType(exportedAs: "public.zip-archive"), archive = UTType(exportedAs: "public.archive"), package = UTType(exportedAs: "com.apple.package"),
        propertyList = UTType(exportedAs: "com.apple.property-list"), xml = UTType(exportedAs: "public.xml"), commaSeparatedText = UTType(exportedAs: "public.comma-separated-values-text")
}
