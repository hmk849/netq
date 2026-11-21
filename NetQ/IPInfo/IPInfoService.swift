import Foundation
import Darwin

struct PublicIPs: Sendable, Equatable {
    var v4: String?
    var v6: String?
}

struct IPLocation: Sendable, Equatable {
    var ip: String
    var country: String
    var countryCode: String
    var region: String
    var city: String
    var latitude: Double
    var longitude: Double
    var timezone: String
    var isp: String
    var flag: String { countryCode.flagEmoji }
}

extension String {
    var flagEmoji: String {
        let u = uppercased().unicodeScalars
        guard u.count == 2, u.allSatisfy({ $0.value >= 65 && $0.value <= 90 }) else { return "🌐" }
        return String(String.UnicodeScalarView(u.compactMap { UnicodeScalar(127397 + $0.value) }))
    }
}

/// Public IP: ipify (HTTPS). Geolocation: ipwho.is, fallback ipapi.co (both HTTPS, no API key).
/// ip-api.com is not used because its free tier is HTTP-only and blocked by ATS.
enum IPInfoService {
    private struct Ipify: Decodable, Sendable { let ip: String }

    private struct WhoIs: Decodable, Sendable {
        struct Conn: Decodable, Sendable { let isp: String?; let org: String? }
        struct TZ: Decodable, Sendable { let id: String? }
        let success: Bool
        let ip: String?
        let country: String?
        let countryCode: String?
        let region: String?
        let city: String?
        let latitude: Double?
        let longitude: Double?
        let connection: Conn?
        let timezone: TZ?
    }

    private struct IPApiCo: Decodable, Sendable {
        let error: Bool?
        let ip: String?
        let city: String?
        let region: String?
        let countryCode: String?
        let countryName: String?
        let timezone: String?
        let org: String?
        let latitude: Double?
        let longitude: Double?
    }

    static func isIP(_ s: String) -> Bool {
        var a4 = in_addr(), a6 = in6_addr()
        return inet_pton(AF_INET, s, &a4) == 1 || inet_pton(AF_INET6, s, &a6) == 1
    }

    static func publicIPs() async -> PublicIPs {
        async let a = try? HTTP.json(URL(string: "https://api.ipify.org?format=json")!, as: Ipify.self)
        async let b = try? HTTP.json(URL(string: "https://api64.ipify.org?format=json")!, as: Ipify.self)
        let v4only = await a?.ip
        let any = await b?.ip
        let anyIsV6 = any?.contains(":") == true
        return PublicIPs(v4: v4only ?? (anyIsV6 ? nil : any), v6: anyIsV6 ? any : nil)
    }

    /// `ip == nil` looks up the caller's own public address.
    static func lookup(_ ip: String?) async throws -> IPLocation {
        do { return try await viaWhoIs(ip) } catch { return try await viaIPApiCo(ip) }
    }

    private static func viaWhoIs(_ ip: String?) async throws -> IPLocation {
        let r = try await HTTP.json(URL(string: "https://ipwho.is/\(ip ?? "")")!, as: WhoIs.self)
        guard r.success, let lat = r.latitude, let lon = r.longitude else { throw URLError(.cannotParseResponse) }
        return IPLocation(ip: r.ip ?? ip ?? "", country: r.country ?? "", countryCode: r.countryCode ?? "",
                          region: r.region ?? "", city: r.city ?? "", latitude: lat, longitude: lon,
                          timezone: r.timezone?.id ?? "", isp: r.connection?.isp ?? r.connection?.org ?? "")
    }

    private static func viaIPApiCo(_ ip: String?) async throws -> IPLocation {
        let path = ip.map { "\($0)/json/" } ?? "json/"
        let r = try await HTTP.json(URL(string: "https://ipapi.co/\(path)")!, as: IPApiCo.self)
        guard r.error != true, let lat = r.latitude, let lon = r.longitude else { throw URLError(.cannotParseResponse) }
        return IPLocation(ip: r.ip ?? ip ?? "", country: r.countryName ?? "", countryCode: r.countryCode ?? "",
                          region: r.region ?? "", city: r.city ?? "", latitude: lat, longitude: lon,
                          timezone: r.timezone ?? "", isp: r.org ?? "")
    }
}
