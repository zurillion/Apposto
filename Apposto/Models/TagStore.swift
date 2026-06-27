import Foundation
import Combine

/// Un gruppo di sinonimi: tag che vengono assegnati/rimossi insieme.
/// `text` è la stringa modificabile ("tag1, tag2, …"); `tags` la sua versione
/// suddivisa.
struct SynonymGroup: Codable, Identifiable {
    var id = UUID()
    var text: String = ""

    var tags: [String] {
        text.components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

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
    /// Gruppi di sinonimi configurati dall'utente.
    @Published var synonymGroups: [SynonymGroup] = [] { didSet { if isLoaded { save() } } }

    private let fileURL: URL?
    private var isLoaded = false

    init() {
        fileURL = TagStore.makeFileURL()
        load()
        isLoaded = true
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

        // Espande con i sinonimi: il tag più tutti quelli dei suoi gruppi.
        var expansion = synonymExpansion(of: canon)
        if expansion[canon] == nil {
            expansion[canon] = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for (c, display) in expansion {
            if displayByCanonical[c] == nil { displayByCanonical[c] = display }
            for id in appIDs {
                tagsByApp[id, default: []].insert(c)
            }
        }
        save()
    }

    func removeTag(canonical canon: String, from appIDs: [String]) {
        // Rimuove il tag e tutti i suoi sinonimi.
        var toRemove = Set(synonymExpansion(of: canon).keys)
        toRemove.insert(canon)

        for id in appIDs {
            for c in toRemove { tagsByApp[id]?.remove(c) }
            if tagsByApp[id]?.isEmpty == true { tagsByApp[id] = nil }
        }
        // Dimentica la grafia dei tag non più usati da nessuna app.
        for c in toRemove where !tagsByApp.values.contains(where: { $0.contains(c) }) {
            displayByCanonical[c] = nil
        }
        save()
    }

    // MARK: - Sinonimi

    /// Per un tag canonico, restituisce tutti i tag dei gruppi che lo contengono
    /// (canonico → grafia), incluso il tag stesso.
    private func synonymExpansion(of canon: String) -> [String: String] {
        var result: [String: String] = [:]
        for group in synonymGroups where group.tags.contains(where: { TagStore.canonical($0) == canon }) {
            for tag in group.tags {
                let c = TagStore.canonical(tag)
                if !c.isEmpty { result[c] = tag.trimmingCharacters(in: .whitespaces) }
            }
        }
        return result
    }

    func addSynonymGroup() {
        synonymGroups.append(SynonymGroup())
    }

    func removeSynonymGroup(_ id: UUID) {
        synonymGroups.removeAll { $0.id == id }
    }

    // MARK: - Persistenza

    private struct Payload: Codable {
        var displayByCanonical: [String: String]
        var tagsByApp: [String: [String]]
        var synonymGroups: [SynonymGroup]?
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
        synonymGroups = payload.synonymGroups ?? []
    }

    private func save() {
        guard let fileURL else { return }
        let payload = Payload(displayByCanonical: displayByCanonical,
                              tagsByApp: tagsByApp.mapValues { Array($0) },
                              synonymGroups: synonymGroups)
        guard let data = try? JSONEncoder().encode(payload) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                 withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
