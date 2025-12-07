import Foundation
import CoreMIDI
@testable import bt4bridge

/// Mock MIDI client for testing without real CoreMIDI devices
@available(macOS 12.0, *)
public actor MockMIDIClient {
    
    // MARK: - Properties
    
    /// Client name
    public let name: String
    
    /// Virtual source port (for sending to DAW)
    public private(set) var sourcePort: MIDIPortRef = 0
    
    /// Virtual destination port (for receiving from DAW)
    public private(set) var destinationPort: MIDIPortRef = 0
    
    /// Messages received by the destination port
    public private(set) var receivedMessages: [MIDIMessage] = []
    
    /// Messages sent through the source port
    public private(set) var sentMessages: [MIDIMessage] = []
    
    /// Callback for when messages are received
    private var receiveCallback: ((MIDIMessage) -> Void)?
    
    /// Simulated connection state
    public private(set) var isConnected = false
    
    // MARK: - Statistics
    
    public private(set) var statistics = MIDIStatistics()
    
    public struct MIDIStatistics {
        var totalMessagesSent: Int = 0
        var totalMessagesReceived: Int = 0
        var ccMessagesSent: Int = 0
        var pcMessagesSent: Int = 0
        var ccMessagesReceived: Int = 0
        var pcMessagesReceived: Int = 0
        var lastMessageTime: Date?
    }
    
    // MARK: - Initialization
    
    public init(name: String = "MockMIDIClient") {
        self.name = name
    }
    
    // MARK: - Connection Management
    
    /// Simulate creating MIDI ports
    public func connect() async throws {
        // Simulate port creation delay
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Assign mock port references
        sourcePort = 1001
        destinationPort = 1002
        isConnected = true
    }
    
    /// Simulate closing MIDI ports
    public func disconnect() {
        sourcePort = 0
        destinationPort = 0
        isConnected = false
        receiveCallback = nil
    }
    
    // MARK: - Message Handling
    
    /// Set callback for received messages
    public func setReceiveCallback(_ callback: @escaping (MIDIMessage) -> Void) {
        self.receiveCallback = callback
    }
    
    /// Send a MIDI message (simulating sending to DAW)
    public func send(_ message: MIDIMessage) async throws {
        guard isConnected else {
            throw MockMIDIError.notConnected
        }
        
        sentMessages.append(message)
        statistics.totalMessagesSent += 1
        statistics.lastMessageTime = Date()
        
        // Update type-specific statistics
        switch message {
        case .controlChange:
            statistics.ccMessagesSent += 1
        case .programChange:
            statistics.pcMessagesSent += 1
        default:
            break
        }
        
        // Simulate send delay
        try await Task.sleep(nanoseconds: 1_000_000) // 1ms
    }
    
    /// Simulate receiving a MIDI message from DAW
    public func simulateReceive(_ message: MIDIMessage) {
        guard isConnected else { return }
        
        receivedMessages.append(message)
        statistics.totalMessagesReceived += 1
        statistics.lastMessageTime = Date()
        
        // Update type-specific statistics
        switch message {
        case .controlChange:
            statistics.ccMessagesReceived += 1
        case .programChange:
            statistics.pcMessagesReceived += 1
        default:
            break
        }
        
        // Trigger callback
        receiveCallback?(message)
    }
    
    /// Simulate receiving Program Change from DAW
    public func simulateProgramChangeFromDAW(channel: UInt8, program: UInt8) {
        let message = MIDIMessage.programChange(channel: channel, program: program)
        simulateReceive(message)
    }
    
    /// Simulate a burst of CC messages (like expression pedal)
    public func simulateCCBurst(count: Int, controller: UInt8 = 11, channel: UInt8 = 0) async {
        for i in 0..<count {
            let value = UInt8(min(127, i * 127 / max(1, count - 1)))
            let message = MIDIMessage.controlChange(channel: channel, controller: controller, value: value)
            simulateReceive(message)
            
            // Small delay between messages
            try? await Task.sleep(nanoseconds: 5_000_000) // 5ms
        }
    }
    
    // MARK: - Testing Helpers
    
    /// Clear all message history
    public func clearHistory() {
        receivedMessages.removeAll()
        sentMessages.removeAll()
    }
    
    /// Get the last sent message
    public func getLastSentMessage() -> MIDIMessage? {
        return sentMessages.last
    }
    
    /// Get the last received message
    public func getLastReceivedMessage() -> MIDIMessage? {
        return receivedMessages.last
    }
    
    /// Check if a specific message was sent
    public func wasSent(_ message: MIDIMessage) -> Bool {
        return sentMessages.contains(message)
    }
    
    /// Check if a specific message was received
    public func wasReceived(_ message: MIDIMessage) -> Bool {
        return receivedMessages.contains(message)
    }
    
    /// Get statistics
    public func getStatistics() -> MIDIStatistics {
        return statistics
    }
    
    /// Reset statistics
    public func resetStatistics() {
        statistics = MIDIStatistics()
    }
}

// MARK: - Mock MIDI Errors

public enum MockMIDIError: Error, LocalizedError {
    case notConnected
    case portCreationFailed
    case sendFailed
    
    public var errorDescription: String? {
        switch self {
        case .notConnected:
            return "Mock MIDI client is not connected"
        case .portCreationFailed:
            return "Failed to create mock MIDI ports"
        case .sendFailed:
            return "Failed to send MIDI message"
        }
    }
}