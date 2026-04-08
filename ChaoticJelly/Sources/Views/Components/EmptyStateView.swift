import SwiftUI

struct CJEmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?
    var isPrimaryAction: Bool = true

    var body: some View {
        VStack(spacing: 16) {
            Text(icon)
                .font(.system(size: 40))
                .opacity(0.6)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.cjTextPrimary)

            Text(message)
                .font(.cjBody)
                .foregroundStyle(Color.cjTextSecondary)

            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                }
                .buttonStyle(isPrimaryAction ? .borderedProminent : .bordered)
                .controlSize(.regular)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
