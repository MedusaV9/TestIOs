import SwiftUI
import UIKit

/// Header-authenticated equivalent of `AsyncImage`. Bearer tokens never
/// enter URLs, caches, screenshots, proxy logs or share sheets.
struct AuthenticatedAsyncImage<Content: View>: View {
    let api: API?
    let path: String?
    private let content: (AsyncImagePhase) -> Content

    @State private var phase: AsyncImagePhase = .empty

    init(api: API?, path: String?,
         @ViewBuilder content: @escaping (AsyncImagePhase) -> Content) {
        self.api = api
        self.path = path
        self.content = content
    }

    var body: some View {
        content(phase)
            .task(id: path) {
                phase = .empty
                guard let api, let path else { return }
                do {
                    let data = try await api.mediaData(path)
                    guard let image = UIImage(data: data) else {
                        throw URLError(.cannotDecodeContentData)
                    }
                    phase = .success(Image(uiImage: image))
                } catch {
                    phase = .failure(error)
                }
            }
    }
}

/// Filled remote photo thumbnail with a neutral placeholder — the common
/// case for grids, hero cards and chat bubbles.
struct RemotePhoto: View {
    let api: API?
    let path: String?
    var contentMode: ContentMode = .fill

    var body: some View {
        AuthenticatedAsyncImage(api: api, path: path) { phase in
            switch phase {
            case .success(let image):
                image
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            case .failure:
                placeholder(systemImage: "photo.badge.exclamationmark")
            case .empty:
                placeholder(systemImage: nil)
            @unknown default:
                placeholder(systemImage: nil)
            }
        }
    }

    private func placeholder(systemImage: String?) -> some View {
        ZStack {
            Color.tertiaryCardBackground
            if let systemImage {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            } else {
                ProgressView()
            }
        }
    }
}
