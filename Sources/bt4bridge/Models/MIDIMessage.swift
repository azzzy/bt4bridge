import Foundation

/// MIDI message types supported by PG_BT4
public enum MIDIMessage: Equatable, Sendable {
    /// Control Change message
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    
    /// Program Change message
    case programChange(channel: UInt8, program: UInt8)
    
    /// System Exclusive message (for future expansion)
    case systemExclusive(data: Data)
    
    /// Note On message (for future expansion)
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    
    /// Note Off message (for future expansion)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    
    // MARK: - Properties
    
    /// The MIDI channel (0-15) for channel messages
    public var channel: UInt8? {
        switch self {
        case .controlChange(let channel, _, _),
             .programChange(let channel, _),
             .noteOn(let channel, _, _),
             .noteOff(let channel, _, _):
            return channel
        case .systemExclusive:
            return nil
        }
    }
    
    /// The status byte for this message
    public var statusByte: UInt8 {
        switch self {
        case .controlChange(let channel, _, _):
            return 0xB0 | (channel & 0x0F)
        case .programChange(let channel, _):
            return 0xC0 | (channel & 0x0F)
        case .systemExclusive:
            return 0xF0
        case .noteOn(let channel, _, _):
            return 0x90 | (channel & 0x0F)
        case .noteOff(let channel, _, _):
            return 0x80 | (channel & 0x0F)
        }
    }
    
    /// Returns true if this is a Control Change message
    public var isControlChange: Bool {
        if case .controlChange = self { return true }
        return false
    }
    
    /// Returns true if this is a Program Change message
    public var isProgramChange: Bool {
        if case .programChange = self { return true }
        return false
    }
    
    // MARK: - Validation
    
    /// Validates channel number (0-15)
    public static func validateChannel(_ channel: UInt8) -> Bool {
        return channel <= 15
    }
    
    /// Validates MIDI data byte (0-127)
    public static func validateDataByte(_ value: UInt8) -> Bool {
        return value <= 127
    }
    
    /// Validates controller number (0-127)
    public static func validateController(_ controller: UInt8) -> Bool {
        return controller <= 127
    }
    
    /// Validates program number (0-127)
    public static func validateProgram(_ program: UInt8) -> Bool {
        return program <= 127
    }
}

// MARK: - CustomStringConvertible

extension MIDIMessage: CustomStringConvertible {
    public var description: String {
        switch self {
        case .controlChange(let channel, let controller, let value):
            return "CC[ch:\(channel) ctrl:\(controller) val:\(value)]"
        case .programChange(let channel, let program):
            return "PC[ch:\(channel) prog:\(program)]"
        case .systemExclusive(let data):
            return "SysEx[\(data.count) bytes]"
        case .noteOn(let channel, let note, let velocity):
            return "NoteOn[ch:\(channel) note:\(note) vel:\(velocity)]"
        case .noteOff(let channel, let note, let velocity):
            return "NoteOff[ch:\(channel) note:\(note) vel:\(velocity)]"
        }
    }
}

// MARK: - Serialization

public extension MIDIMessage {
    /// Convert message to raw MIDI bytes
    /// - Returns: Data containing the MIDI message bytes
    func toData() -> Data {
        switch self {
        case .controlChange(let channel, let controller, let value):
            return Data([
                0xB0 | (channel & 0x0F),
                controller & 0x7F,
                value & 0x7F
            ])
            
        case .programChange(let channel, let program):
            return Data([
                0xC0 | (channel & 0x0F),
                program & 0x7F
            ])
            
        case .systemExclusive(let data):
            // Ensure SysEx starts with 0xF0 and ends with 0xF7
            var result = data
            if result.isEmpty || result[0] != 0xF0 {
                result.insert(0xF0, at: 0)
            }
            if result.last != 0xF7 {
                result.append(0xF7)
            }
            return result
            
        case .noteOn(let channel, let note, let velocity):
            return Data([
                0x90 | (channel & 0x0F),
                note & 0x7F,
                velocity & 0x7F
            ])
            
        case .noteOff(let channel, let note, let velocity):
            return Data([
                0x80 | (channel & 0x0F),
                note & 0x7F,
                velocity & 0x7F
            ])
        }
    }
    
    /// Get the raw bytes as an array
    /// - Returns: Array of UInt8 bytes
    func toBytes() -> [UInt8] {
        return Array(toData())
    }
    
    /// Get the message length in bytes
    var byteLength: Int {
        switch self {
        case .controlChange:
            return 3
        case .programChange:
            return 2
        case .systemExclusive(let data):
            var length = data.count
            if data.isEmpty || data[0] != 0xF0 { length += 1 }
            if data.last != 0xF7 { length += 1 }
            return length
        case .noteOn, .noteOff:
            return 3
        }
    }
}

// MARK: - Common CC Controllers

public extension MIDIMessage {
    /// Common MIDI CC controller numbers
    enum Controller {
        public static let modWheel: UInt8 = 1
        public static let breath: UInt8 = 2
        public static let footController: UInt8 = 4
        public static let portamentoTime: UInt8 = 5
        public static let dataEntry: UInt8 = 6
        public static let volume: UInt8 = 7
        public static let balance: UInt8 = 8
        public static let pan: UInt8 = 10
        public static let expression: UInt8 = 11
        public static let sustainPedal: UInt8 = 64
        public static let portamentoOnOff: UInt8 = 65
        public static let sostenutoPedal: UInt8 = 66
        public static let softPedal: UInt8 = 67
        public static let allSoundOff: UInt8 = 120
        public static let resetAllControllers: UInt8 = 121
        public static let allNotesOff: UInt8 = 123
    }
}