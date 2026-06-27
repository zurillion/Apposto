import SwiftUI

/// Vista radice del pannello: barra di ordinamento, ricerca (con chip dei tag)
/// e griglia paginata.
struct LauncherRootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var tagStore: TagStore

    /// Tag confermati (canonici) mostrati come chip nella barra di ricerca.
    @State private var committedTags: [String] = []
    /// Testo libero della ricerca (nome app e/o tag in corso di digitazione).
    @State private var searchText = ""

    /// App filtrate: devono avere tutti i tag-chip e soddisfare il resto della
    /// query (nome e/o `#tag` ancora in digitazione, vedi `SearchQuery`).
    private var filtered: [AppItem] {
        let parsed = SearchQuery.parse(searchText,
                                       knownCanonicalTags: Array(tagStore.displayByCanonical.keys))
        if committedTags.isEmpty && parsed.isEmpty { return model.apps }
        return model.apps.filter { app in
            let appTags = tagStore.canonicalTags(for: app.id)
            for tag in committedTags where !appTags.contains(tag) { return false }
            return parsed.matches(appName: app.name, appTags: appTags)
        }
    }

    /// App filtrate e ordinate secondo le preferenze.
    private var displayedApps: [AppItem] {
        sortApps(filtered)
    }

    var body: some View {
        let visible = displayedApps
        return VStack(spacing: 0) {
            sortBar
                .padding(.horizontal, 24)
                .padding(.top, 14)

            TagSearchBar(committedTags: $committedTags,
                         text: $searchText,
                         displayName: { tagStore.displayByCanonical[$0] ?? $0 },
                         color: settings.theme.color,
                         focusTrigger: model.resetToken,
                         onTab: autocompleteSearchTag,
                         onSubmit: launchFirst)
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 8)

            if model.isLoading && model.apps.isEmpty {
                Spacer()
                ProgressView("Caricamento applicazioni…")
                Spacer()
            } else if visible.isEmpty {
                Spacer()
                Text("Nessuna applicazione trovata")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                PagedGridView(apps: visible)
            }
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .tint(settings.theme.color)
        .onAppear {
            model.visibleAppIDs = visible.map(\.id)
            indexSizesIfNeeded()
        }
        .onChange(of: visible.map(\.id)) { ids in
            model.visibleAppIDs = ids
        }
        .onChange(of: settings.sortField) { _ in indexSizesIfNeeded() }
        .onChange(of: committedTags) { _ in model.currentPage = 0 }
        .onChange(of: searchText) { _ in model.currentPage = 0 }
        .onChange(of: model.resetToken) { _ in
            committedTags = []
            searchText = ""
            model.currentPage = 0
        }
    }

    // MARK: - Completamento tag nella ricerca

    /// Tab: completa il `#tag` in corso (dall'ultimo `#`). Se diventa un tag
    /// esistente (o il match è unico) lo conferma come chip; altrimenti estende
    /// al prefisso comune.
    private func autocompleteSearchTag() {
        guard let hashRange = searchText.range(of: "#", options: .backwards) else { return }
        let afterHash = String(searchText[hashRange.upperBound...])
        let canon = TagStore.canonical(afterHash)
        guard !canon.isEmpty else { return }

        let known = tagStore.displayByCanonical
        let candidates = known.keys.filter { $0.hasPrefix(canon) }

        if known[canon] != nil || candidates.count == 1 {
            let chosen = candidates.count == 1 ? candidates[0] : canon
            if !committedTags.contains(chosen) { committedTags.append(chosen) }
            searchText.removeSubrange(hashRange.lowerBound...)
        } else if candidates.count > 1 {
            let common = longestCommonPrefix(candidates)
            if common.count > canon.count {
                searchText.replaceSubrange(hashRange.upperBound..., with: common)
            }
        }
    }

    private func longestCommonPrefix(_ strings: [String]) -> String {
        guard var prefix = strings.first else { return "" }
        for s in strings.dropFirst() {
            while !s.hasPrefix(prefix) {
                prefix = String(prefix.dropLast())
                if prefix.isEmpty { return "" }
            }
        }
        return prefix
    }

    // MARK: - Barra di ordinamento

    private var sortBar: some View {
        HStack(spacing: 8) {
            Picker("Ordina", selection: $settings.sortField) {
                Text("Nome").tag(SortField.name)
                Text("Dimensione").tag(SortField.size)
                Text("Data").tag(SortField.dateAdded)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)

            Button {
                settings.sortAscending.toggle()
            } label: {
                Image(systemName: settings.sortAscending ? "arrow.up" : "arrow.down")
            }
            .buttonStyle(.borderless)
            .help(settings.sortAscending ? "Ordine crescente" : "Ordine decrescente")

            Spacer(minLength: 0)
        }
    }

    // MARK: - Ordinamento

    private func sortApps(_ apps: [AppItem]) -> [AppItem] {
        let ascending = settings.sortAscending
        switch settings.sortField {
        case .name:
            return apps.sorted { a, b in
                let result = a.name.localizedStandardCompare(b.name)
                return ascending ? result == .orderedAscending : result == .orderedDescending
            }
        case .size:
            return apps.sorted { a, b in
                orderedBefore(model.sizesByID[a.id], model.sizesByID[b.id],
                              ascending: ascending, tieBreak: a.name, b.name)
            }
        case .dateAdded:
            return apps.sorted { a, b in
                orderedBefore(a.dateAdded, b.dateAdded,
                              ascending: ascending, tieBreak: a.name, b.name)
            }
        }
    }

    /// Confronto per valori opzionali: i valori mancanti finiscono in fondo,
    /// con il nome come spareggio.
    private func orderedBefore<T: Comparable>(_ a: T?, _ b: T?,
                                              ascending: Bool,
                                              tieBreak aName: String, _ bName: String) -> Bool {
        if a == b {
            return aName.localizedStandardCompare(bName) == .orderedAscending
        }
        guard let a else { return false }
        guard let b else { return true }
        return ascending ? a < b : a > b
    }

    private func indexSizesIfNeeded() {
        if settings.sortField == .size { model.ensureSizesIndexed() }
    }

    private func launchFirst() {
        if let first = displayedApps.first { model.launch(first) }
    }
}
