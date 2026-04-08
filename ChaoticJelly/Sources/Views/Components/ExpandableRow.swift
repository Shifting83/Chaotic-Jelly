import SwiftUI

struct ExpandableRow<Header: View, Detail: View>: View {
    @State private var isExpanded = false
    @ViewBuilder let header: () -> Header
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 10) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.cjTextSecondary)
                    .frame(width: 10)

                header()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(isExpanded ? Color.cjExpandedRow : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            }

            // Detail panel
            if isExpanded {
                VStack(alignment: .leading) {
                    detail()
                }
                .padding(.leading, 44)
                .padding(.trailing, 16)
                .padding(.vertical, 12)
                .background(Color.cjExpandedRow.opacity(0.7))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}
