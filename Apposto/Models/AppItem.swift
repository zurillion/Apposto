import AppKit

/// Rappresenta una singola applicazione individuata sul disco.
///
/// È una classe (tipo riferimento) così l'`NSImage` dell'icona viene
/// condivisa senza copie. L'identità è data dal bundle identifier (o, in sua
/// assenza, dal percorso del bundle).
final class AppItem: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let bundleIdentifier: String?
    let icon: NSImage

    init(id: String, name: String, url: URL, bundleIdentifier: String?, icon: NSImage) {
        self.id = id
        self.name = name
        self.url = url
        self.bundleIdentifier = bundleIdentifier
        self.icon = icon
    }

    static func == (lhs: AppItem, rhs: AppItem) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
