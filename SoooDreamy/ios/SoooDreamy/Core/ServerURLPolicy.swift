import Foundation

/// URL rules for couple-server addresses. Public Internet hosts need HTTPS
/// except for a tiny allow-list that matches Info.plist ATS exception domains
/// (currently the AMP host `ark.atomi23.de`). Plain HTTP is also allowed for
/// loopback, private LAN, and Tailscale CGNAT. Foundation-only so Linux tests
/// can pin the policy.
enum ServerURLPolicy {
    /// Must stay in lockstep with `NSExceptionDomains` in `project.yml` and
    /// both Info.plists.
    static let cleartextExceptionHosts: Set<String> = [
        "ark.atomi23.de",
    ]

    static func isPrivateHost(_ host: String) -> Bool {
        let h = host.lowercased()
        if h == "localhost" || h.hasSuffix(".local") || h == "::1" { return true }
        let parts = h.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 10 || parts[0] == 127 || (parts[0] == 192 && parts[1] == 168)
                || (parts[0] == 169 && parts[1] == 254) { return true }
            if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
            if parts[0] == 100 && (64...127).contains(parts[1]) { return true }
        }
        return h.hasPrefix("fc") || h.hasPrefix("fd") || h.hasPrefix("fe8")
            || h.hasPrefix("fe9") || h.hasPrefix("fea") || h.hasPrefix("feb")
    }

    static func allowsCleartext(_ host: String) -> Bool {
        let h = host.lowercased()
        return isPrivateHost(h) || cleartextExceptionHosts.contains(h)
    }

    /// Trims, adds a scheme when missing (http for cleartext-allowed hosts,
    /// otherwise https), strips a trailing slash. Nil when the result is not
    /// an http(s) URL or public cleartext without an exception.
    static func normalize(_ raw: String) -> String? {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !s.isEmpty else { return nil }
        let lower = s.lowercased()
        let hasHTTP = lower.hasPrefix("http://")
        let hasHTTPS = lower.hasPrefix("https://")
        if lower.contains("://") && !hasHTTP && !hasHTTPS { return nil }
        if !hasHTTP && !hasHTTPS {
            guard let probed = URL(string: "https://" + s), let host = probed.host, !host.isEmpty else {
                return nil
            }
            s = (allowsCleartext(host) ? "http://" : "https://") + s
        } else if hasHTTP {
            s = "http://" + String(s.dropFirst(7))
        } else {
            s = "https://" + String(s.dropFirst(8))
        }
        while s.hasSuffix("/") { s.removeLast() }
        guard let url = URL(string: s), let host = url.host, !host.isEmpty else { return nil }
        if url.scheme == "https" { return s }
        if url.scheme == "http", allowsCleartext(host) { return s }
        return nil
    }
}
