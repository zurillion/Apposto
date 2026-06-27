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

        // --- Diagnostica nomi localizzati (temporanea) ---
        let q: (String?) -> String = { $0.map { "'\($0)'" } ?? "nil" }
        var diag: [String] = []
        var finderDiff = 0, plistDiff = 0, fsDiff = 0, loctableDiff = 0

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
                // Nome MOSTRATO = quello del Finder. `displayName(atPath:)` applica
                // la stessa risoluzione del Finder (confronta CFBundleDisplayName
                // col nome del file e usa la localizzazione del bundle) e torna il
                // nome localizzato, es. "Utility Disco". NB: `.localizedNameKey`
                // NON fa questa risoluzione e torna il nome del file (inglese), e
                // `localizedInfoDictionary` non legge il formato InfoPlist.loctable
                // usato dalle app di sistema: per questo serve `displayName`.
                let finderName = clean(fm.displayName(atPath: url.path))
                let fsName = clean(values?.localizedName)
                let localizedPlist = clean(bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String)
                                 ?? clean(bundle?.localizedInfoDictionary?["CFBundleName"] as? String)
                // Nome dal file InfoPlist.loctable (formato consolidato usato dalle
                // app di sistema, NON letto da localizedInfoDictionary).
                let loctable = clean(loctableName(url))
                // Nome base NON localizzato dell'Info.plist (l'inglese "vero").
                let baseName = clean(bundle?.infoDictionary?["CFBundleDisplayName"] as? String)
                           ?? clean(bundle?.infoDictionary?["CFBundleName"] as? String)

                let name = loctable ?? localizedPlist ?? finderName ?? fsName ?? fileName

                // Alias per la ricerca: gli altri nomi (in particolare l'inglese,
                // cioè il nome del file e i valori base dell'Info.plist), unici e
                // diversi dal mostrato. Così "Utility Disco" si trova anche con
                // "Disk Utility" e viceversa.
                var aliases: [String] = []
                let candidates: [String?] = [fileName, baseName, fsName, localizedPlist, finderName, loctable]
                for case let cand? in candidates {
                    guard cand.localizedCaseInsensitiveCompare(name) != .orderedSame,
                          !aliases.contains(where: { $0.localizedCaseInsensitiveCompare(cand) == .orderedSame })
                    else { continue }
                    aliases.append(cand)
                }

                // --- Diagnostica: quali fonti danno un nome diverso dall'inglese? ---
                let finderLoc = finderName.map { $0.localizedCaseInsensitiveCompare(fileName) != .orderedSame } ?? false
                let plistLoc = localizedPlist.map { $0.localizedCaseInsensitiveCompare(fileName) != .orderedSame } ?? false
                let fsLoc = fsName.map { $0.localizedCaseInsensitiveCompare(fileName) != .orderedSame } ?? false
                let loctableLoc = loctable.map { $0.localizedCaseInsensitiveCompare(fileName) != .orderedSame } ?? false
                if finderLoc { finderDiff += 1 }
                if plistLoc { plistDiff += 1 }
                if fsLoc { fsDiff += 1 }
                if loctableLoc { loctableDiff += 1 }
                if finderLoc || plistLoc || fsLoc || loctableLoc {
                    diag.append("[Apposto] file=\(q(fileName)) loctable=\(q(loctable)) finder=\(q(finderName)) plist=\(q(localizedPlist)) base=\(q(baseName))")
                }
                // Sonda mirata su alcune app di sistema note per essere localizzate:
                // mostra se il loctable esiste e quali lingue contiene.
                if ["Disk Utility", "Dictionary", "Calculator", "Reminders",
                    "Maps", "Notes", "System Settings", "Console"].contains(fileName) {
                    print("[Apposto][probe] \(q(fileName)) loctable=\(q(loctable)) \(loctableInfo(url)) lproj=\(lprojList(url))")
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

        // --- Riepilogo diagnostica nomi localizzati (temporanea) ---
        print("[Apposto] SCAN nomi: totale=\(items.count)  loctable!=file=\(loctableDiff)  displayName!=file=\(finderDiff)  localizedInfoDictionary!=file=\(plistDiff)  localizedNameKey!=file=\(fsDiff)")
        for line in diag.prefix(80) { print(line) }
        if diag.count > 80 { print("[Apposto] ...e altre \(diag.count - 80) app con nome localizzato") }

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

    /// Carica un plist (binario, XML o vecchio formato `.strings`) come dizionario.
    private static func loadPlistDict(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else { return nil }
        return plist as? [String: Any]
    }

    /// Estrae il nome (display o bundle) da una tabella di localizzazione.
    private static func nameIn(_ table: [String: Any]) -> String? {
        guard let n = (table["CFBundleDisplayName"] as? String) ?? (table["CFBundleName"] as? String),
              !n.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return n
    }

    /// Nome localizzato dell'app letto dai file di localizzazione del bundle che
    /// le API standard non leggono: il `InfoPlist.loctable` consolidato (formato
    /// usato dalle app di sistema) e, in fallback, i `*.lproj/InfoPlist.loctable`
    /// o `InfoPlist.strings` per lingua. Sceglie la lingua migliore secondo le
    /// preferenze dell'utente.
    private static func loctableName(_ bundleURL: URL) -> String? {
        let res = bundleURL.appendingPathComponent("Contents/Resources")
        let prefs = Locale.preferredLanguages

        // 1) loctable consolidato: { lingua: { chiave: valore } }
        if let byLang = loadPlistDict(res.appendingPathComponent("InfoPlist.loctable")) {
            let available = byLang.keys.filter { $0 != "LocProvenance" }
            for lang in Bundle.preferredLocalizations(from: Array(available), forPreferences: prefs) {
                if let table = byLang[lang] as? [String: Any], let n = nameIn(table) { return n }
            }
        }

        // 2) per-lingua: <lang>.lproj/InfoPlist.(loctable|strings)
        let items = (try? FileManager.default.contentsOfDirectory(atPath: res.path)) ?? []
        let langDirs = items.filter { $0.hasSuffix(".lproj") }.map { String($0.dropLast(6)) }
        for lang in Bundle.preferredLocalizations(from: langDirs, forPreferences: prefs) {
            let dir = res.appendingPathComponent("\(lang).lproj")
            for file in ["InfoPlist.loctable", "InfoPlist.strings"] {
                guard let dict = loadPlistDict(dir.appendingPathComponent(file)) else { continue }
                if let n = nameIn(dict) { return n }                       // formato flat
                if let inner = dict[lang] as? [String: Any], let n = nameIn(inner) { return n } // lingua-chiave
            }
        }
        return nil
    }

    // --- Helper diagnostici (temporanei) ---

    private static func loctableInfo(_ bundleURL: URL) -> String {
        let res = bundleURL.appendingPathComponent("Contents/Resources")
        if let byLang = loadPlistDict(res.appendingPathComponent("InfoPlist.loctable")) {
            return "loctable_langs=[\(byLang.keys.sorted().joined(separator: ","))]"
        }
        return "loctable=ASSENTE"
    }

    private static func lprojList(_ bundleURL: URL) -> String {
        let res = bundleURL.appendingPathComponent("Contents/Resources").path
        let items = (try? FileManager.default.contentsOfDirectory(atPath: res)) ?? []
        let lprojs = items.filter { $0.hasSuffix(".lproj") }.sorted()
        return "[\(lprojs.prefix(25).joined(separator: ","))]"
    }
}
