import SwiftUI
import MapKit
import Observation

struct MapPin: Equatable {
    var name: String
    var latitude: Double
    var longitude: Double
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
}

enum MapKind: String, CaseIterable { case standard, hybrid, imagery
    var style: MapStyle {
        switch self {
        case .standard: .standard
        case .hybrid: .hybrid
        case .imagery: .imagery
        }
    }
}

@MainActor @Observable
final class MapModel {
    var ips = PublicIPs()
    var ipLoc: IPLocation?
    var loading = false
    var errorKey: String?
    var pin: MapPin?
    var position: MapCameraPosition = .automatic
    var kind: MapKind = .standard
    let device = DeviceLocation()

    func load() async {
        loading = true
        errorKey = nil
        device.refresh()
        async let ipsTask = IPInfoService.publicIPs()
        do { ipLoc = try await IPInfoService.lookup(nil) } catch { errorKey = "map.err" }
        ips = await ipsTask
        loading = false
        if let l = ipLoc { focus(l.latitude, l.longitude, distance: 1_500_000) }
    }

    func focus(_ lat: Double, _ lon: Double, distance: Double) {
        position = .camera(MapCamera(centerCoordinate: .init(latitude: lat, longitude: lon), distance: distance))
    }

    func goToDevice() {
        device.refresh()
        if let c = device.coordinate { focus(c.latitude, c.longitude, distance: 3_000) }
    }

    func search(_ raw: String) async {
        let q = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return }
        errorKey = nil
        if IPInfoService.isIP(q) {
            do {
                let l = try await IPInfoService.lookup(q)
                pin = MapPin(name: "\(l.flag) \(l.ip)", latitude: l.latitude, longitude: l.longitude)
                focus(l.latitude, l.longitude, distance: 800_000)
            } catch { errorKey = "map.err" }
        } else {
            let req = MKLocalSearch.Request()
            req.naturalLanguageQuery = q
            do {
                let res = try await MKLocalSearch(request: req).start()
                guard let item = res.mapItems.first else { errorKey = "map.nosuch"; return }
                let c = item.location.coordinate
                pin = MapPin(name: item.name ?? q, latitude: c.latitude, longitude: c.longitude)
                focus(c.latitude, c.longitude, distance: 400_000)
            } catch { errorKey = "map.nosuch" }
        }
    }
}
