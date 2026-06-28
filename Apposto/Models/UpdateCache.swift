import Foundation

/// Cache su disco degli esiti del controllo aggiornamenti (appID → record),
/// così non si ricontattano i server a ogni avvio.
enum UpdateCache {
    static func load() -> [String: UpdateRecord] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: UpdateRecord].self, from: data) else {
            return [:]
        }
        return dict
    }

    static func save(_ records: [String: UpdateRecord]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(records) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches
            .appendingPathComponent("Apposto", isDirectory: true)
            .appendingPathComponent("updates.json")
    }
}
