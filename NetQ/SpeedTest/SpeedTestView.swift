import SwiftUI

struct SpeedTestView: View {
    let context: TestContext
    var node: NodeTarget? = nil
    @Environment(AppSettings.self) private var s
    @Environment(ReportStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var vm = SpeedTestModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [s.accentColor.opacity(0.18), .clear], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            VStack(spacing: 18) {
                topBar
                if let r = vm.result { ReportView(result: r, vm: vm) }
                else if let e = vm.errorKey { errorView(e) }
                else { testing }
                Spacer(minLength: 0)
            }
            .padding()
        }
        .background(.background)
        .task { vm.start(context, node: node) }
        .onDisappear { vm.cancel() }
        .sensoryFeedback(.selection, trigger: vm.phase)
        .sensoryFeedback(.success, trigger: vm.result)
    }

    private var topBar: some View {
        HStack {
            Text(node?.name ?? s.t("ctx.\(context.rawValue)")).font(.headline)
            Spacer()
            GlassIconButton(systemName: "xmark") { dismiss() }
        }
    }

    private var testing: some View {
        VStack(spacing: 20) {
            if let m = vm.mismatchKey {
                Label(s.t(m), systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
            Text(s.t(vm.phase.key)).font(.title3.weight(.semibold))
                .contentTransition(.opacity)
            GaugeView(fraction: vm.fraction, value: vm.live,
                      unit: vm.phase.usesMbps ? "Mbps" : "ms", active: vm.phase.rawValue >= 1 && vm.phase.rawValue <= 4)
            WaveView(samples: vm.samples).frame(height: 70)
            steps
        }
        .animation(reduceMotion ? nil : .smooth, value: vm.phase)
    }

    private var steps: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(SpeedPhase.allCases, id: \.self) { p in
                HStack {
                    Image(systemName: p.rawValue < vm.phase.rawValue ? "checkmark.circle.fill"
                          : p == vm.phase ? "circle.dotted" : "circle")
                        .foregroundStyle(p.rawValue <= vm.phase.rawValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    Text(s.t(p.key)).font(.footnote)
                        .foregroundStyle(p == vm.phase ? .primary : .secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func errorView(_ key: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "wifi.exclamationmark").font(.system(size: 48)).foregroundStyle(.orange)
            Text(s.t(key)).multilineTextAlignment(.center)
            Button(s.t("sp.retest")) { vm.start(context, node: node) }.buttonStyle(.glassProminent)
        }.padding(.top, 60)
    }
}

struct GaugeView: View {
    let fraction: Double
    let value: Double
    let unit: String
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private let sweep = 0.75

    var body: some View {
        ZStack {
            Circle().trim(from: 0, to: sweep)
                .stroke(.quaternary, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
            Circle().trim(from: 0, to: sweep * max(fraction, 0.001))
                .stroke(AngularGradient(colors: [.cyan, .accentColor, .purple],
                                        center: .center, startAngle: .degrees(0), endAngle: .degrees(270)),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round))
                .rotationEffect(.degrees(135))
            VStack(spacing: 2) {
                Text(String(format: value >= 100 ? "%.0f" : "%.1f", value))
                    .font(.system(size: 60, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText(value: value))
                Text(unit).font(.headline).foregroundStyle(.secondary)
            }
        }
        .frame(width: 260, height: 260)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: fraction)
        .animation(reduceMotion ? nil : .smooth(duration: 0.3), value: value)
    }
}

struct WaveView: View {
    let samples: [Double]
    var body: some View {
        GeometryReader { g in
            let peak = max(samples.max() ?? 1, 1)
            let pts: [CGPoint] = samples.enumerated().map { i, v in
                CGPoint(x: g.size.width * CGFloat(i) / 59, y: g.size.height * (1 - CGFloat(v / peak)) )
            }
            ZStack {
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: CGPoint(x: f.x, y: g.size.height)); p.addLine(to: f)
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: g.size.height)); p.closeSubpath()
                }.fill(LinearGradient(colors: [.accentColor.opacity(0.35), .clear], startPoint: .top, endPoint: .bottom))
                Path { p in
                    guard let f = pts.first else { return }
                    p.move(to: f); for pt in pts.dropFirst() { p.addLine(to: pt) }
                }.stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineJoin: .round))
            }
        }
    }
}

struct ReportView: View {
    let result: SpeedResult
    let vm: SpeedTestModel
    @Environment(AppSettings.self) private var s
    @Environment(ReportStore.self) private var store

    var body: some View {
        VStack(spacing: 14) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: s.density.spacing) {
                tile("sp.ping", String(format: "%.0f ms", result.ping))
                tile("sp.jitter", String(format: "%.1f ms", result.jitter))
                tile("sp.download", SpeedResult.speedText(result.download, s.t("node.na")))
                tile("sp.upload", SpeedResult.speedText(result.upload, s.t("node.na")))
                tile("sp.loss", String(format: "%.1f %%", result.loss))
                tile("sp.type", s.t("net.\(result.networkType)"))
                tile("sp.ip", result.ip)
                tile("sp.country", "\(result.countryCode.flagEmoji) \(result.country)")
                tile("sp.isp", result.isp)
                tile("sp.time", result.date.formatted(date: .abbreviated, time: .shortened))
            }
            if let m = vm.mismatchKey {
                Label(s.t(m), systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(.orange)
            }
            GlassEffectContainer {
                HStack {
                    Button { vm.start(TestContext(rawValue: result.context) ?? .wifi, node: vm.node) } label: {
                        Label(s.t("sp.retest"), systemImage: "arrow.clockwise")
                    }.buttonStyle(.glass)
                    Button {
                        store.add(result); vm.saved = true
                    } label: {
                        Label(s.t(vm.saved ? "sp.saved" : "sp.save"), systemImage: vm.saved ? "checkmark" : "square.and.arrow.down")
                    }.buttonStyle(.glass).disabled(vm.saved)
                    ShareLink(item: result.summary(s.language)) { Image(systemName: "square.and.arrow.up") }
                        .buttonStyle(.glassProminent)
                }
            }
        }
    }

    private func tile(_ key: String, _ value: String) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 4) {
                Text(s.t(key)).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.subheadline.weight(.semibold)).lineLimit(2).minimumScaleFactor(0.7)
            }
        }
    }
}
