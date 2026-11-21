import SwiftUI

struct WiFiView: View {
    @Environment(AppSettings.self) private var s
    @State private var net = NetworkMonitor()
    @State private var ip = IPModuleModel()
    @State private var loc = DeviceLocation()
    @State private var wifi: WiFiDetails?
    @State private var test = false

    var body: some View {
        List {
            Section(s.t("det.status")) {
                InfoRow("det.status", s.t(net.kind == .wifi ? "det.connected" : "det.disconnected"))
                InfoRow("det.ssid", wifi?.ssid ?? s.t("det.ssidNA"))
                InfoRow("det.security", wifi.map { s.t("sec.\($0.securityKey)") } ?? s.t("det.ssidNA"))
                if wifi == nil { Text(s.t("det.wifiNote")).font(.footnote).foregroundStyle(.secondary) }
                InfoRow("det.localip", LocalInterfaces.all().first { $0.name == "en0" && !$0.isIPv6 }?.address)
                InfoRow("det.v4sup", s.t(net.supportsIPv4 ? "det.yes" : "det.no"))
                InfoRow("det.v6sup", s.t(net.supportsIPv6 ? "det.yes" : "det.no"))
                InfoRow("det.constrained", s.t(net.constrained ? "det.yes" : "det.no"))
            }
            IPSections(m: ip)
            LatestResultSection(context: .wifi)
            Section { Button(s.t("det.start")) { test = true }.buttonStyle(.glassProminent).frame(maxWidth: .infinity) }
        }
        .navigationTitle("Wi-Fi")
        .fullScreenCover(isPresented: $test) { SpeedTestView(context: .wifi) }
        .onAppear { net.start() }
        .onDisappear { net.stop() }
        .task {
            loc.refresh()
            for _ in 0..<5 { wifi = await WiFiInfo.fetch(); if wifi != nil { break }; try? await Task.sleep(for: .seconds(1)) }
        }
        .task { await ip.load() }
        .refreshable { await ip.load() }
    }
}

struct CellularView: View {
    @Environment(AppSettings.self) private var s
    @State private var net = NetworkMonitor()
    @State private var ip = IPModuleModel()
    @State private var test = false

    var body: some View {
        let tech = CellularInfo.technology()
        List {
            Section(s.t("det.status")) {
                InfoRow("det.cellAvail", s.t(net.cellularAvailable ? "det.yes" : "det.no"))
                InfoRow("det.cellInUse", s.t(net.kind == .cellular ? "det.yes" : "det.no"))
                InfoRow("det.radio", tech?.label ?? s.t("det.radioNA"))
                InfoRow("det.sims", tech.map { String($0.services) })
                InfoRow("det.localip", LocalInterfaces.all().first { $0.name.hasPrefix("pdp_ip") && !$0.isIPv6 }?.address)
                InfoRow("det.v4sup", s.t(net.supportsIPv4 ? "det.yes" : "det.no"))
                InfoRow("det.v6sup", s.t(net.supportsIPv6 ? "det.yes" : "det.no"))
                Text(s.t("det.carrierNote")).font(.footnote).foregroundStyle(.secondary)
            }
            if net.kind != .cellular {
                Section { Label(s.t("sp.mismatch.cell"), systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange) }
            }
            IPSections(m: ip)
            LatestResultSection(context: .cellular)
            Section { Button(s.t("det.start")) { test = true }.buttonStyle(.glassProminent).frame(maxWidth: .infinity) }
        }
        .navigationTitle(s.t("ctx.cellular"))
        .fullScreenCover(isPresented: $test) { SpeedTestView(context: .cellular) }
        .onAppear { net.start() }
        .onDisappear { net.stop() }
        .task { await ip.load() }
        .refreshable { await ip.load() }
    }
}

struct VPNView: View {
    @Environment(AppSettings.self) private var s
    @State private var net = NetworkMonitor()
    @State private var ip = IPModuleModel()
    @State private var ifaces: [String] = VPNDetector.interfaces()
    @State private var direct = VPNHistory.lastDirect()
    @State private var dnsRes: [DNSResolver]?
    @State private var dnsRunning = false
    @State private var dnsFailed = false
    @State private var probe = 0
    @State private var rtc: [String]?
    @State private var test = false

