import AppKit
import Combine

/// Architettura dell'eseguibile dell'app.
enum AppArchitecture: String, Codable {
    case universal      // arm64 + Intel
    case appleSilicon   // solo arm64
    case intel          // solo x86_64/i386
    case unknown        // non determinabile

    var label: String {
        switch self {
        case .universal: return "Universal"
        case .appleSilicon: return "Apple Silicon"
        case .intel: return "Intel"
        case .unknown: return "—"
        }
    }

    /// Ordine per l'ordinamento (nativo prima, sconosciuto in fondo).
    var sortRank: Int {
        switch self {
        case .appleSilicon: return 0
        case .universal: return 1
        case .intel: return 2
        case .unknown: return 3
        }
    }
}

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

    /// Nome "originale" (non localizzato) da mostrare opzionalmente sotto al
    /// nome localizzato. `nil` se coincide col nome mostrato.
    let originalName: String?

    /// Architettura dell'eseguibile (Universal / Apple Silicon / Intel).
    let architecture: AppArchitecture

    /// `true` se l'app è solo-Intel (gira via Rosetta su Apple Silicon).
    var isIntelOnly: Bool { architecture == .intel }

    /// Versione dell'app (`CFBundleShortVersionString`), da mostrare opzionalmente.
    let version: String?

    /// Data in cui l'app è stata aggiunta alla cartella (per l'ordinamento).
    let dateAdded: Date?

    /// Tutti i nomi su cui può avvenire una corrispondenza in ricerca: il nome
    /// localizzato più gli alias.
    var searchNames: [String] { [name] + aliases }

    /// Icona dell'app. `nil` finché non viene caricata da `IconLoader`.
    @Published var icon: NSImage?

    init(id: String, name: String, url: URL, bundleIdentifier: String?,
         aliases: [String] = [], originalName: String? = nil,
         architecture: AppArchitecture = .unknown, version: String? = nil,
         dateAdded: Date? = nil, icon: NSImage? = nil) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.aliases = aliases
        self.originalName = originalName
        self.architecture = architecture
        self.version = version
        self.dateAdded = dateAdded
        self.icon = icon
    }
}
