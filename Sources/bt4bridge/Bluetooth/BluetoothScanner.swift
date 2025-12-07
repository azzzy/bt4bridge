import Foundation
@preconcurrency import CoreBluetooth
import os

/// Actor responsible for scanning and managing Bluetooth connections to PG_BT4
@available(macOS 12.0, *)
public actor BluetoothScanner: NSObject {
    
    // MARK: - Constants
    
    /// The name of the PG_BT4 device to search for
    private static let targetDeviceName = "PG_BT4"
    
    /// Standard MIDI over BLE service UUID (unused by PG_BT4)
    private static let standardMidiServiceUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    
    /// PG_BT4 uses this custom service UUID
    private static let pg4ServiceUUID = CBUUID(string: "1910")
    
    /// MIDI I/O characteristic UUID
    private static let midiCharacteristicUUID = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")
    
    // MARK: - Properties
    
    /// Central manager for BLE operations
    private var centralManager: CBCentralManager?
    
    /// Currently connected PG_BT4 peripheral
    private var connectedPeripheral: CBPeripheral?
    
    /// MIDI characteristic for receiving data (notify)
    private var midiReadCharacteristic: CBCharacteristic?
    
    /// MIDI characteristic for sending data (write)
    private var midiWriteCharacteristic: CBCharacteristic?
    
    /// Connection state
    public private(set) var isConnected = false
    
    /// Scanning state
    public private(set) var isScanning = false
    
    /// Delegate for receiving MIDI data
    public weak var delegate: BluetoothScannerDelegate?
    
    /// Set the delegate
    public func setDelegate(_ newDelegate: BluetoothScannerDelegate?) {
        self.delegate = newDelegate
    }
    
    /// Connection continuation for async connection
    private var connectionContinuation: CheckedContinuation<Bool, Error>?
    
    /// Service discovery continuation
    private var serviceContinuation: CheckedContinuation<Bool, Error>?
    
    /// Characteristic discovery continuation
    private var characteristicContinuation: CheckedContinuation<Bool, Error>?
    
    /// Last seen RSSI value
    public private(set) var lastRSSI: NSNumber?
    
    /// Connection attempt count for retry logic
    private var connectionAttempts = 0
    private let maxConnectionAttempts = 3
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - Public Methods
    
    /// Start scanning for PG_BT4 devices
    public func startScanning() async {
        await logInfo("Starting scan for \(Self.targetDeviceName)", category: .bluetooth)
        
        // Initialize central manager
        self.centralManager = CBCentralManager(
            delegate: self,
            queue: nil
        )
        
        isScanning = true
    }
    
    /// Stop scanning for devices
    public func stopScanning() async {
        guard isScanning else { return }
        
        await logInfo("Stopping scan", category: .bluetooth)
        centralManager?.stopScan()
        isScanning = false
    }
    
    /// Connect to a discovered PG_BT4 device
    public func connect() async throws -> Bool {
        guard let peripheral = connectedPeripheral else {
            await logError("No PG_BT4 device found to connect", category: .bluetooth)
            throw BluetoothError.deviceNotFound
        }
        
        guard !isConnected else {
            await logInfo("Already connected to PG_BT4", category: .bluetooth)
            return true
        }
        
        connectionAttempts += 1
        await logInfo("Connecting to PG_BT4 (attempt \(connectionAttempts)/\(maxConnectionAttempts))", category: .bluetooth)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.connectionContinuation = continuation
            centralManager?.connect(peripheral, options: nil)
            
            // Add timeout
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000) // 10 seconds
                self.connectionContinuation?.resume(throwing: BluetoothError.connectionTimeout)
                self.connectionContinuation = nil
            }
        }
    }
    
    /// Disconnect from the current device
    public func disconnect() async {
        guard let peripheral = connectedPeripheral else { return }
        
        await logInfo("Disconnecting from PG_BT4", category: .bluetooth)
        centralManager?.cancelPeripheralConnection(peripheral)
        
        isConnected = false
        connectedPeripheral = nil
        midiReadCharacteristic = nil
        midiWriteCharacteristic = nil
        connectionAttempts = 0
    }
    
    /// Send data to the PG_BT4 device
    public func sendMIDIData(_ data: Data) async throws {
        guard isConnected else {
            throw BluetoothError.notConnected
        }
        
        guard let peripheral = connectedPeripheral,
              let characteristic = midiWriteCharacteristic else {
            throw BluetoothError.characteristicNotFound
        }
        
        // Send raw protocol data to device
        await logTrace("TX: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .bluetooth)
        
        // Use .withResponse if the characteristic requires it, otherwise .withoutResponse
        let writeType: CBCharacteristicWriteType = characteristic.properties.contains(.write) ? .withResponse : .withoutResponse
        
        peripheral.writeValue(
            data,
            for: characteristic,
            type: writeType
        )
    }
    
    // MARK: - Private Methods
    
    /// Discover services on the connected peripheral
    private func discoverServices() async throws -> Bool {
        guard let peripheral = connectedPeripheral else {
            throw BluetoothError.notConnected
        }
        
        await logDebug("Discovering ALL services on PG_BT4", category: .bluetooth)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.serviceContinuation = continuation
            // Discover ALL services to see what the PG_BT4 actually has
            peripheral.discoverServices(nil)
            
            // Add timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                self.serviceContinuation?.resume(throwing: BluetoothError.serviceDiscoveryTimeout)
                self.serviceContinuation = nil
            }
        }
    }
    
    /// Discover characteristics for the MIDI service
    private func discoverCharacteristics(for service: CBService) async throws -> Bool {
        guard let peripheral = connectedPeripheral else {
            throw BluetoothError.notConnected
        }
        
        await logDebug("Discovering ALL characteristics for service", category: .bluetooth)
        
        return try await withCheckedThrowingContinuation { continuation in
            self.characteristicContinuation = continuation
            // Discover ALL characteristics to see what the PG_BT4 has
            peripheral.discoverCharacteristics(nil, for: service)
            
            // Add timeout
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
                self.characteristicContinuation?.resume(throwing: BluetoothError.characteristicDiscoveryTimeout)
                self.characteristicContinuation = nil
            }
        }
    }
}

