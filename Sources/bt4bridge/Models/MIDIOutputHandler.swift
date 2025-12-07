import Foundation

/// Handles MIDI output for button events
@available(macOS 12.0, *)
public actor MIDIOutputHandler: OutputHandler {
    
    private weak var midiPortManager: MIDIPortManager?
    
    public init(midiPortManager: MIDIPortManager) {
        self.midiPortManager = midiPortManager
    }
    
    public func handleButtonEvent(button: Int, pressed: Bool) async {
        // Convert button (1-4) to MIDI CC (80-83)
        let controller: UInt8 = UInt8(79 + button)
        let value: UInt8 = pressed ? 127 : 0
        
        let message = MIDIMessage.controlChange(channel: 0, controller: controller, value: value)
        
        await Logger.shared.trace("MIDI: Button \(button) \(pressed ? "pressed" : "released") -> CC\(controller)=\(value)", category: .midi)
        
        // Send immediately (button events don't need coalescing)
        do {
            try await midiPortManager?.sendToDAW(message)
        } catch {
            await Logger.shared.error("Failed to send MIDI to DAW: \(error)", category: .midi)
        }
    }
    
    public func shouldHandle(mode: OutputMode) -> Bool {
        return mode == .midi || mode == .both
    }
}
