import Foundation
import Combine
import Carbon.HIToolbox

/// Criterio di ordinamento delle app.
enum SortField: String, CaseIterable {
    case name
    case size
    case dateAdded

    var title: String {
        switch self {
        case .name: return "Nome"
        case .size: return "Dimensione"
        case .dateAdded: return "Data"
        }
    }
}

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
        static let showInDock = "showInDock"
        static let hotKeyCode = "hotKeyCode"
        static let hotKeyModifiers = "hotKeyModifiers"
        static let sortField = "sortField"
        static let sortAscending = "sortAscending"
        static let showTagIndicator = "showTagIndicator"
        static let theme = "theme"
    }

    /// Valori di default della scorciatoia globale: ⌃⌥⌘ + Spazio.
    enum HotKeyDefault {
        static let code = Int(kVK_Space)                       // 49
        static let modifiers = controlKey | optionKey | cmdKey // maschera Carbon
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

    /// Mostra l'icona nel Dock (app normale) oppure solo nella barra dei menu.
    @Published var showInDock: Bool { didSet { defaults.set(showInDock, forKey: Keys.showInDock) } }

    /// Virtual key code della scorciatoia globale.
    @Published var hotKeyCode: Int { didSet { defaults.set(hotKeyCode, forKey: Keys.hotKeyCode) } }

    /// Maschera dei modificatori Carbon della scorciatoia globale.
    @Published var hotKeyModifiers: Int { didSet { defaults.set(hotKeyModifiers, forKey: Keys.hotKeyModifiers) } }

    /// Criterio di ordinamento e direzione.
    @Published var sortField: SortField { didSet { defaults.set(sortField.rawValue, forKey: Keys.sortField) } }
    @Published var sortAscending: Bool { didSet { defaults.set(sortAscending, forKey: Keys.sortAscending) } }

    /// Mostra un pallino sulle app che hanno almeno un tag.
    @Published var showTagIndicator: Bool { didSet { defaults.set(showTagIndicator, forKey: Keys.showTagIndicator) } }

    /// Tema colorato selezionato.
    @Published var theme: AppTheme { didSet { defaults.set(theme.rawValue, forKey: Keys.theme) } }

    init() {
        iconSize = (defaults.object(forKey: Keys.iconSize) as? Double) ?? 72
        spacing = (defaults.object(forKey: Keys.spacing) as? Double) ?? 24
        showLabels = (defaults.object(forKey: Keys.showLabels) as? Bool) ?? true
        columnsOverride = (defaults.object(forKey: Keys.columns) as? Int) ?? 0
        showInDock = (defaults.object(forKey: Keys.showInDock) as? Bool) ?? true
        hotKeyCode = (defaults.object(forKey: Keys.hotKeyCode) as? Int) ?? HotKeyDefault.code
        hotKeyModifiers = (defaults.object(forKey: Keys.hotKeyModifiers) as? Int) ?? HotKeyDefault.modifiers
        sortField = SortField(rawValue: defaults.string(forKey: Keys.sortField) ?? "") ?? .name
        sortAscending = (defaults.object(forKey: Keys.sortAscending) as? Bool) ?? true
        showTagIndicator = (defaults.object(forKey: Keys.showTagIndicator) as? Bool) ?? true
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .blue
    }

    /// Riporta la scorciatoia al valore di default.
    func resetHotKey() {
        hotKeyModifiers = HotKeyDefault.modifiers
        hotKeyCode = HotKeyDefault.code
    }
}
