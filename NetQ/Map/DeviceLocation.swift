import CoreLocation
import Observation

/// GPS / device position. Kept separate from IP geolocation on purpose.
@MainActor @Observable
final class DeviceLocation {
    var coordinate: CLLocationCoordinate2D?
    var accuracy: Double?
    var denied = false
    @ObservationIgnored private var session: CLServiceSession?
    @ObservationIgnored private var task: Task<Void, Never>?

    func refresh() {
        task?.cancel()
        session = CLServiceSession(authorization: .whenInUse)
        task = Task { [weak self] in
            do {
                for try await u in CLLocationUpdate.liveUpdates() {
                    guard let self else { return }
                    if u.authorizationDenied || u.authorizationDeniedGlobally { self.denied = true; return }
                    if let l = u.location {
                        self.denied = false
                        self.coordinate = l.coordinate
                        self.accuracy = l.horizontalAccuracy
                        return
                    }
                }
            } catch {}
        }
    }
}
