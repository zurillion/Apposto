import SwiftUI

/// Vista radice del pannello: barra di ordinamento, ricerca e griglia paginata.
struct LauncherRootView: View {
    @EnvironmentObject var model: AppModel
    @EnvironmentObject var settings: LauncherSettings
    @EnvironmentObject var tagStore: TagStore

    @State private var query = ""
    @FocusState private var searchFocused: Bool

    /// App filtrate dal testo di ricerca: testo libero sul nome e/o filtri per
    /// tag scritti come `#tag` (vedi `SearchQuery`).
    private var filtered: [AppItem] {
        let raw = query.trimmingCharacters(in: .whitespaces)
        guard !raw.isEmpty else { return model.apps }
        let parsed = SearchQuery.parse(query, knownCanonicalTags: Array(tagStore.displayByCanonical.keys))
        guard !parsed.isEmpty else { return model.apps }
        return model.apps.filter {
            parsed.matches(appName: $0.name, appTags: tagStore.canonicalTags(for: $0.id))
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

            SearchBar(text: $query, focused: $searchFocused, onSubmit: launchFirst)
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
            focusSearch()
        }
        .onChange(of: visible.map(\.id)) { ids in
            model.visibleAppIDs = ids
        }
        .onChange(of: settings.sortField) { _ in indexSizesIfNeeded() }
        .onChange(of: query) { _ in model.currentPage = 0 }
        .onChange(of: model.resetToken) { _ in
            query = ""
            model.currentPage = 0
            focusSearch()
        }
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
        guard let a else { return false } // a mancante → dopo
        guard let b else { return true }  // b mancante → a prima
        return ascending ? a < b : a > b
    }

    private func indexSizesIfNeeded() {
        if settings.sortField == .size { model.ensureSizesIndexed() }
    }

    private func focusSearch() {
        // Leggero rinvio: il focus attecchisce dopo che il pannello è key.
        DispatchQueue.main.async { searchFocused = true }
    }

    private func launchFirst() {
        if let first = displayedApps.first { model.launch(first) }
    }
}
