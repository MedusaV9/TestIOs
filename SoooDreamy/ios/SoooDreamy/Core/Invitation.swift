import Foundation

/// Pairing invitations: the https page link the creator shares, the
/// `sooodreamy://pair` deep link the page (and QR flow) bounce back with, and
/// the normalisation of couple codes typed or scanned by hand. Pure
/// Foundation so the round trip is unit-tested on Linux.
enum Invitation {
    /// Couple codes are six characters from the server's unambiguous alphabet
    /// (no 0/O/1/I).
    static let codeAlphabet: Set<Character> = Set("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// Upper-cases, drops separators/decoration and keeps the first six
    /// alphanumerics; nil when fewer than six remain.
    static func normalizeCode(_ raw: String) -> String? {
        let cleaned = String(raw.uppercased().filter { $0.isLetter || $0.isNumber }.prefix(6))
        return cleaned.count == 6 ? cleaned : nil
    }

    /// Strict check against the server alphabet (what `/invite` accepts).
    static func isWellFormedCode(_ code: String) -> Bool {
        code.count == 6 && code.allSatisfy { codeAlphabet.contains($0) }
    }

    /// `https://<server>/invite?code=…` — tappable in Messages, rendered by the server.
    static func pageURL(server: URL, code: String) -> URL? {
        guard let code = normalizeCode(code) else { return nil }
        var comps = URLComponents(url: server.appendingPathComponent("invite"), resolvingAgainstBaseURL: false)
        comps?.queryItems = [URLQueryItem(name: "code", value: code)]
        return comps?.url
    }

    /// `sooodreamy://pair?server=…&code=…` — what the page's button opens.
    static func deepLink(server: URL, code: String) -> URL? {
        guard let code = normalizeCode(code) else { return nil }
        var comps = URLComponents()
        comps.scheme = "sooodreamy"
        comps.host = "pair"
        comps.queryItems = [URLQueryItem(name: "server", value: server.absoluteString),
                            URLQueryItem(name: "code", value: code)]
        return comps.url
    }

    struct Payload: Equatable {
        var server: String?
        var code: String
    }

    /// Parses `sooodreamy://pair?server=…&code=…`; nil for other URLs or an
    /// unusable code. The server stays a raw string — `ServerProfile.normalize`
    /// decides whether it is acceptable.
    static func parse(_ url: URL) -> Payload? {
        guard url.scheme?.lowercased() == "sooodreamy", url.host()?.lowercased() == "pair",
              let comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        let items = comps.queryItems ?? []
        guard let rawCode = items.first(where: { $0.name == "code" })?.value,
              let code = normalizeCode(rawCode) else { return nil }
        let server = items.first(where: { $0.name == "server" })?.value.flatMap { $0.isEmpty ? nil : $0 }
        return Payload(server: server, code: code)
    }
}
