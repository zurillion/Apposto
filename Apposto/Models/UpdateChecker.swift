import Foundation

/// Esito (persistito in cache) del controllo aggiornamenti per un'app.
struct UpdateRecord: Codable {
    var latestVersion: String?    // ultima versione disponibile (nil se non determinata)
    var source: String?           // "Sparkle" o "App Store"
    var pageURL: String?          // dove aggiornare
    var installedAtCheck: String? // versione installata al momento del check
    var checkedAt: Double         // epoch del check
}

/// Informazione "aggiornamento disponibile" usata dalla UI per il badge.
struct UpdateInfo {
    let latestVersion: String
    let source: String
    let url: String?
}

/// Controlla la disponibilità di aggiornamenti per un'app tramite il suo feed
/// Sparkle (`SUFeedURL` nell'Info.plist) o, per le app del Mac App Store, l'API
/// pubblica di lookup di iTunes. (MacUpdate non offre un'API utilizzabile.)
enum UpdateChecker {

    /// `true` se `latest` è una versione successiva a `installed`.
    static func isNewer(_ latest: String, than installed: String) -> Bool {
        installed.compare(latest, options: .numeric) == .orderedAscending
    }

    /// Controlla una singola app (identificata da valori semplici, così è sicura
    /// da usare in task concorrenti). Restituisce un record con la versione più
    /// recente trovata (o `latestVersion == nil` se non determinabile).
    static func check(url: URL, bundleID: String?, installed: String?) async -> UpdateRecord {
        let now = Date().timeIntervalSince1970
        let bundle = Bundle(url: url)

        // 1) Sparkle: feed dichiarato nell'Info.plist.
        if let feedString = bundle?.infoDictionary?["SUFeedURL"] as? String,
           let feed = URL(string: feedString),
           let v = await sparkleLatestVersion(feed) {
            return UpdateRecord(latestVersion: v, source: "Sparkle",
                                pageURL: feed.absoluteString,
                                installedAtCheck: installed, checkedAt: now)
        }

        // 2) Mac App Store: solo se l'app proviene dallo store (ha la ricevuta).
        let receipt = url.appendingPathComponent("Contents/_MASReceipt/receipt")
        if FileManager.default.fileExists(atPath: receipt.path),
           let bundleID, let res = await appStoreLatest(bundleID: bundleID) {
            return UpdateRecord(latestVersion: res.version, source: "App Store",
                                pageURL: res.url,
                                installedAtCheck: installed, checkedAt: now)
        }

        return UpdateRecord(latestVersion: nil, source: nil, pageURL: nil,
                            installedAtCheck: installed, checkedAt: now)
    }

    // MARK: - Sparkle

    private static func sparkleLatestVersion(_ feedURL: URL) async -> String? {
        var req = URLRequest(url: feedURL)
        req.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return AppcastParser().latestShortVersion(from: data)
    }

    // MARK: - Mac App Store

    private static func appStoreLatest(bundleID: String) async -> (version: String, url: String?)? {
        let region: String
        if #available(macOS 13, *) {
            region = Locale.current.region?.identifier.lowercased() ?? "us"
        } else {
            region = Locale.current.regionCode?.lowercased() ?? "us"
        }
        guard let url = URL(string: "https://itunes.apple.com/lookup?bundleId=\(bundleID)&country=\(region)") else {
            return nil
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 12
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let results = json["results"] as? [[String: Any]],
              let first = results.first,
              let version = first["version"] as? String, !version.isEmpty else {
            return nil
        }
        return (version, first["trackViewUrl"] as? String)
    }
}

/// Parser minimale di un appcast Sparkle: raccoglie le `shortVersionString`
/// (dagli elementi `<sparkle:shortVersionString>` o dagli attributi
/// dell'`<enclosure>`) e restituisce la più recente.
private final class AppcastParser: NSObject, XMLParserDelegate {
    private var versions: [String] = []
    private var capturing = false
    private var buffer = ""

    func latestShortVersion(from data: Data) -> String? {
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return versions.max { $0.compare($1, options: .numeric) == .orderedAscending }
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String: String] = [:]) {
        if elementName == "enclosure",
           let v = attributeDict["sparkle:shortVersionString"], !v.isEmpty {
            versions.append(v)
        }
        if elementName == "sparkle:shortVersionString" {
            capturing = true
            buffer = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if capturing { buffer += string }
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "sparkle:shortVersionString" {
            let v = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !v.isEmpty { versions.append(v) }
            capturing = false
        }
    }
}
