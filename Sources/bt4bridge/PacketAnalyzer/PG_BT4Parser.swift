import Foundation

/// Parser for PG_BT4 proprietary protocol
public struct PG_BT4Parser {
    
    /// Parse PG_BT4 data packet and convert to MIDI
    /// - Parameter data: Raw data from PG_BT4
    /// - Returns: MIDI message if successful
    public static func parse(_ data: Data) -> MIDIMessage? {
        // PG_BT4 protocol: [B1] [switch] [state]
        // B1 = header/prefix
        // Switch: 0x10-0x13 = Switch 1-4
        // State: 0x00 = Pressed, 0x01 = Released (REVERSED LOGIC!)
        
        guard data.count >= 3 else { return nil }
        guard data[0] == 0xB1 else { return nil }  // Check for B1 header
        
        let switchNumber = data[1]
        let state = data[2]
        
        // Map to MIDI Control Change messages
        // Switch 1-4 -> CC 80-83 (general purpose controllers)
        // PG_BT4 uses reversed logic: 0x00 = pressed, 0x01 = released
        let value: UInt8 = (state == 0x00) ? 127 : 0  // Pressed = 127, Released = 0
        
        // Calculate CC number based on switch
        let ccNumber: UInt8
        switch switchNumber {
        case 0x10: ccNumber = 80  // Switch 1 -> CC 80
        case 0x11: ccNumber = 81  // Switch 2 -> CC 81
        case 0x12: ccNumber = 82  // Switch 3 -> CC 82
        case 0x13: ccNumber = 83  // Switch 4 -> CC 83
        default: return nil
        }
        
        // Create MIDI CC message on channel 0
        return .controlChange(channel: 0, controller: ccNumber, value: value)
    }
    
    /// Convert MIDI message back to PG_BT4 format (for bidirectional communication)
    /// - Parameter message: MIDI message
    /// - Returns: PG_BT4 data packet if applicable
    public static func toData(_ message: MIDIMessage) -> Data? {
        guard case .controlChange(_, let controller, let value) = message else {
            return nil
        }
        
        // Map CC numbers back to switch numbers
        let switchNumber: UInt8
        switch controller {
        case 80: switchNumber = 0x10  // CC 80 -> Switch 1
        case 81: switchNumber = 0x11  // CC 81 -> Switch 2
        case 82: switchNumber = 0x12  // CC 82 -> Switch 3
        case 83: switchNumber = 0x13  // CC 83 -> Switch 4
        default: return nil
        }
        
        // Convert MIDI value to on/off
        let state: UInt8 = (value >= 64) ? 0x01 : 0x00
        
        // PG_BT4 format: [B1] [switch] [state]
        return Data([0xB1, switchNumber, state])
    }
    
    /// Create LED control packet
    /// - Parameters:
    ///   - switchNumber: Switch number (0x10-0x13)
    ///   - ledState: LED state (true = ON, false = OFF)
    /// - Returns: PG_BT4 data packet for LED control
    public static func createLEDPacket(switchNumber: UInt8, ledState: Bool) -> Data {
        // Try 0xFF for ON instead of 0x01 (since 0x00 for OFF works)
        let state: UInt8 = ledState ? 0xFF : 0x00
        return Data([0xB1, switchNumber, state])
    }
    
    /// Get human-readable description of PG_BT4 packet
    public static func describe(_ data: Data) -> String? {
        guard data.count >= 3 else { return nil }
        guard data[0] == 0xB1 else { return nil }
        
        let switchNum = data[1] - 0x10 + 1  // Convert to 1-4
        let state = (data[2] == 0x00) ? "PRESSED" : "RELEASED"  // Reversed logic
        
        return "Switch \(switchNum): \(state)"
    }
    
    /// Extract switch number from packet
    public static func getSwitchNumber(_ data: Data) -> UInt8? {
        guard data.count >= 3 else { return nil }
        guard data[0] == 0xB1 else { return nil }
        return data[1]
    }
    
    /// Check if packet is a button press (not release)
    public static func isButtonPress(_ data: Data) -> Bool {
        guard data.count >= 3 else { return false }
        return data[2] == 0x00  // Reversed logic: 0x00 = pressed
    }
}

/// LED state tracker for PG_BT4
public actor PG_BT4LEDState {
    private var ledStates: [UInt8: Bool] = [:]  // switchNumber -> LED state
    
    /// Toggle LED state for a switch
    /// - Parameter switchNumber: Switch number (0x10-0x13)
    /// - Returns: New LED state
    public func toggle(_ switchNumber: UInt8) -> Bool {
        let currentState = ledStates[switchNumber] ?? false
        let newState = !currentState
        ledStates[switchNumber] = newState
        return newState
    }
    
    /// Get current LED state
    /// - Parameter switchNumber: Switch number (0x10-0x13)
    /// - Returns: Current LED state
    public func getState(_ switchNumber: UInt8) -> Bool {
        return ledStates[switchNumber] ?? false
    }
    
    /// Set LED state directly
    /// - Parameters:
    ///   - switchNumber: Switch number (0x10-0x13)
    ///   - state: New state
    public func setState(_ switchNumber: UInt8, _ state: Bool) {
        ledStates[switchNumber] = state
    }
}