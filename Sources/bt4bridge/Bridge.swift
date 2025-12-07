import Foundation
import CoreBluetooth
import CoreMIDI
import os

/// Main coordinator that bridges PG_BT4 Bluetooth device with virtual MIDI ports
@available(macOS 12.0, *)
public actor Bridge {
    
    // MARK: - Properties
    
    /// Bluetooth scanner for PG_BT4
    private let bluetoothScanner = BluetoothScanner()
    
    /// MIDI port manager
    private let midiPortManager = MIDIPortManager()
    
    /// Packet analyzer for CC discovery
    private let packetAnalyzer = PacketAnalyzer()
    
    /// Message coalescer for expression pedal optimization
    private let messageCoalescer = MessageCoalescer()
    
    /// LED controller for PG_BT4
    private let ledController = LEDController()
    
    /// LED state tracker for PG_BT4 (legacy, kept for compatibility)
    private let ledState = PG_BT4LEDState()
    
    /// Bridge state
    public private(set) var isRunning = false
    
    /// Connection state
    public private(set) var isConnected = false
    
    /// Statistics
    public private(set) var statistics = BridgeStatistics()
    
    public struct BridgeStatistics: Sendable {
        var startTime: Date?
        var totalMessagesForwarded: Int = 0
        var messagesFromPG_BT4: Int = 0
        var messagesFromDAW: Int = 0
        var coalescedMessages: Int = 0
        var discoveredCCs: Set<UInt8> = []
    }
    
    // MARK: - Message Coalescing
    
    /// Message coalescer for optimizing expression pedal data
    actor MessageCoalescer {
        private var pendingMessages: [MIDIMessage] = []
        private var coalesceTask: Task<Void, Never>?
        private let coalesceWindow: TimeInterval = 0.02 // 20ms window
        
        /// Add message for coalescing
        func add(_ message: MIDIMessage) async -> MIDIMessage? {
            // Only coalesce CC messages (expression pedal)
            guard case .controlChange(_, let controller, _) = message else {
                return message // Pass through non-CC immediately
            }
            
            // Don't coalesce button CCs (80-83) - send immediately
            if controller >= 80 && controller <= 83 {
                return message
            }
            
            pendingMessages.append(message)
            
            // Cancel existing coalesce task
            coalesceTask?.cancel()
            
            // Start new coalesce window
            coalesceTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(coalesceWindow * 1_000_000_000))
                await self.flush()
            }
            
            return nil // Message will be sent after coalescing
        }
        
        /// Get coalesced message if any
        func flush() async -> MIDIMessage? {
            guard !pendingMessages.isEmpty else { return nil }
            
            // Take the last CC value for each controller
            var latestCCs: [String: MIDIMessage] = [:]
            
            for message in pendingMessages {
                if case .controlChange(let channel, let controller, _) = message {
                    let key = "\(channel)-\(controller)"
                    latestCCs[key] = message
                }
            }
            
            pendingMessages.removeAll()
            
            // Return the most recent message (typically expression pedal)
            return latestCCs.values.max { first, second in
                // Compare by assuming messages were added in order
                false // Keep last one
            }
        }
        
        /// Reset coalescer
        func reset() {
            coalesceTask?.cancel()
            pendingMessages.removeAll()
        }
    }
    
    // MARK: - Initialization
    
    public init() {}
    
    // MARK: - Public Methods
    
    /// Start the bridge
    public func start() async throws {
        guard !isRunning else {
            await logInfo("Bridge already running", category: .bridge)
            return
        }
        
        await logInfo("Starting PG_BT4 Bridge", category: .bridge)
        
        // Reset statistics
        statistics = BridgeStatistics()
        statistics.startTime = Date()
        
        // Set up delegates
        await bluetoothScanner.setDelegate(self)
        await midiPortManager.setDelegate(self)
        
        // Create MIDI ports first
        try await midiPortManager.createPorts()
        
        // Start Bluetooth scanning
        await bluetoothScanner.startScanning()
        
        isRunning = true
        
        await logInfo("PG_BT4 Bridge started", category: .bridge)
    }
    
    /// Stop the bridge
    public func stop() async {
        guard isRunning else { return }
        
        await logInfo("Stopping PG_BT4 Bridge", category: .bridge)
        
        // Stop Bluetooth
        await bluetoothScanner.stopScanning()
        await bluetoothScanner.disconnect()
        
        // Destroy MIDI ports
        await midiPortManager.destroyPorts()
        
        // Reset coalescer
        await messageCoalescer.reset()
        
        isRunning = false
        isConnected = false
        
        await logInfo("PG_BT4 Bridge stopped", category: .bridge)
    }
    
    /// Get current statistics
    public func getStatistics() -> BridgeStatistics {
        return statistics
    }
    
    /// Get Bluetooth statistics
    public func getBluetoothStatistics() async -> (isConnected: Bool, rssi: NSNumber?) {
        let connected = await bluetoothScanner.isConnected
        let rssi = await bluetoothScanner.lastRSSI
        return (connected, rssi)
    }
    
    /// Get MIDI statistics
    public func getMIDIStatistics() async -> MIDIPortManager.MIDIStatistics {
        return await midiPortManager.getStatistics()
    }
    
    /// Get discovered CC numbers
    public func getDiscoveredCCs() async -> [PacketAnalyzer.CCInfo] {
        return await packetAnalyzer.getDiscoveredCCs()
    }
    
    /// Send raw test command to PG_BT4 (for LED testing)
    public func sendTestCommand(_ data: Data) async {
        do {
            try await bluetoothScanner.sendMIDIData(data)
        } catch {
            await logError("Failed to send test command: \(error)", category: .bridge)
        }
    }
    
    // MARK: - Private Methods
    
    /// Handle MIDI message from PG_BT4
    private func handleMessageFromPG_BT4(_ data: Data) async {
        // Parse PG_BT4 protocol
        guard let message = PG_BT4Parser.parse(data) else {
            let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
            await logWarning("Unknown packet: [\(hexString)]", category: .bridge)
            return
        }
        
        // Log button events
        if let description = PG_BT4Parser.describe(data) {
            await logDebug("\(description) -> \(message)", category: .bridge)
        }
        
        // Analyze for CC discovery
        await packetAnalyzer.analyze(message.toData())
        
        // Update statistics
        statistics.messagesFromPG_BT4 += 1
        statistics.totalMessagesForwarded += 1
        
        // Check if message should be coalesced
        if let coalescedMessage = await messageCoalescer.add(message) {
            // Send immediately (not coalesced)
            do {
                try await midiPortManager.sendToDAW(coalescedMessage)
            } catch {
                await logError("Failed to send MIDI to DAW: \(error)", category: .bridge)
            }
        } else {
            // Message added for coalescing, will be sent after window
            statistics.coalescedMessages += 1
            
            // Check for flush after coalesce window
            Task {
                try? await Task.sleep(nanoseconds: 25_000_000) // 25ms
                if let flushedMessage = await messageCoalescer.flush() {
                    do {
                        try await midiPortManager.sendToDAW(flushedMessage)
                        await logTrace("Sent coalesced message: \(flushedMessage)", category: .bridge)
                    } catch {
                        await logError("Failed to send coalesced MIDI to DAW: \(error)", category: .bridge)
                    }
                }
            }
        }
        
        // Update discovered CCs
        if case .controlChange(_, let controller, _) = message {
            statistics.discoveredCCs.insert(controller)
        }
    }
    
    /// Handle MIDI message from DAW
    private func handleMessageFromDAW(_ message: MIDIMessage) async {
        // Update statistics
        statistics.messagesFromDAW += 1
        statistics.totalMessagesForwarded += 1
        
        // Check if message is a CC that maps to an LED
        if case .controlChange(_, let controller, let value) = message {
            if let ledCommand = await ledController.handleMIDICC(controller: controller, value: value) {
                // This is an LED control message - send directly to device
                let ledNum = controller - 15
                let state = value >= 64 ? "ON" : "OFF"
                await logDebug("LED \(ledNum) \(state)", category: .bridge)
                
                do {
                    try await bluetoothScanner.sendMIDIData(ledCommand)
                } catch {
                    await logError("Failed to send LED command: \(error)", category: .bridge)
                }
                return // Don't forward LED CC to device as regular MIDI
            }
        }
        
        // Convert MIDI to PG_BT4 protocol
        guard let data = PG_BT4Parser.toData(message) else {
            await logWarning("MIDI message cannot be converted to PG_BT4 format: \(message)", category: .bridge)
            return
        }
        
        // Send to PG_BT4
        do {
            try await bluetoothScanner.sendMIDIData(data)
        } catch {
            await logError("Failed to send data to PG_BT4: \(error)", category: .bridge)
        }
    }
}

