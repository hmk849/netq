import SwiftUI
import Observation
import UIKit

enum AppearanceMode: String, CaseIterable, Sendable {
    case system, light, dark
    var scheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}

enum AccentChoice: String, CaseIterable, Sendable {
    case blue, purple, green, orange, red, pink, custom
    var preset: Color? {
        switch self {
        case .blue: .blue; case .purple: .purple; case .green: .green
        case .orange: .orange; case .red: .red; case .pink: .pink; case .custom: nil
        }
    }
}

enum TextScale: String, CaseIterable, Sendable {
    case small, standard, large, xLarge
    var size: DynamicTypeSize {
        switch self {
        case .small: .small; case .standard: .large
        case .large: .xxxLarge; case .xLarge: .accessibility1
        }
    }
}

enum Density: String, CaseIterable, Sendable {
    case compact, standard, relaxed
    var spacing: CGFloat {
        switch self { case .compact: 8; case .standard: 14; case .relaxed: 20 }
    }
}

enum AppLanguage: String, CaseIterable, Sendable { case zh, en }

@MainActor @Observable
final class AppSettings {
    @ObservationIgnored private let d = UserDefaults.standard

    var appearance: AppearanceMode { didSet { d.set(appearance.rawValue, forKey: "appearance") } }
    var accent: AccentChoice { didSet { d.set(accent.rawValue, forKey: "accent") } }
    var customAccentHex: String { didSet { d.set(customAccentHex, forKey: "customAccentHex") } }
    var textScale: TextScale { didSet { d.set(textScale.rawValue, forKey: "textScale") } }
    var density: Density { didSet { d.set(density.rawValue, forKey: "density") } }
    var language: AppLanguage { didSet { d.set(language.rawValue, forKey: "language") } }

    init() {
        let d = UserDefaults.standard
        appearance = AppearanceMode(rawValue: d.string(forKey: "appearance") ?? "") ?? .system
        accent = AccentChoice(rawValue: d.string(forKey: "accent") ?? "") ?? .blue
        customAccentHex = d.string(forKey: "customAccentHex") ?? "#0A84FF"
        textScale = TextScale(rawValue: d.string(forKey: "textScale") ?? "") ?? .standard
        density = Density(rawValue: d.string(forKey: "density") ?? "") ?? .standard
        let sys = Locale.preferredLanguages.first?.hasPrefix("zh") == true ? "zh" : "en"
        language = AppLanguage(rawValue: d.string(forKey: "language") ?? sys) ?? .en
    }

    var accentColor: Color { accent.preset ?? Color(hex: customAccentHex) }

    var customColorBinding: Binding<Color> {
        Binding(get: { Color(hex: self.customAccentHex) },
                set: { self.customAccentHex = $0.hexString; self.accent = .custom })
    }

    func t(_ key: String) -> String { L10n.text(key, language) }
}

extension Color {
    init(hex: String) {
        let h = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(red: Double((v >> 16) & 255) / 255,
                  green: Double((v >> 8) & 255) / 255,
                  blue: Double(v & 255) / 255)
    }
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}
