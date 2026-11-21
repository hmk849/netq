import SwiftUI
import MapKit

struct MapScreen: View {
    @Environment(AppSettings.self) private var s
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = MapModel()
    @State private var query = ""
    @State private var expanded = true

    var body: some View {
        @Bindable var vm = vm
        Map(position: $vm.position) {
            UserAnnotation()
            if let l = vm.ipLoc {
                Marker(l.city.isEmpty ? l.ip : l.city, systemImage: "network",
                       coordinate: .init(latitude: l.latitude, longitude: l.longitude)).tint(.orange)
            }
            if let p = vm.pin { Marker(p.name, coordinate: p.coordinate).tint(.red) }
        }
        .mapStyle(vm.kind.style)
        .mapControls { MapCompass(); MapScaleView() }
        .safeAreaInset(edge: .top) { searchBar }
        .overlay(alignment: .bottomTrailing) { sideButtons.padding(.trailing, 12).padding(.bottom, expanded ? 330 : 90) }
        .overlay(alignment: .bottom) { infoCard.padding(.horizontal, 12).padding(.bottom, 8) }
        .animation(reduceMotion ? nil : .smooth, value: expanded)
        .task { await vm.load() }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(s.t("map.search"), text: $query)
                .submitLabel(.search)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onSubmit { Task { await vm.search(query) } }
            if !query.isEmpty {
                Button { query = ""; vm.pin = nil } label: { Image(systemName: "xmark.circle.fill") }
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .glassEffect(.regular.interactive(), in: .capsule)
        .padding(.horizontal, 12)
        .padding(.top, 4)
    }

    private var sideButtons: some View {
        GlassEffectContainer(spacing: 10) {
            VStack(spacing: 10) {
                GlassIconButton(systemName: "location.fill") { vm.goToDevice() }
                Menu {
                    Picker(s.t("map.style"), selection: $vm.kind) {
                        ForEach(MapKind.allCases, id: \.self) { Text(s.t("map.\($0.rawValue)")).tag($0) }
                    }
                } label: {
                    Image(systemName: "square.2.layers.3d").font(.title3).frame(width: 44, height: 44)
                }
                .buttonStyle(.glass)
                GlassIconButton(systemName: "arrow.clockwise") { Task { await vm.load() } }
            }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: vm.loading)
    }

    private var infoCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Button { expanded.toggle() } label: {
                    HStack {
                        Text(vm.ipLoc?.flag ?? "🌐").font(.largeTitle)
                        VStack(alignment: .leading) {
                            Text(headline).font(.headline)
                            Text(vm.ips.v4 ?? vm.ips.v6 ?? (vm.loading ? s.t("map.loading") : "-"))
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if vm.loading { ProgressView() }
                        Image(systemName: expanded ? "chevron.down" : "chevron.up").foregroundStyle(.secondary)
                    }
                }
                .buttonStyle(.plain)
                if let e = vm.errorKey { Text(s.t(e)).font(.footnote).foregroundStyle(.red) }
                if expanded {
                    Divider()
                    Text(s.t("map.ipsrc")).font(.caption).foregroundStyle(.secondary)
                    if let l = vm.ipLoc {
                        row("map.country", l.country); row("map.city", l.city); row("map.region", l.region)
                        row("map.cc", l.countryCode); row("map.isp", l.isp)
                        row("map.coord", String(format: "%.4f, %.4f", l.latitude, l.longitude))
                        row("map.tz", l.timezone)
                    }
                    row("map.v4", vm.ips.v4 ?? "-"); row("map.v6", vm.ips.v6 ?? "-")
                    Divider()
                    Text(s.t("map.gps")).font(.caption).foregroundStyle(.secondary)
                    if let c = vm.device.coordinate {
                        row("map.coord", String(format: "%.5f, %.5f", c.latitude, c.longitude))
                        if let a = vm.device.accuracy { row("map.acc", String(format: "±%.0f m", a)) }
                    } else {
                        Text(s.t(vm.device.denied ? "map.denied" : "map.locating")).font(.footnote)
                    }
                }
            }
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var headline: String {
        guard let l = vm.ipLoc else { return s.t("tab.map") }
        return [l.country, l.city].filter { !$0.isEmpty }.joined(separator: " · ")
    }

    private func row(_ key: String, _ value: String) -> some View {
        LabeledContent(s.t(key), value: value.isEmpty ? "-" : value).font(.subheadline)
    }
}
