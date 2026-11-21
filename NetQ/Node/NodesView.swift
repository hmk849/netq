import SwiftUI

struct NodesView: View {
    @Environment(AppSettings.self) private var s
    @Environment(NodeStore.self) private var store
    @State private var showAdd = false
    @State private var mode = 0
    @State private var favOnly = false

    private var shown: [NodeTarget] {
        let base = mode == 1 ? store.ranking : store.nodes
        return favOnly ? base.filter(\.favorite) : base
    }

    var body: some View {
        List {
            Section {
                Picker("", selection: $mode) {
                    Text(s.t("node.list")).tag(0); Text(s.t("node.rank")).tag(1)
                }.pickerStyle(.segmented)
                Toggle(s.t("node.favOnly"), isOn: $favOnly)
                Text(s.t("node.note")).font(.footnote).foregroundStyle(.secondary)
            }
            if shown.isEmpty { Text(s.t("node.empty")).foregroundStyle(.secondary) }
            ForEach(Array(shown.enumerated()), id: \.element.id) { idx, n in
                NavigationLink { NodeDetailView(nodeID: n.id) } label: { row(n, rank: mode == 1 ? idx + 1 : nil) }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { store.delete([n.id]) } label: { Label(s.t("node.delete"), systemImage: "trash") }
                    }
                    .swipeActions(edge: .leading) {
                        Button { store.toggleFavorite(n.id) } label: {
                            Label(s.t(n.favorite ? "node.unfav" : "node.fav"), systemImage: n.favorite ? "star.slash" : "star")
                        }.tint(.yellow)
                    }
            }
        }
        .navigationTitle(s.t("ctx.node"))
        .toolbar {
            ToolbarItem { Button { Task { await store.testAll() } } label: { Image(systemName: "bolt.horizontal") }
                .disabled(store.nodes.isEmpty || !store.testing.isEmpty) }
            ToolbarItem { Button { showAdd = true } label: { Image(systemName: "plus") } }
        }
        .sheet(isPresented: $showAdd) { AddNodeView() }
        .sensoryFeedback(.success, trigger: store.nodes.count)
    }

    private func row(_ n: NodeTarget, rank: Int?) -> some View {
        HStack {
            if let r = rank { Text("\(r)").font(.headline).frame(width: 26).foregroundStyle(r <= 3 ? Color.accentColor : .secondary) }
            Text(n.last?.countryCode.flagEmoji ?? "🌐").font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                HStack { Text(n.name).font(.headline); if n.favorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) } }
                Text("\(n.host):\(n.port)").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if store.testing.contains(n.id) { ProgressView() }
            else if let l = n.last {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(l.reachable ? String(format: "%.0f ms", l.pingAvg) : s.t("node.timeout")).font(.subheadline.weight(.semibold))
                    Text(String(format: "%.0f%% %@", l.loss, s.t("sp.loss"))).font(.caption2).foregroundStyle(.secondary)
                }
            } else { Text(s.t("node.never")).font(.caption).foregroundStyle(.secondary) }
        }
    }
}

