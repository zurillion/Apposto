import Foundation
import Combine
import Carbon.HIToolbox

/// Modalità di visualizzazione della griglia.
enum AppViewMode: String {
    case icons   // griglia di icone paginata
    case list    // elenco a colonne
}

/// Criterio di ordinamento delle app.
enum SortField: String, CaseIterable {
    case name
    case size
    case dateAdded
    case architecture
    case update

    var title: String {
        switch self {
        case .name: return "Nome"
        case .size: return "Dimensione"
        case .dateAdded: return "Data"
        case .architecture: return "Architettura"
        case .update: return "Update"
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
        static let showOriginalName = "showOriginalName"
        static let showIntelBadge = "showIntelBadge"
        static let showVersion = "showVersion"
        static let checkForUpdates = "checkForUpdates"
        static let viewMode = "viewMode"
        static let listRowHeight = "listRowHeight"
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

    /// Mostra il nome originale (non localizzato) sotto al nome localizzato.
    @Published var showOriginalName: Bool { didSet { defaults.set(showOriginalName, forKey: Keys.showOriginalName) } }

    /// Mostra un badge "Intel" sulle app solo-Intel (senza slice arm64).
    @Published var showIntelBadge: Bool { didSet { defaults.set(showIntelBadge, forKey: Keys.showIntelBadge) } }

    /// Mostra la versione dell'app sotto al nome.
    @Published var showVersion: Bool { didSet { defaults.set(showVersion, forKey: Keys.showVersion) } }

    /// Controlla in background la disponibilità di aggiornamenti (Sparkle + App
    /// Store) e segnala con un badge le app aggiornabili. Opt-in (usa la rete).
    @Published var checkForUpdates: Bool { didSet { defaults.set(checkForUpdates, forKey: Keys.checkForUpdates) } }

    /// Modalità di visualizzazione: icone o elenco.
    @Published var viewMode: AppViewMode { didSet { defaults.set(viewMode.rawValue, forKey: Keys.viewMode) } }

    /// Altezza delle righe nella vista a elenco (in punti).
    @Published var listRowHeight: Double { didSet { defaults.set(listRowHeight, forKey: Keys.listRowHeight) } }

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
        showOriginalName = (defaults.object(forKey: Keys.showOriginalName) as? Bool) ?? false
        showIntelBadge = (defaults.object(forKey: Keys.showIntelBadge) as? Bool) ?? false
        showVersion = (defaults.object(forKey: Keys.showVersion) as? Bool) ?? false
        checkForUpdates = (defaults.object(forKey: Keys.checkForUpdates) as? Bool) ?? false
        viewMode = AppViewMode(rawValue: defaults.string(forKey: Keys.viewMode) ?? "") ?? .icons
        listRowHeight = (defaults.object(forKey: Keys.listRowHeight) as? Double) ?? 34
        theme = AppTheme(rawValue: defaults.string(forKey: Keys.theme) ?? "") ?? .blue
    }

    /// Riporta la scorciatoia al valore di default.
    func resetHotKey() {
        hotKeyModifiers = HotKeyDefault.modifiers
        hotKeyCode = HotKeyDefault.code
    }
}
