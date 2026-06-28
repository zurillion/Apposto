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
    /// Colonna laterale a scomparsa con l'elenco dei tag.
    @State private var showTagSidebar = false

    /// App filtrate: devono avere tutti i tag-chip e soddisfare il resto della
    /// query (nome e/o `#tag` ancora in digitazione, vedi `SearchQuery`).
    private var filtered: [AppItem] {
        let parsed = SearchQuery.parse(searchText,
                                       knownCanonicalTags: Array(tagStore.displayByCanonical.keys))
        // I chip "senza tag", "Intel" e "update" sono token sentinella: li
        // trattiamo a parte dai tag reali.
        let chipUntagged = committedTags.contains(SearchQuery.untaggedToken)
        let chipIntel = committedTags.contains(SearchQuery.intelToken)
        let chipUpdate = committedTags.contains(SearchQuery.updateToken)
        let realTags = committedTags.filter {
            $0 != SearchQuery.untaggedToken && $0 != SearchQuery.intelToken
                && $0 != SearchQuery.updateToken
        }
        if realTags.isEmpty && !chipUntagged && !chipIntel && !chipUpdate && parsed.isEmpty {
            return model.apps
        }
        return model.apps.filter { app in
            let appTags = tagStore.canonicalTags(for: app.id)
            let hasUpdate = model.updatesByID[app.id] != nil
            if chipUntagged && !appTags.isEmpty { return false }
            if chipIntel && !app.isIntelOnly { return false }
            if chipUpdate && !hasUpdate { return false }
            for tag in realTags where !appTags.contains(tag) { return false }
            return parsed.matches(appNames: app.searchNames, appTags: appTags,
                                  isIntelOnly: app.isIntelOnly, hasUpdate: hasUpdate)
        }
    }

    /// App filtrate e ordinate secondo le preferenze.
    private var displayedApps: [AppItem] {
        sortApps(filtered)
    }

    var body: some View {
        let visible = displayedApps
        return HStack(spacing: 0) {
            if showTagSidebar {
                tagSidebar
                    .transition(.move(edge: .leading).combined(with: .opacity))
                Divider()
            }
            mainColumn(visible)
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
            // Uscendo e rientrando nel launcher la colonna torna nascosta.
            showTagSidebar = false
        }
    }

    /// Colonna principale: barra di ordinamento, ricerca e griglia.
    private func mainColumn(_ visible: [AppItem]) -> some View {
        VStack(spacing: 0) {
            sortBar(count: visible.count)
                .padding(.horizontal, 24)
                .padding(.top, 14)

            TagSearchBar(committedTags: $committedTags,
                         text: $searchText,
                         displayName: { canon in
                             switch canon {
                             case SearchQuery.untaggedToken: return "Untagged"
                             case SearchQuery.intelToken: return "Intel"
                             case SearchQuery.updateToken: return "Update"
                             default: return tagStore.displayByCanonical[canon] ?? canon
                             }
                         },
                         chipColor: { canon in
                             switch canon {
                             case SearchQuery.untaggedToken: return .orange
                             case SearchQuery.intelToken: return .indigo
                             case SearchQuery.updateToken: return .teal
                             default: return settings.theme.color
                             }
                         },
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
        // Tag virtuali (parola-chiave → token sentinella del chip).
        let specials = SearchQuery.untaggedKeywords.map { ($0, SearchQuery.untaggedToken) }
                     + SearchQuery.intelKeywords.map { ($0, SearchQuery.intelToken) }
                     + SearchQuery.updateKeywords.map { ($0, SearchQuery.updateToken) }
        let tagMatches = known.keys.filter { $0.hasPrefix(canon) }
        let specialMatches = specials.filter { $0.0.hasPrefix(canon) }

        // Tag virtuale: diventa un chip (token sentinella), come i tag reali, e
        // il testo `#…` viene rimosso.
        if let exact = specials.first(where: { $0.0 == canon })
            ?? (specialMatches.count == 1 && tagMatches.isEmpty ? specialMatches[0] : nil) {
            if !committedTags.contains(exact.1) { committedTags.append(exact.1) }
            searchText.removeSubrange(hashRange.lowerBound...)
            return
        }

        // Tag reale esistente o match unico → diventa chip.
        if known[canon] != nil || (tagMatches.count == 1 && specialMatches.isEmpty) {
            let chosen = tagMatches.count == 1 ? tagMatches[0] : canon
            if !committedTags.contains(chosen) { committedTags.append(chosen) }
            searchText.removeSubrange(hashRange.lowerBound...)
            return
        }

        // Ambiguo: estendi al prefisso comune di tutti i candidati.
        let all = Array(tagMatches) + specialMatches.map { $0.0 }
        if all.count > 1 {
            let common = longestCommonPrefix(all)
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

    // MARK: - Colonna laterale dei tag

    private var tagSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Tag")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { showTagSidebar = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Nascondi i tag")
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    let tags = tagStore.allTags
                    if tags.isEmpty {
                        Text("Nessun tag")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                    } else {
                        ForEach(tags, id: \.self) { tag in
                            tagRow(tag)
                        }
                    }

                    Divider().padding(.vertical, 4)
                    specialRow(title: "Untagged", systemImage: "tag.slash",
                               color: .orange, token: SearchQuery.untaggedToken)
                    specialRow(title: "Intel", systemImage: "cpu",
                               color: .indigo, token: SearchQuery.intelToken)
                    if settings.checkForUpdates {
                        specialRow(title: "Update", systemImage: "arrow.up.circle.fill",
                                   color: .teal, token: SearchQuery.updateToken)
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 10)
            }
        }
        .frame(width: 210)
        .background(Color.primary.opacity(0.05))
    }

    private func tagRow(_ tag: String) -> some View {
        let isActive = committedTags == [TagStore.canonical(tag)]
        return Button {
            selectOnlyTag(tag)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(settings.theme.color)
                    .frame(width: 7, height: 7)
                Text(tag)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? settings.theme.color.opacity(0.20) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    /// Imposta la ricerca sul solo tag scelto (un unico chip, nessun testo).
    private func selectOnlyTag(_ displayTag: String) {
        committedTags = [TagStore.canonical(displayTag)]
        searchText = ""
    }

    /// Voce speciale in fondo all'elenco (tag virtuale): imposta la ricerca sul
    /// solo chip-token indicato.
    private func specialRow(title: String, systemImage: String,
                            color: Color, token: String) -> some View {
        let active = committedTags == [token]
        return Button {
            committedTags = [token]
            searchText = ""
        } label: {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(active ? color.opacity(0.20) : Color.clear)
            )
            .contentShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
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

    /// Controllo segmentato (il campo attivo mostra la freccia di direzione e,
    /// ricliccandolo, inverte l'ordine) e, a destra, il numero di app mostrate.
    private func sortBar(count: Int) -> some View {
        HStack(spacing: 12) {
            sidebarToggle

            HStack(spacing: 4) {
                ForEach(SortField.allCases, id: \.self) { field in
                    sortSegment(field)
                }
            }
            .padding(3)
            .background(RoundedRectangle(cornerRadius: 9).fill(Color.primary.opacity(0.08)))
            .frame(maxWidth: 360)

            Spacer(minLength: 0)

            Text("\(count) app")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    /// Pulsante che mostra/nasconde la colonna laterale dei tag.
    private var sidebarToggle: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.22)) { showTagSidebar.toggle() }
        } label: {
            Image(systemName: "sidebar.left")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(showTagSidebar ? settings.theme.color : Color.primary)
                .frame(width: 26, height: 26)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(showTagSidebar ? "Nascondi i tag" : "Mostra i tag")
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
