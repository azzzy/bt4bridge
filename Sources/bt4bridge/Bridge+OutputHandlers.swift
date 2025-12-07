import Foundation

/// Bridge extension for output handler support
@available(macOS 12.0, *)
extension Bridge {
    
    /// Configuration for output mode and keyboard mappings
    public static var sharedConfiguration = BridgeConfiguration()
    
    /// Keyboard event sender
    internal static var sharedKeyboardSender = KeyboardEventSender()
    
    /// Output handlers array
    internal static var sharedOutputHandlers: [any OutputHandler] = []
    
    // MARK: - Initialization
    
    /// Initialize output handlers (call during bridge start)
    internal func initializeOutputHandlers(midiPortManager: MIDIPortManager) async {
        let midiHandler = MIDIOutputHandler(midiPortManager: midiPortManager)
        let keyboardHandler = KeyboardOutputHandler(
            keyboardSender: Bridge.sharedKeyboardSender,
            configuration: Bridge.sharedConfiguration
        )
        
        Bridge.sharedOutputHandlers = [midiHandler, keyboardHandler]
        
        // Initialize all handlers
        for handler in Bridge.sharedOutputHandlers {
            await handler.initialize()
        }
    }
    
    // MARK: - Configuration Methods
    
    /// Set output mode (MIDI, Keyboard, or Both)
    public func setOutputMode(_ mode: OutputMode) async {
        await Bridge.sharedConfiguration.setMode(mode)
        await Logger.shared.info("Output mode set to: \(mode.rawValue)", category: .bridge)
    }
    
    /// Get current output mode
    public func getOutputMode() async -> OutputMode {
        return await Bridge.sharedConfiguration.getMode()
    }
    
    /// Set keyboard mapping for a button
    public func setKeyboardMapping(button: Int, action: KeyboardAction) async {
        await Bridge.sharedConfiguration.setKeyboardAction(for: button, action: action)
        await Logger.shared.info("Button \(button) mapped to keyCode: \(action.keyCode)", category: .bridge)
    }
    
    /// Get keyboard mapping for a button
    public func getKeyboardMapping(button: Int) async -> KeyboardAction? {
        return await Bridge.sharedConfiguration.getKeyboardAction(for: button)
    }
    
    // MARK: - Event Handling
    
    /// Handle button event through output handlers
    internal func dispatchButtonEvent(button: Int, pressed: Bool) async {
        let mode = await Bridge.sharedConfiguration.getMode()
        for handler in Bridge.sharedOutputHandlers {
            if await handler.shouldHandle(mode: mode) {
                await handler.handleButtonEvent(button: button, pressed: pressed)
            }
        }
    }
}
