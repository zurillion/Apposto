import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

/// Coordina il ciclo di vita dell'app: crea il pannello floating, registra
/// l'hotkey globale, installa l'icona nella barra dei menu e i monitor degli
/// eventi (ESC e swipe del trackpad).
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    let model = AppModel()
    let settings = LauncherSettings()

    private var windowController: LauncherWindowController!
    private var statusItem: NSStatusItem!
    private var scrollMonitor: Any?
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // Stato di accumulo per lo swipe orizzontale del trackpad.
    private var scrollAccum: CGFloat = 0
    private var scrollTriggered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = LauncherRootView()
            .environmentObject(model)
            .environmentObject(settings)
        windowController = LauncherWindowController(rootView: AnyView(root))
        windowController.panel.delegate = self

        model.onRequestClose = { [weak self] in self?.hideLauncher() }
        model.reload()

        setupStatusItem()
        setupBindings()
        setupEventMonitors()
        setupActivationPolicyRestore()

        // Primo avvio: mostra subito il launcher per dare un riscontro visibile.
        showLauncher()
    }

    // Mantiene l'app viva anche quando la finestra Preferenze viene chiusa.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // Click sull'icona nel Dock: riapre il launcher.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showLauncher()
        return true
    }

    // MARK: - Visibilità del launcher

    @objc private func toggleLauncher() {
        if windowController.isVisible { hideLauncher() } else { showLauncher() }
    }

    private func showLauncher() {
        model.prepareForShow()
        windowController.positionOnActiveScreen()
        activateApp()
        windowController.panel.makeKeyAndOrderFront(nil)
        // Per un'app accessory l'attivazione può non essere ancora completa in
        // questo giro di runloop: rinforziamo lo stato "key" al tick successivo
        // così la barra di ricerca riceve subito l'input da tastiera.
        DispatchQueue.main.async { [weak self] in
            guard let self, self.windowController.isVisible else { return }
            self.windowController.panel.makeKey()
        }
    }

    private func hideLauncher() {
        windowController.panel.orderOut(nil)
    }

    /// Per un launcher (app accessory) `ignoringOtherApps: true` è più
    /// affidabile dell'attivazione cooperativa di macOS 14, che è asincrona e
    /// può lasciare il pannello senza focus da tastiera.
    private func activateApp() {
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Auto-nascondi quando il pannello perde il focus

    func windowDidResignKey(_ notification: Notification) {
        guard let window = notification.object as? NSWindow,
              window == windowController.panel else { return }
        hideLauncher()
    }

    // MARK: - Icona barra dei menu

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = NSImage(systemSymbolName: "square.grid.3x3.fill",
                                           accessibilityDescription: "Apposto")

        let menu = NSMenu()
        menu.addItem(withTitle: "Mostra Apposto", action: #selector(toggleLauncher), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Preferenze…", action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: "Esci da Apposto", action: #selector(quit), keyEquivalent: "q")
        statusItem.menu = menu
    }

    @objc private func openSettings() {
        // Un'app accessory non porterebbe in primo piano una finestra normale:
        // passiamo temporaneamente a .regular per mostrare le Preferenze a
        // fuoco; torniamo a .accessory alla chiusura (vedi observer).
        _ = NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Binding impostazioni (scorciatoia + Dock)

    /// Collega le impostazioni osservabili ai loro effetti: la scorciatoia
    /// globale viene (ri)registrata e la visibilità nel Dock aggiornata ogni
    /// volta che cambiano dalle Preferenze. Entrambi i `sink` scattano subito
    /// con i valori correnti, applicando così lo stato iniziale.
    private func setupBindings() {
        HotKeyManager.shared.onHotKey = { [weak self] in
            DispatchQueue.main.async { self?.toggleLauncher() }
        }

        settings.$hotKeyCode
            .combineLatest(settings.$hotKeyModifiers)
            .sink { code, modifiers in
                HotKeyManager.shared.register(keyCode: UInt32(code),
                                              modifiers: UInt32(modifiers))
            }
            .store(in: &cancellables)

        settings.$showInDock
            .sink { show in
                _ = NSApp.setActivationPolicy(show ? .regular : .accessory)
            }
            .store(in: &cancellables)
    }

    // MARK: - Monitor eventi (ESC + swipe trackpad)

    private func setupEventMonitors() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.windowController.isVisible else { return event }
            if event.keyCode == 53 { // Esc
                self.hideLauncher()
                return nil
            }
            return event
        }

        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.windowController.isVisible else { return event }
            self.handleScroll(event)
            return event
        }
    }

    /// Torna ad app accessory (niente icona nel Dock) quando la finestra
    /// Preferenze viene chiusa — è l'unica finestra "normale" dell'app.
    private func setupActivationPolicyRestore() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let closing = note.object as? NSWindow,
                  closing != self.windowController.panel else { return }
            _ = NSApp.setActivationPolicy(self.settings.showInDock ? .regular : .accessory)
        }
    }

    /// Converte uno swipe orizzontale a due dita in cambio pagina, con
    /// accumulo per gesto in modo da scattare una sola volta per swipe.
    private func handleScroll(_ event: NSEvent) {
        // Ignora gli eventi di inerzia (momentum) successivi al sollevamento
        // delle dita: appartengono allo stesso swipe e altrimenti potrebbero
        // far scattare un secondo cambio pagina.
        guard event.momentumPhase.isEmpty else { return }

        let phase = event.phase
        if phase.contains(.began) {
            scrollAccum = 0
            scrollTriggered = false
        }

        let dx = event.scrollingDeltaX
        let dy = event.scrollingDeltaY
        if abs(dx) > abs(dy) {
            scrollAccum += dx
            let threshold: CGFloat = 40
            if !scrollTriggered {
                if scrollAccum <= -threshold {
                    model.stepPage(1)
                    scrollTriggered = true
                } else if scrollAccum >= threshold {
                    model.stepPage(-1)
                    scrollTriggered = true
                }
            }
        }

        if phase.contains(.ended) || phase.contains(.cancelled) {
            scrollAccum = 0
            scrollTriggered = false
        }
    }
}
