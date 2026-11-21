import SwiftUI
import Observation

@MainActor @Observable
final class SpeedTestModel {
    var phase: SpeedPhase = .connecting
    var live = 0.0
    var samples: [Double] = []
    var result: SpeedResult?
    var errorKey: String?
    var running = false
    var mismatchKey: String?
    var saved = false
    var node: NodeTarget?
    @ObservationIgnored private var task: Task<Void, Never>?

    func start(_ ctx: TestContext, node: NodeTarget? = nil) {
        self.node = node
        task?.cancel()
        phase = .connecting; live = 0; samples = []; result = nil; errorKey = nil; saved = false
        mismatchKey = nil; running = true
        task = Task {
            let kind = await NetworkKind.current()
            if ctx == .wifi, kind != .wifi { mismatchKey = "sp.mismatch.wifi" }
            if ctx == .cellular, kind != .cellular { mismatchKey = "sp.mismatch.cell" }
            if kind == .none { errorKey = "sp.err.offline"; running = false; return }
            for await e in SpeedEngine.run(context: ctx.rawValue, networkType: kind.rawValue, node: node) {
                switch e {
                case .phase(let p): phase = p; live = 0; samples = []
                case .live(let v):
                    live = v
                    samples.append(v)
                    if samples.count > 60 { samples.removeFirst() }
                case .failed(let k): errorKey = k
                case .done(let r): result = r
                }
            }
            running = false
        }
    }

    func cancel() { task?.cancel(); running = false }

    /// 0...1 for the gauge: log scale for Mbps, linear 0-200 ms for latency.
    var fraction: Double {
        phase.usesMbps ? min(log10(1 + live) / log10(1001), 1) : min(live / 200, 1)
    }
}
