import SwiftUI

/// Finestra (popover) per gestire i tag di una o più app.
///
/// Con una sola app mostra i suoi tag; con più app mostra i tag **comuni** a
/// tutte. Aggiungere o rimuovere un tag agisce su tutte le app indicate.
struct TagEditorView: View {
    let appIDs: [String]
    let anchorName: String

    @EnvironmentObject var tagStore: TagStore
    @State private var newTag = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .lineLimit(1)

            let current = currentTags
            if current.isEmpty {
                Text("Nessun tag")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(current, id: \.self) { tag in
                        HStack(spacing: 6) {
                            Image(systemName: "tag.fill")
                                .font(.caption2)
                                .foregroundStyle(.tint)
                            Text(tag).lineLimit(1)
                            Spacer(minLength: 8)
                            Button {
                                tagStore.removeTag(canonical: TagStore.canonical(tag), from: appIDs)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("Rimuovi tag")
                        }
                    }
                }
            }

            Divider()

            TextField("Aggiungi tag…", text: $newTag)
                .textFieldStyle(.roundedBorder)
                .focused($fieldFocused)
                .onSubmit { commit(newTag) }

            let sugg = suggestions
            if !sugg.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(sugg, id: \.self) { suggestion in
                        Button {
                            commit(suggestion)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "tag")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Text(suggestion).lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .frame(width: 260)
        .onAppear { fieldFocused = true }
    }

    private var title: String {
        appIDs.count <= 1 ? anchorName : "\(appIDs.count) app selezionate"
    }

    private var currentTags: [String] {
        appIDs.count <= 1 ? tagStore.tags(for: appIDs.first ?? "") : tagStore.commonTags(for: appIDs)
    }

    private var suggestions: [String] {
        let query = TagStore.canonical(newTag)
        guard !query.isEmpty else { return [] }
        let alreadyApplied = Set(currentTags.map { TagStore.canonical($0) })
        return tagStore.allTags
            .filter { tag in
                let canon = TagStore.canonical(tag)
                return canon.hasPrefix(query) && !alreadyApplied.contains(canon)
            }
            .prefix(8)
            .map { $0 }
    }

    private func commit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !appIDs.isEmpty else { return }
        tagStore.addTag(trimmed, to: appIDs)
        newTag = ""
        fieldFocused = true
    }
}
