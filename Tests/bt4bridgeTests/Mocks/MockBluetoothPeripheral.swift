import Foundation
import CoreBluetooth

/// Mock Bluetooth peripheral for testing PG_BT4 interactions
@available(macOS 12.0, *)
public class MockBluetoothPeripheral: NSObject {
    
    // MARK: - Properties
    
    /// Simulated peripheral name
    public let name: String = "PG_BT4"
    
    /// Simulated peripheral identifier
    public let identifier = UUID()
    
    /// Simulated RSSI value
    public var rssi: NSNumber = -50
    
    /// Simulated connection state
    public private(set) var isConnected = false
    
    /// Simulated services
    public private(set) var services: [MockCBService] = []
    
    /// Delegate for callbacks
    public weak var delegate: MockBluetoothPeripheralDelegate?
    
    /// Queue for simulating async operations
    private let queue = DispatchQueue(label: "mock.peripheral.queue")
    
    /// Simulated MIDI messages to send
    private var messageQueue: [Data] = []
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
        setupMIDIService()
    }
    
    // MARK: - Setup
    
    private func setupMIDIService() {
        // Create MIDI BLE service with standard UUID
        let midiService = MockCBService(uuid: CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"))
        
        // Add MIDI I/O characteristic
        let midiCharacteristic = MockCBCharacteristic(
            uuid: CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3"),
            properties: [.notify, .writeWithoutResponse, .read],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        midiService.characteristics = [midiCharacteristic]
        services = [midiService]
    }
    
    // MARK: - Connection Management
    
    /// Simulate connection
    public func connect(completion: @escaping (Bool) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }
            self.isConnected = true
            self.delegate?.mockPeripheralDidConnect(self)
            completion(true)
        }
    }
    
    /// Simulate disconnection
    public func disconnect() {
        isConnected = false
        delegate?.mockPeripheralDidDisconnect(self)
    }
    
    // MARK: - Service Discovery
    
    /// Simulate service discovery
    public func discoverServices(completion: @escaping ([MockCBService]?) -> Void) {
        queue.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            completion(self?.services)
        }
    }
    
    // MARK: - MIDI Message Simulation
    
    /// Queue a MIDI message to be sent
    public func queueMIDIMessage(_ data: Data) {
        messageQueue.append(data)
    }
    
    /// Simulate sending a Control Change message
    public func sendControlChange(channel: UInt8, controller: UInt8, value: UInt8) {
        let data = Data([
            0xB0 | (channel & 0x0F),
            controller & 0x7F,
            value & 0x7F
        ])
        sendMIDIData(data)
    }
    
    /// Simulate sending a Program Change message
    public func sendProgramChange(channel: UInt8, program: UInt8) {
        let data = Data([
            0xC0 | (channel & 0x0F),
            program & 0x7F
        ])
        sendMIDIData(data)
    }
    
    /// Simulate expression pedal movement
    public func simulateExpressionPedal(from startValue: UInt8, to endValue: UInt8, duration: TimeInterval = 1.0) {
        let steps = 20
        let stepDuration = duration / Double(steps)
        let valueDelta = Int(endValue) - Int(startValue)
        
        for i in 0...steps {
            let progress = Double(i) / Double(steps)
            let currentValue = UInt8(Int(startValue) + Int(Double(valueDelta) * progress))
            
            queue.asyncAfter(deadline: .now() + stepDuration * Double(i)) { [weak self] in
                self?.sendControlChange(channel: 0, controller: 11, value: currentValue) // CC#11 = Expression
            }
        }
    }
    
    /// Send MIDI data to delegate
    private func sendMIDIData(_ data: Data) {
        guard isConnected else { return }
        
        // Wrap in BLE MIDI packet format (simplified)
        var packet = Data()
        packet.append(0x80) // Header with timestamp
        packet.append(contentsOf: data)
        
        delegate?.mockPeripheral(self, didReceiveMIDIData: packet)
    }
    
    // MARK: - Write Operations
    
    /// Handle write operations (for receiving data from bridge)
    public func writeValue(_ data: Data, for characteristic: MockCBCharacteristic) {
        // Simulate processing time
        queue.asyncAfter(deadline: .now() + 0.01) { [weak self] in
            guard let self = self else { return }
            self.delegate?.mockPeripheral(self, didWriteValueFor: characteristic)
        }
    }
}

// MARK: - Mock Service

public class MockCBService {
    public let uuid: CBUUID
    public var characteristics: [MockCBCharacteristic] = []
    
    init(uuid: CBUUID) {
        self.uuid = uuid
    }
}

// MARK: - Mock Characteristic

public class MockCBCharacteristic {
    public let uuid: CBUUID
    public let properties: CBCharacteristicProperties
    public var value: Data?
    public let permissions: CBAttributePermissions
    
    init(uuid: CBUUID, properties: CBCharacteristicProperties, value: Data?, permissions: CBAttributePermissions) {
        self.uuid = uuid
        self.properties = properties
        self.value = value
        self.permissions = permissions
    }
}

// MARK: - Delegate Protocol

public protocol MockBluetoothPeripheralDelegate: AnyObject {
    func mockPeripheralDidConnect(_ peripheral: MockBluetoothPeripheral)
    func mockPeripheralDidDisconnect(_ peripheral: MockBluetoothPeripheral)
    func mockPeripheral(_ peripheral: MockBluetoothPeripheral, didReceiveMIDIData data: Data)
    func mockPeripheral(_ peripheral: MockBluetoothPeripheral, didWriteValueFor characteristic: MockCBCharacteristic)
}