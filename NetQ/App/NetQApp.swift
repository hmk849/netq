import SwiftUI

@main
struct NetQApp: App {
    @State private var settings = AppSettings()
    @State private var store = ReportStore()
    @State private var nodes = NodeStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(settings)
                .environment(store)
                .environment(nodes)
                .tint(settings.accentColor)
                .preferredColorScheme(settings.appearance.scheme)
                .dynamicTypeSize(settings.textScale.size)
        }
    }
}
