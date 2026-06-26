import AppKit
import SwiftUI
import Carbon.HIToolbox

/// Coordina il ciclo di vita dell'app: crea il pannello floating, registra
/// l'hotkey globale, installa l'icona nella barra dei menu e i monitor degli
/// eventi (ESC e swipe del trackpad).
final class AppDelegate: NSObject, NSApplicationDelegate {
    let model = AppModel()
    let settings = LauncherSettings()

    private var windowController: LauncherWindowController!
    private var statusItem: NSStatusItem!
    private var scrollMonitor: Any?
    private var keyMonitor: Any?

    // Stato di accumulo per lo swipe orizzontale del trackpad.
    private var scrollAccum: CGFloat = 0
    private var scrollTriggered = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        let root = LauncherRootView()
            .environmentObject(model)
            .environmentObject(settings)
        windowController = LauncherWindowController(rootView: AnyView(root))

        model.onRequestClose = { [weak self] in self?.hideLauncher() }
        model.reload()

        setupStatusItem()
        setupHotKey()
        setupEventMonitors()
    }

    // Mantiene l'app viva anche quando la finestra Preferenze viene chiusa.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Visibilità del launcher

    @objc private func toggleLauncher() {
        if windowController.isVisible { hideLauncher() } else { showLauncher() }
    }

    private func showLauncher() {
        model.prepareForShow()
        windowController.positionOnActiveScreen()
        activateApp()
        windowController.panel.makeKeyAndOrderFront(nil)
    }

    private func hideLauncher() {
        windowController.panel.orderOut(nil)
    }

    private func activateApp() {
        if #available(macOS 14.0, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
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
        activateApp()
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    // MARK: - Hotkey globale

    private func setupHotKey() {
        HotKeyManager.shared.onHotKey = { [weak self] in
            DispatchQueue.main.async { self?.toggleLauncher() }
        }
        // Default: ⌃⌥⌘ + Spazio (Ctrl + Opzione + Cmd + Spazio).
        // In futuro questa combinazione sarà configurabile dalle Preferenze.
        HotKeyManager.shared.register(
            keyCode: UInt32(kVK_Space),
            modifiers: UInt32(controlKey | optionKey | cmdKey)
        )
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

    /// Converte uno swipe orizzontale a due dita in cambio pagina, con
    /// accumulo per gesto in modo da scattare una sola volta per swipe.
    private func handleScroll(_ event: NSEvent) {
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
