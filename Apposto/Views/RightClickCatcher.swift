import SwiftUI
import AppKit

/// Intercetta SOLO il clic destro, lasciando passare tutto il resto (clic
/// sinistro, drag, hover) alle viste SwiftUI sottostanti. SwiftUI su macOS non
/// offre un gesto nativo per il clic destro: questo overlay lo aggiunge senza
/// disturbare le altre interazioni.
struct RightClickCatcher: NSViewRepresentable {
    var onRightClick: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = CatcherView()
        view.onRightClick = onRightClick
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? CatcherView)?.onRightClick = onRightClick
    }

    final class CatcherView: NSView {
        var onRightClick: (() -> Void)?

        override func rightMouseDown(with event: NSEvent) {
            onRightClick?()
        }

        /// Reclama solo gli eventi del tasto destro: per tutti gli altri
        /// restituisce nil così l'evento prosegue verso le viste sotto.
        override func hitTest(_ point: NSPoint) -> NSView? {
            switch NSApp.currentEvent?.type {
            case .rightMouseDown, .rightMouseUp, .rightMouseDragged:
                return super.hitTest(point)
            default:
                return nil
            }
        }
    }
}
