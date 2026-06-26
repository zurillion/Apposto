import Foundation

/// Cache su disco dei metadati delle app (solo nome/percorso/bundle id, niente
/// icone). Permette di mostrare la lista istantaneamente all'avvio mentre, in
/// background, una nuova scansione la aggiorna.
enum AppCache {
    private struct Entry: Codable {
        let id: String
        let name: String
        let path: String
        let bundleIdentifier: String?
    }

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches
            .appendingPathComponent("Apposto", isDirectory: true)
            .appendingPathComponent("apps.json")
    }

    static func load() -> [AppItem] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else { return [] }
        return entries.map {
            AppItem(id: $0.id,
                    name: $0.name,
                    url: URL(fileURLWithPath: $0.path),
                    bundleIdentifier: $0.bundleIdentifier)
        }
    }

    static func save(_ apps: [AppItem]) {
        guard let url = fileURL else { return }
        let entries = apps.map {
            Entry(id: $0.id, name: $0.name, path: $0.url.path, bundleIdentifier: $0.bundleIdentifier)
        }
        guard let data = try? JSONEncoder().encode(entries) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
