import SwiftUI

/// Emoji grid picker (avatar, event and coupon emoji).
struct EmojiPickerGrid: View {
    let emojis: [String]
    @Binding var selection: String
    var columns = 6

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(emojis, id: \.self) { emoji in
                Button {
                    selection = emoji
                } label: {
                    Text(emoji)
                        .font(.title)
                        .frame(maxWidth: .infinity, minHeight: 48)
                        .background(
                            selection == emoji ? Color.accentColor.opacity(0.18) : Color.tertiaryCardBackground,
                            in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay {
                            if selection == emoji {
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.accentColor, lineWidth: 2)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(emoji)
                .accessibilityAddTraits(selection == emoji ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Member color swatches.
struct MemberColorPicker: View {
    @Binding var selection: String

    var body: some View {
        HStack(spacing: 12) {
            ForEach(Brand.memberColors, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 34, height: 34)
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.footnote.weight(.bold))
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hex)
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// Horizontal filter chips ("Alle · Fotos · Videos …") — glass buttons,
/// the selected one is the prominent (accent-filled) glass variant.
struct FilterChips<Item: Hashable & Identifiable>: View {
    let items: [Item]
    @Binding var selection: Item
    let title: (Item) -> String

    var body: some View {
        ScrollView(.horizontal) {
            GlassEffectContainer(spacing: 8) {
                HStack(spacing: 8) {
                    ForEach(items) { item in
                        GlassChip(title: title(item), selected: selection == item) {
                            withAnimation(.snappy) { selection = item }
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .scrollTargetLayout()
        }
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, Brand.screenInset, for: .scrollContent)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

/// One selectable glass chip.
struct GlassChip: View {
    let title: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Group {
            if selected {
                Button(action: action) { label }
                    .buttonStyle(.glassProminent)
            } else {
                Button(action: action) { label }
                    .buttonStyle(.glass)
            }
        }
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var label: some View {
        Text(title)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 4)
    }
}
