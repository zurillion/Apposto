import AppKit
import Combine

/// Sorgente di verità condivisa per la UI: elenco delle app, pagina corrente,
/// stato di caricamento. Espone le azioni di ricarica e avvio.
final class AppModel: ObservableObject {
    @Published private(set) var apps: [AppItem] = []
    @Published private(set) var isLoading = false

    /// Pagina visualizzata. Aggiornata da swipe, drag e pallini.
    @Published var currentPage = 0

    /// Incrementato a ogni apertura del pannello per resettare ricerca/focus.
    @Published var resetToken = 0

    /// Numero di pagine corrente, comunicato dalla griglia per consentire il
    /// clamp di `currentPage` durante gli swipe.
    var pageCount = 1

    /// Chiusura invocata quando il launcher deve nascondersi (es. dopo l'avvio
    /// di un'app). Impostata dall'`AppDelegate`.
    var onRequestClose: (() -> Void)?

    // MARK: - Selezione multipla e editor dei tag

    /// App selezionate (con Shift/⌘ + clic) per l'assegnazione in blocco dei tag.
    @Published var selectedAppIDs: Set<String> = []

    /// App attualmente visibili, nell'ordine mostrato (serve alla selezione a
    /// intervallo con Shift). Aggiornato dalla vista radice.
    var visibleAppIDs: [String] = []

    /// Ancora della selezione: la prima app selezionata, da cui parte il range.
    private var selectionAnchorID: String?

    /// `id` della cella su cui è ancorato il popover dei tag (nil = chiuso).
    @Published var tagEditorAnchorID: String?

    /// App a cui si applicano le modifiche dei tag nell'editor aperto.
    @Published var tagEditorTargetIDs: [String] = []

    var isTagEditorOpen: Bool { tagEditorAnchorID != nil }

    /// ⌘ + clic: aggiunge o toglie la singola app dalla selezione.
    func commandSelect(_ id: String) {
        if selectedAppIDs.isEmpty { selectionAnchorID = id }
        if selectedAppIDs.contains(id) {
            selectedAppIDs.remove(id)
        } else {
            selectedAppIDs.insert(id)
        }
        if selectedAppIDs.isEmpty { selectionAnchorID = nil }
    }

    /// Shift + clic: seleziona tutte le app dall'ancora fino a quella cliccata
    /// (nell'ordine visibile), aggiungendole alla selezione esistente.
    func shiftSelect(_ id: String) {
        guard let anchor = selectionAnchorID,
              let from = visibleAppIDs.firstIndex(of: anchor),
              let to = visibleAppIDs.firstIndex(of: id) else {
            // Nessuna ancora: comportati come una singola selezione.
            if selectedAppIDs.isEmpty { selectionAnchorID = id }
            selectedAppIDs.insert(id)
            return
        }
        for visibleID in visibleAppIDs[min(from, to)...max(from, to)] {
            selectedAppIDs.insert(visibleID)
        }
    }

    func clearSelection() {
        selectedAppIDs.removeAll()
        selectionAnchorID = nil
    }

    /// Apre l'editor dei tag: se l'app fa parte di una selezione, agisce su
    /// tutte le app selezionate, altrimenti solo su quella.
    func openTagEditor(anchor app: AppItem) {
        if !selectedAppIDs.isEmpty, selectedAppIDs.contains(app.id) {
            tagEditorTargetIDs = Array(selectedAppIDs)
        } else {
            tagEditorTargetIDs = [app.id]
        }
        tagEditorAnchorID = app.id
    }

    func closeTagEditor() {
        tagEditorAnchorID = nil
        tagEditorTargetIDs = []
    }

    /// Caricamento iniziale: mostra subito le app dalla cache (se presente) e
    /// avvia in background una scansione aggiornata.
    func loadInitial() {
        let cached = AppCache.load()
        if !cached.isEmpty {
            apps = cached
        }
        reload()
    }

    /// Ri-scansiona le app in background e aggiorna la lista + la cache,
    /// senza bloccare l'interfaccia.
    func reload() {
        if apps.isEmpty { isLoading = true }
        DispatchQueue.global(qos: .userInitiated).async {
            let items = AppScanner.scanMetadata()
            AppCache.save(items)
            DispatchQueue.main.async {
                self.apply(items)
                self.isLoading = false
            }
        }
    }

    /// Sostituisce la lista conservando le icone già caricate (per stesso id),
    /// così l'aggiornamento in background non provoca sfarfallii.
    private func apply(_ items: [AppItem]) {
        let existingIcons = Dictionary(
            apps.compactMap { item -> (String, NSImage)? in
                guard let icon = item.icon else { return nil }
                return (item.id, icon)
            },
            uniquingKeysWith: { current, _ in current }
        )
        for item in items where item.icon == nil {
            item.icon = existingIcons[item.id]
        }
        apps = items
    }

    func launch(_ app: AppItem) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: app.url, configuration: config, completionHandler: nil)
        onRequestClose?()
    }

    func stepPage(_ direction: Int) {
        let upper = max(pageCount - 1, 0)
        currentPage = min(max(currentPage + direction, 0), upper)
    }

    func prepareForShow() {
        currentPage = 0
        resetToken &+= 1
        clearSelection()
        closeTagEditor()
    }
}
