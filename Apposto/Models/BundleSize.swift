import Foundation

/// Calcola la dimensione su disco di un bundle `.app` sommando i suoi file.
/// È un'operazione costosa (attraversa l'intero bundle), quindi va eseguita in
/// background e i risultati vanno messi in cache (vedi `SizeCache`).
enum BundleSize {
    static func size(at url: URL) -> Int64 {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileAllocatedSizeKey, .isRegularFileKey]
        guard let enumerator = fm.enumerator(at: url,
                                             includingPropertiesForKeys: keys,
                                             options: []) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile == true {
                total += Int64(values?.fileAllocatedSize ?? 0)
            }
        }
        return total
    }
}

/// Cache su disco delle dimensioni dei bundle, invalidata se cambia la data di
/// modifica del bundle (es. dopo un aggiornamento dell'app).
enum SizeCache {
    struct Entry: Codable {
        let bytes: Int64
        let modDate: Double
    }

    private static var fileURL: URL? {
        let fm = FileManager.default
        guard let caches = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        return caches
            .appendingPathComponent("Apposto", isDirectory: true)
            .appendingPathComponent("sizes.json")
    }

    static func load() -> [String: Entry] {
        guard let url = fileURL,
              let data = try? Data(contentsOf: url),
              let dict = try? JSONDecoder().decode([String: Entry].self, from: data) else { return [:] }
        return dict
    }

    static func save(_ dict: [String: Entry]) {
        guard let url = fileURL, let data = try? JSONEncoder().encode(dict) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }
}