// MARK: - CBCentralManagerDelegate

@available(macOS 12.0, *)
extension BluetoothScanner: CBCentralManagerDelegate {
    
    nonisolated public func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task {
            await handleStateUpdate(central.state)
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        Task {
            await handleDiscoveredPeripheral(peripheral, advertisementData: advertisementData, rssi: RSSI)
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task {
            await handleConnectedPeripheral(peripheral)
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task {
            await handleFailedConnection(peripheral, error: error)
        }
    }
    
    nonisolated public func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task {
            await handleDisconnectedPeripheral(peripheral, error: error)
        }
    }
    
    // MARK: - Delegate Handlers
    
    private func handleStateUpdate(_ state: CBManagerState) async {
        switch state {
        case .poweredOn:
            await logInfo("Bluetooth powered on, starting scan", category: .bluetooth)
            // Start scanning for all BLE devices (we'll filter by name)
            // Some devices don't advertise the MIDI service UUID
            centralManager?.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            
        case .poweredOff:
            await logWarning("Bluetooth powered off", category: .bluetooth)
            isScanning = false
            
        case .resetting:
            await logWarning("Bluetooth resetting", category: .bluetooth)
            
        case .unauthorized:
            await logError("Bluetooth unauthorized", category: .bluetooth)
            
        case .unsupported:
            await logError("Bluetooth unsupported on this device", category: .bluetooth)
            
        case .unknown:
            await logWarning("Bluetooth state unknown", category: .bluetooth)
            
        @unknown default:
            await logWarning("Unknown Bluetooth state: \(state.rawValue)", category: .bluetooth)
        }
    }
    
    private func handleDiscoveredPeripheral(_ peripheral: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) async {
        // Check if this is our target device
        guard peripheral.name == Self.targetDeviceName else {
            return
        }
        
        await logInfo("Found PG_BT4 device (RSSI: \(rssi))", category: .bluetooth)
        
        // Stop scanning once we find our device
        centralManager?.stopScan()
        isScanning = false
        
        // Store the peripheral
        connectedPeripheral = peripheral
        lastRSSI = rssi
        
        // Auto-connect
        do {
            _ = try await connect()
        } catch {
            await logError("Failed to auto-connect to PG_BT4: \(error)", category: .bluetooth)
        }
    }
    
    private func handleConnectedPeripheral(_ peripheral: CBPeripheral) async {
        await logInfo("Connected to PG_BT4", category: .bluetooth)
        
        isConnected = true
        connectionAttempts = 0
        peripheral.delegate = self
        
        // Discover services
        do {
            _ = try await discoverServices()
        } catch {
            await logError("Failed to discover services: \(error)", category: .bluetooth)
            connectionContinuation?.resume(returning: false)
            connectionContinuation = nil
        }
    }
    
    private func handleFailedConnection(_ peripheral: CBPeripheral, error: Error?) async {
        await logError("Failed to connect to PG_BT4: \(error?.localizedDescription ?? "Unknown error")", category: .bluetooth)
        
        isConnected = false
        
        // Retry if under max attempts
        if connectionAttempts < maxConnectionAttempts {
            await logInfo("Retrying connection...", category: .bluetooth)
            do {
                _ = try await connect()
            } catch {
                connectionContinuation?.resume(throwing: error)
                connectionContinuation = nil
            }
        } else {
            connectionContinuation?.resume(throwing: error ?? BluetoothError.connectionFailed)
            connectionContinuation = nil
            connectionAttempts = 0
        }
    }
    
    private func handleDisconnectedPeripheral(_ peripheral: CBPeripheral, error: Error?) async {
        if let error = error {
            await logWarning("Disconnected from PG_BT4 with error: \(error.localizedDescription)", category: .bluetooth)
        } else {
            await logInfo("Disconnected from PG_BT4", category: .bluetooth)
        }
        
        isConnected = false
        midiReadCharacteristic = nil
        midiWriteCharacteristic = nil
        
        // Notify delegate
        await delegate?.bluetoothScannerDidDisconnect(self)
        
        // Auto-reconnect if it was unexpected
        if error != nil {
            await logInfo("Attempting to reconnect to PG_BT4", category: .bluetooth)
            // Restart scanning
            await startScanning()
        }
    }
}

// MARK: - CBPeripheralDelegate

@available(macOS 12.0, *)
extension BluetoothScanner: CBPeripheralDelegate {
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task {
            await handleDiscoveredServices(peripheral, error: error)
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task {
            await handleDiscoveredCharacteristics(service, error: error)
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task {
            await handleUpdatedValue(characteristic, error: error)
        }
    }
    
    nonisolated public func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        Task {
            await handleNotificationStateUpdate(characteristic, error: error)
        }
    }
    
