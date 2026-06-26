import SwiftUI

/// Punto di ingresso dell'app.
///
/// Apposto è un'app "agent" (vedi `LSUIElement` nelle impostazioni del target):
/// non ha icona nel Dock e vive nella barra dei menu. Tutta la logica di
/// avvio è nell'`AppDelegate`; qui esponiamo solo la scena `Settings`, che
/// fornisce la finestra delle Preferenze (apribile con ⌘,).
@main
struct AppostoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
                .environmentObject(appDelegate.settings)
                .environmentObject(appDelegate.model)
        }
    }
}
