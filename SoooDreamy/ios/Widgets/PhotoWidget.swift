import WidgetKit
import SwiftUI
import UIKit
import AppIntents

// MARK: - Timeline

struct PhotoEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
    let caption: String?
    let palette: WidgetPalette
    /// v3.0 frame style ("polaroid" | "filmstrip" | "scrapbook"); nil = full-bleed.
    var frame: String?
}

struct PhotoProvider: AppIntentTimelineProvider {
    private func palette(for configuration: PhotoWidgetConfigIntent) -> WidgetPalette {
        WidgetPalette.resolve(kind: WidgetKindID.photo,
                              intentThemeId: configuration.theme.themeId)
    }

    /// Effective frame: per-widget intent override → studio config → none.
    private func frame(for configuration: PhotoWidgetConfigIntent) -> String? {
        if configuration.frame != .studio { return configuration.frame.frameId }
        return SharedStore.readStudioConfig().config(for: WidgetKindID.photo).photoFrame
    }

    func placeholder(in context: Context) -> PhotoEntry {
        PhotoEntry(date: Date(), image: Self.cachedImage(), caption: nil,
                   palette: WidgetPalette.resolve(kind: WidgetKindID.photo))
    }

    func snapshot(for configuration: PhotoWidgetConfigIntent, in context: Context) async -> PhotoEntry {
        // Gallery preview: no network fetch — show the last cached photo
        // instead of a blank gradient whenever one exists.
        PhotoEntry(date: Date(), image: Self.cachedImage(),
                   caption: SharedStore.readSnapshot()?.photoCaption,
                   palette: palette(for: configuration),
                   frame: frame(for: configuration))
    }

    func timeline(for configuration: PhotoWidgetConfigIntent, in context: Context) async -> Timeline<PhotoEntry> {
        let snapshot = SharedStore.readSnapshot()
        let refresh = Date().addingTimeInterval(30 * 60)
        let palette = palette(for: configuration)

        // Which photo? The studio/app showcase by default; the per-widget
        // intent can force favorite/newest via a direct server lookup.
        var urlString = snapshot?.photoURLString
        var caption = snapshot?.photoCaption
        let studioSource = SharedStore.readStudioConfig()
            .config(for: WidgetKindID.photo).photoSource
        let effectiveSource: String? = {
            switch configuration.source {
            case .studio: return studioSource
            case .favorite: return "favorite"
            case .newest: return "newest"
            }
        }()
        if let source = effectiveSource, source == "favorite" || source == "newest",
           let picked = await Self.pickPhoto(source: source) {
            urlString = picked.url
            caption = picked.caption
        }

        let frame = frame(for: configuration)
        guard let urlString, let url = URL(string: urlString) else {
            // No showcase photo (e.g. gallery emptied) — genuine empty state.
            return Timeline(entries: [PhotoEntry(date: Date(), image: nil,
                                                 caption: nil, palette: palette,
                                                 frame: frame)],
                            policy: .after(refresh))
        }
        let image: UIImage?
        if let credentials = SharedStore.readServerCredentials(),
           let token = SharedKeychain.activeToken(profileID: credentials.profileID),
           let data = await Self.fetchData(from: url, token: token),
           let fetched = WidgetImages.decode(data, maxDimension: 800) {
            // Remember the bytes so the widget survives the server napping.
            SharedStore.writeCachedPhotoJPEG(data)
            image = fetched
        } else {
            // Offline / server asleep: fall back to the last good photo.
            image = Self.cachedImage()
        }
        let entry = PhotoEntry(date: Date(), image: image, caption: caption,
                               palette: palette, frame: frame)
        return Timeline(entries: [entry], policy: .after(refresh))
    }

    static func cachedImage() -> UIImage? {
        guard let data = SharedStore.readCachedPhotoJPEG() else { return nil }
        return WidgetImages.decode(data, maxDimension: 800)
    }

    private static func fetchData(from url: URL, token: String) async -> Data? {
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            return nil
        }
        return data.isEmpty ? nil : data
    }

    /// Direct server lookup for the per-widget photo source override.
    /// Uses the app-group-mirrored credentials; nil on any failure.
    private static func pickPhoto(source: String) async -> (url: String, caption: String?)? {
        guard let creds = SharedStore.readServerCredentials(),
              let token = SharedKeychain.activeToken(profileID: creds.profileID),
              let base = URL(string: creds.baseURLString) else { return nil }
        var request = URLRequest(url: base.appendingPathComponent("api/photos"),
                                 timeoutInterval: 12)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse).map({ (200..<300).contains($0.statusCode) }) ?? false,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let photos = json["photos"] as? [[String: Any]], !photos.isEmpty else { return nil }
        let chosen: [String: Any]?
        if source == "favorite" {
            chosen = photos.first { (($0["favorites"] as? [String]) ?? []).isEmpty == false }
                ?? photos.first
        } else {
            chosen = photos.first
        }
        guard let chosen,
              let path = (chosen["thumbUrl"] as? String) ?? (chosen["url"] as? String) else {
            return nil
        }
        let absolute = base.absoluteString + path
        return (url: absolute, caption: chosen["caption"] as? String)
    }
}

// MARK: - Views

