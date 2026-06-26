import AppKit
import Carbon.HIToolbox

/// Registra una hotkey globale tramite l'API Carbon `RegisterEventHotKey`.
///
/// A differenza dei monitor `NSEvent` globali, questa via non richiede il
/// permesso di Accessibilità ed è quella storicamente usata dai launcher.
final class HotKeyManager {
    static let shared = HotKeyManager()

    /// Invocata sul thread principale a ogni pressione della hotkey.
    var onHotKey: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?

    private init() {}

    /// - Parameters:
    ///   - keyCode: virtual key code (es. `kVK_Space`).
    ///   - modifiers: maschera Carbon (es. `optionKey`, `cmdKey`).
    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()

        // Handler C: senza catture, riceve `self` via userData.
        let callback: EventHandlerUPP = { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotKeyManager>.fromOpaque(userData).takeUnretainedValue()
            manager.onHotKey?()
            return noErr
        }

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(),
                            callback,
                            1,
                            &eventType,
                            Unmanaged.passUnretained(self).toOpaque(),
                            &eventHandler)

        let hotKeyID = EventHotKeyID(signature: OSType(0x4150_504F), id: 1) // 'APPO'
        RegisterEventHotKey(keyCode,
                            modifiers,
                            hotKeyID,
                            GetApplicationEventTarget(),
                            0,
                            &hotKeyRef)
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
}
