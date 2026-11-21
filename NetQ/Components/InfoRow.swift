import SwiftUI

struct InfoRow: View {
    @Environment(AppSettings.self) private var s
    let key: String
    let value: String
    init(_ key: String, _ value: String?) { self.key = key; self.value = (value?.isEmpty == false) ? value! : "-" }
    var body: some View {
        LabeledContent(s.t(key), value: value).textSelection(.enabled)
    }
}

@MainActor @Observable
final class IPModuleModel {
    var ips = PublicIPs()
    var loc: IPLocation?
    var loading = false
    var failed = false
    var dns: [String] = []

    func load() async {
        loading = true; failed = false
        dns = DNSServers.read()
        async let i = IPInfoService.publicIPs()
        do { loc = try await IPInfoService.lookup(nil) } catch { failed = true }
        ips = await i
        loading = false
    }
}

struct LatestResultSection: View {
    @Environment(AppSettings.self) private var s
    @Environment(ReportStore.self) private var store
    let context: TestContext
    var body: some View {
        Section(s.t("det.last")) {
            if let r = store.reports.first(where: { $0.context == context.rawValue }) {
                InfoRow("sp.ping", String(format: "%.0f ms", r.ping))
                InfoRow("sp.download", SpeedResult.speedText(r.download, s.t("node.na")))
                InfoRow("sp.upload", SpeedResult.speedText(r.upload, s.t("node.na")))
                InfoRow("sp.time", r.date.formatted(date: .abbreviated, time: .shortened))
            } else { Text(s.t("det.lastNone")).foregroundStyle(.secondary) }
        }
    }
}

struct IPSections: View {
    let m: IPModuleModel
    @Environment(AppSettings.self) private var s
    var body: some View {
        Section(s.t("det.public")) {
            if m.loading && m.loc == nil { ProgressView() }
            InfoRow("map.v4", m.ips.v4); InfoRow("map.v6", m.ips.v6)
            if let l = m.loc {
                InfoRow("sp.country", "\(l.flag) \(l.country)"); InfoRow("map.city", l.city); InfoRow("map.isp", l.isp)
            }
            if m.failed { Text(s.t("map.err")).font(.footnote).foregroundStyle(.red) }
        }
        Section(s.t("det.dns")) {
            if m.dns.isEmpty { Text(s.t("det.dnsNone")).foregroundStyle(.secondary) }
            ForEach(m.dns, id: \.self) { Text($0).textSelection(.enabled) }
        }
    }
}
