import AppKit
import SwiftUI
import SnapTexCore

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: GlobalKeyboardShortcut

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.shortcut = shortcut
        button.onChange = { newShortcut in
            shortcut = newShortcut
        }
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
    }
}

final class ShortcutRecorderButton: NSButton {
    var onChange: ((GlobalKeyboardShortcut) -> Void)?
    var shortcut = GlobalKeyboardShortcut.defaultSnip {
        didSet {
            if !isRecording {
                updateTitle()
            }
        }
    }

    private var isRecording = false

    override var acceptsFirstResponder: Bool {
        true
    }

    init() {
        super.init(frame: .zero)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        updateTitle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        updateTitle()
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }
        record(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard isRecording else {
            return super.performKeyEquivalent(with: event)
        }
        record(event)
        return true
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        updateTitle()
        return super.resignFirstResponder()
    }

    @objc private func beginRecording() {
        isRecording = true
        title = "Press shortcut"
        window?.makeFirstResponder(self)
    }

    private func record(_ event: NSEvent) {
        if event.keyCode == 53 {
            isRecording = false
            updateTitle()
            window?.makeFirstResponder(nil)
            return
        }

        let modifiers = KeyboardShortcutModifiers(eventModifierFlags: event.modifierFlags)
        guard !modifiers.isEmpty else {
            NSSound.beep()
            return
        }

        let newShortcut = GlobalKeyboardShortcut(keyCode: event.keyCode, modifiers: modifiers)
        shortcut = newShortcut
        onChange?(newShortcut)
        isRecording = false
        updateTitle()
        window?.makeFirstResponder(nil)
    }

    private func updateTitle() {
        title = shortcut.displayText
    }
}
