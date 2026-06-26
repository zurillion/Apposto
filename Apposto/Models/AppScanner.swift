import AppKit

/// Scopre le applicazioni installate scandendo le cartelle standard.
///
/// Come Launchpad, la ricerca è ricorsiva nelle sottocartelle (es.
/// `/Applications/Utilities`), ma i bundle `.app` sono trattati come foglie:
/// l'opzione `.skipsPackageDescendants` evita di entrare dentro i bundle.
enum AppScanner {

    /// Cartelle in cui cercare. L'ordine determina quale copia "vince" in caso
    /// di duplicati (stesso bundle identifier in più percorsi).
    static var searchRoots: [URL] {
        let fm = FileManager.default
        var roots: [URL] = [
            URL(fileURLWithPath: "/Applications"),
            URL(fileURLWithPath: "/System/Applications"),
            URL(fileURLWithPath: "/System/Library/CoreServices/Applications"),
        ]
        // ~/Applications (es. PWA di Chrome, app installate per il solo utente).
        if let userApps = fm.urls(for: .applicationDirectory, in: .userDomainMask).first {
            roots.append(userApps)
        }
        return roots
    }

    static func scan() -> [AppItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.isApplicationKey, .localizedNameKey, .isDirectoryKey]
        let keySet = Set(keys)

        var seen = Set<String>()
        var items: [AppItem] = []

        for root in searchRoots {
            guard fm.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fm.enumerator(
                at: root,
                includingPropertiesForKeys: keys,
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                guard url.pathExtension == "app" else { continue }

                let values = try? url.resourceValues(forKeys: keySet)
                // Se il sistema sa dirci che è un'applicazione lo rispettiamo,
                // altrimenti ci fidiamo dell'estensione .app.
                if let isApp = values?.isApplication, isApp == false { continue }

                let bundle = Bundle(url: url)
                let bundleID = bundle?.bundleIdentifier
                let dedupKey = bundleID ?? url.path
                guard !seen.contains(dedupKey) else { continue }
                seen.insert(dedupKey)

                let rawName = values?.localizedName ?? fm.displayName(atPath: url.path)
                let name = rawName.hasSuffix(".app") ? String(rawName.dropLast(4)) : rawName

                let icon = NSWorkspace.shared.icon(forFile: url.path)
                items.append(AppItem(id: dedupKey,
                                     name: name,
                                     url: url,
                                     bundleIdentifier: bundleID,
                                     icon: icon))
            }
        }

        return items.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}
