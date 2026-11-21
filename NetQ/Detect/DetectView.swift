import SwiftUI

struct DetectView: View {
    @Environment(AppSettings.self) private var s

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink { WiFiView() } label: { Label(s.t("ctx.wifi"), systemImage: "wifi") }
                    NavigationLink { CellularView() } label: { Label(s.t("ctx.cellular"), systemImage: "antenna.radiowaves.left.and.right") }
                    NavigationLink { VPNView() } label: { Label(s.t("ctx.vpn"), systemImage: "lock.shield") }
                    NavigationLink { NodesView() } label: { Label(s.t("ctx.node"), systemImage: "point.3.connected.trianglepath.dotted") }
                } footer: { Text(s.t("det.note")) }
                Section {
                    NavigationLink { ReportsView() } label: { Label(s.t("det.reports"), systemImage: "doc.text") }
                }
            }
            .navigationTitle(s.t("tab.detect"))
        }
    }

}

struct ReportsView: View {
    @Environment(AppSettings.self) private var s
    @Environment(ReportStore.self) private var store

    var body: some View {
        @Bindable var store = store
        List {
            if store.reports.isEmpty { Text(s.t("rep.empty")).foregroundStyle(.secondary) }
            ForEach(store.reports) { r in
                NavigationLink {
                    ScrollView { Text(r.summary(s.language)).padding().frame(maxWidth: .infinity, alignment: .leading) }
                        .toolbar { ShareLink(item: r.summary(s.language)) }
                        .navigationTitle(s.t("ctx.\(r.context)"))
                } label: {
                    VStack(alignment: .leading) {
                        Text("\(r.nodeName ?? s.t("ctx.\(r.context)")) · ↓\(SpeedResult.speedText(r.download, "N/A")) ↑\(SpeedResult.speedText(r.upload, "N/A"))")
                        Text(r.date.formatted(date: .abbreviated, time: .shortened)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { store.delete(at: $0) }
        }
        .navigationTitle(s.t("det.reports"))
        .toolbar { if !store.reports.isEmpty { Button(s.t("rep.clear"), role: .destructive) { store.clear() } } }
    }
}
