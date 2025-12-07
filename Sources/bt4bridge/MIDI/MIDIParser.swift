import Foundation

/// Parser for converting raw MIDI bytes into MIDIMessage objects
public struct MIDIParser: Sendable {
    
    /// Error types that can occur during parsing
    public enum ParserError: Error, LocalizedError {
        case invalidStatusByte(UInt8)
        case insufficientData(expected: Int, got: Int)
        case invalidChannelMessage
        case invalidDataByte(UInt8)
        case unsupportedMessage(status: UInt8)
        
        public var errorDescription: String? {
            switch self {
            case .invalidStatusByte(let byte):
                return "Invalid MIDI status byte: 0x\(String(byte, radix: 16))"
            case .insufficientData(let expected, let got):
                return "Insufficient data: expected \(expected) bytes, got \(got)"
            case .invalidChannelMessage:
                return "Invalid channel message format"
            case .invalidDataByte(let byte):
                return "Invalid MIDI data byte (>127): \(byte)"
            case .unsupportedMessage(let status):
                return "Unsupported MIDI message type: 0x\(String(status, radix: 16))"
            }
        }
    }
    
    /// Parse a single MIDI message from raw bytes
    /// - Parameter data: Raw MIDI bytes
    /// - Returns: Parsed MIDIMessage
    /// - Throws: ParserError if parsing fails
    public static func parse(_ data: Data) throws -> MIDIMessage {
        guard !data.isEmpty else {
            throw ParserError.insufficientData(expected: 1, got: 0)
        }
        
        let statusByte = data[0]
        
        // Check if it's a valid status byte (MSB must be 1)
        guard statusByte & 0x80 == 0x80 else {
            throw ParserError.invalidStatusByte(statusByte)
        }
        
        let messageType = statusByte & 0xF0
        let channel = statusByte & 0x0F
        
        switch messageType {
        case 0xB0: // Control Change
            guard data.count >= 3 else {
                throw ParserError.insufficientData(expected: 3, got: data.count)
            }
            let controller = data[1]
            let value = data[2]
            
            // Validate data bytes
            guard controller <= 127 else {
                throw ParserError.invalidDataByte(controller)
            }
            guard value <= 127 else {
                throw ParserError.invalidDataByte(value)
            }
            
            return .controlChange(channel: channel, controller: controller, value: value)
            
        case 0xC0: // Program Change
            guard data.count >= 2 else {
                throw ParserError.insufficientData(expected: 2, got: data.count)
            }
            let program = data[1]
            
            // Validate data byte
            guard program <= 127 else {
                throw ParserError.invalidDataByte(program)
            }
            
            return .programChange(channel: channel, program: program)
            
        case 0x90: // Note On
            guard data.count >= 3 else {
                throw ParserError.insufficientData(expected: 3, got: data.count)
            }
            let note = data[1]
            let velocity = data[2]
            
            // Validate data bytes
            guard note <= 127 else {
                throw ParserError.invalidDataByte(note)
            }
            guard velocity <= 127 else {
                throw ParserError.invalidDataByte(velocity)
            }
            
            return .noteOn(channel: channel, note: note, velocity: velocity)
            
        case 0x80: // Note Off
            guard data.count >= 3 else {
                throw ParserError.insufficientData(expected: 3, got: data.count)
            }
            let note = data[1]
            let velocity = data[2]
            
            // Validate data bytes
            guard note <= 127 else {
                throw ParserError.invalidDataByte(note)
            }
            guard velocity <= 127 else {
                throw ParserError.invalidDataByte(velocity)
            }
            
            return .noteOff(channel: channel, note: note, velocity: velocity)
            
        case 0xF0: // System Exclusive
            // Find the end of SysEx (0xF7)
            if let endIndex = data.firstIndex(of: 0xF7) {
                let sysexData = data[0...endIndex]
                return .systemExclusive(data: sysexData)
            } else {
                // Incomplete SysEx, return what we have
                return .systemExclusive(data: data)
            }
            
        default:
            throw ParserError.unsupportedMessage(status: statusByte)
        }
    }
    
    /// Parse multiple MIDI messages from a buffer
    /// - Parameter data: Buffer containing one or more MIDI messages
    /// - Returns: Array of parsed messages and any remaining unparsed bytes
    public static func parseMultiple(_ data: Data) -> (messages: [MIDIMessage], remaining: Data) {
        var messages: [MIDIMessage] = []
        var position = 0
        
        while position < data.count {
            // Look for status byte
            guard position < data.count, data[position] & 0x80 == 0x80 else {
                position += 1
                continue
            }
            
            let statusByte = data[position]
            let messageType = statusByte & 0xF0
            
            // Determine message length
            var messageLength = 0
            switch messageType {
            case 0xC0, 0xD0: // Program Change, Channel Pressure
                messageLength = 2
            case 0x80, 0x90, 0xA0, 0xB0, 0xE0: // Note Off/On, Aftertouch, CC, Pitch Bend
                messageLength = 3
            case 0xF0: // System Exclusive
                // Find end of SysEx
                if let endIndex = data[position...].firstIndex(of: 0xF7) {
                    messageLength = endIndex - position + 1
                } else {
                    // Incomplete SysEx, stop parsing
                    break
                }
            default:
                // Unknown message, skip
                position += 1
                continue
            }
            
            // Skip if we couldn't determine message length
            if messageLength == 0 {
                break
            }
            
            // Check if we have enough data
            guard position + messageLength <= data.count else {
                break
            }
            
            // Extract and parse message
            let messageData = data[position..<(position + messageLength)]
            if let message = try? parse(messageData) {
                messages.append(message)
            }
            
            position += messageLength
        }
        
        let remaining = position < data.count ? data[position...] : Data()
        return (messages, Data(remaining))
    }
    
    /// Optimized parsing for CC/PC messages only (PG_BT4 focus)
    /// - Parameter data: Raw MIDI bytes
    /// - Returns: Parsed message if it's CC or PC, nil otherwise
    public static func parseCCOrPC(_ data: Data) -> MIDIMessage? {
        guard data.count >= 2 else { return nil }
        
        let statusByte = data[0]
        guard statusByte & 0x80 == 0x80 else { return nil }
        
        let messageType = statusByte & 0xF0
        let channel = statusByte & 0x0F
        
        switch messageType {
        case 0xB0: // Control Change
            guard data.count >= 3 else { return nil }
            let controller = data[1]
            let value = data[2]
            guard controller <= 127, value <= 127 else { return nil }
            return .controlChange(channel: channel, controller: controller, value: value)
            
        case 0xC0: // Program Change
            let program = data[1]
            guard program <= 127 else { return nil }
            return .programChange(channel: channel, program: program)
            
        default:
            return nil
        }
    }
}