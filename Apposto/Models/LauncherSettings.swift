import Foundation
import Combine

/// Impostazioni dell'utente, persistite in `UserDefaults`.
///
/// I valori vengono salvati nei rispettivi `didSet`. L'inizializzatore assegna
/// i valori direttamente (gli osservatori `didSet` non scattano durante
/// l'init), quindi al primo avvio non scriviamo i default su disco.
final class LauncherSettings: ObservableObject {
    private enum Keys {
        static let iconSize = "iconSize"
        static let spacing = "spacing"
        static let showLabels = "showLabels"
        static let columns = "columnsOverride"
    }

    private let defaults = UserDefaults.standard

    /// Lato dell'icona in punti.
    @Published var iconSize: Double { didSet { defaults.set(iconSize, forKey: Keys.iconSize) } }

    /// Spaziatura tra le celle in punti.
    @Published var spacing: Double { didSet { defaults.set(spacing, forKey: Keys.spacing) } }

    /// Mostra il nome sotto ogni icona.
    @Published var showLabels: Bool { didSet { defaults.set(showLabels, forKey: Keys.showLabels) } }

    /// Numero di colonne fisso. `0` = adatta automaticamente alla larghezza.
    @Published var columnsOverride: Int { didSet { defaults.set(columnsOverride, forKey: Keys.columns) } }

    init() {
        iconSize = (defaults.object(forKey: Keys.iconSize) as? Double) ?? 72
        spacing = (defaults.object(forKey: Keys.spacing) as? Double) ?? 24
        showLabels = (defaults.object(forKey: Keys.showLabels) as? Bool) ?? true
        columnsOverride = (defaults.object(forKey: Keys.columns) as? Int) ?? 0
    }
}
