import SwiftUI

/// The host UI is laid out on a fixed logical canvas (1180 × 820 pt = an 11"
/// iPad in landscape) that is scaled uniformly to the real display. A 13"
/// iPad, "More Space" display zoom or an iPad mini therefore all show the
/// same composition — no tiny type on big screens, no cramped wall on small
/// ones. Sheets and covers present outside the canvas and wrap it themselves.
struct StageCanvas<Content: View>: View {
    static var referenceWidth: CGFloat { 1180 }
    static var referenceHeight: CGFloat { 820 }
    @ViewBuilder var content: () -> Content

    var body: some View {
        GeometryReader { geo in
            let w = max(1, geo.size.width), h = max(1, geo.size.height)
            let raw = min(w / Self.referenceWidth, h / Self.referenceHeight)
            let scale = min(1.9, max(0.7, raw))
            content()
                .frame(width: w / scale, height: h / scale)
                .scaleEffect(scale, anchor: .center)
                .frame(width: w, height: h)
                .environment(\.stageScale, scale)
        }
    }
}

private struct StageScaleKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

private struct PodiumNamespaceKey: EnvironmentKey {
    static let defaultValue: Namespace.ID? = nil
}

extension EnvironmentValues {
    /// Scale factor of the enclosing `StageCanvas` (for pixel-exact rasters such as QR codes).
    var stageScale: CGFloat {
        get { self[StageScaleKey.self] }
        set { self[StageScaleKey.self] = newValue }
    }

    /// Namespace for the podium hero transition: a player's podium morphs from
    /// its place in one scene to its place in the next instead of popping.
    var podiumNamespace: Namespace.ID? {
        get { self[PodiumNamespaceKey.self] }
        set { self[PodiumNamespaceKey.self] = newValue }
    }
}

extension View {
    /// Opt a podium into the cross-scene morph (only for the main player row of a scene).
    @ViewBuilder
    func podiumMorph(_ id: String, in ns: Namespace.ID?) -> some View {
        if let ns = ns { self.matchedGeometryEffect(id: "podium-\(id)", in: ns) } else { self }
    }
}
