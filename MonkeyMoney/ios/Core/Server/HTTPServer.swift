import Foundation
#if canImport(Glibc)
import Glibc
#elseif canImport(Darwin)
import Darwin
#endif

/// Minimal HTTP/1.1 + WebSocket (RFC 6455) server on BSD sockets. Runs on
/// iOS (the iPad hosts the show) and on Linux (dev server + tests). One
/// thread per connection — a party has at most a couple dozen connections.
public final class HTTPServer: @unchecked Sendable {
    public struct Request {
        public var method: String
        public var path: String
        public var query: [String: String]
        public var headers: [String: String]
        public var body: Data
    }

    public struct Response {
        public var status: Int
        public var headers: [String: String]
        public var body: Data

        public init(status: Int = 200, contentType: String = "text/plain; charset=utf-8", body: Data = Data(), headers: [String: String] = [:]) {
            self.status = status
            var h = headers
            h["Content-Type"] = contentType
            self.headers = h
            self.body = body
        }

        public static func text(_ s: String, status: Int = 200) -> Response { Response(status: status, body: Data(s.utf8)) }
        public static func html(_ s: String) -> Response { Response(contentType: "text/html; charset=utf-8", body: Data(s.utf8)) }
        public static func json(_ d: Data, status: Int = 200) -> Response { Response(status: status, contentType: "application/json", body: d) }
        public static func notFound() -> Response { .text("404 — im Dschungel verlaufen", status: 404) }
        public static func redirect(_ to: String) -> Response { Response(status: 302, body: Data(), headers: ["Location": to]) }
    }

    public var handler: (Request) -> Response = { _ in .notFound() }
    public var onWebSocketOpen: (String, Request) -> Void = { _, _ in }
    public var onWebSocketMessage: (String, String) -> Void = { _, _ in }
    public var onWebSocketClose: (String) -> Void = { _ in }
    public var webSocketPath = "/ws"

    public private(set) var port: UInt16
    private var listenFd: Int32 = -1
    private var running = false
    private let lock = NSLock()
    private var sockets: [String: Int32] = [:]
    private var writeLocks: [String: NSLock] = [:]
    private var counter = 0

    public init(port: UInt16) {
        self.port = port
    }

    // MARK: Lifecycle

