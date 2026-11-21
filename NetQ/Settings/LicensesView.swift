import SwiftUI

struct LicenseEntry: Identifiable {
    let id = UUID()
    let name, author, url, license, useZh, useEn: String
}

struct LicensesView: View {
    @Environment(AppSettings.self) private var s

    static let entries: [LicenseEntry] = [
        .init(name: "ipify", author: "ipify", url: "https://www.ipify.org",
              license: "Public API, site terms apply", useZh: "获取公网 IPv4 / IPv6", useEn: "Public IPv4 / IPv6 lookup"),
        .init(name: "ipwho.is", author: "ipwho.is", url: "https://ipwho.is",
              license: "Public API, site terms apply", useZh: "IP 地理定位（主）", useEn: "IP geolocation (primary)"),
        .init(name: "ipapi.co", author: "ipapi.co", url: "https://ipapi.co",
              license: "Public API, free-tier rate limits", useZh: "IP 地理定位（备用）", useEn: "IP geolocation (fallback)"),
        .init(name: "Cloudflare Speed Test endpoints", author: "Cloudflare, Inc.", url: "https://speed.cloudflare.com",
              license: "Public endpoints, terms apply", useZh: "Ping、下载与上传测速", useEn: "Ping, download and upload tests"),
        .init(name: "Network.framework", author: "Apple Inc.", url: "https://developer.apple.com/documentation/network",
              license: "Apple SDK license", useZh: "网络接口类型检测", useEn: "Network interface detection"),
        .init(name: "bash.ws DNS leak test", author: "bash.ws", url: "https://bash.ws",
              license: "Public API, site terms apply", useZh: "DNS 泄漏检测", useEn: "DNS leak test"),
        .init(name: "Google public STUN server", author: "Google LLC", url: "https://developers.google.com/speed/public-dns",
              license: "Public service, terms apply", useZh: "WebRTC 暴露地址检测", useEn: "WebRTC exposure probe"),
        .init(name: "CoreTelephony / NetworkExtension / WebKit", author: "Apple Inc.", url: "https://developer.apple.com/documentation",
              license: "Apple SDK license", useZh: "蜂窝类型、Wi-Fi 信息、WebRTC 检测页", useEn: "Cellular type, Wi-Fi info, WebRTC probe page"),
        .init(name: "MapKit / CoreLocation", author: "Apple Inc.", url: "https://developer.apple.com/documentation/mapkit",
              license: "Apple SDK license", useZh: "地图、搜索与设备定位", useEn: "Maps, search and device location"),
    ]

    var body: some View {
        List {
            Section { Text(s.t("lic.none")).font(.footnote).foregroundStyle(.secondary) }
            ForEach(Self.entries) { e in
                Section(e.name) {
                    LabeledContent(s.t("lic.author"), value: e.author)
                    LabeledContent(s.t("lic.license"), value: e.license)
                    LabeledContent(s.t("lic.use"), value: s.language == .zh ? e.useZh : e.useEn)
                    Link(e.url, destination: URL(string: e.url)!).font(.footnote)
                }
            }
        }
        .navigationTitle(s.t("set.licenses")).navigationBarTitleDisplayMode(.inline)
    }
}
