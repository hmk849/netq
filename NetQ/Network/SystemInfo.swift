import Foundation
import Darwin
import CoreTelephony
import NetworkExtension
import CFNetwork

struct LocalAddress: Identifiable, Sendable {
    let id = UUID()
    let name: String
    let address: String
    let isIPv6: Bool
}

enum LocalInterfaces {
    /// Addresses of up, non-loopback interfaces (link-local IPv6 omitted).
    static func all() -> [LocalAddress] {
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }
        var out: [LocalAddress] = []
        for p in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let f = p.pointee
            guard let sa = f.ifa_addr, f.ifa_flags & UInt32(IFF_UP) != 0, f.ifa_flags & UInt32(IFF_LOOPBACK) == 0 else { continue }
            let fam = Int32(sa.pointee.sa_family)
            guard fam == AF_INET || fam == AF_INET6 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(sa, socklen_t(sa.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 else { continue }
            let addr = String(cString: host).split(separator: "%").first.map(String.init) ?? ""
            if fam == AF_INET6, addr.lowercased().hasPrefix("fe80") { continue }
            out.append(LocalAddress(name: String(cString: f.ifa_name), address: addr, isIPv6: fam == AF_INET6))
        }
        return out
    }
}

enum DNSServers {
    static func read() -> [String] {
        (0..<8).compactMap { i in
            var buf = [CChar](repeating: 0, count: 64)
            return netq_dns_server(Int32(i), &buf, 64) == 1 ? String(cString: buf) : nil
        }
    }
}

enum CellularInfo {
    /// Radio generation as reported by CoreTelephony (nil if no cellular service).
    static func technology() -> (label: String, services: Int)? {
        let info = CTTelephonyNetworkInfo()
        guard let d = info.serviceCurrentRadioAccessTechnology, let raw = d.values.first else { return nil }
        let label: String
        switch raw {
        case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA: label = "5G"
        case CTRadioAccessTechnologyLTE: label = "4G (LTE)"
        case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA,
             CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA,
             CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD: label = "3G"
        case CTRadioAccessTechnologyGPRS, CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyCDMA1x: label = "2G"
        default: label = raw
        }
        return (label, d.count)
    }
}

struct WiFiDetails: Sendable { let ssid: String; let securityKey: String }

enum WiFiInfo {
    /// Needs the "Access Wi-Fi Information" entitlement and location permission; otherwise returns nil.
    static func fetch() async -> WiFiDetails? {
        guard let n = await NEHotspotNetwork.fetchCurrent() else { return nil }
        let key: String
        switch n.securityType {
        case .open: key = "open"; case .WEP: key = "wep"
        case .personal: key = "personal"; case .enterprise: key = "enterprise"
        @unknown default: key = "unknown"
        }
        return WiFiDetails(ssid: n.ssid, securityKey: key)
    }
}

enum VPNDetector {
    /// VPN-type interfaces present in the system's scoped network settings.
    /// This is a public-API heuristic; it cannot tell which VPN app or server is in use.
    static func interfaces() -> [String] {
        guard let cf = CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any],
              let scoped = cf["__SCOPED__"] as? [String: Any] else { return [] }
        return scoped.keys.filter { k in ["tap", "tun", "ppp", "ipsec", "utun"].contains { k.hasPrefix($0) } }.sorted()
    }
}
