import Foundation

/// LED Controller for PG_BT4 device
@available(macOS 12.0, *)
public actor LEDController {
    
    // MARK: - LED State
    
    /// Current LED states (true = ON, false = OFF)
    private var ledStates: [Int: Bool] = [
        1: false,
        2: false,
        3: false,
        4: false
    ]
    
    // MARK: - LED Control
    
    /// Set LED state
    /// - Parameters:
    ///   - led: LED number (1-4)
    ///   - state: true = ON, false = OFF
    /// - Returns: Command data to send to PG_BT4
    public func setLED(_ led: Int, state: Bool) -> Data? {
        guard (1...4).contains(led) else {
            return nil
        }
        
        // Update internal state
        ledStates[led] = state
        
        // LED command format discovered via PacketLogger:
        // A2 [LED_NUMBER] [STATE]
        // LED_NUMBER: 0x10=LED1, 0x11=LED2, 0x12=LED3, 0x13=LED4
        // STATE: 0x00=ON, 0x01=OFF (logic is REVERSED!)
        
        let ledNumber: UInt8 = 0x10 + UInt8(led - 1)
        let ledState: UInt8 = state ? 0x00 : 0x01  // Reversed: ON=0x00, OFF=0x01
        
        return Data([0xA2, ledNumber, ledState])
    }
    
    /// Get current LED state
    public func getLEDState(_ led: Int) -> Bool? {
        return ledStates[led]
    }
    
    /// Get all LED states
    public func getAllLEDStates() -> [Int: Bool] {
        return ledStates
    }
    
    /// Turn all LEDs off
    public func allLEDsOff() -> [Data] {
        var commands: [Data] = []
        for led in 1...4 {
            if let cmd = setLED(led, state: false) {
                commands.append(cmd)
            }
        }
        return commands
    }
    
    /// Turn all LEDs on
    public func allLEDsOn() -> [Data] {
        var commands: [Data] = []
        for led in 1...4 {
            if let cmd = setLED(led, state: true) {
                commands.append(cmd)
            }
        }
        return commands
    }
    
    // MARK: - MIDI CC Mapping
    
    /// Map MIDI CC to LED control
    /// - Parameters:
    ///   - controller: MIDI CC number
    ///   - value: MIDI CC value (0-127)
    /// - Returns: LED command if CC maps to an LED, nil otherwise
    public func handleMIDICC(controller: UInt8, value: UInt8) -> Data? {
        // Map MIDI CCs to LEDs
        // CC 16 = LED 1
        // CC 17 = LED 2
        // CC 18 = LED 3
        // CC 19 = LED 4
        
        let ledNumber: Int
        switch controller {
        case 16: ledNumber = 1
        case 17: ledNumber = 2
        case 18: ledNumber = 3
        case 19: ledNumber = 4
        default: return nil
        }
        
        // CC value >= 64 = ON, < 64 = OFF
        let state = value >= 64
        
        return setLED(ledNumber, state: state)
    }
}
