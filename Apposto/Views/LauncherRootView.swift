import SwiftUI

/// Vista radice del pannello: barra di ricerca in alto e griglia paginata.
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

    var body: some View {
        VStack(spacing: 0) {
            SearchBar(text: $query, focused: $searchFocused, onSubmit: launchFirst)
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 8)

            if model.isLoading && model.apps.isEmpty {
                Spacer()
                ProgressView("Caricamento applicazioni…")
                Spacer()
            } else if filtered.isEmpty {
                Spacer()
                Text("Nessuna applicazione trovata")
                    .foregroundStyle(.secondary)
                Spacer()
            } else {
                PagedGridView(apps: filtered)
            }
        }
        .background(VisualEffectBackground().ignoresSafeArea())
        .onAppear { focusSearch() }
        .onChange(of: query) { _ in model.currentPage = 0 }
        .onChange(of: model.resetToken) { _ in
            query = ""
            model.currentPage = 0
            focusSearch()
        }
    }

    private func focusSearch() {
        // Leggero rinvio: il focus attecchisce dopo che il pannello è key.
        DispatchQueue.main.async { searchFocused = true }
    }

    private func launchFirst() {
        if let first = filtered.first { model.launch(first) }
    }
}