    // MARK: - Peripheral Delegate Handlers
    
    private func handleDiscoveredServices(_ peripheral: CBPeripheral, error: Error?) async {
        if let error = error {
            await logError("Error discovering services: \(error.localizedDescription)", category: .bluetooth)
            serviceContinuation?.resume(throwing: error)
            serviceContinuation = nil
            return
        }
        
        guard let services = peripheral.services, !services.isEmpty else {
            await logError("No services found", category: .bluetooth)
            serviceContinuation?.resume(throwing: BluetoothError.serviceNotFound)
            serviceContinuation = nil
            return
        }
        
        // Log all discovered services
        await logInfo("Discovered \(services.count) service(s):", category: .bluetooth)
        for service in services {
            await logInfo("  Service UUID: \(service.uuid)", category: .bluetooth)
        }
        
        // Look for PG_BT4 service first (UUID 1910)
        var midiService = services.first(where: { $0.uuid == Self.pg4ServiceUUID })
        
        if midiService == nil {
            // Try standard MIDI service
            midiService = services.first(where: { $0.uuid == Self.standardMidiServiceUUID })
            if midiService != nil {
                await logInfo("Found standard MIDI service", category: .bluetooth)
            }
        } else {
            await logInfo("Found PG_BT4 service (UUID 1910)", category: .bluetooth)
        }
        
        if midiService == nil {
            await logWarning("Neither PG_BT4 nor standard MIDI service found", category: .bluetooth)
            // Filter out "Device Information" and similar services
            midiService = services.first(where: { 
                $0.uuid.uuidString != "180A" && // Device Information
                $0.uuid.uuidString != "1800" && // Generic Access
                $0.uuid.uuidString != "1801"    // Generic Attribute
            })
            if let service = midiService {
                await logInfo("Using service: \(service.uuid)", category: .bluetooth)
            }
        }
        
        guard let service = midiService else {
            await logError("No usable service found", category: .bluetooth)
            serviceContinuation?.resume(throwing: BluetoothError.serviceNotFound)
            serviceContinuation = nil
            return
        }
        
        // Discover characteristics
        do {
            _ = try await discoverCharacteristics(for: service)
            serviceContinuation?.resume(returning: true)
            serviceContinuation = nil
        } catch {
            serviceContinuation?.resume(throwing: error)
            serviceContinuation = nil
        }
    }
    
