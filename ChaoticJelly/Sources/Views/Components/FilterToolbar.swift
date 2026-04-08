import SwiftUI

struct FilterPill<Value: Hashable>: View {
    let label: String
    let value: Value?
    @Binding var selection: Value?
    var labelColor: Color?

    var isSelected: Bool {
        selection == value
    }

    var body: some View {
        Button {
            selection = value
        } label: {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .medium : .regular))
                .foregroundStyle(isSelected ? .white : (labelColor ?? Color.cjTextSecondary))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isSelected ? Color.cjPrimary : Color.cjCard)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? Color.clear : Color.cjBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

struct SearchField: View {
    @Binding var text: String
    var placeholder: String = "Search..."

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color.cjTextSecondary)
                .font(.system(size: 12))
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.cjSecondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.cjCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.cjBorder, lineWidth: 1)
        )
        .frame(maxWidth: 220)
    }
}