// MARK: - BluetoothScannerDelegate

@available(macOS 12.0, *)
extension Bridge: BluetoothScannerDelegate {
    
    nonisolated public func bluetoothScannerDidConnect(_ scanner: BluetoothScanner) async {
        await logInfo("PG_BT4 connected", category: .bridge)
        await setConnected(true)
        
        // Initialize LEDs to OFF state
        await initializeLEDs(scanner)
        
        await logInfo("✅ LED control ready: Send MIDI CC 16-19 (LEDs 1-4) from DAW", category: .bridge)
    }
    
    /// Initialize LED states on connection (turn all OFF)
    private func initializeLEDs(_ scanner: BluetoothScanner) async {
        await logDebug("Initializing LEDs to OFF state...", category: .bridge)
        
        // Get all LED OFF commands from controller (correct format: A2 XX 01)
        let offCommands = await ledController.allLEDsOff()
        
        for (index, command) in offCommands.enumerated() {
            let ledNum = index + 1
            let hexString = command.map { String(format: "%02X", $0) }.joined(separator: " ")
            await logTrace("Init LED \(ledNum): OFF -> \(hexString)", category: .bridge)
            
            do {
                try await scanner.sendMIDIData(command)
                // Small delay between commands
                try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            } catch {
                await logError("Failed to init LED \(ledNum): \(error)", category: .bridge)
            }
        }
        
        await logDebug("✅ LED initialization complete (all LEDs OFF)", category: .bridge)
    }
    