    private func handleDiscoveredCharacteristics(_ service: CBService, error: Error?) async {
        if let error = error {
            await logError("Error discovering characteristics: \(error.localizedDescription)", category: .bluetooth)
            characteristicContinuation?.resume(throwing: error)
            characteristicContinuation = nil
            return
        }
        
        guard let characteristics = service.characteristics, !characteristics.isEmpty else {
            await logError("No characteristics found", category: .bluetooth)
            characteristicContinuation?.resume(throwing: BluetoothError.characteristicNotFound)
            characteristicContinuation = nil
            return
        }
        
        // Log all discovered characteristics
        await logInfo("Discovered \(characteristics.count) characteristic(s):", category: .bluetooth)
        for char in characteristics {
            await logInfo("  Characteristic UUID: \(char.uuid) Properties: \(char.properties.rawValue)", category: .bluetooth)
        }
        
        // Find read characteristic (with notify property)
        let readChar = characteristics.first(where: { $0.properties.contains(.notify) })
        
        // Use FFF2 for writing (LED commands)
        // FFF3 is for indications (responses from device), not for sending commands
        var writeChar = characteristics.first(where: { $0.uuid.uuidString == "FFF2" })
        if writeChar == nil {
            // Fallback to any write characteristic
            writeChar = characteristics.first(where: { $0.properties.contains(.write) || $0.properties.contains(.writeWithoutResponse) })
        }
        
        await logInfo("💡 Testing LED control with characteristic: \(writeChar?.uuid.uuidString ?? "none")", category: .bluetooth)
        
        guard let read = readChar else {
            await logError("No characteristic with notify found", category: .bluetooth)
            characteristicContinuation?.resume(throwing: BluetoothError.characteristicNotFound)
            characteristicContinuation = nil
            return
        }
        
        guard let write = writeChar else {
            await logError("No characteristic with write found", category: .bluetooth)
            characteristicContinuation?.resume(throwing: BluetoothError.characteristicNotFound)
            characteristicContinuation = nil
            return
        }
        
        await logInfo("Using read characteristic: \(read.uuid)", category: .bluetooth)
        await logInfo("Using write characteristic: \(write.uuid) (Properties: \(write.properties.rawValue))", category: .bluetooth)
        
        midiReadCharacteristic = read
        midiWriteCharacteristic = write
        
        // Subscribe to notifications
        connectedPeripheral?.setNotifyValue(true, for: read)
        
        characteristicContinuation?.resume(returning: true)
        characteristicContinuation = nil
        
        // Connection fully established
        connectionContinuation?.resume(returning: true)
        connectionContinuation = nil
        
        // Notify delegate
        await delegate?.bluetoothScannerDidConnect(self)
    }
    
    private func handleUpdatedValue(_ characteristic: CBCharacteristic, error: Error?) async {
        if let error = error {
            await logError("Error receiving data: \(error.localizedDescription)", category: .bluetooth)
            return
        }
        
        guard let data = characteristic.value, !data.isEmpty else {
            return
        }
        
        await logTrace("Received data: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))", category: .bluetooth)
        
        // PG_BT4 sends raw protocol data (no BLE MIDI wrapping)
        await delegate?.bluetoothScanner(self, didReceiveMIDIData: data)
    }
    
    private func handleNotificationStateUpdate(_ characteristic: CBCharacteristic, error: Error?) async {
        if let error = error {
            await logError("Error updating notification state: \(error.localizedDescription)", category: .bluetooth)
            return
        }
        
        if characteristic.isNotifying {
            await logInfo("Notifications enabled for MIDI characteristic", category: .bluetooth)
        } else {
            await logWarning("Notifications disabled for MIDI characteristic", category: .bluetooth)
        }
    }
}

// MARK: - BluetoothScannerDelegate

@available(macOS 12.0, *)
public protocol BluetoothScannerDelegate: AnyObject {
    func bluetoothScannerDidConnect(_ scanner: BluetoothScanner) async
    func bluetoothScannerDidDisconnect(_ scanner: BluetoothScanner) async
    func bluetoothScanner(_ scanner: BluetoothScanner, didReceiveMIDIData data: Data) async
}

// MARK: - BluetoothError

public enum BluetoothError: Error, LocalizedError {
    case deviceNotFound
    case connectionFailed
    case connectionTimeout
    case notConnected
    case serviceNotFound
    case serviceDiscoveryTimeout
    case characteristicNotFound
    case characteristicDiscoveryTimeout
    case bluetoothUnavailable
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotFound:
            return "PG_BT4 device not found"
        case .connectionFailed:
            return "Failed to connect to PG_BT4"
        case .connectionTimeout:
            return "Connection to PG_BT4 timed out"
        case .notConnected:
            return "Not connected to PG_BT4"
        case .serviceNotFound:
            return "MIDI service not found on device"
        case .serviceDiscoveryTimeout:
            return "Service discovery timed out"
        case .characteristicNotFound:
            return "MIDI characteristic not found"
        case .characteristicDiscoveryTimeout:
            return "Characteristic discovery timed out"
        case .bluetoothUnavailable:
            return "Bluetooth is unavailable"
        }
    }
}

// MARK: - Logging Helpers

@available(macOS 12.0, *)
private extension BluetoothScanner {
    func logError(_ message: String, category: Logger.Category = .bluetooth) async {
        await Logger.shared.error(message, category: category)
    }
    
    func logWarning(_ message: String, category: Logger.Category = .bluetooth) async {
        await Logger.shared.warning(message, category: category)
    }
    
    func logInfo(_ message: String, category: Logger.Category = .bluetooth) async {
        await Logger.shared.info(message, category: category)
    }
    
    func logDebug(_ message: String, category: Logger.Category = .bluetooth) async {
        await Logger.shared.debug(message, category: category)
    }
    
    func logTrace(_ message: String, category: Logger.Category = .bluetooth) async {
        await Logger.shared.trace(message, category: category)
    }
}