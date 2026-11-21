import Network
import Observation

extension NetworkKind {
    init(path p: NWPath) {
        if p.status != .satisfied { self = .none }
        else if p.usesInterfaceType(.wifi) { self = .wifi }
        else if p.usesInterfaceType(.cellular) { self = .cellular }
        else if p.usesInterfaceType(.wiredEthernet) { self = .wired }
        else { self = .other }
    }
}

@MainActor @Observable
final class NetworkMonitor {
    var kind: NetworkKind = .none
    var satisfied = false
    var expensive = false
    var constrained = false
    var supportsIPv4 = false
    var supportsIPv6 = false
    var supportsDNS = false
    var cellularAvailable = false

    @ObservationIgnored private var main: NWPathMonitor?
    @ObservationIgnored private var cell: NWPathMonitor?

    func start() {
        guard main == nil else { return }
        let m = NWPathMonitor()
        m.pathUpdateHandler = { [weak self] p in
            let k = NetworkKind(path: p)
            let vals = (p.status == .satisfied, p.isExpensive, p.isConstrained,
                        p.supportsIPv4, p.supportsIPv6, p.supportsDNS)
            Task { @MainActor in
                guard let self else { return }
                self.kind = k
                (self.satisfied, self.expensive, self.constrained,
                 self.supportsIPv4, self.supportsIPv6, self.supportsDNS) = vals
            }
        }
        m.start(queue: DispatchQueue(label: "netq.monitor.main"))
        main = m
        let c = NWPathMonitor(requiredInterfaceType: .cellular)
        c.pathUpdateHandler = { [weak self] p in
            let ok = p.status == .satisfied
            Task { @MainActor in self?.cellularAvailable = ok }
        }
        c.start(queue: DispatchQueue(label: "netq.monitor.cell"))
        cell = c
    }

    func stop() { main?.cancel(); cell?.cancel(); main = nil; cell = nil }
}
