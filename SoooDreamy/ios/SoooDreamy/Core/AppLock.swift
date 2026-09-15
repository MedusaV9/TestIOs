import SwiftUI
import Observation
import LocalAuthentication

/// Optional app lock: Face ID / Touch ID / passcode gate over the whole app.
/// Locks when the app goes to background (if enabled in settings).
@MainActor
@Observable
final class AppLock {
    private static let enabledKey = "sooodreamy.appLockEnabled"

    var locked: Bool
    @ObservationIgnored private var authenticating = false

    init() {
        locked = Self.isEnabled
    }

    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// Device supports some form of local authentication (biometrics or passcode).
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    func lockIfNeeded() {
        if Self.isEnabled { locked = true }
    }

    func unlock() async {
        guard locked, !authenticating else { return }
        authenticating = true
        defer { authenticating = false }
        let context = LAContext()
        context.localizedCancelTitle = L10n.t("common.cancel")
        do {
            let ok = try await context.evaluatePolicy(.deviceOwnerAuthentication,
                                                      localizedReason: L10n.t("lock.reason"))
            if ok {
                withAnimation(.easeOut(duration: 0.3)) {
                    locked = false
                }
            }
        } catch {
            // User cancelled or auth unavailable — stay locked, button retries.
        }
    }
}

/// Full-screen lock overlay (system background, glass unlock button).
struct LockScreenView: View {
    @Environment(AppLock.self) private var appLock

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)
                .ignoresSafeArea()
            VStack(spacing: 16) {
                Spacer()
                Image(systemName: "lock.heart.fill")
                    .font(.system(size: 64, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .symbolEffect(.pulse)
                    .accessibilityHidden(true)
                Text(L10n.t("lock.title"))
                    .font(.title2.weight(.bold))
                Text(L10n.t("lock.subtitle"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                Spacer()
                Button {
                    Task { await appLock.unlock() }
                } label: {
                    Label(L10n.t("lock.unlock"), systemImage: "faceid")
                        .padding(.horizontal, 8)
                }
                .buttonStyle(.glassProminent)
                .controlSize(.large)
                .padding(.bottom, 40)
            }
        }
        .task {
            await appLock.unlock()
        }
    }
}
