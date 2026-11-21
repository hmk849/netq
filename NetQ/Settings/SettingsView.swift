import SwiftUI
import UIKit

struct SettingsView: View {
    @Environment(AppSettings.self) private var s

    var body: some View {
        @Bindable var s = s
        NavigationStack {
            List {
                Section(s.t("set.device")) {
                    row("dev.name", UIDevice.current.name)
                    row("dev.model", Self.modelIdentifier)
                    row("dev.os", UIDevice.current.systemName)
                    row("dev.osv", UIDevice.current.systemVersion)
                    row("dev.ver", Self.info("CFBundleShortVersionString"))
                    row("dev.build", Self.info("CFBundleVersion"))
                }
                Section(s.t("set.appearance")) {
                    Picker(s.t("ap.mode"), selection: $s.appearance) {
                        ForEach(AppearanceMode.allCases, id: \.self) { Text(s.t("ap.\($0.rawValue)")).tag($0) }
                    }
                    Picker(s.t("ap.accent"), selection: $s.accent) {
                        ForEach(AccentChoice.allCases.filter { $0 != .custom }, id: \.self) {
                            Label(s.t("c.\($0.rawValue)"), systemImage: "circle.fill")
                                .foregroundStyle($0.preset ?? .accentColor).tag($0)
                        }
                        Text(s.t("c.custom")).tag(AccentChoice.custom)
                    }
                    ColorPicker(s.t("c.pick"), selection: s.customColorBinding, supportsOpacity: false)
                }
                Section(s.t("set.display")) {
                    Picker(s.t("ts.title"), selection: $s.textScale) {
                        ForEach(TextScale.allCases, id: \.self) { Text(s.t("ts.\($0.rawValue)")).tag($0) }
                    }
                    Picker(s.t("dn.title"), selection: $s.density) {
                        ForEach(Density.allCases, id: \.self) { Text(s.t("dn.\($0.rawValue)")).tag($0) }
                    }
                }
                Section(s.t("set.language")) {
                    Picker(s.t("set.language"), selection: $s.language) {
                        ForEach(AppLanguage.allCases, id: \.self) { Text(s.t("lang.\($0.rawValue)")).tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                Section {
                    NavigationLink(s.t("set.privacy")) { TextPage(title: s.t("set.privacy"), text: s.t("priv.body")) }
                    NavigationLink(s.t("set.licenses")) { LicensesView() }
                    NavigationLink(s.t("set.about")) { AboutView() }
                }
            }
            .environment(\.defaultMinListRowHeight, 36 + s.density.spacing)
            .navigationTitle(s.t("tab.settings"))
            .sensoryFeedback(.selection, trigger: s.accent)
            .sensoryFeedback(.selection, trigger: s.language)
        }
    }

    private func row(_ key: String, _ value: String) -> some View {
        LabeledContent(s.t(key), value: value)
    }

    static func info(_ k: String) -> String { Bundle.main.object(forInfoDictionaryKey: k) as? String ?? "-" }

    static var modelIdentifier: String {
        var u = utsname(); uname(&u)
        return withUnsafeBytes(of: &u.machine) { raw in
            String(decoding: raw.prefix { $0 != 0 }, as: UTF8.self)
        }
    }
}

struct TextPage: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView { Text(text).padding().frame(maxWidth: .infinity, alignment: .leading) }
            .navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    @Environment(AppSettings.self) private var s
    var body: some View {
        List {
            Section {
                VStack(spacing: 8) {
                    Image(systemName: "network").font(.system(size: 56)).foregroundStyle(.tint)
                    Text("NetQ").font(.title.bold())
                    Text("\(SettingsView.info("CFBundleShortVersionString")) (\(SettingsView.info("CFBundleVersion")))")
                        .foregroundStyle(.secondary)
                }.frame(maxWidth: .infinity)
            }
            Section(s.t("about.dev")) { LabeledContent(s.t("about.dev"), value: "hmk849") }
            Section(s.t("about.links")) {
                Link("GitHub · hmk849", destination: URL(string: "https://github.com/hmk849")!)
                Link("GitHub · hmk11131", destination: URL(string: "https://github.com/hmk11131")!)
                Link("X · hmk2778", destination: URL(string: "https://x.com/hmk2778?s=11")!)
            }
        }
        .navigationTitle(s.t("set.about")).navigationBarTitleDisplayMode(.inline)
    }
}
