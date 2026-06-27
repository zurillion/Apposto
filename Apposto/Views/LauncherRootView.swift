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
        .background(themedBackground.ignoresSafeArea())
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

    // MARK: - Sfondo a tema

    /// Vibrancy del pannello con sopra un velo del colore del tema, così l'intera
    /// finestra assume la tinta scelta.
    private var themedBackground: some View {
        ZStack {
            VisualEffectBackground()
            LinearGradient(
                colors: [settings.theme.color.opacity(0.30),
                         settings.theme.color.opacity(0.12)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Barra di ordinamento

    /// Controllo segmentato: il campo attivo mostra la freccia di direzione e,
    /// ricliccandolo, inverte l'ordine.
    private var sortBar: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(SortField.allCases, id: \.self) { field in
                    sortSegment(field)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.08)))
            .frame(maxWidth: 360)

            Spacer(minLength: 0)
        }
    }

    private func sortSegment(_ field: SortField) -> some View {
        let isActive = settings.sortField == field
        return Button {
            if isActive {
                settings.sortAscending.toggle()
            } else {
                settings.sortField = field
            }
        } label: {
            HStack(spacing: 4) {
                Text(field.title)
                    .font(.system(size: 12, weight: .medium))
                if isActive {
                    Image(systemName: settings.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isActive ? settings.theme.color : Color.clear)
            )
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .contentShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .help(isActive
              ? (settings.sortAscending ? "Crescente — clicca per invertire" : "Decrescente — clicca per invertire")
              : "Ordina per \(field.title.lowercased())")
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
