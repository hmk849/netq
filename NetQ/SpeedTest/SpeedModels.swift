import Foundation

enum TestContext: String, CaseIterable, Identifiable, Sendable {
    case wifi, cellular, vpn, node
    var id: String { rawValue }
}

enum SpeedPhase: Int, CaseIterable, Sendable {
    case connecting, ping, download, upload, stability, security, report
    var key: String {
        switch self {
        case .connecting: "sp.connecting"; case .ping: "sp.ping"; case .download: "sp.download"
        case .upload: "sp.upload"; case .stability: "sp.stability"; case .security: "sp.security"
        case .report: "sp.report"
        }
    }
    var usesMbps: Bool { self == .download || self == .upload }
}

struct SpeedEndpoints: Sendable {
    var ping: String
    var download: String
    var upload: String
    /// Cloudflare's public speed-test endpoints (no key needed).
    static let cloudflare = SpeedEndpoints(
        ping: "https://speed.cloudflare.com/__down?bytes=0",
        download: "https://speed.cloudflare.com/__down?bytes=50000000",
        upload: "https://speed.cloudflare.com/__up")
}

struct SpeedResult: Codable, Sendable, Identifiable, Equatable {
    var id = UUID()
    var date = Date()
    var context: String
    var networkType: String
    var ping: Double
    var jitter: Double
    var download: Double
    var upload: Double
    var loss: Double
    var ip: String
    var country: String
    var countryCode: String
    var isp: String
    var nodeName: String? = nil

    /// Negative values mean "not measured" (e.g. a node without speed-test URLs).
    static func speedText(_ v: Double, _ na: String) -> String { v < 0 ? na : String(format: "%.1f Mbps", v) }

    func summary(_ lang: AppLanguage) -> String {
        func t(_ k: String) -> String { L10n.text(k, lang) }
        return """
        NetQ · \(t("ctx.\(context)"))\(nodeName.map { " (\($0))" } ?? "") · \(date.formatted(date: .abbreviated, time: .shortened))
        \(t("sp.ping")): \(String(format: "%.0f", ping)) ms · \(t("sp.jitter")): \(String(format: "%.1f", jitter)) ms
        \(t("sp.download")): \(Self.speedText(download, "N/A")) · \(t("sp.upload")): \(Self.speedText(upload, "N/A"))
        \(t("sp.loss")): \(String(format: "%.1f", loss))% · \(t("sp.type")): \(t("net.\(networkType)"))
        IP: \(ip) · \(countryCode.flagEmoji) \(country) · \(isp)
        """
    }
}

enum SpeedEvent: Sendable {
    case phase(SpeedPhase)
    case live(Double)
    case failed(String)
    case done(SpeedResult)
}

extension Duration {
    var seconds: Double { Double(components.seconds) + Double(components.attoseconds) / 1e18 }
}
