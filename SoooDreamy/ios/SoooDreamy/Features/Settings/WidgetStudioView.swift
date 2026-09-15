import SwiftUI
import WidgetKit

/// Widget Studio: live preview + configuration of every SoooDreamy widget
/// (theme, layout, data source, animation). Everything lands in the
/// app-group studio config; widgets re-render on the WidgetCenter reload.
struct WidgetStudioView: View {
    @Environment(AppState.self) private var appState

    @State private var config = SharedStore.readStudioConfig()
    private let snapshot = SharedStore.readSnapshot()

    var body: some View {
        List {
            diagnosticsSection
            globalSection

            widgetSection(kind: WidgetKindID.daysTogether, title: L10n.t("studio.widget.days"),
                          systemImage: "heart.fill", showsLayout: true, showsAnimated: true) { palette in
                DaysPreview(palette: palette, snapshot: snapshot,
                            layout: config.config(for: WidgetKindID.daysTogether).layout)
            }

            widgetSection(kind: WidgetKindID.countdown, title: L10n.t("studio.widget.countdown"),
                          systemImage: "calendar", showsLayout: false, showsAnimated: true) { palette in
                CountdownPreview(palette: palette, snapshot: snapshot,
                                 pinnedEventId: config.config(for: WidgetKindID.countdown).eventId,
                                 events: appState.events)
            } extra: {
                countdownEventPicker
            }

            widgetSection(kind: WidgetKindID.mood, title: L10n.t("studio.widget.mood"),
                          systemImage: "face.smiling", showsLayout: false, showsAnimated: false) { palette in
                MoodPreview(palette: palette, snapshot: snapshot)
            }

            widgetSection(kind: WidgetKindID.daily, title: L10n.t("studio.widget.daily"),
                          systemImage: "text.bubble", showsLayout: false, showsAnimated: true) { palette in
                DailyPreview(palette: palette, snapshot: snapshot)
            }

            widgetSection(kind: WidgetKindID.streak, title: L10n.t("studio.widget.streak"),
                          systemImage: "flame", showsLayout: false, showsAnimated: true) { palette in
                StreakPreview(palette: palette, snapshot: snapshot)
            }

            widgetSection(kind: WidgetKindID.photo, title: L10n.t("studio.widget.photo"),
                          systemImage: "photo", showsLayout: false, showsAnimated: false) { palette in
                PhotoPreview(palette: palette)
            } extra: {
                photoSourcePicker
                photoFramePicker
            }

            widgetSection(kind: WidgetKindID.sendLove, title: L10n.t("studio.widget.sendLove"),
                          systemImage: "paperplane", showsLayout: false, showsAnimated: false) { palette in
                SendLovePreview(palette: palette, snapshot: snapshot)
            }

            Section {
                Label(L10n.t("settings.widgets"), systemImage: "square.grid.2x2")
            } footer: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.t("settings.widgetsHint"))
                    Text(L10n.t("studio.perWidgetHint"))
                }
            }
        }
        .navigationTitle(L10n.t("studio.title"))
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: config) { _, newValue in
            SharedStore.writeStudioConfig(newValue)
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    // MARK: Diagnostics

    @ViewBuilder
    private var diagnosticsSection: some View {
        Section {
            if SharedStore.appGroupAvailable {
                if snapshot != nil {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L10n.t("studio.diag.ok"))
                            if let updatedAt = snapshot?.updatedAt {
                                Text(L10n.t("studio.diag.updated", ["time": L10n.relativeShort(updatedAt)]))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } icon: {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(Color.green)
                    }
                } else {
                    Label {
                        Text(L10n.t("studio.diag.noData"))
                    } icon: {
                        Image(systemName: "hourglass")
                            .foregroundStyle(Color.orange)
                    }
                }
            } else {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.t("studio.diag.noGroup"))
                        Text(L10n.t("studio.diag.noGroupHint"))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.red)
                }
            }
        }
    }

    // MARK: Global

    private var globalSection: some View {
        Section {
            ThemeSwatchRow(selection: Binding(
                get: { config.themeId },
                set: { config.themeId = $0 ?? "night" }
            ))
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            Toggle(isOn: Binding(
                get: { config.usePhotoChrome },
                set: { config.usePhotoChrome = $0 }
            )) {
                Label(L10n.t("settings.widgetPhotoChrome"), systemImage: "photo.on.rectangle.angled")
            }
        } header: {
            Text(L10n.t("studio.globalTheme"))
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                Text(L10n.t("studio.globalThemeHint"))
                Text(L10n.t("settings.widgetPhotoChromeHint"))
            }
        }
    }

    // MARK: Per-widget section

    private func widgetSection<Preview: View, Extra: View>(
        kind: String, title: String, systemImage: String,
        showsLayout: Bool, showsAnimated: Bool,
        @ViewBuilder preview: (WidgetPreviewPalette) -> Preview,
        @ViewBuilder extra: () -> Extra = { EmptyView() }
    ) -> some View {
        let palette = WidgetPreviewPalette(spec: config.theme(for: kind))
        return Section {
            WidgetPreviewFrame(palette: palette) {
                preview(palette)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

            ThemeSwatchRow(selection: themeBinding(kind), allowsDefault: true)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            if showsLayout {
                Picker(L10n.t("studio.layout"), selection: layoutBinding(kind)) {
                    Text(L10n.t("studio.layout.auto")).tag("auto")
                    Text(L10n.t("studio.layout.classic")).tag("classic")
                    Text(L10n.t("studio.layout.hero")).tag("hero")
                    Text(L10n.t("studio.layout.minimal")).tag("minimal")
                }
                .pickerStyle(.menu)
            }

            if showsAnimated {
                Toggle(isOn: animatedBinding(kind)) {
                    Label(L10n.t("studio.animated"), systemImage: "timer")
                }
            }

            extra()
        } header: {
            Label(title, systemImage: systemImage)
        }
    }

    // MARK: Extras

    private var countdownEventPicker: some View {
        Picker(L10n.t("studio.countdownEvent"), selection: Binding<String>(
            get: { config.config(for: WidgetKindID.countdown).eventId ?? "" },
            set: { id in config.update(kind: WidgetKindID.countdown) { $0.eventId = id.isEmpty ? nil : id } }
        )) {
            Text(L10n.t("studio.countdownNext")).tag("")
            ForEach(appState.events) { event in
                Text("\(event.emoji) \(event.title)").tag(event.id)
            }
        }
        .pickerStyle(.menu)
    }

    private var photoSourcePicker: some View {
        Picker(L10n.t("studio.photoSource"), selection: Binding<String>(
            get: { config.config(for: WidgetKindID.photo).photoSource ?? "favorite" },
            set: { value in
                config.update(kind: WidgetKindID.photo) { $0.photoSource = value == "favorite" ? nil : value }
                Task {
                    await appState.refreshWidgetPhoto()
                    appState.updateWidgetSnapshot()
                }
            }
        )) {
            Text(L10n.t("studio.photoSource.favorite")).tag("favorite")
            Text(L10n.t("studio.photoSource.newest")).tag("newest")
        }
        .pickerStyle(.menu)
    }

    private var photoFramePicker: some View {
        Picker(L10n.t("photoframe.title"), selection: Binding<String>(
            get: { config.config(for: WidgetKindID.photo).photoFrame ?? "none" },
            set: { value in config.update(kind: WidgetKindID.photo) { $0.photoFrame = value == "none" ? nil : value } }
        )) {
            Text(L10n.t("photoframe.none")).tag("none")
            Text(L10n.t("photoframe.polaroid")).tag("polaroid")
            Text(L10n.t("photoframe.filmstrip")).tag("filmstrip")
            Text(L10n.t("photoframe.scrapbook")).tag("scrapbook")
        }
        .pickerStyle(.menu)
    }

    // MARK: Bindings

    private func themeBinding(_ kind: String) -> Binding<String?> {
        Binding(
            get: { config.config(for: kind).themeId },
            set: { newValue in config.update(kind: kind) { $0.themeId = newValue } }
        )
    }

    private func layoutBinding(_ kind: String) -> Binding<String> {
        Binding(
            get: { config.config(for: kind).layout ?? "auto" },
            set: { newValue in config.update(kind: kind) { $0.layout = newValue == "auto" ? nil : newValue } }
        )
    }

    private func animatedBinding(_ kind: String) -> Binding<Bool> {
        Binding(
            get: { config.config(for: kind).animated ?? true },
            set: { newValue in config.update(kind: kind) { $0.animated = newValue } }
        )
    }
}
