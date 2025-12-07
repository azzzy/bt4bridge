import Foundation
import CoreMIDI
import os

/// Actor responsible for managing virtual MIDI ports for bridging with PG_BT4
@available(macOS 12.0, *)
public actor MIDIPortManager {
    
    // MARK: - Properties
    
    /// MIDI client reference
    private var midiClient: MIDIClientRef = 0
    
    /// Virtual source port (sends to DAW)
    private var sourcePort: MIDIPortRef = 0
    
    /// Virtual destination port (receives from DAW)
    private var destinationPort: MIDIPortRef = 0
    
    /// Port name displayed in DAW
    private let portName = "PG_BT4 Bridge"
    
    /// Manufacturer name
    private let manufacturerName = "bt4bridge"
    
    /// Connection state
    public private(set) var isConnected = false
    
    /// Delegate for receiving MIDI from DAW
    public weak var delegate: MIDIPortManagerDelegate?
    
    /// Set the delegate
    public func setDelegate(_ newDelegate: MIDIPortManagerDelegate?) {
        self.delegate = newDelegate
    }
    
    /// Queue for MIDI operations
    private let midiQueue = DispatchQueue(label: "midi.port.queue", qos: .userInteractive)
    
    /// Packet buffer for sending MIDI
    private var packetBuffer: UnsafeMutablePointer<MIDIPacketList>?
    
    /// Statistics
    public private(set) var statistics = MIDIStatistics()
    
    public struct MIDIStatistics {
        var messagesSent: Int = 0
        var messagesReceived: Int = 0
        var ccMessagesSent: Int = 0
        var pcMessagesSent: Int = 0
        var ccMessagesReceived: Int = 0
        var pcMessagesReceived: Int = 0
        var lastActivityTime: Date?
        var connectionTime: Date?
    }
    
    // MARK: - Initialization
    
    public init() {
        // Allocate packet buffer
        let bufferSize = MemoryLayout<MIDIPacketList>.size + 256
        packetBuffer = UnsafeMutablePointer<MIDIPacketList>.allocate(capacity: bufferSize)
    }
    
    deinit {
        packetBuffer?.deallocate()
    }
    
    // MARK: - Public Methods
    
    /// Create virtual MIDI ports
    public func createPorts() async throws {
        guard !isConnected else {
            await logInfo("MIDI ports already created", category: .midi)
            return
        }
        
        await logInfo("Creating virtual MIDI ports", category: .midi)
        
        // Create MIDI client
        let clientName = "PG_BT4 Bridge Client" as CFString
        let status = MIDIClientCreateWithBlock(clientName, &midiClient) { [weak self] notification in
            Task {
                await self?.handleMIDINotification(notification)
            }
        }
        
        guard status == noErr else {
            await logError("Failed to create MIDI client: \(status)", category: .midi)
            throw MIDIError.clientCreationFailed(status)
        }
        
        // Create virtual source (sends to DAW)
        try await createSourcePort()
        
        // Create virtual destination (receives from DAW)
        try await createDestinationPort()
        
        isConnected = true
        statistics.connectionTime = Date()
        
        await logInfo("Virtual MIDI ports created successfully", category: .midi)
    }
    
    /// Destroy virtual MIDI ports
    public func destroyPorts() async {
        guard isConnected else { return }
        
        await logInfo("Destroying virtual MIDI ports", category: .midi)
        
        // Dispose ports
        if sourcePort != 0 {
            MIDIEndpointDispose(sourcePort)
            sourcePort = 0
        }
        
        if destinationPort != 0 {
            MIDIEndpointDispose(destinationPort)
            destinationPort = 0
        }
        
        // Dispose client
        if midiClient != 0 {
            MIDIClientDispose(midiClient)
            midiClient = 0
        }
        
        isConnected = false
        statistics.connectionTime = nil
        
        await logInfo("Virtual MIDI ports destroyed", category: .midi)
    }
    
    /// Send MIDI message to DAW
    public func sendToDAW(_ message: MIDIMessage) async throws {
        guard isConnected else {
            throw MIDIError.notConnected
        }
        
        guard sourcePort != 0 else {
            throw MIDIError.invalidPort
        }
        
        let data = message.toData()
        await logDebug("Sending to DAW: \(message)", category: .midi)
        
        // Convert MIDI to UMP format (Universal MIDI Packet)
        // Standard MIDI: [status] [data1] [data2]
        // UMP format: [data2] [data1] [status] [type]
        var umpWords: [UInt32] = []
        
        if data.count == 3 {
            let status = data[0]
            let data1 = data[1]
            let data2 = data[2]
            
            // Create UMP MIDI 1.0 Channel Voice Message (Type 2)
            let word = UInt32(data2) | (UInt32(data1) << 8) | (UInt32(status) << 16) | (UInt32(0x20) << 24)
            umpWords.append(word)
        } else {
            await logWarning("Unsupported MIDI message length: \(data.count)", category: .midi)
            return
        }
        
        // Create MIDIEventList with UMP packets
        let eventListSize = MemoryLayout<MIDIEventList>.size + umpWords.count * MemoryLayout<UInt32>.size
        let eventListPtr = UnsafeMutablePointer<UInt8>.allocate(capacity: eventListSize)
        defer { eventListPtr.deallocate() }
        
        eventListPtr.withMemoryRebound(to: MIDIEventList.self, capacity: 1) { listPtr in
            listPtr.pointee.protocol = MIDIProtocolID._1_0
            listPtr.pointee.numPackets = 1
            
            var packet = MIDIEventPacket()
            packet.timeStamp = 0
            packet.wordCount = UInt32(umpWords.count)
            packet.words.0 = umpWords[0]
            
            listPtr.pointee.packet = packet
            
            // Send the event list
            let status = MIDIReceivedEventList(sourcePort, listPtr)
            
            if status != noErr {
                Task {
                    await logError("Failed to send MIDI event: \(status)", category: .midi)
                }
            }
        }
        
        // Update statistics
        statistics.messagesSent += 1
        statistics.lastActivityTime = Date()
        
        switch message {
        case .controlChange:
            statistics.ccMessagesSent += 1
        case .programChange:
            statistics.pcMessagesSent += 1
        default:
            break
        }
    }
    
    /// Send raw MIDI data to DAW
    public func sendRawToDAW(_ data: Data) async throws {
        // Try to parse as MIDI message for statistics
        if let message = try? MIDIParser.parse(data) {
            try await sendToDAW(message)
        } else {
            // Send raw if parsing fails
            guard isConnected else {
                throw MIDIError.notConnected
            }
            
            guard sourcePort != 0 else {
                throw MIDIError.invalidPort
            }
            
            await logTrace("Sending raw data to DAW: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .midi)
            
            var packetList = MIDIPacketList()
            var packet = MIDIPacketListInit(&packetList)
            
            data.withUnsafeBytes { bytes in
                packet = MIDIPacketListAdd(
                    &packetList,
                    1024,
                    packet,
                    MIDITimeStamp(0),
                    data.count,
                    bytes.bindMemory(to: UInt8.self).baseAddress!
                )
            }
            
            let status = MIDIReceived(sourcePort, &packetList)
            
            guard status == noErr else {
                await logError("Failed to send raw MIDI to DAW: \(status)", category: .midi)
                throw MIDIError.sendFailed(status)
            }
            
            statistics.messagesSent += 1
            statistics.lastActivityTime = Date()
        }
    }
    
    /// Get current statistics
    public func getStatistics() -> MIDIStatistics {
        return statistics
    }
    
    /// Reset statistics
    public func resetStatistics() {
        statistics = MIDIStatistics()
        statistics.connectionTime = isConnected ? Date() : nil
    }
    
    // MARK: - Private Methods
    
    private func createSourcePort() async throws {
        let portName = self.portName as CFString
        
        let status = MIDISourceCreateWithProtocol(
            midiClient,
            portName,
            MIDIProtocolID._1_0,
            &sourcePort
        )
        
        guard status == noErr else {
            await logError("Failed to create source port: \(status)", category: .midi)
            throw MIDIError.portCreationFailed(status)
        }
        
        // Set port properties
        setPortProperties(sourcePort, isSource: true)
        
        await logInfo("Created virtual source port", category: .midi)
    }
    
    private func createDestinationPort() async throws {
        let portName = self.portName as CFString
        
        // Create destination with protocol API (works better with Swift actors)
        let status = MIDIDestinationCreateWithProtocol(
            midiClient,
            portName,
            MIDIProtocolID._1_0,
            &destinationPort
        ) { [weak self] eventList, srcConnRefCon in
            Task {
                await self?.handleIncomingMIDI(eventList: eventList)
            }
        }
        
        guard status == noErr else {
            await logError("Failed to create destination port: \(status)", category: .midi)
            throw MIDIError.portCreationFailed(status)
        }
        
        // Set port properties
        setPortProperties(destinationPort, isSource: false)
        
        await logInfo("Created virtual destination port", category: .midi)
    }
    
    private func setPortProperties(_ port: MIDIEndpointRef, isSource: Bool) {
        // Set manufacturer
        let manufacturer = manufacturerName as CFString
        MIDIObjectSetStringProperty(port, kMIDIPropertyManufacturer, manufacturer)
        
        // Set display name
        let displayName = portName as CFString
        MIDIObjectSetStringProperty(port, kMIDIPropertyDisplayName, displayName)
        
        // Set unique ID (helps with DAW recognition)
        let uniqueID = Int32(isSource ? 0x504734F1 : 0x504734F2) // PG4 in hex + F1/F2
        MIDIObjectSetIntegerProperty(port, kMIDIPropertyUniqueID, uniqueID)
        
        // Mark as virtual
        MIDIObjectSetIntegerProperty(port, kMIDIPropertyDriverOwner, 0)
    }
    
    private func handleIncomingMIDI(eventList: UnsafePointer<MIDIEventList>) async {
        let events = eventList.pointee
        let packetCount = Int(events.numPackets)
        
        // Process each packet
        var packet = events.packet
        for _ in 0..<packetCount {
            // Convert packet words to bytes
            let wordCount = Int(packet.wordCount)
            
            // UMP packets come as 32-bit words
            if wordCount > 0 {
                let word = packet.words.0  // First word contains the MIDI message
                
                // Extract bytes from the UMP word (little-endian)
                let byte0 = UInt8((word >> 0) & 0xFF)
                let byte1 = UInt8((word >> 8) & 0xFF)
                let byte2 = UInt8((word >> 16) & 0xFF)
                let byte3 = UInt8((word >> 24) & 0xFF)
                
                let rawData = Data([byte0, byte1, byte2, byte3])
                
                // Reorder UMP format to standard MIDI
                // UMP: [value] [controller] [status] [type]
                // MIDI: [status] [controller] [value]
                var data: Data
                if rawData.count == 4 && rawData[2] >= 0x80 {  // Check if byte 2 is a status byte
                    let value = rawData[0]
                    let controller = rawData[1]
                    let status = rawData[2]
                    data = Data([status, controller, value])
                } else {
                    data = rawData
                }
                
                // Parse and handle MIDI message
                if let message = try? MIDIParser.parse(data) {
                    await logDebug("Received from DAW: \(message)", category: .midi)
                    
                    // Update statistics
                    statistics.messagesReceived += 1
                    statistics.lastActivityTime = Date()
                    
                    switch message {
                    case .controlChange:
                        statistics.ccMessagesReceived += 1
                    case .programChange:
                        statistics.pcMessagesReceived += 1
                    default:
                        break
                    }
                    
                    // Notify delegate
                    await delegate?.midiPortManager(self, didReceiveMessage: message)
                } else {
                    // Handle raw data if parsing fails
                    await logWarning("Failed to parse MIDI data", category: .midi)
                    await delegate?.midiPortManager(self, didReceiveRawData: data)
                }
            }
            
            // Move to next packet
            let wordsToAdvance = wordCount
            packet = withUnsafePointer(to: &packet) { ptr in
                let rawPtr = UnsafeRawPointer(ptr).advanced(by: (wordsToAdvance + 1) * MemoryLayout<UInt32>.size)
                return rawPtr.assumingMemoryBound(to: MIDIEventPacket.self).pointee
            }
        }
    }
    
    private func handleIncomingMIDILegacy(packetList: UnsafePointer<MIDIPacketList>) async {
        await logInfo("📥 INCOMING MIDI (LEGACY): packet from DAW", category: .midi)
        
        let packets = packetList.pointee
        var packet = packets.packet
        
        for _ in 0..<packets.numPackets {
            // Extract MIDI data
            var data = withUnsafePointer(to: &packet.data) { ptr in
                Data(bytes: ptr, count: Int(packet.length))
            }
            
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            await logInfo("📥 RAW MIDI RX: [\(hexString)]", category: .midi)
            
            // Handle Universal MIDI Packet (UMP) format if length is 4
            // UMP MIDI 1.0 Channel Voice Message format: [status] [data1] [status] [data2]
            // We need to reorder to standard MIDI: [status] [data1] [data2]
            if data.count == 4 {
                // UMP format detected: byte[0]=value, byte[1]=controller, byte[2]=status, byte[3]=?
                // Reorder to: byte[0]=status, byte[1]=controller, byte[2]=value
                let value = data[0]      // CC value (0x7F or 0x00)
                let controller = data[1] // CC number (0x10, 0x11, etc.)
                let status = data[2]     // Status byte (0xB0)
                
                data = Data([status, controller, value])
                
                let reorderedHex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                await logInfo("📥 Reordered to standard MIDI: [\(reorderedHex)]", category: .midi)
            }
            
            // Parse and handle MIDI message
            if let message = try? MIDIParser.parse(data) {
                await logDebug("Received from DAW: \(message)", category: .midi)
                
                // Update statistics
                statistics.messagesReceived += 1
                statistics.lastActivityTime = Date()
                
                switch message {
                case .controlChange:
                    statistics.ccMessagesReceived += 1
                case .programChange:
                    statistics.pcMessagesReceived += 1
                default:
                    break
                }
                
                // Notify delegate
                await delegate?.midiPortManager(self, didReceiveMessage: message)
            } else {
                // Handle raw data if parsing fails
                await logTrace("Received raw MIDI data from DAW", category: .midi)
                await delegate?.midiPortManager(self, didReceiveRawData: data)
            }
            
            // Move to next packet
            packet = MIDIPacketNext(&packet).pointee
        }
    }
    
    private func handleMIDINotification(_ notification: UnsafePointer<MIDINotification>) async {
        let messageID = notification.pointee.messageID
        
        switch messageID {
        case .msgSetupChanged:
            await logInfo("MIDI setup changed", category: .midi)
            
        case .msgObjectAdded:
            await logDebug("MIDI object added", category: .midi)
            
        case .msgObjectRemoved:
            await logDebug("MIDI object removed", category: .midi)
            
        case .msgPropertyChanged:
            await logDebug("MIDI property changed", category: .midi)
            
        case .msgThruConnectionsChanged:
            await logDebug("MIDI thru connections changed", category: .midi)
            
        case .msgSerialPortOwnerChanged:
            await logDebug("MIDI serial port owner changed", category: .midi)
            
        case .msgIOError:
            await logError("MIDI I/O error", category: .midi)
            
        @unknown default:
            await logDebug("Unknown MIDI notification: \(messageID.rawValue)", category: .midi)
        }
    }
}

// MARK: - MIDIPortManagerDelegate

@available(macOS 12.0, *)
public protocol MIDIPortManagerDelegate: AnyObject {
    func midiPortManager(_ manager: MIDIPortManager, didReceiveMessage message: MIDIMessage) async
    func midiPortManager(_ manager: MIDIPortManager, didReceiveRawData data: Data) async
}

// MARK: - MIDIError

public enum MIDIError: Error, LocalizedError {
    case clientCreationFailed(OSStatus)
    case portCreationFailed(OSStatus)
    case notConnected
    case invalidPort
    case sendFailed(OSStatus)
    case bufferAllocationFailed
    
    public var errorDescription: String? {
        switch self {
        case .clientCreationFailed(let status):
            return "Failed to create MIDI client (error: \(status))"
        case .portCreationFailed(let status):
            return "Failed to create MIDI port (error: \(status))"
        case .notConnected:
            return "MIDI ports not connected"
        case .invalidPort:
            return "Invalid MIDI port"
        case .sendFailed(let status):
            return "Failed to send MIDI (error: \(status))"
        case .bufferAllocationFailed:
            return "Failed to allocate MIDI buffer"
        }
    }
}

// MARK: - Logging Helpers

@available(macOS 12.0, *)
private extension MIDIPortManager {
    func logError(_ message: String, category: Logger.Category = .midi) async {
        await Logger.shared.error(message, category: category)
    }
    
    func logWarning(_ message: String, category: Logger.Category = .midi) async {
        await Logger.shared.warning(message, category: category)
    }
    
    func logInfo(_ message: String, category: Logger.Category = .midi) async {
        await Logger.shared.info(message, category: category)
    }
    
    func logDebug(_ message: String, category: Logger.Category = .midi) async {
        await Logger.shared.debug(message, category: category)
    }
    
    func logTrace(_ message: String, category: Logger.Category = .midi) async {
        await Logger.shared.trace(message, category: category)
    }
}