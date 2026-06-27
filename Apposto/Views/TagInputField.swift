import SwiftUI
import AppKit

/// Campo di testo (basato su `NSTextField`) per inserire un tag, capace di
/// intercettare **Tab** (per il completamento) e **Invio** (per confermare),
/// che SwiftUI altrimenti userebbe per spostare il focus o nient'altro.
struct TagInputField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onTab: () -> Void
    var onSubmit: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        field.font = .systemFont(ofSize: NSFont.systemFontSize)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self

        if nsView.stringValue != text {
            nsView.stringValue = text
            // Dopo un aggiornamento programmatico (es. il completamento con Tab)
            // riporta il cursore in fondo.
            if let editor = nsView.currentEditor() {
                editor.selectedRange = NSRange(location: (text as NSString).length, length: 0)
            }
        }

        // Focus automatico alla comparsa (la finestra del popover esiste già al
        // giro di runloop successivo).
        if !context.coordinator.didFocus {
            context.coordinator.didFocus = true
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: TagInputField
        var didFocus = false

        init(_ parent: TagInputField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)):
                parent.onTab()
                return true   // consuma il Tab: niente cambio di focus
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            default:
                return false
            }
        }
    }
}
