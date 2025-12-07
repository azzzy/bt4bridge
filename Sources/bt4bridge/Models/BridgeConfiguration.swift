import Foundation

/// Output mode for the bridge
public enum OutputMode: String, Codable, CaseIterable {
    case midi = "MIDI"
    case keyboard = "Keyboard"
    case both = "Both"
}

/// Keyboard key codes for macOS
public enum KeyCode: UInt16 {
    // Arrow keys
    case leftArrow = 123
    case rightArrow = 124
    case downArrow = 125
    case upArrow = 126
    
    // Common keys
    case space = 49
    case returnKey = 36
    case escape = 53
    case tab = 48
    case delete = 51
    
    // Function keys
    case f1 = 122
    case f2 = 120
    case f3 = 99
    case f4 = 118
    case f5 = 96
    case f6 = 97
    case f7 = 98
    case f8 = 100
    case f9 = 101
    case f10 = 109
    case f11 = 103
    case f12 = 111
    
    // Number keys
    case key1 = 18
    case key2 = 19
    case key3 = 20
    case key4 = 21
    
    // Letters (common for shortcuts)
    case a = 0
    case b = 11
    case c = 8
    case d = 2
    case e = 14
    case f = 3
    case g = 5
    case h = 4
    case i = 34
    case j = 38
    case k = 40
    case l = 37
    case m = 46
    case n = 45
    case o = 31
    case p = 35
    case q = 12
    case r = 15
    case s = 1
    case t = 17
    case u = 32
    case v = 9
    case w = 13
    case x = 7
    case y = 16
    case z = 6
}

/// Modifier keys for keyboard events
public struct KeyModifiers: OptionSet, Codable {
    public let rawValue: UInt64
    
    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }
    
    public static let command = KeyModifiers(rawValue: 1 << 0)  // Cmd
    public static let shift = KeyModifiers(rawValue: 1 << 1)    // Shift
    public static let option = KeyModifiers(rawValue: 1 << 2)   // Alt/Option
    public static let control = KeyModifiers(rawValue: 1 << 3)  // Ctrl
}

/// Keyboard action for a button
public struct KeyboardAction: Codable {
    public let keyCode: UInt16
    public let modifiers: KeyModifiers
    
    public init(keyCode: KeyCode, modifiers: KeyModifiers = []) {
        self.keyCode = keyCode.rawValue
        self.modifiers = modifiers
    }
    
    public init(keyCodeValue: UInt16, modifiers: KeyModifiers = []) {
        self.keyCode = keyCodeValue
        self.modifiers = modifiers
    }
}

/// Configuration for the PG_BT4 bridge
@available(macOS 12.0, *)
public actor BridgeConfiguration {
    
    // MARK: - Output Mode
    
    private var currentMode: OutputMode = .midi
    
    /// Get current output mode
    public func getMode() -> OutputMode {
        return currentMode
    }
    
    /// Set output mode
    public func setMode(_ mode: OutputMode) {
        currentMode = mode
    }
    
    // MARK: - Keyboard Mappings
    
    /// Default keyboard mappings for buttons 1-4
    private var keyboardMappings: [Int: KeyboardAction] = [
        1: KeyboardAction(keyCode: .space),
        2: KeyboardAction(keyCode: .rightArrow),
        3: KeyboardAction(keyCode: .upArrow),
        4: KeyboardAction(keyCode: .downArrow)
    ]
    
    /// Get keyboard action for a button
    public func getKeyboardAction(for button: Int) -> KeyboardAction? {
        return keyboardMappings[button]
    }
    
    /// Set keyboard action for a button
    public func setKeyboardAction(for button: Int, action: KeyboardAction) {
        keyboardMappings[button] = action
    }
    
    /// Reset to default keyboard mappings
    public func resetKeyboardMappings() {
        keyboardMappings = [
            1: KeyboardAction(keyCode: .space),
            2: KeyboardAction(keyCode: .rightArrow),
            3: KeyboardAction(keyCode: .upArrow),
            4: KeyboardAction(keyCode: .downArrow)
        ]
    }
    
    /// Get all keyboard mappings
    public func getAllKeyboardMappings() -> [Int: KeyboardAction] {
        return keyboardMappings
    }
}
