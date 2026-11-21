import SwiftUI

/// Rounded settings-style card.
struct Card<Content: View>: View {
    @Environment(AppSettings.self) private var s
    @ViewBuilder var content: Content
    var body: some View {
        content
            .padding(s.density.spacing)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: 20))
    }
}

/// Floating button using native iOS 26 Liquid Glass.
struct GlassIconButton: View {
    let systemName: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: systemName).font(.title3).frame(width: 44, height: 44)
        }
        .buttonStyle(.glass)
    }
}