struct AddNodeView: View {
    @Environment(AppSettings.self) private var s
    @Environment(NodeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var host = ""
    @State private var port = "443"
    @State private var dl = ""
    @State private var ul = ""
    @State private var errorKey: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(s.t("node.name"), text: $name)
                    TextField(s.t("node.host"), text: $host).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField(s.t("node.port"), text: $port).keyboardType(.numberPad)
                }
                Section { 
                    TextField("https://…", text: $dl, prompt: Text(s.t("node.dl"))).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    TextField("https://…", text: $ul, prompt: Text(s.t("node.ul"))).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                } footer: { Text(s.t("node.speedhint")) }
                if let e = errorKey { Text(s.t(e)).foregroundStyle(.red) }
            }
            .navigationTitle(s.t("node.add"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(s.t("node.cancel")) { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(s.t("node.save")) { save() } }
            }
        }
    }

    private func validURL(_ t: String) -> Bool {
        t.isEmpty || (URL(string: t).map { $0.scheme == "https" && ($0.host?.isEmpty == false) } ?? false)
    }

    private func save() {
        let h = host.trimmingCharacters(in: .whitespacesAndNewlines)
        let bad = h.isEmpty || h.contains(where: { $0 == " " || $0 == "/" || $0 == "?" || $0 == "#" })
        guard !bad, !h.contains("://") else { errorKey = "node.badhost"; return }
        guard let p = Int(port), (1...65535).contains(p) else { errorKey = "node.badport"; return }
        let d = dl.trimmingCharacters(in: .whitespaces), u = ul.trimmingCharacters(in: .whitespaces)
        guard validURL(d), validURL(u) else { errorKey = "node.badurl"; return }
        let n = name.trimmingCharacters(in: .whitespaces)
        store.add(NodeTarget(name: n.isEmpty ? h : n, host: h, port: p,
                             downloadURL: d.isEmpty ? nil : d, uploadURL: u.isEmpty ? nil : u))
        dismiss()
    }
}

struct NodeDetailView: View {
    let nodeID: UUID
    @Environment(AppSettings.self) private var s
    @Environment(NodeStore.self) private var store
    @Environment(ReportStore.self) private var reports
    @State private var test = false

    var body: some View {
        if let n = store.nodes.first(where: { $0.id == nodeID }) {
            List {
                Section {
                    InfoRow("node.host", n.host); InfoRow("node.port", String(n.port))
                    InfoRow("node.dl", n.downloadURL ?? s.t("node.speedNA"))
                    InfoRow("node.ul", n.uploadURL ?? s.t("node.speedNA"))
                }
                Section(s.t("node.status")) {
                    if let l = n.last {
                        InfoRow("sp.ip", l.ip)
                        InfoRow("sp.country", l.countryCode.isEmpty ? nil : "\(l.countryCode.flagEmoji) \(l.country)")
                        InfoRow("map.isp", l.isp)
                        if l.reachable {
                            InfoRow("node.avg", String(format: "%.1f ms", l.pingAvg))
                            InfoRow("node.min", String(format: "%.1f ms", l.pingMin))
                            InfoRow("sp.jitter", String(format: "%.1f ms", l.jitter))
                            InfoRow("node.stab", String(format: "± %.1f ms", l.stddev))
                            InfoRow("node.resp", l.responseMs.map { String(format: "%.0f ms", $0) })
                        } else { Text(s.t("node.timeout")).foregroundStyle(.red) }
                        InfoRow("sp.loss", String(format: "%.0f %%", l.loss))
                        InfoRow("sp.time", l.date.formatted(date: .abbreviated, time: .shortened))
                    } else { Text(s.t("node.never")).foregroundStyle(.secondary) }
                    Button { Task { await store.test(n.id) } } label: {
                        HStack { Text(s.t("node.test")); if store.testing.contains(n.id) { Spacer(); ProgressView() } }
                    }.disabled(store.testing.contains(n.id))
                }
                Section(s.t("det.last")) {
                    if let r = reports.reports.first(where: { $0.context == "node" && $0.nodeName == n.name }) {
                        InfoRow("sp.download", SpeedResult.speedText(r.download, s.t("node.na")))
                        InfoRow("sp.upload", SpeedResult.speedText(r.upload, s.t("node.na")))
                        InfoRow("sp.time", r.date.formatted(date: .abbreviated, time: .shortened))
                    } else { Text(s.t("det.lastNone")).foregroundStyle(.secondary) }
                }
                Section { Button(s.t("det.start")) { test = true }.buttonStyle(.glassProminent).frame(maxWidth: .infinity) }
            }
            .navigationTitle(n.name)
            .toolbar { Button { store.toggleFavorite(n.id) } label: { Image(systemName: n.favorite ? "star.fill" : "star") } }
            .fullScreenCover(isPresented: $test) { SpeedTestView(context: .node, node: n) }
        }
    }
}
