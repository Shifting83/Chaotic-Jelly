import SwiftUI

struct CJCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Color.cjCard)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.cjBorder, lineWidth: 1)
            )
    }
}

struct CJSectionLabelModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .font(.cjSectionLabel)
            .foregroundStyle(Color.cjTextSecondary)
            .textCase(.uppercase)
            .tracking(0.5)
    }
}

extension View {
    func cjCard() -> some View {
        modifier(CJCardModifier())
    }

    func cjSectionLabel() -> some View {
        modifier(CJSectionLabelModifier())
    }
}
