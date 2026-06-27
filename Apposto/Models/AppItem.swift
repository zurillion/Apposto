import AppKit
import Combine

/// Rappresenta una singola applicazione individuata sul disco.
///
/// È un `ObservableObject` così l'icona — caricata pigramente e in modo
/// asincrono — può aggiornare la cella senza ridisegnare l'intera griglia.
/// L'identità è data dal bundle identifier (o, in sua assenza, dal percorso).
final class AppItem: ObservableObject, Identifiable {
    let id: String
    /// Nome mostrato: quello **localizzato** (come nel Finder).
    let name: String
    let url: URL
    let bundleIdentifier: String?

    /// Nomi alternativi su cui cercare oltre a `name` — tipicamente il nome
    /// originale/inglese del bundle (es. "Calculator" per "Calcolatrice").
    /// Non vengono mai mostrati.
    let aliases: [String]

    /// Data in cui l'app è stata aggiunta alla cartella (per l'ordinamento).
    let dateAdded: Date?

    /// Tutti i nomi su cui può avvenire una corrispondenza in ricerca: il nome
    /// localizzato più gli alias.
    var searchNames: [String] { [name] + aliases }

    /// Icona dell'app. `nil` finché non viene caricata da `IconLoader`.
    @Published var icon: NSImage?

    init(id: String, name: String, url: URL, bundleIdentifier: String?,
         aliases: [String] = [], dateAdded: Date? = nil, icon: NSImage? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.aliases = aliases
        self.dateAdded = dateAdded
        self.icon = icon
    }
}
