import Network
import Synchronization

final class OnceFlag: @unchecked Sendable {
    private let m = Mutex(false)
    /// Returns true only on the first call.
    func first() -> Bool { m.withLock { let was = $0; $0 = true; return !was } }
}

enum NetworkKind: String, Sendable {
    case wifi, cellular, wired, other, none

    /// One-shot read of the current default path interface.
    static func current() async -> NetworkKind {
        await withCheckedContinuation { cont in
            let monitor = NWPathMonitor()
            let once = OnceFlag()
            monitor.pathUpdateHandler = { p in
                guard once.first() else { return }
                monitor.cancel()
                let k: NetworkKind
                if p.status != .satisfied { k = .none }
                else if p.usesInterfaceType(.wifi) { k = .wifi }
                else if p.usesInterfaceType(.cellular) { k = .cellular }
                else if p.usesInterfaceType(.wiredEthernet) { k = .wired }
                else { k = .other }
                cont.resume(returning: k)
            }
            monitor.start(queue: DispatchQueue(label: "netq.pathkind"))
        }
    }
}
