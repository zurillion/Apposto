import AppKit

/// Scopre le applicazioni installate scandendo le cartelle standard.
///
/// Come Launchpad, la ricerca è ricorsiva nelle sottocartelle (es.
/// `/Applications/Utilities`), ma i bundle `.app` sono trattati come foglie:
/// l'opzione `.skipsPackageDescendants` evita di entrare dentro i bundle.
///
/// La scansione produce solo i **metadati** (nome, percorso, bundle id): le
/// icone, che sono la parte costosa, vengono caricate a parte e pigramente da
/// `IconLoader`, così la lista è pronta in fretta e l'app resta reattiva.
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

    /// Esegue la scansione (pensata per girare in background) e restituisce gli
    /// `AppItem` ordinati per nome, senza icone.
    static func scanMetadata() -> [AppItem] {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [
            .isApplicationKey, .localizedNameKey, .isDirectoryKey,
            .addedToDirectoryDateKey, .creationDateKey,
        ]
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

                let fileName = url.deletingPathExtension().lastPathComponent
                // Nome localizzato dell'app (come Finder/Dock/Launchpad): viene
                // dal CFBundleDisplayName/CFBundleName *localizzato* in
                // InfoPlist.strings, NON dal nome del file. `.localizedNameKey` e
                // `displayName(atPath:)` restituiscono solo il nome del file con
                // l'estensione nascosta, quindi qui non bastano.
                let localized = clean(bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                            ?? clean(bundle?.localizedInfoDictionary?["CFBundleName"] as? String)
                // Nome dal file system (estensione nascosta): di norma l'inglese.
                let fsName = clean(values?.localizedName) ?? clean(fm.displayName(atPath: url.path))
                // Nome base NON localizzato dell'Info.plist (l'inglese "vero").
                let baseName = clean(bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                           ?? clean(bundle?.infoDictionary?["CFBundleName"] as? String)

                // Mostrato: prima il nome localizzato dell'app, poi il file system.
                let name = localized ?? fsName ?? fileName

                // Alias per la ricerca: gli altri nomi (originale/inglese), unici
                // e diversi dal mostrato. Così "Utility Disco" si trova anche con
                // "Disk Utility" e viceversa.
                var aliases: [String] = []
                let candidates: [String?] = [fsName, baseName, fileName, localized]
                for case let cand? in candidates {
                    guard cand.localizedCaseInsensitiveCompare(name) != .orderedSame,
                          !aliases.contains(where: { $0.localizedCaseInsensitiveCompare(cand) == .orderedSame })
                    else { continue }
                    aliases.append(cand)
                }

                // "Data di aggiunta" come in Finder; fallback alla creazione.
                let dateAdded = values?.addedToDirectoryDate ?? values?.creationDate

                items.append(AppItem(id: dedupKey,
                                     name: name,
                                     url: url,
                                     bundleIdentifier: bundleID,
                                     aliases: aliases,
                                     dateAdded: dateAdded))
            }
        }

        return items.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    /// Normalizza un nome candidato: trim, rimozione dell'eventuale suffisso
    /// `.app`, `nil` se vuoto.
    private static func clean(_ s: String?) -> String? {
        guard var t = s?.trimmingCharacters(in: .whitespacesAndNewlines), !t.isEmpty else { return nil }
        if t.hasSuffix(".app") { t = String(t.dropLast(4)) }
        return t.isEmpty ? nil : t
    }
}