    private var vpnOn: Bool { !ifaces.isEmpty }

    var body: some View {
        List {
            Section(s.t("det.status")) {
                InfoRow("det.vpnState", s.t(vpnOn ? "det.vpnOn" : "det.vpnOff"))
                if vpnOn { InfoRow("det.vpnIfaces", ifaces.joined(separator: ", ")) }
                Text(s.t("det.vpnNote")).font(.footnote).foregroundStyle(.secondary)
            }
            IPSections(m: ip)
            Section(s.t("det.ipchange")) {
                if vpnOn, let d = direct, let l = ip.loc {
                    InfoRow("det.before", "\(d.countryCode.flagEmoji) \(d.ip) · \(d.isp)")
                    InfoRow("det.after", "\(l.flag) \(l.ip) · \(l.isp)")
                    InfoRow("sp.time", d.date.formatted(date: .abbreviated, time: .shortened))
                } else if vpnOn { Text(s.t("det.noHistory")).foregroundStyle(.secondary) }
                else { Text(s.t("det.vpnOffHistory")).foregroundStyle(.secondary) }
            }
            dnsSection
            rtcSection
            LatestResultSection(context: .vpn)
            Section { Button(s.t("det.start")) { test = true }.buttonStyle(.glassProminent).frame(maxWidth: .infinity) }
        }
        .navigationTitle("VPN")
        .background { if probe > 0 { WebRTCProbe(token: probe) { rtc = $0 }.frame(width: 1, height: 1).opacity(0) } }
        .fullScreenCover(isPresented: $test) { SpeedTestView(context: .vpn) }
        .onAppear { net.start() }
        .onDisappear { net.stop() }
        .task { await refresh() }
        .refreshable { await refresh() }
    }

    private func refresh() async {
        ifaces = VPNDetector.interfaces()
        await ip.load()
        if !vpnOn, let l = ip.loc {
            let snap = IPSnapshot(ip: l.ip, country: l.country, countryCode: l.countryCode, isp: l.isp, date: .now)
            VPNHistory.save(snap); direct = snap
        }
    }

    private var dnsSection: some View {
        Section(s.t("det.dnsLeak")) {
            Button(s.t("det.run")) {
                dnsRunning = true; dnsFailed = false; dnsRes = nil
                Task { dnsRes = await DNSLeakTest.run(); dnsFailed = dnsRes == nil; dnsRunning = false }
            }.disabled(dnsRunning)
            if dnsRunning { ProgressView() }
            if dnsFailed { Text(s.t("det.dnsFail")).foregroundStyle(.red).font(.footnote) }
            if let r = dnsRes {
                ForEach(r) { x in InfoRow(x.ip, "\(x.country) \(x.asn)") }
                let leak = vpnOn && r.contains { !$0.country.isEmpty && !(ip.loc?.country ?? "").isEmpty && $0.country != ip.loc?.country }
                Text(s.t(r.isEmpty ? "det.dnsEmpty" : !vpnOn ? "det.dnsVerdictOff" : leak ? "det.dnsVerdictLeak" : "det.dnsVerdictOk"))
                    .font(.footnote).foregroundStyle(leak ? .orange : .secondary)
            }
        }
    }

    private var rtcSection: some View {
        Section(s.t("det.rtc")) {
            Button(s.t("det.run")) { rtc = nil; probe += 1 }
            Text(s.t("det.rtcScope")).font(.footnote).foregroundStyle(.secondary)
            if probe > 0, rtc == nil { ProgressView() }
            if let r = rtc {
                let pub = r.filter { $0.hasPrefix("srflx:") }.map { String($0.dropFirst(6)) }
                ForEach(r, id: \.self) { Text($0).font(.footnote.monospaced()) }
                let mine = Set([ip.ips.v4, ip.ips.v6].compactMap { $0 })
                let leak = vpnOn && pub.contains { !mine.contains($0) }
                Text(s.t(pub.isEmpty ? "det.rtcNone" : leak ? "det.rtcLeak" : "det.rtcOk"))
                    .font(.footnote).foregroundStyle(leak ? .orange : .secondary)
            }
        }
    }
}
