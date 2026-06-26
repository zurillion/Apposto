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
    }
}
