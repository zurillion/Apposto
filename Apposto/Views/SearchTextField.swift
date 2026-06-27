import SwiftUI
import AppKit

/// Campo di testo trasparente (per la barra di ricerca) basato su `NSTextField`,
/// capace di intercettare **Tab** (completamento tag), **Invio** (conferma) e
/// **Backspace a campo vuoto** (rimuove l'ultimo chip). Si rifocalizza quando
/// `focusTrigger` cambia (es. alla riapertura del launcher).
struct SearchTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var focusTrigger: Int
    var onTab: () -> Void
    var onSubmit: () -> Void
    var onBackspaceWhenEmpty: () -> Void

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.delegate = context.coordinator
        field.placeholderString = placeholder
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: 18)
        field.cell?.wraps = false
        field.cell?.isScrollable = true
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        nsView.placeholderString = placeholder

        if nsView.stringValue != text {
            nsView.stringValue = text
            if let editor = nsView.currentEditor() {
                editor.selectedRange = NSRange(location: (text as NSString).length, length: 0)
            }
        }

        if context.coordinator.lastFocusTrigger != focusTrigger {
            context.coordinator.lastFocusTrigger = focusTrigger
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: SearchTextField
        var lastFocusTrigger = Int.min

        init(_ parent: SearchTextField) { self.parent = parent }

        func controlTextDidChange(_ obj: Notification) {
            guard let field = obj.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertTab(_:)):
                parent.onTab()
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.deleteBackward(_:)):
                if textView.string.isEmpty {
                    parent.onBackspaceWhenEmpty()
                    return true
                }
                return false
            default:
                return false
            }
        }
    }
}
