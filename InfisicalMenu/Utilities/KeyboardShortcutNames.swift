import Carbon
import AppKit

/// Manages a global keyboard shortcut using Carbon Hot Key API.
/// Default: Cmd+Shift+K to toggle the menubar menu.
final class GlobalShortcutManager {
    static let shared = GlobalShortcutManager()

    private var hotKeyRef: EventHotKeyRef?
    private var handler: (() -> Void)?

    private init() {}

    /// Register a global hotkey. Default: Cmd+Shift+K
    func register(keyCode: UInt32 = UInt32(kVK_ANSI_K),
                  modifiers: UInt32 = UInt32(cmdKey | shiftKey),
                  handler: @escaping () -> Void) {
        self.handler = handler

        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(0x494E4653) // "INFS"
        hotKeyID.id = 1

        // Install event handler
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: UInt32(kEventHotKeyPressed))

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData else { return OSStatus(eventNotHandledErr) }
                let mgr = Unmanaged<GlobalShortcutManager>.fromOpaque(userData).takeUnretainedValue()
                mgr.handler?()
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            nil
        )

        RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                           GetApplicationEventTarget(), 0, &hotKeyRef)
    }

    func unregister() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
}
