import AppKit
import Carbon.HIToolbox
import SnapTexCore

final class GlobalHotKeyController {
    var action: (() -> Void)?

    private let hotKeyID: UInt32
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    init(hotKeyID: UInt32 = 1) {
        self.hotKeyID = hotKeyID
    }

    deinit {
        unregister()
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    @discardableResult
    func register(_ shortcut: GlobalKeyboardShortcut) -> Bool {
        unregister()
        guard shortcut.canRegisterGlobally else {
            return false
        }

        installEventHandlerIfNeeded()

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: self.hotKeyID)
        let status = RegisterEventHotKey(
            UInt32(shortcut.keyCode),
            shortcut.modifiers.carbonFlags,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        return status == noErr
    }

    private func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
    }

    private func installEventHandlerIfNeeded() {
        guard eventHandlerRef == nil else {
            return
        }

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let userData else {
                    return OSStatus(eventNotHandledErr)
                }
                let controller = Unmanaged<GlobalHotKeyController>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                return controller.handle(event: event)
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandlerRef
        )
    }

    private func handle(event: EventRef?) -> OSStatus {
        var hotKeyID = EventHotKeyID(signature: 0, id: 0)
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )

        guard status == noErr,
              hotKeyID.signature == Self.signature,
              hotKeyID.id == self.hotKeyID else {
            return OSStatus(eventNotHandledErr)
        }

        DispatchQueue.main.async { [weak self] in
            self?.action?()
        }
        return noErr
    }

    private static let signature: OSType = 0x534E_5058
}

extension KeyboardShortcutModifiers {
    init(eventModifierFlags: NSEvent.ModifierFlags) {
        var modifiers: KeyboardShortcutModifiers = []
        if eventModifierFlags.contains(.command) {
            modifiers.insert(.command)
        }
        if eventModifierFlags.contains(.shift) {
            modifiers.insert(.shift)
        }
        if eventModifierFlags.contains(.option) {
            modifiers.insert(.option)
        }
        if eventModifierFlags.contains(.control) {
            modifiers.insert(.control)
        }
        self = modifiers
    }

    var carbonFlags: UInt32 {
        var flags: UInt32 = 0
        if contains(.command) {
            flags |= UInt32(cmdKey)
        }
        if contains(.shift) {
            flags |= UInt32(shiftKey)
        }
        if contains(.option) {
            flags |= UInt32(optionKey)
        }
        if contains(.control) {
            flags |= UInt32(controlKey)
        }
        return flags
    }
}
