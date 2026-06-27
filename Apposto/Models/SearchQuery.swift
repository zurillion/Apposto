import Foundation

/// Interpreta il testo della ricerca distinguendo i filtri per tag (`#tag`) dal
/// testo libero (nome dell'app), in qualunque ordine. Esempi:
///   `#tag1 #tag2`
///   `#tag1 nome app #tag2`
///   `nome app #tag1 #tag2`
///
/// Poiché i tag possono contenere spazi, dopo ogni `#` si cerca il tag
/// conosciuto **più lungo** che ne è prefisso: il resto del segmento diventa
/// testo libero. (In Fase 2 il completamento con Tab renderà la cosa esplicita.)
struct SearchQuery {
    /// Tag (canonici) che l'app deve avere tutti.
    var requiredTags: [String] = []
    /// Prefissi di tag (per un `#tag` ancora incompleto): l'app deve avere
    /// almeno un tag che inizia così.
    var prefixTags: [String] = []
    /// Testo libero: il nome dell'app deve contenerlo.
    var text: String = ""

    var isEmpty: Bool { requiredTags.isEmpty && prefixTags.isEmpty && text.isEmpty }

    static func parse(_ raw: String, knownCanonicalTags: [String]) -> SearchQuery {
        var query = SearchQuery()
        var textParts: [String] = []
        // Match greedy: prima i tag più lunghi.
        let known = knownCanonicalTags.filter { !$0.isEmpty }
                                      .sorted { $0.count > $1.count }

        let segments = raw.components(separatedBy: "#")

        if let head = segments.first {
            let t = head.trimmingCharacters(in: .whitespaces)
            if !t.isEmpty { textParts.append(t) }
        }

        for segment in segments.dropFirst() {
            // Ignora eventuali spazi subito dopo il '#'.
            let leadingTrimmed = String(segment.drop(while: { $0 == " " }))
            let lower = leadingTrimmed.lowercased()

            if let match = known.first(where: { lower.hasPrefix($0) }) {
                query.requiredTags.append(match)
                let rest = String(leadingTrimmed.dropFirst(match.count))
                    .trimmingCharacters(in: .whitespaces)
                if !rest.isEmpty { textParts.append(rest) }
            } else {
                let prefix = leadingTrimmed.trimmingCharacters(in: .whitespaces).lowercased()
                if !prefix.isEmpty { query.prefixTags.append(prefix) }
            }
        }

        query.text = textParts.joined(separator: " ")
        return query
    }

    /// Verifica se un'app soddisfa la query. `appNames` contiene tutti i nomi su
    /// cui può avvenire la corrispondenza (nome localizzato + alias, es. il nome
    /// originale/inglese): basta che uno contenga il testo cercato.
    func matches(appNames: [String], appTags: Set<String>) -> Bool {
        for tag in requiredTags where !appTags.contains(tag) { return false }
        for prefix in prefixTags where !appTags.contains(where: { $0.hasPrefix(prefix) }) { return false }
        if !text.isEmpty {
            let hit = appNames.contains {
                $0.range(of: text, options: [.caseInsensitive, .diacriticInsensitive]) != nil
            }
            if !hit { return false }
        }
        return true
    }
}
