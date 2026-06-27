import SwiftUI

/// Barra di ricerca con i tag completati mostrati come **chip** (ovali colorati)
/// e un campo di testo per il resto della query (nome app o tag in corso).
struct TagSearchBar: View {
    @Binding var committedTags: [String]   // canonici
    @Binding var text: String
    let displayName: (String) -> String    // canonico → grafia
    let color: Color
    let focusTrigger: Int
    let onTab: () -> Void
    let onSubmit: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16, weight: .medium))

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(committedTags, id: \.self) { canon in
                        chip(canon)
                    }
                    SearchTextField(text: $text,
                                    placeholder: committedTags.isEmpty ? "Cerca app o #tag…" : "",
                                    focusTrigger: focusTrigger,
                                    onTab: onTab,
                                    onSubmit: onSubmit,
                                    onBackspaceWhenEmpty: removeLastChip)
                        .frame(minWidth: 160, minHeight: 24)
                }
                .padding(.vertical, 2)
            }

            if !committedTags.isEmpty || !text.isEmpty {
                Button(action: clearAll) {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Cancella la ricerca")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.primary.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.primary.opacity(0.06), lineWidth: 1))
    }

    private func chip(_ canon: String) -> some View {
        HStack(spacing: 4) {
            Text(displayName(canon))
                .font(.system(size: 13, weight: .medium))
                .lineLimit(1)
            Button {
                committedTags.removeAll { $0 == canon }
            } label: {
                Image(systemName: "xmark.circle.fill").font(.system(size: 11))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 3)
        .background(Capsule().fill(color))
    }

    private func removeLastChip() {
        if !committedTags.isEmpty { committedTags.removeLast() }
    }

    private func clearAll() {
        committedTags = []
        text = ""
    }
}
