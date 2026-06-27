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

            TagInputField(text: $newTag,
                          placeholder: "Aggiungi tag…",
                          onTab: autocomplete,
                          onSubmit: { commit(newTag) })
                .frame(height: 22)

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
    }

    private var title: String {
        appIDs.count <= 1 ? anchorName : "\(appIDs.count) app selezionate"
    }

    private var currentTags: [String] {
        appIDs.count <= 1 ? tagStore.tags(for: appIDs.first ?? "") : tagStore.commonTags(for: appIDs)
    }

    /// Tag esistenti che iniziano col testo digitato (esclusi quelli già
    /// applicati). Usati sia per i suggerimenti sia per il completamento.
    private var matchingTags: [String] {
        let query = TagStore.canonical(newTag)
        guard !query.isEmpty else { return [] }
        let alreadyApplied = Set(currentTags.map { TagStore.canonical($0) })
        return tagStore.allTags.filter { tag in
            let canon = TagStore.canonical(tag)
            return canon.hasPrefix(query) && !alreadyApplied.contains(canon)
        }
    }

    private var suggestions: [String] { Array(matchingTags.prefix(8)) }

    /// Tab: completa il testo fino al punto non ambiguo (prefisso comune dei
    /// match); se il match è unico, completa l'intero tag.
    private func autocomplete() {
        let matches = matchingTags
        guard !matches.isEmpty else { return }
        if matches.count == 1 {
            newTag = matches[0]
        } else {
            let common = TagEditorView.longestCommonPrefix(matches)
            if common.count > newTag.count { newTag = common }
        }
    }

    /// Prefisso comune (case-insensitive) restituito con la grafia del primo.
    private static func longestCommonPrefix(_ strings: [String]) -> String {
        guard let first = strings.first else { return "" }
        let firstChars = Array(first)
        let firstLower = Array(first.lowercased())
        var length = firstChars.count
        for s in strings.dropFirst() {
            let lower = Array(s.lowercased())
            var i = 0
            let limit = min(length, lower.count)
            while i < limit && firstLower[i] == lower[i] { i += 1 }
            length = i
            if length == 0 { break }
        }
        return String(firstChars.prefix(length))
    }

    private func commit(_ raw: String) {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !appIDs.isEmpty else { return }
        tagStore.addTag(trimmed, to: appIDs)
        newTag = ""
    }
}
