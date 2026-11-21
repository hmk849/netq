import Foundation
import Observation

@MainActor @Observable
final class ReportStore {
    var reports: [SpeedResult] = []
    @ObservationIgnored private let url: URL = {
        URL.documentsDirectory.appending(path: "netq-reports.json")
    }()

    init() {
        if let d = try? Data(contentsOf: url),
           let r = try? JSONDecoder().decode([SpeedResult].self, from: d) { reports = r }
    }
    func add(_ r: SpeedResult) {
        guard !reports.contains(where: { $0.id == r.id }) else { return }
        reports.insert(r, at: 0); persist()
    }
    func delete(at offsets: IndexSet) { reports.remove(atOffsets: offsets); persist() }
    func clear() { reports = []; persist() }
    private func persist() {
        if let d = try? JSONEncoder().encode(reports) { try? d.write(to: url, options: .atomic) }
    }
}
