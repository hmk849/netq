import Foundation
import Synchronization

/// Multi-stream transfer used for real download / upload throughput measurement.
final class Transfer: NSObject, URLSessionDataDelegate, @unchecked Sendable {
    enum Kind: Sendable { case down, up }
    let kind: Kind
    let endpoints: SpeedEndpoints
    private let bytes = Mutex(0)
    private let stopped = Mutex(false)
    private let errors = Mutex(0)
    static let payload = Data(count: 8_000_000)

    init(kind: Kind, endpoints: SpeedEndpoints) { self.kind = kind; self.endpoints = endpoints }

    var total: Int { bytes.withLock { $0 } }
    func stop() { stopped.withLock { $0 = true } }

    func start(_ s: URLSession) {
        switch kind {
        case .down:
            guard var c = URLComponents(string: endpoints.download) else { return }
            c.queryItems = (c.queryItems ?? []) + [URLQueryItem(name: "r", value: String(UInt32.random(in: 0...UInt32.max)))]
            guard let u = c.url else { return }
            var r = URLRequest(url: u)
            r.cachePolicy = .reloadIgnoringLocalCacheData
            s.dataTask(with: r).resume()
        case .up:
            guard let u = URL(string: endpoints.upload) else { return }
            var r = URLRequest(url: u)
            r.httpMethod = "POST"
            r.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            s.uploadTask(with: r, from: Self.payload).resume()
        }
    }

    func urlSession(_ s: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if kind == .down { bytes.withLock { $0 += data.count } }
    }
    func urlSession(_ s: URLSession, task: URLSessionTask, didSendBodyData sent: Int64,
                    totalBytesSent: Int64, totalBytesExpectedToSend: Int64) {
        if kind == .up { bytes.withLock { $0 += Int(sent) } }
    }
    func urlSession(_ s: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if stopped.withLock({ $0 }) { return }
        if error != nil, errors.withLock({ $0 += 1; return $0 }) > 6 { return }
        start(s)
    }
}

enum SpeedEngine {
    typealias Cont = AsyncStream<SpeedEvent>.Continuation

    /// `node == nil`: Cloudflare endpoints. With a node: TCP latency to the node, and download/upload only
    /// when the node has its own https test URLs (otherwise those results are reported as N/A, never invented).
    static func run(context: String, networkType: String, endpoints: SpeedEndpoints = .cloudflare,
                    node: NodeTarget? = nil) -> AsyncStream<SpeedEvent> {
        AsyncStream { cont in
            let task = Task {
                await execute(context: context, networkType: networkType, ep: endpoints, node: node, cont: cont)
                cont.finish()
            }
            cont.onTermination = { _ in task.cancel() }
        }
    }

    private static func execute(context: String, networkType: String, ep: SpeedEndpoints,
                                node: NodeTarget?, cont: Cont) async {
        var ep = ep
        var nodeIP: String?

        // 1. connect
        cont.yield(.phase(.connecting))
        if let node {
            guard let ip = await NodeNet.resolve(node.host),
                  await TCPProbe.connectTime(host: ip, port: node.port, timeout: 4) != nil
            else { cont.yield(.failed("sp.err.node")); return }
            nodeIP = ip
            ep.download = node.downloadURL ?? ""
            ep.upload = node.uploadURL ?? ""
        } else {
            do {
                let (_, resp) = try await URLSession(configuration: .ephemeral).data(from: URL(string: ep.ping)!)
                guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
            } catch { cont.yield(.failed("sp.err.connect")); return }
        }
        if Task.isCancelled { return }

        // 2. ping
        cont.yield(.phase(.ping))
        let p1 = await probes(ep, node: node, ip: nodeIP, count: 10, gapMs: 100, cont: cont)
        if Task.isCancelled { return }
        guard !p1.rtts.isEmpty else { cont.yield(.failed("sp.err.connect")); return }

        // 3. download  4. upload (-1 = not measured)
        var down = -1.0, up = -1.0
        if !ep.download.isEmpty {
            cont.yield(.phase(.download))
            guard let d = await measure(.down, ep, seconds: 8, cont: cont) else {
                if !Task.isCancelled { cont.yield(.failed("sp.err.transfer")) }; return
            }
            down = d
        }
        if !ep.upload.isEmpty {
            cont.yield(.phase(.upload))
            guard let u = await measure(.up, ep, seconds: 8, cont: cont) else {
                if !Task.isCancelled { cont.yield(.failed("sp.err.transfer")) }; return
            }
            up = u
        }

        // 5. stability
        cont.yield(.phase(.stability))
        let p2 = await probes(ep, node: node, ip: nodeIP, count: 15, gapMs: 200, cont: cont)
        if Task.isCancelled { return }

        // 6. network / identity info (for a node: the node's address)
        cont.yield(.phase(.security))
        let loc = try? await IPInfoService.lookup(nodeIP)

        // 7. report
        cont.yield(.phase(.report))
        let all = p1.rtts + p2.rtts
        let diffs = zip(all, all.dropFirst()).map { abs($0 - $1) }
        let jitter = diffs.isEmpty ? 0 : diffs.reduce(0, +) / Double(diffs.count)
        let loss = Double(p1.lost + p2.lost) / 25 * 100
        cont.yield(.done(SpeedResult(
            context: context, networkType: networkType,
            ping: p1.rtts.reduce(0, +) / Double(p1.rtts.count), jitter: jitter,
            download: down, upload: up, loss: loss,
            ip: loc?.ip ?? nodeIP ?? "-", country: loc?.country ?? "-", countryCode: loc?.countryCode ?? "",
            isp: loc?.isp ?? "-", nodeName: node?.name)))
    }

