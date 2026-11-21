import SwiftUI

struct RootTabView: View {
    @Environment(AppSettings.self) private var s

    var body: some View {
        TabView {
            Tab(s.t("tab.map"), systemImage: "map") {
                MapScreen()
            }
            Tab(s.t("tab.detect"), systemImage: "speedometer") {
                DetectView()
            }
            Tab(s.t("tab.settings"), systemImage: "gearshape") {
                SettingsView()
            }
        }
    }
}

/// Shown until the module ships (map: batch 2, detect: batches 3-5).
struct PendingModuleView: View {
    @Environment(AppSettings.self) private var s
    let title: String
    let icon: String

    var body: some View {
        ContentUnavailableView(title, systemImage: icon, description: Text(s.t("pending.desc")))
    }
}
