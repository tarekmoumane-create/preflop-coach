import Carbon.HIToolbox

/// A system-wide hotkey. Carbon's hotkey API needs no Accessibility permission.
final class HotKey {
    private static var handlers: [UInt32: () -> Void] = [:]
    private static var installed = false
    private var ref: EventHotKeyRef?

    /// `keyCode` is a virtual key (kVK_ANSI_P), `modifiers` Carbon flags (controlKey | optionKey).
    init(keyCode: Int, modifiers: Int, handler: @escaping () -> Void) {
        let id = UInt32(HotKey.handlers.count + 1)
        HotKey.handlers[id] = handler

        if !HotKey.installed {
            HotKey.installed = true
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
                var pressed = EventHotKeyID()
                GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                                  nil, MemoryLayout<EventHotKeyID>.size, nil, &pressed)
                HotKey.handlers[pressed.id]?()
                return noErr
            }, 1, &spec, nil, nil)
        }

        // 'PFLP'
        let hotKeyID = EventHotKeyID(signature: OSType(0x5046_4C50), id: id)
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), hotKeyID, GetApplicationEventTarget(), 0, &ref)
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
    }
}
