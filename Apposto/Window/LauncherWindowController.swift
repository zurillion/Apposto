import AppKit
import SwiftUI

/// Pannello che può diventare key/main pur essendo borderless di fatto
/// (titlebar nascosta), così la barra di ricerca riceve l'input da tastiera.
final class LauncherPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Crea e configura il pannello floating che ospita la UI SwiftUI.
final class LauncherWindowController {
    let panel: LauncherPanel

    init(rootView: AnyView) {
        panel = LauncherPanel(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 640),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Aspetto: niente titlebar visibile, contenuto a tutta finestra.
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isMovableByWindowBackground = false
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        // Nota: .canJoinAllSpaces e .moveToActiveSpace si escludono a vicenda
        // (AppKit lancia un'eccezione se presenti entrambi). Usiamo
        // .canJoinAllSpaces così il pannello è disponibile su ogni Spazio, e
        // .fullScreenAuxiliary per mostrarlo sopra le app a tutto schermo.
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .none
        panel.minSize = NSSize(width: 480, height: 360)

        let hosting = NSHostingView(rootView: rootView)
        hosting.frame = panel.contentRect(forFrameRect: panel.frame)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        // Angoli arrotondati sul contenuto.
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 20
        panel.contentView?.layer?.masksToBounds = true

        // Ricorda dimensione/posizione tra i riavvii.
        panel.setFrameAutosaveName("AppostoLauncherPanel")
    }

    var isVisible: Bool { panel.isVisible }

    /// Centra il pannello sullo schermo che contiene il puntatore, mantenendo
    /// la dimensione corrente (eventualmente ridotta per stare nello schermo).
    func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let screen else { return }

        let visible = screen.visibleFrame
        var frame = panel.frame
        frame.size.width = min(frame.size.width, visible.width)
        frame.size.height = min(frame.size.height, visible.height)
        frame.origin.x = visible.midX - frame.size.width / 2
        frame.origin.y = visible.midY - frame.size.height / 2
        panel.setFrame(frame, display: false)
    }
}
