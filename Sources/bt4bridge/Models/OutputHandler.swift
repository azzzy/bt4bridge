import Foundation

/// Protocol for handling output events from button presses
@available(macOS 12.0, *)
public protocol OutputHandler: Actor {
    
    /// Handle a button event
    /// - Parameters:
    ///   - button: Button number (1-4)
    ///   - pressed: true = button pressed, false = button released
    func handleButtonEvent(button: Int, pressed: Bool) async
    
    /// Check if this handler should process events for the given mode
    /// - Parameter mode: Current output mode
    /// - Returns: true if this handler should be active
    func shouldHandle(mode: OutputMode) -> Bool
    
    /// Perform any initialization needed
    func initialize() async
    
    /// Perform any cleanup needed
    func cleanup() async
}

/// Default implementations
@available(macOS 12.0, *)
extension OutputHandler {
    public func initialize() async {}
    public func cleanup() async {}
}