    public func start() throws {
        #if canImport(Glibc)
        listenFd = socket(AF_INET, Int32(SOCK_STREAM.rawValue), 0)
        #else
        listenFd = socket(AF_INET, SOCK_STREAM, 0)
        #endif
        guard listenFd >= 0 else { throw NSError(domain: "HTTPServer", code: 1, userInfo: [NSLocalizedDescriptionKey: "socket() failed"]) }
        var yes: Int32 = 1
        setsockopt(listenFd, SOL_SOCKET, SO_REUSEADDR, &yes, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = port.bigEndian
        addr.sin_addr.s_addr = INADDR_ANY
        let bound = withUnsafePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { bind(listenFd, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) } }
        guard bound == 0 else {
            close(listenFd)
            throw NSError(domain: "HTTPServer", code: 2, userInfo: [NSLocalizedDescriptionKey: "Port \(port) ist belegt"])
        }
        if port == 0 {
            var actual = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            withUnsafeMutablePointer(to: &actual) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { _ = getsockname(listenFd, $0, &len) } }
            port = UInt16(bigEndian: actual.sin_port)
        }
        guard listen(listenFd, 32) == 0 else { throw NSError(domain: "HTTPServer", code: 3, userInfo: [NSLocalizedDescriptionKey: "listen() failed"]) }
        running = true
        let t = Thread { [weak self] in self?.acceptLoop() }
        t.name = "mm-http-accept"
        t.start()
    }

    public func stop() {
        running = false
        if listenFd >= 0 { shutdown(listenFd, Int32(SHUT_RDWR)); close(listenFd); listenFd = -1 }
        lock.lock()
        let fds = sockets
        sockets = [:]
        lock.unlock()
        for (_, fd) in fds { shutdown(fd, Int32(SHUT_RDWR)); close(fd) }
    }

    private func acceptLoop() {
        while running {
            var addr = sockaddr_in()
            var len = socklen_t(MemoryLayout<sockaddr_in>.size)
            let fd = withUnsafeMutablePointer(to: &addr) { $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { accept(listenFd, $0, &len) } }
            guard fd >= 0 else { if running { usleep(20_000) }; continue }
            var nodelay: Int32 = 1
            setsockopt(fd, Int32(IPPROTO_TCP), TCP_NODELAY, &nodelay, socklen_t(MemoryLayout<Int32>.size))
            #if canImport(Darwin)
            var nosig: Int32 = 1
            setsockopt(fd, SOL_SOCKET, SO_NOSIGPIPE, &nosig, socklen_t(MemoryLayout<Int32>.size))
            #endif
            let t = Thread { [weak self] in self?.serve(fd: fd) }
            t.name = "mm-http-conn"
            t.start()
        }
    }

    // MARK: Connection handling

    private func readData(_ fd: Int32, into buffer: inout [UInt8]) -> Bool {
        var chunk = [UInt8](repeating: 0, count: 16384)
        let n = recv(fd, &chunk, chunk.count, 0)
        guard n > 0 else { return false }
        buffer.append(contentsOf: chunk[0..<Int(n)])
        return true
    }

    private func writeAll(_ fd: Int32, _ data: Data) -> Bool {
        var offset = 0
        let bytes = [UInt8](data)
        while offset < bytes.count {
            let n = bytes[offset...].withUnsafeBufferPointer { ptr -> Int in
                #if canImport(Glibc)
                return Int(Glibc.send(fd, ptr.baseAddress, ptr.count, Int32(MSG_NOSIGNAL)))
                #else
                return Int(Darwin.send(fd, ptr.baseAddress, ptr.count, 0))
                #endif
            }
            if n <= 0 { return false }
            offset += n
        }
        return true
    }

    private func serve(fd: Int32) {
        var buffer: [UInt8] = []
        defer { close(fd) }
        while true {
            // Read until the header terminator.
            guard let headerEnd = findHeaderEnd(buffer) else {
                if !readData(fd, into: &buffer) { return }
                if buffer.count > 1_000_000 { return }
                continue
            }
            let headerBytes = buffer[0..<headerEnd]
            guard let head = String(bytes: headerBytes, encoding: .utf8) else { return }
            var req = parseHead(head)
            let contentLength = Int(req.headers["content-length"] ?? "0") ?? 0
            let bodyStart = headerEnd + 4
            while buffer.count < bodyStart + contentLength {
                if !readData(fd, into: &buffer) { return }
            }
            req.body = Data(buffer[bodyStart..<(bodyStart + contentLength)])
            buffer.removeFirst(bodyStart + contentLength)

            if req.headers["upgrade"]?.lowercased() == "websocket", req.path == webSocketPath {
                handleWebSocket(fd: fd, req: req, leftover: buffer)
                return
            }
            let resp = handler(req)
            var out = "HTTP/1.1 \(resp.status) \(statusText(resp.status))\r\n"
            var headers = resp.headers
            headers["Content-Length"] = String(resp.body.count)
            headers["Connection"] = "keep-alive"
            headers["Cache-Control"] = headers["Cache-Control"] ?? (req.path.hasPrefix("/api") ? "no-store" : "public, max-age=300")
            headers["Access-Control-Allow-Origin"] = "*"
            for (k, v) in headers { out += "\(k): \(v)\r\n" }
            out += "\r\n"
            var data = Data(out.utf8)
            if req.method != "HEAD" { data.append(resp.body) }
            guard writeAll(fd, data) else { return }
            if req.headers["connection"]?.lowercased() == "close" { return }
        }
    }

    private func findHeaderEnd(_ buf: [UInt8]) -> Int? {
        guard buf.count >= 4 else { return nil }
        for i in 0...(buf.count - 4) where buf[i] == 13 && buf[i + 1] == 10 && buf[i + 2] == 13 && buf[i + 3] == 10 { return i }
        return nil
    }

    private func parseHead(_ head: String) -> Request {
        let lines = head.components(separatedBy: "\r\n")
        let parts = lines.first?.split(separator: " ").map(String.init) ?? []
        let method = parts.count > 0 ? parts[0] : "GET"
        let target = parts.count > 1 ? parts[1] : "/"
        var path = target
        var query: [String: String] = [:]
        if let q = target.firstIndex(of: "?") {
            path = String(target[..<q])
            for pair in target[target.index(after: q)...].split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                let k = kv[0].removingPercentEncoding ?? kv[0]
                let v = kv.count > 1 ? (kv[1].replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? kv[1]) : ""
                query[k] = v
            }
        }
        var headers: [String: String] = [:]
        for line in lines.dropFirst() {
            guard let c = line.firstIndex(of: ":") else { continue }
            headers[line[..<c].lowercased()] = line[line.index(after: c)...].trimmingCharacters(in: .whitespaces)
        }
        return Request(method: method, path: path.removingPercentEncoding ?? path, query: query, headers: headers, body: Data())
    }

    private func statusText(_ s: Int) -> String {
        switch s {
        case 200: return "OK"
        case 204: return "No Content"
        case 302: return "Found"
        case 400: return "Bad Request"
        case 401: return "Unauthorized"
        case 403: return "Forbidden"
        case 404: return "Not Found"
        case 405: return "Method Not Allowed"
        default: return "Internal Server Error"
        }
    }

    // MARK: WebSocket

    private func handleWebSocket(fd: Int32, req: Request, leftover: [UInt8]) {
        guard let key = req.headers["sec-websocket-key"] else { return }
        let accept = SHA1.base64(key + "258EAFA5-E914-47DA-95CA-C5AB0DC85B11")
        let resp = "HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: \(accept)\r\n\r\n"
        guard writeAll(fd, Data(resp.utf8)) else { return }
        lock.lock()
        counter += 1
        let id = "ws\(counter)"
        sockets[id] = fd
        writeLocks[id] = NSLock()
        lock.unlock()
        onWebSocketOpen(id, req)
        var buffer = leftover
        var fragments: [UInt8] = []
        defer {
            lock.lock()
            sockets[id] = nil
            writeLocks[id] = nil
            lock.unlock()
            onWebSocketClose(id)
        }
        while true {
            guard let frame = parseFrame(&buffer) else {
                if !readData(fd, into: &buffer) { return }
                if buffer.count > 4_000_000 { return }
                continue
            }
            switch frame.opcode {
            case 0x1, 0x2, 0x0:
                fragments.append(contentsOf: frame.payload)
                if frame.fin {
                    if let text = String(bytes: fragments, encoding: .utf8) { onWebSocketMessage(id, text) }
                    fragments = []
                }
            case 0x8:
                _ = sendFrame(id, opcode: 0x8, payload: [])
                return
            case 0x9:
                _ = sendFrame(id, opcode: 0xA, payload: frame.payload)
            default:
                break
            }
        }
    }

    private struct Frame { var fin: Bool; var opcode: UInt8; var payload: [UInt8] }

    private func parseFrame(_ buf: inout [UInt8]) -> Frame? {
        guard buf.count >= 2 else { return nil }
        let fin = buf[0] & 0x80 != 0
        let opcode = buf[0] & 0x0F
        let masked = buf[1] & 0x80 != 0
        var len = Int(buf[1] & 0x7F)
        var offset = 2
        if len == 126 {
            guard buf.count >= 4 else { return nil }
            len = Int(buf[2]) << 8 | Int(buf[3])
            offset = 4
        } else if len == 127 {
            guard buf.count >= 10 else { return nil }
            len = 0
            for i in 2..<10 { len = len << 8 | Int(buf[i]) }
            offset = 10
        }
        var mask: [UInt8] = []
        if masked {
            guard buf.count >= offset + 4 else { return nil }
            mask = Array(buf[offset..<(offset + 4)])
            offset += 4
        }
        guard buf.count >= offset + len else { return nil }
        var payload = Array(buf[offset..<(offset + len)])
        if masked { for i in 0..<payload.count { payload[i] ^= mask[i % 4] } }
        buf.removeFirst(offset + len)
        return Frame(fin: fin, opcode: opcode, payload: payload)
    }

    @discardableResult
    private func sendFrame(_ id: String, opcode: UInt8, payload: [UInt8]) -> Bool {
        lock.lock()
        let fd = sockets[id]
        let wl = writeLocks[id]
        lock.unlock()
        guard let fd = fd, let wl = wl else { return false }
        var frame: [UInt8] = [0x80 | opcode]
        if payload.count < 126 { frame.append(UInt8(payload.count)) }
        else if payload.count < 65_536 { frame.append(126); frame.append(UInt8(payload.count >> 8)); frame.append(UInt8(payload.count & 0xFF)) }
        else { frame.append(127); for i in (0..<8).reversed() { frame.append(UInt8((payload.count >> (i * 8)) & 0xFF)) } }
        frame.append(contentsOf: payload)
        wl.lock()
        defer { wl.unlock() }
        return writeAll(fd, Data(frame))
    }

    /// Send a text frame to one WebSocket connection.
    public func send(_ id: String, text: String) {
        _ = sendFrame(id, opcode: 0x1, payload: Array(text.utf8))
    }

    public func closeConnection(_ id: String) {
        _ = sendFrame(id, opcode: 0x8, payload: [])
        lock.lock()
        let fd = sockets[id]
        lock.unlock()
        if let fd = fd { shutdown(fd, Int32(SHUT_RDWR)) }
    }

    public var openConnections: [String] {
        lock.lock()
        defer { lock.unlock() }
        return Array(sockets.keys)
    }

    // MARK: Helpers

    public static func mimeType(for path: String) -> String {
        switch (path as NSString).pathExtension.lowercased() {
        case "html": return "text/html; charset=utf-8"
        case "css": return "text/css; charset=utf-8"
        case "js": return "application/javascript; charset=utf-8"
        case "json": return "application/json"
        case "svg": return "image/svg+xml"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "webp": return "image/webp"
        case "ttf": return "font/ttf"
        case "woff2": return "font/woff2"
        case "m4a": return "audio/mp4"
        case "mp3": return "audio/mpeg"
        case "ogg": return "audio/ogg"
        case "mp4": return "video/mp4"
        case "webm": return "video/webm"
        default: return "application/octet-stream"
        }
    }

    /// Best-effort LAN IPv4 address of this device (for the join URL/QR).
    public static func lanIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>? = nil
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }
        var best: String? = nil
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let p = ptr {
            defer { ptr = p.pointee.ifa_next }
            guard let sa = p.pointee.ifa_addr, sa.pointee.sa_family == sa_family_t(AF_INET) else { continue }
            let name = String(cString: p.pointee.ifa_name)
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(sa, socklen_t(MemoryLayout<sockaddr_in>.size), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                let ip = String(cString: host)
                if ip.hasPrefix("127.") { continue }
                // Prefer Wi-Fi (en0 on iOS) and private ranges.
                if name == "en0" { return ip }
                if best == nil || ip.hasPrefix("192.168.") || ip.hasPrefix("10.") { best = ip }
            }
        }
        return best
    }
}

