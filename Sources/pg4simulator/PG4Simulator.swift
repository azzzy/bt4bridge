import Foundation
import CoreBluetooth
import Dispatch

/// BLE Peripheral simulator that mimics a PG_BT4 device
/// This allows the iPhone app to connect and we can log all commands it sends
@available(macOS 10.13, *)
class PG4Simulator: NSObject, CBPeripheralManagerDelegate {
    
    // MARK: - Properties
    
    private var peripheralManager: CBPeripheralManager!
    private var service: CBMutableService!
    
    // Characteristics matching real PG_BT4
    private var fff4Characteristic: CBMutableCharacteristic!  // Notify - sends button data
    private var fff2Characteristic: CBMutableCharacteristic!  // Write - receives LED commands
    private var fff3Characteristic: CBMutableCharacteristic!  // WriteWithoutResponse - receives LED commands
    
    // UUIDs from real PG_BT4
    private let serviceUUID = CBUUID(string: "1910")
    private let fff4UUID = CBUUID(string: "FFF4")
    private let fff2UUID = CBUUID(string: "FFF2")
    private let fff3UUID = CBUUID(string: "FFF3")
    
    // State
    private var isAdvertising = false
    private var connectedCentral: CBCentral?
    
    // Logging
    private var logFile: FileHandle?
    private let logPath = "/Users/daniel/dev/bt4bridge/pg4_simulator_log.txt"
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        
        // Create log file
        setupLogging()
        
        // Create peripheral manager
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Logging
    
    private func setupLogging() {
        let header = """
        ═══════════════════════════════════════════════════════
        PG_BT4 SIMULATOR LOG
        Date: \(Date())
        ═══════════════════════════════════════════════════════
        
        This simulator pretends to be a PG_BT4 device.
        Connect the iPhone app to see what commands it sends!
        
        """
        
        FileManager.default.createFile(atPath: logPath, contents: header.data(using: .utf8))
        logFile = FileHandle(forWritingAtPath: logPath)
        logFile?.seekToEndOfFile()
        
        print("📝 Logging to: \(logPath)")
    }
    
    private func log(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        print(logMessage, terminator: "")
        
        if let data = logMessage.data(using: .utf8) {
            logFile?.write(data)
        }
    }
    
    private func logHex(_ label: String, data: Data) {
        let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        log("\(label): \(hexString) (length: \(data.count) bytes)")
    }
    
    // MARK: - Setup
    
    private func setupService() {
        log("🔧 Setting up PG_BT4 service...")
        
        // Create characteristics matching real device
        
        // FFF4: Notify + Read - This is where we send button press data
        // Adding .read property in case the app tries to read initial state
        fff4Characteristic = CBMutableCharacteristic(
            type: fff4UUID,
            properties: [.notify, .read],
            value: nil,
            permissions: [.readable]
        )
        
        // FFF2: Write + Read - This is where app sends LED commands (with response)
        // Adding .read in case app reads current LED state
        fff2Characteristic = CBMutableCharacteristic(
            type: fff2UUID,
            properties: [.write, .read],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // FFF3: WriteWithoutResponse + Read - This is where app sends LED commands (no response)
        fff3Characteristic = CBMutableCharacteristic(
            type: fff3UUID,
            properties: [.writeWithoutResponse, .read],
            value: nil,
            permissions: [.readable, .writeable]
        )
        
        // Create service with all characteristics
        service = CBMutableService(type: serviceUUID, primary: true)
        service.characteristics = [fff4Characteristic, fff2Characteristic, fff3Characteristic]
        
        // Add service
        peripheralManager.add(service)
        
        log("✅ Service 1910 created with characteristics FFF4 (Notify), FFF2 (Write), FFF3 (WriteWithoutResponse)")
    }
    
    private func startAdvertising() {
        log("📡 Starting advertisement as 'PG_BT4'...")
        
        let advertisementData: [String: Any] = [
            CBAdvertisementDataLocalNameKey: "PG_BT4",
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID]
        ]
        
        peripheralManager.startAdvertising(advertisementData)
        isAdvertising = true
        
        log("✅ Now advertising! Connect from your iPhone app.")
    }
    