    nonisolated public func bluetoothScannerDidDisconnect(_ scanner: BluetoothScanner) async {
        await logWarning("PG_BT4 disconnected", category: .bridge)
        await setConnected(false)
        
        // Reset coalescer on disconnect
        await messageCoalescer.reset()
    }
    
    nonisolated public func bluetoothScanner(_ scanner: BluetoothScanner, didReceiveMIDIData data: Data) async {
        await handleMessageFromPG_BT4(data)
    }
    
    private func setConnected(_ connected: Bool) {
        isConnected = connected
    }
}

// MARK: - MIDIPortManagerDelegate

@available(macOS 12.0, *)
extension Bridge: MIDIPortManagerDelegate {
    
    nonisolated public func midiPortManager(_ manager: MIDIPortManager, didReceiveMessage message: MIDIMessage) async {
        await handleMessageFromDAW(message)
    }
    
    nonisolated public func midiPortManager(_ manager: MIDIPortManager, didReceiveRawData data: Data) async {
        // Try to parse and handle
        if let message = try? MIDIParser.parse(data) {
            await handleMessageFromDAW(message)
        } else {
            await logWarning("Received unparseable MIDI from DAW: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .bridge)
        }
    }
}

// MARK: - PacketAnalyzer

/// Analyzes MIDI packets to discover CC numbers used by PG_BT4
@available(macOS 12.0, *)
public actor PacketAnalyzer {
    
    public struct CCInfo: Equatable, Sendable {
        public let controller: UInt8
        public let channel: UInt8
        public let minValue: UInt8
        public let maxValue: UInt8
        public let messageCount: Int
        public let firstSeen: Date
        public let lastSeen: Date
    }
    
    private var ccData: [String: CCInfo] = [:] // Key: "channel-controller"
    
    /// Analyze a MIDI packet
    func analyze(_ data: Data) {
        guard let message = try? MIDIParser.parse(data) else { return }
        
        if case .controlChange(let channel, let controller, let value) = message {
            let key = "\(channel)-\(controller)"
            
            if var info = ccData[key] {
                // Update existing CC info
                info = CCInfo(
                    controller: controller,
                    channel: channel,
                    minValue: min(info.minValue, value),
                    maxValue: max(info.maxValue, value),
                    messageCount: info.messageCount + 1,
                    firstSeen: info.firstSeen,
                    lastSeen: Date()
                )
                ccData[key] = info
            } else {
                // New CC discovered
                ccData[key] = CCInfo(
                    controller: controller,
                    channel: channel,
                    minValue: value,
                    maxValue: value,
                    messageCount: 1,
                    firstSeen: Date(),
                    lastSeen: Date()
                )
                
                Task {
                    await logInfo("Discovered new CC: #\(controller) on channel \(channel)", category: .packet)
                }
            }
        }
    }
    
    /// Get all discovered CCs
    func getDiscoveredCCs() -> [CCInfo] {
        return Array(ccData.values).sorted { $0.controller < $1.controller }
    }
    
    /// Get info for specific CC
    func getCCInfo(channel: UInt8, controller: UInt8) -> CCInfo? {
        let key = "\(channel)-\(controller)"
        return ccData[key]
    }
    
    /// Reset analyzer
    func reset() {
        ccData.removeAll()
    }
}

// MARK: - Logging Helpers

@available(macOS 12.0, *)
private func logError(_ message: String, category: Logger.Category) async {
    await Logger.shared.error(message, category: category)
}

@available(macOS 12.0, *)
private func logWarning(_ message: String, category: Logger.Category) async {
    await Logger.shared.warning(message, category: category)
}

@available(macOS 12.0, *)
private func logInfo(_ message: String, category: Logger.Category) async {
    await Logger.shared.info(message, category: category)
}

@available(macOS 12.0, *)
private func logDebug(_ message: String, category: Logger.Category) async {
    await Logger.shared.debug(message, category: category)
}

@available(macOS 12.0, *)
private func logTrace(_ message: String, category: Logger.Category) async {
    await Logger.shared.trace(message, category: category)
}