import Foundation

/// Handles keyboard output for button events
@available(macOS 12.0, *)
public actor KeyboardOutputHandler: OutputHandler {
    
    private let keyboardSender: KeyboardEventSender
    private let configuration: BridgeConfiguration
    private var permissionsChecked = false
    
    public init(keyboardSender: KeyboardEventSender, configuration: BridgeConfiguration) {
        self.keyboardSender = keyboardSender
        self.configuration = configuration
    }
    
    public func handleButtonEvent(button: Int, pressed: Bool) async {
        // Only send key events on button press (not release)
        guard pressed else { return }
        
        // Check permissions on first use
        if !permissionsChecked {
            let hasPermissions = await keyboardSender.checkAccessibilityPermissions()
            if !hasPermissions {
                await Logger.shared.warning("⚠️  Accessibility permissions required for keyboard mode", category: .keyboard)
                await Logger.shared.warning("   Grant in: System Preferences > Privacy & Security > Accessibility", category: .keyboard)
            }
            permissionsChecked = true
        }
        
        // Get the keyboard action for this button
        if let action = await configuration.getKeyboardAction(for: button) {
            await Logger.shared.trace("Keyboard: Button \(button) pressed -> keyCode \(action.keyCode)", category: .keyboard)
            await keyboardSender.sendKeyPress(action)
        } else {
            await Logger.shared.warning("No keyboard mapping for button \(button)", category: .keyboard)
        }
    }
    
    public func shouldHandle(mode: OutputMode) -> Bool {
        return mode == .keyboard || mode == .both
    }
    
    public func initialize() async {
        // Check permissions when initializing
        let mode = await configuration.getMode()
        if mode == .keyboard || mode == .both {
            let hasPermissions = await keyboardSender.checkAccessibilityPermissions()
            if !hasPermissions {
                await Logger.shared.warning("⚠️  Accessibility permissions required for keyboard mode", category: .keyboard)
            }
            permissionsChecked = true
        }
    }
}
