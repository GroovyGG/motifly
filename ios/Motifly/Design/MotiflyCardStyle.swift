import SwiftUI

/// Standard grouped card: padding, width, rounded rect fill from `MotiflyTokens`.
private struct MotiflyCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(MotiflyTokens.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: MotiflyTokens.Radius.card, style: .continuous)
                    .fill(MotiflyTokens.Colors.cardSurface)
            )
    }
}

extension View {
    /// Applies P0 card chrome (matches previous `HomeView` / `SettingsView` `cardStyle()`).
    func motiflyCardStyle() -> some View {
        modifier(MotiflyCardStyle())
    }
}
