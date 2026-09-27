import SwiftUI

/// iPhone: a controller shell. Guests normally just scan the QR code with the
/// camera (Safari opens the iPad's player page); the app does the same inside a
/// web view and remembers the iPad's address.
@MainActor
final class PhoneController: ObservableObject {
    @Published var target: URL?
    @Published var address: String = UserDefaults.standard.string(forKey: "mm.ipad") ?? ""

    /// `http://<ipad>:8080/j/CODE`, `…/gm?code=…` or `monkeymoney://join?host=<ip:port>&code=CODE`.
    func handle(url: URL) {
        if url.scheme == "http" || url.scheme == "https" {
            if let h = url.host { remember(url.port.map { "\(h):\($0)" } ?? h) }
            target = url
            return
        }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        guard let host = items.first(where: { $0.name == "host" })?.value else { return }
        let code = items.first(where: { $0.name == "code" })?.value ?? ""
        remember(host)
        target = URL(string: "http://\(host)/" + (code.isEmpty ? "" : "j/\(code)"))
    }

    func open() {
        var a = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !a.isEmpty else { return }
        a = a.replacingOccurrences(of: "http://", with: "")
        if !a.contains(":") { a += ":8080" }
        remember(a)
        target = URL(string: "http://\(a)/")
    }

    private func remember(_ a: String) {
        address = a
        UserDefaults.standard.set(a, forKey: "mm.ipad")
    }
}

struct PhoneShellView: View {
    @EnvironmentObject var phone: PhoneController

    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(red: 0.11, green: 0.06, blue: 0.29), Color(red: 0.05, green: 0.03, blue: 0.13)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            if let url = phone.target {
                VStack(spacing: 0) {
                    WebView(url: url)
                    Button("iPad wechseln") { phone.target = nil }
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.vertical, 6)
                }
            } else {
                VStack(spacing: 22) {
                    Text("🐵").font(.system(size: 90))
                    Text("MONKEY MONEY").font(.system(size: 34, weight: .black, design: .rounded)).foregroundStyle(Color(red: 1, green: 0.79, blue: 0.24))
                    Text("Scanne den QR-Code auf dem iPad mit der Kamera — oder gib die Adresse ein, die in der Lobby steht.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.8))
                    TextField("192.168.0.23:8080", text: $phone.address)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button { phone.open() } label: {
                        Text("Verbinden").font(.headline).frame(maxWidth: .infinity).padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Color(red: 1, green: 0.79, blue: 0.24))
                    .foregroundStyle(.black)
                }
                .padding(30)
            }
        }
    }
}