struct PhotoWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PhotoEntry

    private var palette: WidgetPalette { entry.palette }

    /// Framed styles render the photo inset (frame around it); full-bleed
    /// uses the photo itself as the widget background.
    private var framed: Bool { entry.frame != nil && entry.image != nil }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular: rectangular
            default:
                if framed, let image = entry.image, let style = entry.frame {
                    PhotoFrameView(image: image, caption: entry.caption,
                                   style: style, family: family)
                } else {
                    photoOrEmpty
                }
            }
        }
        .containerBackground(for: .widget) { background }
        .widgetURL(URL(string: "sooodreamy://photos"))
    }

    @ViewBuilder
    private var photoOrEmpty: some View {
        if entry.image != nil {
            captionOverlay
        } else {
            emptyState
        }
    }

    @ViewBuilder
    private var background: some View {
        if family != .accessoryRectangular, !framed, let image = entry.image {
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                bottomScrim
            }
        } else {
            WidgetChromeBackground(palette: palette, photoFriendly: true)
        }
    }

    private var bottomScrim: some View {
        LinearGradient(
            colors: [.clear, .clear, Color.black.opacity(0.55)],
            startPoint: .top, endPoint: .bottom)
    }

    private var captionOverlay: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)
            HStack(alignment: .bottom, spacing: 6) {
                if let caption = entry.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .foregroundStyle(.white)
                        .lineLimit(family == .systemLarge ? 3 : 2)
                        .minimumScaleFactor(0.8)
                        .shadow(color: .black.opacity(0.6), radius: 2)
                }
                Spacer(minLength: 0)
                Text("💜")
                    .font(.system(size: 13))
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Text("📸")
                .font(.system(size: family == .systemSmall ? 30 : 40))
            Text(WText.t("Noch kein Foto", "No photo yet"))
                .font(.system(.caption, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var rectangular: some View {
        HStack(spacing: 8) {
            Text("📸")
                .font(.system(size: 24))
            VStack(alignment: .leading, spacing: 1) {
                Text(WText.t("Euer Foto", "Your photo"))
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .lineLimit(1)
                    .widgetAccentable()
                if let caption = entry.caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                } else {
                    Text(WText.t("Tippen zum Ansehen", "Tap to view"))
                        .font(.system(.caption, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
        }
    }
}

// MARK: - v3.0 frame styles (Agent C)

/// Photo frames drawn purely in SwiftUI: Polaroid (white border, chin,
/// slight tilt), film strip (sprocket holes) and scrapbook (paper + washi
/// tape). No binary assets — everything is shapes and gradients.
struct PhotoFrameView: View {
    let image: UIImage
    let caption: String?
    let style: String
    let family: WidgetFamily

    private var compact: Bool { family == .systemSmall }

    var body: some View {
        switch style {
        case "filmstrip": filmstrip
        case "scrapbook": scrapbook
        default: polaroid
        }
    }

    // MARK: Polaroid

    private var polaroid: some View {
        VStack(spacing: 0) {
            photo
                .padding(compact ? 5 : 8)
            HStack {
                if let caption, !caption.isEmpty {
                    Text(caption)
                        .font(.system(size: compact ? 10 : 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color(red: 0.25, green: 0.2, blue: 0.3))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                } else {
                    Text("💜")
                        .font(.system(size: compact ? 10 : 13))
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, compact ? 7 : 10)
            .padding(.bottom, compact ? 6 : 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color(red: 0.98, green: 0.97, blue: 0.94))
                .shadow(color: .black.opacity(0.45), radius: 5, y: 3))
        .rotationEffect(.degrees(-2.2))
        .padding(compact ? 2 : 6)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: Film strip

    private var filmstrip: some View {
        VStack(spacing: 0) {
            sprocketRow
            photo
            sprocketRow
        }
        .background(RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(Color.black.opacity(0.92)))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var sprocketRow: some View {
        HStack(spacing: compact ? 7 : 10) {
            ForEach(0..<(compact ? 6 : 9), id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.6, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: compact ? 7 : 9, height: compact ? 5 : 7)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, compact ? 4 : 6)
    }

    // MARK: Scrapbook

    private var scrapbook: some View {
        ZStack(alignment: .bottom) {
            photo
                .padding(compact ? 6 : 9)
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color(red: 0.96, green: 0.93, blue: 0.86))
                        .shadow(color: .black.opacity(0.4), radius: 4, y: 2))
                .overlay(alignment: .topLeading) { tape(rotation: -38) }
                .overlay(alignment: .topTrailing) { tape(rotation: 38) }

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.system(size: compact ? 10 : 12, weight: .semibold, design: .serif).italic())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.vertical, 3)
                    .padding(.horizontal, 8)
                    .background(Capsule().fill(Color.black.opacity(0.5)))
                    .offset(y: compact ? 2 : 0)
            }
        }
        .padding(compact ? 3 : 7)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tape(rotation: Double) -> some View {
        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
            .fill(Color(red: 1.0, green: 0.82, blue: 0.55).opacity(0.82))
            .frame(width: compact ? 26 : 36, height: compact ? 9 : 12)
            .rotationEffect(.degrees(rotation))
            .offset(x: rotation < 0 ? -6 : 6, y: -3)
    }

    // MARK: Shared photo pane

    private var photo: some View {
        Color.clear
            .aspectRatio(family == .systemMedium ? 1.9 : 1.0, contentMode: .fit)
            .overlay(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill())
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
    }
}

// MARK: - Widget

struct PhotoWidget: Widget {
    let kind = WidgetKindID.photo

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind,
                               intent: PhotoWidgetConfigIntent.self,
                               provider: PhotoProvider()) { entry in
            PhotoWidgetView(entry: entry)
        }
        .configurationDisplayName(WText.t("Euer Foto", "Your photo"))
        .description(WText.t("Zeigt euer schönstes gemeinsames Foto.",
                             "Shows your favorite photo together."))
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge,
                            .accessoryRectangular])
    }
}