    // MARK: - Peripheral Manager Delegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            log("✅ Bluetooth powered on")
            setupService()
        case .poweredOff:
            log("❌ Bluetooth powered off")
        case .resetting:
            log("⏳ Bluetooth resetting")
        case .unauthorized:
            log("❌ Bluetooth unauthorized")
        case .unsupported:
            log("❌ Bluetooth unsupported")
        case .unknown:
            log("❓ Bluetooth state unknown")
        @unknown default:
            log("❓ Bluetooth state unknown default")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            log("❌ Error adding service: \(error.localizedDescription)")
            return
        }
        
        log("✅ Service added successfully")
        startAdvertising()
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            log("❌ Error starting advertisement: \(error.localizedDescription)")
            return
        }
        
        log("✅ Advertisement started successfully")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        log("📱 iPhone app subscribed to characteristic: \(characteristic.uuid.uuidString)")
        connectedCentral = central
        
        if characteristic.uuid == fff4UUID {
            log("✅ App is now listening for button presses on FFF4")
            log("💡 You can simulate button presses by typing 1-4 and pressing Enter")
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        log("📱 iPhone app unsubscribed from characteristic: \(characteristic.uuid.uuidString)")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        log("📥 RECEIVED WRITE REQUEST FROM iPHONE APP!")
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        for request in requests {
            let charUUID = request.characteristic.uuid.uuidString
            
            log("Characteristic: \(charUUID)")
            
            if let value = request.value {
                logHex("📦 DATA", data: value)
                
                // Analyze the data
                if value.count >= 3 {
                    let byte0 = value[0]
                    let byte1 = value[1]
                    let byte2 = value[2]
                    
                    log("   Byte 0: 0x\(String(format: "%02X", byte0)) (\(byte0))")
                    log("   Byte 1: 0x\(String(format: "%02X", byte1)) (\(byte1))")
                    log("   Byte 2: 0x\(String(format: "%02X", byte2)) (\(byte2))")
                    
                    // Check if it matches known button format
                    if byte0 == 0xB1 {
                        switch byte1 {
                        case 0x10:
                            log("   → This looks like LED control for BUTTON 1")
                        case 0x11:
                            log("   → This looks like LED control for BUTTON 2")
                        case 0x12:
                            log("   → This looks like LED control for BUTTON 3")
                        case 0x13:
                            log("   → This looks like LED control for BUTTON 4")
                        case 0x1F:
                            log("   → This is the mystery 0x1F packet!")
                        default:
                            log("   → Unknown button/command")
                        }
                        
                        if byte2 == 0x00 {
                            log("   → LED OFF (0x00)")
                        } else if byte2 == 0x01 {
                            log("   → LED ON (0x01)")
                        } else {
                            log("   → Unknown value: 0x\(String(format: "%02X", byte2))")
                        }
                    } else {
                        log("   → NOT standard B1 format - new protocol discovery!")
                    }
                }
                
                if value.count > 3 {
                    log("   → Additional bytes present - analyzing...")
                    for i in 3..<value.count {
                        log("   Byte \(i): 0x\(String(format: "%02X", value[i])) (\(value[i]))")
                    }
                }
            } else {
                log("⚠️  No data in request")
            }
            
            // Respond to write requests (for FFF2)
            if request.characteristic.uuid == fff2UUID {
                peripheralManager.respond(to: request, withResult: .success)
                log("✅ Responded with success to FFF2 write")
            }
        }
        
        log("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        log("📥 READ request for characteristic: \(request.characteristic.uuid.uuidString)")
        
        // Return dummy data for reads
        var responseData: Data?
        
        switch request.characteristic.uuid {
        case fff4UUID:
            // Return "all buttons released" state
            responseData = Data([0xB1, 0x10, 0x00])
            log("   → Returning dummy button state: B1 10 00")
        case fff2UUID, fff3UUID:
            // Return "all LEDs off" state
            responseData = Data([0xB1, 0x10, 0x00])
            log("   → Returning dummy LED state: B1 10 00")
        default:
            log("   → Unknown characteristic, returning empty")
        }
        
        if let data = responseData, request.offset < data.count {
            request.value = data.subdata(in: request.offset..<data.count)
        }
        
        peripheralManager.respond(to: request, withResult: .success)
        log("✅ Read request handled")
    }
    
    // Track connection state changes
    func peripheralManager(_ peripheral: CBPeripheralManager, willRestoreState dict: [String : Any]) {
        log("📱 Peripheral manager will restore state")
    }
    
    // MARK: - Simulating Button Presses
    
    func simulateButtonPress(button: Int) {
        guard let central = connectedCentral else {
            log("⚠️  No central connected - cannot send button press")
            return
        }
        
        guard button >= 1 && button <= 4 else {
            log("⚠️  Invalid button number: \(button)")
            return
        }
        
        let switchByte: UInt8 = 0x10 + UInt8(button - 1)  // 0x10-0x13
        
        // Send press (0x01)
        let pressData = Data([0xB1, switchByte, 0x01])
        log("🔘 Simulating button \(button) PRESS")
        logHex("   TX", data: pressData)
        peripheralManager.updateValue(pressData, for: fff4Characteristic, onSubscribedCentrals: [central])
        
        // Wait 100ms then send release
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            let releaseData = Data([0xB1, switchByte, 0x00])
            self?.log("🔘 Simulating button \(button) RELEASE")
            self?.logHex("   TX", data: releaseData)
            self?.peripheralManager.updateValue(releaseData, for: self!.fff4Characteristic, onSubscribedCentrals: [central])
        }
    }
}

// MARK: - Main Application

@available(macOS 10.13, *)
@main
struct PG4SimulatorApp {
    static func main() {
        print("""
        ╔═══════════════════════════════════════════════════════════╗
        ║           PG_BT4 BLUETOOTH PERIPHERAL SIMULATOR           ║
        ╚═══════════════════════════════════════════════════════════╝
        
        This program simulates a PG_BT4 device so the iPhone app
        can connect to it. We'll log EVERY command the app sends!
        
        📱 HOW TO USE:
        1. Make sure your REAL PG_BT4 is turned OFF
        2. Wait for "Now advertising!" message
        3. Open the PG_BT4 iPhone app
        4. Connect to "PG_BT4" in the app
        5. Press buttons in the app to control LEDs
        6. Watch this terminal for logged commands!
        
        💡 INTERACTIVE COMMANDS:
        - Type 1-4 and press Enter to simulate button presses
        - Type 'q' and press Enter to quit
        
        ═══════════════════════════════════════════════════════════
        
        """)
        
        let simulator = PG4Simulator()
        
        // Handle user input on background thread
        DispatchQueue.global(qos: .userInteractive).async {
            while true {
                if let input = readLine()?.trimmingCharacters(in: .whitespaces) {
                    if input.lowercased() == "q" {
                        print("\n👋 Shutting down simulator...")
                        exit(0)
                    } else if let buttonNumber = Int(input), buttonNumber >= 1 && buttonNumber <= 4 {
                        DispatchQueue.main.async {
                            simulator.simulateButtonPress(button: buttonNumber)
                        }
                    }
                }
            }
        }
        
        // Keep running
        RunLoop.main.run()
    }
}
