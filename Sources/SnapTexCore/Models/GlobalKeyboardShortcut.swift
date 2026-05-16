import Foundation

public struct KeyboardShortcutModifiers: OptionSet, Codable, Equatable, Sendable {
    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let command = KeyboardShortcutModifiers(rawValue: 1 << 0)
    public static let shift = KeyboardShortcutModifiers(rawValue: 1 << 1)
    public static let option = KeyboardShortcutModifiers(rawValue: 1 << 2)
    public static let control = KeyboardShortcutModifiers(rawValue: 1 << 3)

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(rawValue: try container.decode(UInt.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }

    public var displayText: String {
        var text = ""
        if contains(.command) {
            text += "⌘"
        }
        if contains(.shift) {
            text += "⇧"
        }
        if contains(.option) {
            text += "⌥"
        }
        if contains(.control) {
            text += "⌃"
        }
        return text
    }
}

public struct GlobalKeyboardShortcut: Codable, Equatable, Sendable {
    public var keyCode: UInt16
    public var modifiers: KeyboardShortcutModifiers

    public init(keyCode: UInt16, modifiers: KeyboardShortcutModifiers) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    public static let defaultSnip = GlobalKeyboardShortcut(
        keyCode: 1,
        modifiers: [.command, .shift]
    )

    public static let defaultOpenApp = GlobalKeyboardShortcut(
        keyCode: 31,
        modifiers: [.command, .shift]
    )

    public var displayText: String {
        "\(modifiers.displayText)\(Self.keyName(for: keyCode))"
    }

    public var canRegisterGlobally: Bool {
        !modifiers.isEmpty
    }

    public static func keyName(for keyCode: UInt16) -> String {
        keyNames[keyCode] ?? "Key \(keyCode)"
    }

    private static let keyNames: [UInt16: String] = [
        0: "A",
        1: "S",
        2: "D",
        3: "F",
        4: "H",
        5: "G",
        6: "Z",
        7: "X",
        8: "C",
        9: "V",
        11: "B",
        12: "Q",
        13: "W",
        14: "E",
        15: "R",
        16: "Y",
        17: "T",
        18: "1",
        19: "2",
        20: "3",
        21: "4",
        22: "6",
        23: "5",
        25: "9",
        26: "7",
        28: "8",
        29: "0",
        31: "O",
        32: "U",
        34: "I",
        35: "P",
        37: "L",
        38: "J",
        40: "K",
        45: "N",
        46: "M",
        49: "Space",
        51: "Delete",
        53: "Esc",
        123: "←",
        124: "→",
        125: "↓",
        126: "↑"
    ]
}
