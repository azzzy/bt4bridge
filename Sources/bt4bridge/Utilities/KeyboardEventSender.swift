import Foundation
import CoreGraphics
import ApplicationServices

/// Sends keyboard events to macOS
@available(macOS 12.0, *)
public actor KeyboardEventSender {
    
    /// Send a key press (down + up)
    /// - Parameters:
    ///   - action: The keyboard action to perform
    public func sendKeyPress(_ action: KeyboardAction) async {
        await Logger.shared.debug("Sending key: \(action.keyCode) with modifiers: \(action.modifiers.rawValue)", category: .keyboard)
        
        // Convert our modifiers to CGEventFlags
        var flags: CGEventFlags = []
        if action.modifiers.contains(.command) {
            flags.insert(.maskCommand)
        }
        if action.modifiers.contains(.shift) {
            flags.insert(.maskShift)
        }
        if action.modifiers.contains(.option) {
            flags.insert(.maskAlternate)
        }
        if action.modifiers.contains(.control) {
            flags.insert(.maskControl)
        }
        
        // Create key down event
        guard let keyDownEvent = CGEvent(keyboardEventSource: nil, virtualKey: action.keyCode, keyDown: true) else {
            await Logger.shared.error("Failed to create key down event for keyCode: \(action.keyCode)", category: .keyboard)
            return
        }
        
        // Set modifiers
        keyDownEvent.flags = flags
        
        // Create key up event
        guard let keyUpEvent = CGEvent(keyboardEventSource: nil, virtualKey: action.keyCode, keyDown: false) else {
            await Logger.shared.error("Failed to create key up event for keyCode: \(action.keyCode)", category: .keyboard)
            return
        }
        
        // Set modifiers
        keyUpEvent.flags = flags
        
        // Post events
        keyDownEvent.post(tap: .cghidEventTap)
        
        // Small delay between down and up (10ms)
        try? await Task.sleep(nanoseconds: 10_000_000)
        
        keyUpEvent.post(tap: .cghidEventTap)
        
        await Logger.shared.trace("Key event sent successfully", category: .keyboard)
    }
    
    /// Check if the app has accessibility permissions (required for keyboard events)
    public func checkAccessibilityPermissions() -> Bool {
        // Check if process is trusted (has accessibility permissions)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }
}
