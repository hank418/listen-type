import Carbon
import Cocoa

func debugLog(_ message: String) {
    let logFile = "/tmp/listentype_debug.log"
    let timestamp = ISO8601DateFormatter().string(from: Date())
    let line = "[\(timestamp)] \(message)\n"
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: logFile) {
            if let fh = FileHandle(forWritingAtPath: logFile) {
                fh.seekToEndOfFile()
                fh.write(data)
                fh.closeFile()
            }
        } else {
            FileManager.default.createFile(atPath: logFile, contents: data)
        }
    }
}

// Global reference for the C callback
private var globalHotKeyManager: HotKeyManager?

class HotKeyManager {
    private var hotKeyRef: EventHotKeyRef?
    var onHotKeyPressed: (() -> Void)?

    func start() {
        globalHotKeyManager = self

        // Install Carbon event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            hotKeyHandler,
            1,
            &eventType,
            nil,
            nil
        )

        // Register Option+S (keyCode 1 = S, optionKey modifier)
        var hotKeyID = EventHotKeyID(
            signature: OSType(0x4C545950), // "LTYP"
            id: 1
        )

        let status = RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(optionKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if status == noErr {
            debugLog("HotKey registered: Option+S (Carbon API)")
        } else {
            debugLog("FAILED to register hotkey, status: \(status)")
        }
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        globalHotKeyManager = nil
    }

    fileprivate func handleHotKey() {
        debugLog("Option+S pressed!")
        DispatchQueue.main.async {
            self.onHotKeyPressed?()
        }
    }
}

// C-compatible callback function
private func hotKeyHandler(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    globalHotKeyManager?.handleHotKey()
    return noErr
}
