import Foundation
import ServiceManagement

/// Gestione dell'avvio automatico all'accesso, tramite `SMAppService`
/// (disponibile da macOS 13). Su macOS 12 la funzione non è supportata.
enum LoginItem {

    /// `true` se l'avvio al login è gestibile su questo sistema (macOS 13+).
    static var isSupported: Bool {
        if #available(macOS 13.0, *) { return true }
        return false
    }

    /// Stato corrente: `true` se l'app è registrata per l'avvio al login.
    static var isEnabled: Bool {
        if #available(macOS 13.0, *) {
            return SMAppService.mainApp.status == .enabled
        }
        return false
    }

    /// Registra/deregistra l'app per l'avvio al login. Restituisce `true` se
    /// l'operazione è andata a buon fine.
    @discardableResult
    static func setEnabled(_ enabled: Bool) -> Bool {
        guard #available(macOS 13.0, *) else { return false }
        do {
            let service = SMAppService.mainApp
            if enabled {
                if service.status != .enabled { try service.register() }
            } else {
                if service.status == .enabled { try service.unregister() }
            }
            return true
        } catch {
            return false
        }
    }
}
