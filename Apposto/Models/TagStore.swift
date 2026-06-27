import Foundation
import Combine

/// Database persistente dei tag associati alle applicazioni.
///
/// I tag sono **case-insensitive** e possono contenere spazi. Internamente si
/// usa una forma "canonica" (minuscolo, spazi normalizzati) per confronti e
/// deduplica, conservando però la grafia con cui un tag è stato inserito la
/// prima volta (per la visualizzazione).
///
/// Le app sono identificate dal loro `AppItem.id` (bundle identifier, o il
/// percorso in sua assenza): chiave stabile tra una scansione e l'altra.
final class TagStore: ObservableObject {
    /// canonico → grafia da mostrare.
    @Published private(set) var displayByCanonical: [String: String] = [:]
    /// appID → insieme di tag canonici.
    @Published private(set) var tagsByApp: [String: Set<String>] = [:]

    private let fileURL: URL?

    init() {
        fileURL = TagStore.makeFileURL()
        load()
    }

    /// Forma canonica di un tag: trim, spazi interni collassati, minuscolo.
    static func canonical(_ raw: String) -> String {
        raw.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .lowercased()
    }

    // MARK: - Letture

    /// Tutti i tag conosciuti (grafia), ordinati.
    var allTags: [String] {
        displayByCanonical.values.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Tag di una singola app (grafia), ordinati.
    func tags(for appID: String) -> [String] {
        (tagsByApp[appID] ?? [])
            .compactMap { displayByCanonical[$0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Tag comuni a tutte le app indicate (grafia), ordinati.
    func commonTags(for appIDs: [String]) -> [String] {
        guard let first = appIDs.first else { return [] }
        var common = tagsByApp[first] ?? []
        for id in appIDs.dropFirst() {
            common.formIntersection(tagsByApp[id] ?? [])
        }
        return common
            .compactMap { displayByCanonical[$0] }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Insieme dei tag canonici di un'app.
    func canonicalTags(for appID: String) -> Set<String> {
        tagsByApp[appID] ?? []
    }

    // MARK: - Mutazioni

    func addTag(_ raw: String, to appIDs: [String]) {
        let canon = TagStore.canonical(raw)
        guard !canon.isEmpty else { return }
        if displayByCanonical[canon] == nil {
            displayByCanonical[canon] = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        for id in appIDs {
            tagsByApp[id, default: []].insert(canon)
        }
        save()
    }

    func removeTag(canonical canon: String, from appIDs: [String]) {
        for id in appIDs {
            tagsByApp[id]?.remove(canon)
            if tagsByApp[id]?.isEmpty == true { tagsByApp[id] = nil }
        }
        // Se nessuna app usa più il tag, dimentica anche la sua grafia.
        let stillUsed = tagsByApp.values.contains { $0.contains(canon) }
        if !stillUsed { displayByCanonical[canon] = nil }
        save()
    }

    // MARK: - Persistenza

    private struct Payload: Codable {
        var displayByCanonical: [String: String]
        var tagsByApp: [String: [String]]
    }

    private static func makeFileURL() -> URL? {
        let fm = FileManager.default
        guard let dir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        return dir
            .appendingPathComponent("Apposto", isDirectory: true)
            .appendingPathComponent("tags.json")
    }

    private func load() {
        guard let fileURL,
              let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        displayByCanonical = payload.displayByCanonical
        tagsByApp = payload.tagsByApp.mapValues { Set($0) }
    }

    private func save() {
        guard let fileURL else { return }
        let payload = Payload(displayByCanonical: displayByCanonical,
                              tagsByApp: tagsByApp.mapValues { Array($0) })
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
