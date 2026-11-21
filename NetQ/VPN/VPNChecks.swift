import Foundation
import WebKit
import SwiftUI

struct IPSnapshot: Codable, Sendable {
    var ip: String, country: String, countryCode: String, isp: String, date: Date
}

/// Remembers the last public IP seen while no VPN interface was present.
enum VPNHistory {
    private static let key = "vpn.lastDirect"
    static func lastDirect() -> IPSnapshot? {
        UserDefaults.standard.data(forKey: key).flatMap { try? JSONDecoder().decode(IPSnapshot.self, from: $0) }
    }
    static func save(_ s: IPSnapshot) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
    }
}

struct DNSResolver: Sendable, Identifiable {
    let id = UUID()
    let ip: String, country: String, asn: String
}

/// DNS leak test via bash.ws: the app resolves unique hostnames, then asks the service which resolvers it saw.
enum DNSLeakTest {
    private struct Row: Decodable, Sendable {
        let type: String?, ip: String?, countryName: String?, asn: String?
    }

    static func run() async -> [DNSResolver]? {
        guard let (d, _) = try? await HTTP.session.data(from: URL(string: "https://bash.ws/id")!),
              let id = String(data: d, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !id.isEmpty, id.allSatisfy({ $0.isLetter || $0.isNumber }) else { return nil }
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 3
        let s = URLSession(configuration: cfg)
        await withTaskGroup(of: Void.self) { g in
            for i in 1...10 {
                g.addTask { _ = try? await s.data(from: URL(string: "https://\(i).\(id).bash.ws")!) }
            }
        }
        guard let rows = try? await HTTP.json(URL(string: "https://bash.ws/dnsleak/test/\(id)?json")!, as: [Row].self)
        else { return nil }
        return rows.filter { $0.type == "dns" }.compactMap { r in
            r.ip.map { DNSResolver(ip: $0, country: r.countryName ?? "", asn: r.asn ?? "") }
        }
    }
}

/// WebRTC exposure probe: a local WKWebView page gathers ICE candidates against a public STUN server.
/// Scope: shows what WebRTC in this system web view exposes, not what your browser would.
struct WebRTCProbe: UIViewRepresentable {
    let token: Int
    let onResult: ([String]) -> Void

    static let html = """
    <html><body><script>
    const found = new Set(); let sent = false;
    function finish() { if (sent) return; sent = true;
      window.webkit.messageHandlers.rtc.postMessage({ips: Array.from(found)}); }
    try {
      const pc = new RTCPeerConnection({iceServers: [{urls: 'stun:stun.l.google.com:19302'}]});
      pc.createDataChannel('x');
      pc.onicecandidate = e => {
        if (!e.candidate) { finish(); return; }
        const m = e.candidate.candidate.split(' ');
        if (m.length > 7) found.add(m[7] + ':' + m[4]);
      };
      pc.createOffer().then(o => pc.setLocalDescription(o)).catch(finish);
    } catch (e) { finish(); }
    setTimeout(finish, 6000);
    </script></body></html>
    """

    @MainActor final class Coordinator: NSObject, WKScriptMessageHandler {
        var onResult: ([String]) -> Void
        var lastToken = -1
        init(_ f: @escaping ([String]) -> Void) { onResult = f }
        func userContentController(_ c: WKUserContentController, didReceive m: WKScriptMessage) {
            let ips = (m.body as? [String: Any])?["ips"] as? [String] ?? []
            onResult(ips)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onResult) }

    func makeUIView(context: Context) -> WKWebView {
        let cfg = WKWebViewConfiguration()
        cfg.userContentController.add(context.coordinator, name: "rtc")
        return WKWebView(frame: .zero, configuration: cfg)
    }

    func updateUIView(_ v: WKWebView, context: Context) {
        context.coordinator.onResult = onResult
        guard context.coordinator.lastToken != token else { return }
        context.coordinator.lastToken = token
        v.loadHTMLString(Self.html, baseURL: URL(string: "https://netq.app"))
    }

    static func dismantleUIView(_ v: WKWebView, coordinator: Coordinator) {
        v.configuration.userContentController.removeScriptMessageHandler(forName: "rtc")
    }
}
