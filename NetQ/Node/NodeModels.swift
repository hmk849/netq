import Foundation
import Network
import Darwin
import Observation

struct NodeStatus: Codable, Sendable, Hashable {
    var date: Date
    var pingAvg: Double
    var pingMin: Double
    var jitter: Double
    var stddev: Double
    var loss: Double
    var responseMs: Double?
    var ip: String
    var country: String
    var countryCode: String
    var isp: String
    var reachable: Bool { loss < 100 }
}

struct NodeTarget: Codable, Sendable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var host: String
    var port: Int = 443
    var downloadURL: String?
    var uploadURL: String?
    var favorite = false
    var last: NodeStatus?
}

enum NodeNet {
    /// Resolves a host name (or passes an IP through) to a numeric address, preferring IPv4.
    static func resolve(_ host: String) async -> String? {
        await Task.detached(priority: .utility) { () -> String? in
            var hints = addrinfo()
            hints.ai_family = AF_UNSPEC
            hints.ai_socktype = SOCK_STREAM
            var res: UnsafeMutablePointer<addrinfo>?
            guard getaddrinfo(host, nil, &hints, &res) == 0, let head = res else { return nil }
            defer { freeaddrinfo(res) }
            let all = Array(sequence(first: head, next: { $0.pointee.ai_next }))
            let pick = all.first { $0.pointee.ai_family == AF_INET } ?? all.first
            guard let p = pick else { return nil }
            var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(p.pointee.ai_addr, p.pointee.ai_addrlen, &buf, socklen_t(buf.count), nil, 0, NI_NUMERICHOST) == 0
            else { return nil }
            return String(cString: buf)
        }.value
    }
}

enum TCPProbe {
    /// Time to complete a TCP handshake, in ms (nil on failure/timeout). ICMP ping is not available to iOS apps.
    static func connectTime(host: String, port: Int, timeout: Double) async -> Double? {
        guard let p = NWEndpoint.Port(rawValue: UInt16(clamping: port)) else { return nil }
        let conn = NWConnection(host: NWEndpoint.Host(host), port: p, using: .tcp)
        let t0 = ContinuousClock.now
        return await withCheckedContinuation { (cont: CheckedContinuation<Double?, Never>) in
            let once = OnceFlag()
            conn.stateUpdateHandler = { st in
                switch st {
                case .ready:
                    if once.first() { conn.cancel(); cont.resume(returning: (ContinuousClock.now - t0).seconds * 1000) }
                case .failed:
                    if once.first() { conn.cancel(); cont.resume(returning: nil) }
                default: break
                }
            }
            conn.start(queue: DispatchQueue(label: "netq.tcp"))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                if once.first() { conn.cancel(); cont.resume(returning: nil) }
            }
        }
    }
}

enum NodeTester {
    /// 20 TCP connects: latency, jitter, stability (std-dev), loss; plus HTTPS response time and IP geolocation.
    static func quick(_ n: NodeTarget) async -> NodeStatus {
        let empty = NodeStatus(date: .now, pingAvg: 0, pingMin: 0, jitter: 0, stddev: 0, loss: 100,
                               responseMs: nil, ip: "", country: "", countryCode: "", isp: "")
        guard let ip = await NodeNet.resolve(n.host) else { return empty }
        async let geo = try? await IPInfoService.lookup(ip)
        var rtts: [Double] = [], lost = 0
        for _ in 0..<20 {
            if Task.isCancelled { break }
            if let ms = await TCPProbe.connectTime(host: ip, port: n.port, timeout: 2) { rtts.append(ms) } else { lost += 1 }
            try? await Task.sleep(for: .milliseconds(150))
        }
        let g = await geo
        var st = empty
        st.ip = ip; st.country = g?.country ?? ""; st.countryCode = g?.countryCode ?? ""; st.isp = g?.isp ?? ""
        st.loss = Double(lost) / 20 * 100
        guard !rtts.isEmpty else { return st }
        let avg = rtts.reduce(0, +) / Double(rtts.count)
        let diffs = zip(rtts, rtts.dropFirst()).map { abs($0 - $1) }
        st.pingAvg = avg
        st.pingMin = rtts.min() ?? 0
        st.jitter = diffs.isEmpty ? 0 : diffs.reduce(0, +) / Double(diffs.count)
        st.stddev = (rtts.map { ($0 - avg) * ($0 - avg) }.reduce(0, +) / Double(rtts.count)).squareRoot()
        st.responseMs = await responseTime(n)
        return st
    }

    private static func responseTime(_ n: NodeTarget) async -> Double? {
        guard n.port != 80, let url = URL(string: "https://\(n.host):\(n.port)/") else { return nil }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 4
        let s = URLSession(configuration: cfg)
        defer { s.finishTasksAndInvalidate() }
        let t0 = ContinuousClock.now
        guard (try? await s.data(from: url)) != nil else { return nil }
        return (ContinuousClock.now - t0).seconds * 1000
    }
}

@MainActor @Observable
final class NodeStore {
    var nodes: [NodeTarget] = []
    var testing: Set<UUID> = []
    @ObservationIgnored private let url = URL.documentsDirectory.appending(path: "netq-nodes.json")

    init() {
        if let d = try? Data(contentsOf: url), let n = try? JSONDecoder().decode([NodeTarget].self, from: d) { nodes = n }
    }

    func add(_ n: NodeTarget) { nodes.append(n); persist() }
    func delete(_ ids: [UUID]) { nodes.removeAll { ids.contains($0.id) }; persist() }
    func toggleFavorite(_ id: UUID) {
        if let i = nodes.firstIndex(where: { $0.id == id }) { nodes[i].favorite.toggle(); persist() }
    }

    func test(_ id: UUID) async {
        guard let n = nodes.first(where: { $0.id == id }), !testing.contains(id) else { return }
        testing.insert(id)
        let st = await NodeTester.quick(n)
        testing.remove(id)
        if let i = nodes.firstIndex(where: { $0.id == id }) { nodes[i].last = st; persist() }
    }

    func testAll() async { for n in nodes { await test(n.id) } }

    /// Reachable nodes sorted by average latency.
    var ranking: [NodeTarget] {
        nodes.filter { $0.last?.reachable == true }.sorted { ($0.last?.pingAvg ?? 0) < ($1.last?.pingAvg ?? 0) }
    }

    private func persist() {
        if let d = try? JSONEncoder().encode(nodes) { try? d.write(to: url, options: .atomic) }
    }
}
