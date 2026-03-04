import SwiftUI
import AppKit

class StatusOverlayController {
    private var window: NSPanel?
    private var messageLabel: NSTextField?
    private var messageBg: NSView?
    private var dismissTimer: Timer?

    func show(state: RecordingState) {
        // Always recreate to avoid SwiftUI relayout issues
        hide()

        let isRecording = state == .recording

        let height: CGFloat = 40
        let dotSize: CGFloat = 10
        let spacing: CGFloat = 8
        let padding: CGFloat = 16

        let label = NSTextField(labelWithString: isRecording ? "錄音中…" : "處理中…")
        label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.sizeToFit()

        let width = padding + dotSize + spacing + label.frame.width + padding

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let bg = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        bg.wantsLayer = true
        bg.layer?.cornerRadius = 12
        bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor

        // Red dot indicator
        let dot = NSView(frame: NSRect(x: padding, y: (height - dotSize) / 2, width: dotSize, height: dotSize))
        dot.wantsLayer = true
        dot.layer?.cornerRadius = dotSize / 2
        dot.layer?.backgroundColor = isRecording ? NSColor.red.cgColor : NSColor.white.cgColor

        label.frame = NSRect(x: padding + dotSize + spacing, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)

        bg.addSubview(dot)
        bg.addSubview(label)
        panel.contentView = bg

        // Position: top center
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.midX - width / 2
            let y = screenFrame.maxY - 60
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        panel.orderFront(nil)
        self.window = panel
        self.messageLabel = nil
        self.messageBg = nil

        // Blink red dot for recording
        if isRecording {
            startBlink(view: dot)
        }
    }

    func showMessage(_ text: String, autoDismissAfter: TimeInterval = 3.0) {
        dismissTimer?.invalidate()
        dismissTimer = nil

        let height: CGFloat = 40
        let padding: CGFloat = 16

        // If we already have a message panel, just update the text
        if let label = messageLabel, let bg = messageBg, let panel = window {
            label.stringValue = text
            label.sizeToFit()
            let width = padding + label.frame.width + padding
            label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
            bg.frame = NSRect(x: 0, y: 0, width: width, height: height)
            panel.setContentSize(NSSize(width: width, height: height))
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - width / 2
                let y = screenFrame.maxY - 60
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        } else {
            // Create new message panel
            hide()

            let label = NSTextField(labelWithString: text)
            label.font = NSFont.systemFont(ofSize: 14, weight: .medium)
            label.textColor = .white
            label.isBezeled = false
            label.drawsBackground = false
            label.isEditable = false
            label.sizeToFit()

            let width = padding + label.frame.width + padding

            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.level = .floating
            panel.hasShadow = true
            panel.ignoresMouseEvents = true
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

            let bg = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
            bg.wantsLayer = true
            bg.layer?.cornerRadius = 12
            bg.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.78).cgColor

            label.frame = NSRect(x: padding, y: (height - label.frame.height) / 2, width: label.frame.width, height: label.frame.height)
            bg.addSubview(label)
            panel.contentView = bg

            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let x = screenFrame.midX - width / 2
                let y = screenFrame.maxY - 60
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }

            panel.orderFront(nil)
            self.window = panel
            self.messageLabel = label
            self.messageBg = bg
        }

        if autoDismissAfter > 0 {
            dismissTimer = Timer.scheduledTimer(withTimeInterval: autoDismissAfter, repeats: false) { [weak self] _ in
                self?.hide()
            }
        }
    }

    func hide() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        window?.orderOut(nil)
        window = nil
        messageLabel = nil
        messageBg = nil
    }

    private func startBlink(view: NSView) {
        Timer.scheduledTimer(withTimeInterval: 0.6, repeats: true) { [weak self, weak view] timer in
            guard let self = self, self.window != nil, let view = view else {
                timer.invalidate()
                return
            }
            view.alphaValue = view.alphaValue > 0.5 ? 0.3 : 1.0
        }
    }
}
