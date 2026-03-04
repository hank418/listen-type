import Cocoa
import Carbon

class TypeSimulator {
    @MainActor
    func type(text: String) async {
        let pasteboard = NSPasteboard.general
        let savedContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure clipboard is ready
        try? await Task.sleep(for: .milliseconds(100))

        // Simulate Cmd+V
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(9), keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cghidEventTap)

        // Wait for paste, then restore clipboard
        try? await Task.sleep(for: .milliseconds(500))
        pasteboard.clearContents()
        if let saved = savedContents {
            pasteboard.setString(saved, forType: .string)
        }
    }
}
