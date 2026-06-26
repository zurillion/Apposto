import SwiftUI
import AppKit
import Carbon.HIToolbox

/// Controllo per registrare una scorciatoia: clicca il pulsante e premi la
/// combinazione desiderata. Esc annulla. Servono uno o più modificatori.
struct ShortcutRecorder: View {
    @Binding var keyCode: Int
    @Binding var carbonModifiers: Int

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button(action: toggle) {
            Text(recording
                 ? "Premi la combinazione…"
                 : ShortcutFormatter.string(keyCode: keyCode, carbonModifiers: carbonModifiers))
                .font(.system(.body, design: .rounded))
                .frame(minWidth: 140)
                .padding(.vertical, 2)
        }
        .help(recording ? "In attesa della combinazione (Esc per annullare)"
                        : "Clicca per cambiare la scorciatoia")
        .onDisappear(perform: stopRecording)
    }

    private func toggle() {
        recording ? stopRecording() : startRecording()
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Assorbi i soli cambi di modificatori: aspettiamo un vero tasto.
            if event.type == .flagsChanged { return nil }
            // Esc annulla.
            if event.keyCode == UInt16(kVK_Escape) {
                stopRecording()
                return nil
            }
            let mods = carbon(from: event.modifierFlags)
            // Una hotkey globale richiede almeno un modificatore.
            guard mods & (controlKey | optionKey | cmdKey | shiftKey) != 0 else {
                NSSound.beep()
                return nil
            }
            keyCode = Int(event.keyCode)
            carbonModifiers = mods
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func carbon(from flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= cmdKey }
        if flags.contains(.option)  { result |= optionKey }
        if flags.contains(.control) { result |= controlKey }
        if flags.contains(.shift)   { result |= shiftKey }
        return result
    }
}

/// Converte keyCode + modificatori Carbon nella classica stringa con i simboli.
enum ShortcutFormatter {
    static func string(keyCode: Int, carbonModifiers: Int) -> String {
        modifiers(carbonModifiers) + keyName(keyCode)
    }

    static func modifiers(_ mask: Int) -> String {
        var result = ""
        if mask & controlKey != 0 { result += "⌃" }
        if mask & optionKey  != 0 { result += "⌥" }
        if mask & shiftKey   != 0 { result += "⇧" }
        if mask & cmdKey     != 0 { result += "⌘" }
        return result
    }

    static func keyName(_ code: Int) -> String {
        specials[code] ?? ansiKeys[code] ?? "Tasto \(code)"
    }

    private static let specials: [Int: String] = [
        kVK_Space: "Spazio",
        kVK_Return: "↩",
        kVK_ANSI_KeypadEnter: "⌅",
        kVK_Tab: "⇥",
        kVK_Escape: "⎋",
        kVK_Delete: "⌫",
        kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←",
        kVK_RightArrow: "→",
        kVK_UpArrow: "↑",
        kVK_DownArrow: "↓",
        kVK_Home: "↖",
        kVK_End: "↘",
        kVK_PageUp: "⇞",
        kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4",
        kVK_F5: "F5", kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8",
        kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]

    private static let ansiKeys: [Int: String] = [
        kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
        kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
        kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
        kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
        kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
        kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
        kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
        kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
        kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
        kVK_ANSI_8: "8", kVK_ANSI_9: "9",
        kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=",
        kVK_ANSI_LeftBracket: "[", kVK_ANSI_RightBracket: "]",
        kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
        kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",",
        kVK_ANSI_Period: ".", kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
    ]
}
