import AppKit

/// Carica le icone delle app in modo asincrono, con cache in memoria.
///
/// L'estrazione dell'icona (`NSWorkspace.icon(forFile:)`) è la parte costosa
/// dello scoprire le app: farla pigramente, fuori dal thread principale e una
/// cella alla volta evita che l'interfaccia si blocchi (niente "beachball").
final class IconLoader {
    static let shared = IconLoader()

    private let queue = DispatchQueue(label: "com.apposto.iconloader", qos: .userInitiated)
    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 1000
    }

    /// Restituisce l'icona per il file indicato. La `completion` è sempre
    /// invocata sul thread principale.
    func icon(for url: URL, completion: @escaping (NSImage) -> Void) {
        let key = url.path as NSString
        if let cached = cache.object(forKey: key) {
            completion(cached)
            return
        }
        queue.async { [weak self] in
            let image = NSWorkspace.shared.icon(forFile: url.path)
            self?.cache.setObject(image, forKey: key)
            DispatchQueue.main.async { completion(image) }
        }
    }
}
