import AppKit
import Combine

/// Rappresenta una singola applicazione individuata sul disco.
///
/// È un `ObservableObject` così l'icona — caricata pigramente e in modo
/// asincrono — può aggiornare la cella senza ridisegnare l'intera griglia.
/// L'identità è data dal bundle identifier (o, in sua assenza, dal percorso).
final class AppItem: ObservableObject, Identifiable {
    let id: String
    let name: String
    let url: URL
    let bundleIdentifier: String?

    /// Data in cui l'app è stata aggiunta alla cartella (per l'ordinamento).
    let dateAdded: Date?

    /// Icona dell'app. `nil` finché non viene caricata da `IconLoader`.
    @Published var icon: NSImage?

    init(id: String, name: String, url: URL, bundleIdentifier: String?, dateAdded: Date? = nil, icon: NSImage? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.dateAdded = dateAdded
        self.icon = icon
    }
}
