import SwiftUI
import UIKit

/// "500 Tage zusammen" — photo-backed hero card with the day counter.
struct DaysTogetherHero: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Fitness-style count-up when the number first appears; later changes
    /// (a new day) roll the digits via `numericText`.
    @State private var countStart: Date?
    @State private var countingUp = false

    private var days: Int { appState.daysTogether ?? 0 }
    private static let countUpDuration: TimeInterval = 1.2

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            LinearGradient(colors: [.clear, .black.opacity(0.15), .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !countingUp)) { context in
                        Text("\(shownDays(at: context.date))")
                            .font(.system(size: 60, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText())
                    }
                    Text(L10n.t("home.daysTogether"))
                        .font(.title2.weight(.semibold))
                }
                Text(tagline)
                    .font(.subheadline)
                    .opacity(0.88)
            }
            .foregroundStyle(.white)
            .padding(20)
            .padding(.trailing, 56)
        }
        .frame(height: 250)
        .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        .overlay(alignment: .bottomTrailing) {
            Image(systemName: "chevron.right")
                .font(.headline.weight(.semibold))
                .frame(width: 40, height: 40)
                .glassEffect(.regular.interactive(), in: .circle)
                .padding(16)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(days) \(L10n.t("home.daysTogether")). \(tagline)")
        .accessibilityAddTraits(.isButton)
        .task(id: days > 0) {
            guard days > 0, !reduceMotion, countStart == nil else { return }
            countStart = Date()
            countingUp = true
            try? await Task.sleep(nanoseconds: UInt64((Self.countUpDuration + 0.1) * 1_000_000_000))
            countingUp = false
        }
    }

    /// Eased 0 → days over `countUpDuration`; the real value once finished.
    private func shownDays(at now: Date) -> Int {
        guard countingUp, let start = countStart else { return days }
        let t = min(1, max(0, now.timeIntervalSince(start) / Self.countUpDuration))
        let eased = 1 - pow(1 - t, 3)
        return Int((Double(days) * eased).rounded())
    }

    @ViewBuilder
    private var background: some View {
        if let photo = appState.widgetPhoto {
            RemotePhoto(api: appState.api, path: photo.thumbUrl ?? photo.url)
        } else {
            ZStack {
                LinearGradient(colors: [Color.accentColor, .purple, .indigo],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: 28) {
                    Text(appState.me?.avatar ?? "💜")
                    Image(systemName: "heart.fill")
                        .foregroundStyle(.white.opacity(0.9))
                    Text(appState.partner?.avatar ?? "💜")
                }
                .font(.system(size: 54))
                .offset(y: -30)
            }
        }
    }

    private var tagline: String {
        if let key = appState.couple?.anniversary, let start = SharedDates.parse(key) {
            return L10n.t("today.hero.since", ["date": start.formatted(date: .long, time: .omitted)])
        }
        return L10n.t("today.hero.tagline")
    }
}

/// Exactly N months / years together today.
struct MilestoneBanner: View {
    let milestone: TodayModel.Milestone

    private var text: String {
        if milestone.years {
            return milestone.count == 1
                ? L10n.t("home.anniversaryOneYear")
                : L10n.t("home.anniversaryYears", ["n": String(milestone.count)])
        }
        return milestone.count == 1
            ? L10n.t("home.monthiversaryOne")
            : L10n.t("home.monthiversary", ["n": String(milestone.count)])
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(milestone.years ? "🥂" : "🎉")
                .font(.system(size: 34))
                .accessibilityHidden(true)
            Text(text)
                .font(.headline)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Color.accentColor, .purple],
                           startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        .overlay {
            FloatingHeartsView(emojis: milestone.years ? ["🥂", "💍", "💖"] : ["🎉", "💞", "✨"], count: 8)
                .clipShape(RoundedRectangle(cornerRadius: Brand.cardRadius, style: .continuous))
        }
    }
}

/// Cold start without network / loading state.
struct SessionStateCard: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 12) {
            if appState.sessionLoading {
                ProgressView()
                    .controlSize(.large)
                Text(L10n.t("common.loading"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ContentUnavailableView {
                    Label(L10n.t("error.network"), systemImage: "wifi.slash")
                } actions: {
                    Button(L10n.t("common.retry")) {
                        Task {
                            await appState.refreshAll()
                            appState.connectSocket()
                        }
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .cardSurface()
    }
}

/// Paired, but the partner has not joined yet: show the couple code.
struct WaitingForPartnerCard: View {
    @Environment(AppState.self) private var appState
    @State private var showQR = false
    @State private var copied = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "envelope.open.fill")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
                .symbolEffect(.breathe, options: .repeating)
                .accessibilityHidden(true)
            VStack(spacing: 4) {
                Text(L10n.t("home.waitingForPartner"))
                    .font(.title3.weight(.bold))
                Text(L10n.t("home.waitingForPartnerSub"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            if let code = appState.couple?.code {
                Text(code.map(String.init).joined(separator: " "))
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .kerning(2)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 18)
                    .background(Color.tertiaryCardBackground,
                                in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .accessibilityLabel(L10n.t("pairing.codeA11y", ["code": code]))

                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = code
                        copied = true
                        Task {
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            copied = false
                        }
                    } label: {
                        Label(L10n.t(copied ? "common.copied" : "common.copy"),
                              systemImage: copied ? "checkmark" : "doc.on.doc")
                            .contentTransition(.symbolEffect(.replace))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .animation(.snappy, value: copied)
                    .sensoryFeedback(.success, trigger: copied) { _, new in new }

                    inviteShareLink(code: code)
                        .buttonStyle(.borderedProminent)
                }
                .controlSize(.large)

                Button {
                    withAnimation(.snappy) { showQR.toggle() }
                } label: {
                    Label(L10n.t("pairing.showQR"), systemImage: "qrcode")
                }
                .buttonStyle(.borderless)

                if showQR, let server = appState.servers.activeProfile?.urlString,
                   let qr = QRGenerator.image(for: PairQRPayload.encode(server: server, code: code)) {
                    VStack(spacing: 6) {
                        Image(uiImage: qr)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(width: 180, height: 180)
                            .padding(10)
                            .background(.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text(L10n.t("pairing.qrHint"))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }

            HStack(spacing: 8) {
                ProgressView()
                Text(L10n.t("pairing.waiting"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .cardSurface(padding: 20)
    }

    /// One tap for the partner: the https invitation page opens the app with
    /// server + code. Falls back to the plain text when the server has no URL.
    @ViewBuilder
    private func inviteShareLink(code: String) -> some View {
        if let url = appState.inviteURL {
            ShareLink(item: url,
                      subject: Text(L10n.t("invite.subject")),
                      message: Text(L10n.t("invite.message", ["code": code]))) {
                Label(L10n.t("invite.share"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        } else {
            ShareLink(item: shareText(code: code)) {
                Label(L10n.t("common.share"), systemImage: "square.and.arrow.up")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func shareText(code: String) -> String {
        let server = appState.servers.activeProfile?.urlString ?? ""
        return L10n.t("pairing.shareText", ["server": server, "code": code])
    }
}