/// SHA-1 (only needed for the WebSocket handshake).
public enum SHA1 {
    public static func digest(_ message: [UInt8]) -> [UInt8] {
        var h0: UInt32 = 0x67452301, h1: UInt32 = 0xEFCDAB89, h2: UInt32 = 0x98BADCFE, h3: UInt32 = 0x10325476, h4: UInt32 = 0xC3D2E1F0
        var msg = message
        let ml = UInt64(message.count) * 8
        msg.append(0x80)
        while msg.count % 64 != 56 { msg.append(0) }
        for i in (0..<8).reversed() { msg.append(UInt8((ml >> (UInt64(i) * 8)) & 0xFF)) }
        var w = [UInt32](repeating: 0, count: 80)
        for chunk in stride(from: 0, to: msg.count, by: 64) {
            for i in 0..<16 {
                w[i] = UInt32(msg[chunk + i * 4]) << 24 | UInt32(msg[chunk + i * 4 + 1]) << 16 | UInt32(msg[chunk + i * 4 + 2]) << 8 | UInt32(msg[chunk + i * 4 + 3])
            }
            for i in 16..<80 {
                let x = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
                w[i] = (x << 1) | (x >> 31)
            }
            var a = h0, b = h1, c = h2, d = h3, e = h4
            for i in 0..<80 {
                let f: UInt32, k: UInt32
                switch i {
                case 0..<20: f = (b & c) | (~b & d); k = 0x5A827999
                case 20..<40: f = b ^ c ^ d; k = 0x6ED9EBA1
                case 40..<60: f = (b & c) | (b & d) | (c & d); k = 0x8F1BBCDC
                default: f = b ^ c ^ d; k = 0xCA62C1D6
                }
                let temp = ((a << 5) | (a >> 27)) &+ f &+ e &+ k &+ w[i]
                e = d; d = c; c = (b << 30) | (b >> 2); b = a; a = temp
            }
            h0 = h0 &+ a; h1 = h1 &+ b; h2 = h2 &+ c; h3 = h3 &+ d; h4 = h4 &+ e
        }
        var out: [UInt8] = []
        for h in [h0, h1, h2, h3, h4] { for i in (0..<4).reversed() { out.append(UInt8((h >> (UInt32(i) * 8)) & 0xFF)) } }
        return out
    }

    public static func base64(_ s: String) -> String { Data(digest(Array(s.utf8))).base64EncodedString() }
}
