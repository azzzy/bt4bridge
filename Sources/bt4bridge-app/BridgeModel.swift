import Foundation
import SwiftUI
import Combine
import BT4BridgeCore

/// Observable model that wraps the Bridge actor for SwiftUI
@available(macOS 12.0, *)
@MainActor
class BridgeModel: ObservableObject {
    
    // MARK: - Published State
    
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var deviceName: String? = nil
    @Published var rssi: Int? = nil
    @Published var midiPortsActive: Bool = false
    @Published var ledStates: [Int: Bool] = [1: false, 2: false, 3: false, 4: false]
    @Published var statistics: BridgeStatistics = BridgeStatistics()
    @Published var isActive: Bool = false
    
    // MARK: - Private Properties
    
    private let bridge = Bridge()
    private var updateTask: Task<Void, Never>?
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default state
    }
    
    // MARK: - Public Methods
    
    /// Start the bridge and begin monitoring
    func start() async throws {
        guard !isActive else { return }
        
        try await bridge.start()
        isActive = true
        
        // Start update loop
        startUpdateLoop()
    }
    
    /// Stop the bridge
    func stop() async {
        guard isActive else { return }
        
        // Cancel update loop
        updateTask?.cancel()
        updateTask = nil
        
        await bridge.stop()
        isActive = false
        
        // Reset state
        connectionStatus = .disconnected
        deviceName = nil
        rssi = nil
        midiPortsActive = false
        ledStates = [1: false, 2: false, 3: false, 4: false]
    }
    
    /// Reconnect to device
    func reconnect() async {
        await bridge.stop()
        
        do {
            try await bridge.start()
            connectionStatus = .scanning
        } catch {
            print("Failed to reconnect: \(error)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Start periodic update loop
    private func startUpdateLoop() {
        updateTask = Task { @MainActor in
            while !Task.isCancelled {
                await updateState()
                
                // Update every 500ms when menu might be open
                // Reduce to 2s when we optimize for menu visibility
                try? await Task.sleep(nanoseconds: 500_000_000)
            }
        }
    }
    
    /// Update state from bridge
    private func updateState() async {
        // Get Bluetooth statistics
        let btStats = await bridge.getBluetoothStatistics()
        
        // Update connection status
        if btStats.isConnected {
            connectionStatus = .connected
            deviceName = "PG_BT4"
            rssi = btStats.rssi?.intValue
        } else {
            if connectionStatus == .connected {
                // Just disconnected
                connectionStatus = .disconnected
            } else if isActive {
                connectionStatus = .scanning
            } else {
                connectionStatus = .disconnected
            }
            deviceName = nil
            rssi = nil
        }
        
        // Get MIDI statistics
        let midiStats = await bridge.getMIDIStatistics()
        midiPortsActive = midiStats.connectionTime != nil
        
        // Get bridge statistics
        let stats = await bridge.getStatistics()
        statistics = BridgeStatistics(
            totalMessages: stats.totalMessagesForwarded,
            fromPG_BT4: stats.messagesFromPG_BT4,
            fromDAW: stats.messagesFromDAW
        )
        
        // Get LED states from bridge
        let currentLEDStates = await bridge.getLEDStates()
        ledStates = currentLEDStates
    }
}

// MARK: - Supporting Types

@available(macOS 12.0, *)
enum ConnectionStatus: Equatable {
    case disconnected
    case scanning
    case connected
}

@available(macOS 12.0, *)
struct BridgeStatistics {
    var totalMessages: Int = 0
    var fromPG_BT4: Int = 0
    var fromDAW: Int = 0
}