    private static func probes(_ ep: SpeedEndpoints, node: NodeTarget?, ip: String?, count: Int, gapMs: Int,
                               cont: Cont) async -> (rtts: [Double], lost: Int) {
        if let node, let ip { return await tcpPings(ip, node.port, count: count, gapMs: gapMs, cont: cont) }
        return await pings(ep, count: count, gapMs: gapMs, cont: cont)
    }

    private static func tcpPings(_ ip: String, _ port: Int, count: Int, gapMs: Int,
                                 cont: Cont) async -> (rtts: [Double], lost: Int) {
        var rtts: [Double] = [], lost = 0
        for _ in 0..<count {
            if Task.isCancelled { break }
            if let ms = await TCPProbe.connectTime(host: ip, port: port, timeout: 3) { rtts.append(ms); cont.yield(.live(ms)) }
            else { lost += 1 }
            try? await Task.sleep(for: .milliseconds(gapMs))
        }
        return (rtts, lost)
    }

    /// HTTP round-trip time to the endpoint (reused connection), in ms. Failed/timeout requests count as loss.
    private static func pings(_ ep: SpeedEndpoints, count: Int, gapMs: Int, cont: Cont) async -> (rtts: [Double], lost: Int) {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 3
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let s = URLSession(configuration: cfg)
        defer { s.finishTasksAndInvalidate() }
        _ = try? await s.data(from: URL(string: ep.ping)!)   // warm-up: TLS/connection, not counted
        var rtts: [Double] = [], lost = 0
        let clock = ContinuousClock()
        for _ in 0..<count {
            if Task.isCancelled { break }
            let url = URL(string: ep.ping + "&r=\(UInt32.random(in: 0...UInt32.max))")!
            let t0 = clock.now
            do {
                let (_, r) = try await s.data(from: url)
                guard (r as? HTTPURLResponse)?.statusCode == 200 else { throw URLError(.badServerResponse) }
                let ms = (clock.now - t0).seconds * 1000
                rtts.append(ms)
                cont.yield(.live(ms))
            } catch { lost += 1 }
            try? await Task.sleep(for: .milliseconds(gapMs))
        }
        return (rtts, lost)
    }

    /// Throughput in Mbps over `seconds`, 4 parallel streams, first second discarded as ramp-up.
    private static func measure(_ kind: Transfer.Kind, _ ep: SpeedEndpoints, seconds: Double, cont: Cont) async -> Double? {
        let t = Transfer(kind: kind, endpoints: ep)
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 10
        cfg.httpMaximumConnectionsPerHost = 6
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        let s = URLSession(configuration: cfg, delegate: t, delegateQueue: nil)
        for _ in 0..<4 { t.start(s) }
        let clock = ContinuousClock()
        let start = clock.now
        var last = 0, lastT = start, smooth = 0.0
        var warm: (Int, ContinuousClock.Instant)?
        while !Task.isCancelled, (clock.now - start).seconds < seconds {
            try? await Task.sleep(for: .milliseconds(250))
            let now = clock.now, b = t.total
            let dt = (now - lastT).seconds
            if dt > 0 {
                let inst = Double(b - last) * 8 / dt / 1e6
                smooth = smooth == 0 ? inst : smooth * 0.6 + inst * 0.4
                cont.yield(.live(smooth))
            }
            if warm == nil, (now - start).seconds >= 1 { warm = (b, now) }
            last = b; lastT = now
        }
        let end = clock.now, total = t.total
        t.stop(); s.invalidateAndCancel()
        guard !Task.isCancelled, total > 0, let w = warm else { return nil }
        let secs = (end - w.1).seconds
        return secs > 0 ? Double(total - w.0) * 8 / secs / 1e6 : nil
    }
}
