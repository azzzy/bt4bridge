import Foundation
import CoreBluetooth
import Dispatch

/// LED Testing Tool - Tries different command combinations based on discovered patterns
@available(macOS 12.0, *)
class LEDTester: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
    
    private var centralManager: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var writeCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    private var testIndex = 0
    
    // NEW: Test commands based on Console.app pattern discovery!
    // The FFF4 notification showed: 01 A1 16 01 A1 17 01 A1 18 01 A1 19 01
    // This appears to be button press reports. Let's try LED control with similar patterns.
    private let testCommands: [(description: String, data: Data)] = [
        // Pattern 1: Based on button notification format (01 A1 XX)
        ("01 A0 16 - LED 1 OFF (pattern match)", Data([0x01, 0xA0, 0x16])),
        ("01 A1 16 - LED 1 ON (pattern match)", Data([0x01, 0xA1, 0x16])),
        ("01 A0 17 - LED 2 OFF (pattern match)", Data([0x01, 0xA0, 0x17])),
        ("01 A1 17 - LED 2 ON (pattern match)", Data([0x01, 0xA1, 0x17])),
        ("01 A0 18 - LED 3 OFF (pattern match)", Data([0x01, 0xA0, 0x18])),
        ("01 A1 18 - LED 3 ON (pattern match)", Data([0x01, 0xA1, 0x18])),
        ("01 A0 19 - LED 4 OFF (pattern match)", Data([0x01, 0xA0, 0x19])),
        ("01 A1 19 - LED 4 ON (pattern match)", Data([0x01, 0xA1, 0x19])),
        
        // Pattern 2: Try A2/A3 for different states
        ("01 A2 16 - LED 1 blink?", Data([0x01, 0xA2, 0x16])),
        ("01 A3 16 - LED 1 dim?", Data([0x01, 0xA3, 0x16])),
        
        // Pattern 3: Try without prefix byte
        ("A0 16 - LED 1 OFF (no prefix)", Data([0xA0, 0x16])),
        ("A1 16 - LED 1 ON (no prefix)", Data([0xA1, 0x16])),
        ("A0 17 - LED 2 OFF (no prefix)", Data([0xA0, 0x17])),
        ("A1 17 - LED 2 ON (no prefix)", Data([0xA1, 0x17])),
        
        // Pattern 4: All LEDs control
        ("01 A0 1A - All LEDs OFF?", Data([0x01, 0xA0, 0x1A])),
        ("01 A1 1A - All LEDs ON?", Data([0x01, 0xA1, 0x1A])),
        ("01 A0 1F - All LEDs OFF (1F)?", Data([0x01, 0xA0, 0x1F])),
        ("01 A1 1F - All LEDs ON (1F)?", Data([0x01, 0xA1, 0x1F])),
        
        // Pattern 5: Original B1 format (still worth trying)
        ("B1 10 00 - LED 1 OFF (MIDI-like)", Data([0xB1, 0x10, 0x00])),
        ("B1 10 01 - LED 1 ON (MIDI-like)", Data([0xB1, 0x10, 0x01])),
        ("B1 11 00 - LED 2 OFF (MIDI-like)", Data([0xB1, 0x11, 0x00])),
        ("B1 11 01 - LED 2 ON (MIDI-like)", Data([0xB1, 0x11, 0x01])),
        ("B1 12 00 - LED 3 OFF (MIDI-like)", Data([0xB1, 0x12, 0x00])),
        ("B1 12 01 - LED 3 ON (MIDI-like)", Data([0xB1, 0x12, 0x01])),
        ("B1 13 00 - LED 4 OFF (MIDI-like)", Data([0xB1, 0x13, 0x00])),
        ("B1 13 01 - LED 4 ON (MIDI-like)", Data([0xB1, 0x13, 0x01])),
        
        // Pattern 6: Try inverted A values
        ("01 16 A0 - LED 1 OFF (reversed)", Data([0x01, 0x16, 0xA0])),
        ("01 16 A1 - LED 1 ON (reversed)", Data([0x01, 0x16, 0xA1])),
        
        // Pattern 7: Try with 0x00 prefix like button reports seem to suggest
        ("00 A0 16 - LED 1 OFF (00 prefix)", Data([0x00, 0xA0, 0x16])),
        ("00 A1 16 - LED 1 ON (00 prefix)", Data([0x00, 0xA1, 0x16])),
        
        // Pattern 8: Try 4-byte format matching button pattern spacing
        ("01 A0 16 00 - LED 1 OFF (4-byte)", Data([0x01, 0xA0, 0x16, 0x00])),
        ("01 A1 16 00 - LED 1 ON (4-byte)", Data([0x01, 0xA1, 0x16, 0x00])),
        
        // Pattern 9: Try single LED index (0-3)
        ("00 - LED index 0", Data([0x00])),
        ("01 - LED index 1", Data([0x01])),
        ("02 - LED index 2", Data([0x02])),
        ("03 - LED index 3", Data([0x03])),
        
        // Pattern 10: Try brightness values
        ("01 A1 16 7F - LED 1 half bright", Data([0x01, 0xA1, 0x16, 0x7F])),
        ("01 A1 16 FF - LED 1 max bright", Data([0x01, 0xA1, 0x16, 0xFF])),
        
        // Pattern 11: Try hex sequences similar to button data
        ("A1 16 - Just state+index", Data([0xA1, 0x16])),
        ("A0 16 - Just off+index", Data([0xA0, 0x16])),
        
        // Pattern 12: Try CC-like format (channel + value)
        ("10 00 - CC 16 value 0", Data([0x10, 0x00])),
        ("10 7F - CC 16 value 127", Data([0x10, 0x7F])),
        
        // Pattern 13: Mystery byte from logs
        ("1F 4B - Mystery from earlier", Data([0x1F, 0x4B])),
        ("1F 00 - Mystery off", Data([0x1F, 0x00])),
        ("1F 01 - Mystery on", Data([0x1F, 0x01])),
    ]
    
    override init() {
        super.init()
        print("🔧 Initializing Bluetooth Central Manager...")
        centralManager = CBCentralManager(delegate: self, queue: nil)
        print("⏳ Waiting for Bluetooth to power on...")
    }
    
    // MARK: - Central Manager Delegate
    
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            print("✅ Bluetooth powered on")
            print("🔍 Scanning for PG_BT4...")
            print("   Looking for device name: PG_BT4")
            // Scan for all devices and filter by name (some devices don't advertise service UUIDs)
            centralManager.scanForPeripherals(
                withServices: nil,
                options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
            )
            
            // Add timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) { [weak self] in
                if self?.peripheral == nil {
                    print("\n⚠️  No PG_BT4 found after 10 seconds")
                    print("   Make sure:")
                    print("   1. PG_BT4 is turned ON")
                    print("   2. Not connected to other apps (close iPhone app!)")
                    print("   3. Close enough to Mac")
                    print("\n   Continuing to scan...")
                }
            }
        case .poweredOff:
            print("❌ Bluetooth is powered off - turn it on in System Settings")
        case .unsupported:
            print("❌ Bluetooth is not supported on this Mac")
        case .unauthorized:
            print("❌ Bluetooth access not authorized - check Privacy settings")
        case .resetting:
            print("⏳ Bluetooth is resetting - please wait...")
        case .unknown:
            print("❓ Bluetooth state unknown")
        @unknown default:
            print("❓ Unknown Bluetooth state")
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? "Unknown"
        
        // Look for PG_BT4
        if name.contains("PG_BT4") || name.contains("PG-BT4") || name.contains("PG_") {
            print("\n📱 Found: \(name)")
            print("   RSSI: \(RSSI) dBm")
            print("   UUID: \(peripheral.identifier)")
            print("🔗 Connecting...")
            
            self.peripheral = peripheral
            peripheral.delegate = self
            central.stopScan()
            central.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("✅ Connected to \(peripheral.name ?? "PG_BT4")")
        print("🔍 Discovering all services...")
        // Discover all services (nil) - some devices may not advertise the service UUID
        peripheral.discoverServices(nil)
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("❌ Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        print("   Retrying in 3 seconds...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            self?.centralManager.connect(peripheral, options: nil)
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("\n📡 Disconnected from PG_BT4")
        if let error = error {
            print("   Error: \(error.localizedDescription)")
        }
        print("   Reconnecting...")
        central.connect(peripheral, options: nil)
    }
    
    // MARK: - Peripheral Delegate
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("❌ Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else {
            print("❌ No services found")
            return
        }
        
        print("✅ Found \(services.count) service(s)")
        
        for service in services {
            print("   Service: \(service.uuid)")
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let error = error {
            print("❌ Error discovering characteristics: \(error.localizedDescription)")
            return
        }
        
        guard let characteristics = service.characteristics else {
            print("❌ No characteristics found")
            return
        }
        
        print("✅ Found \(characteristics.count) characteristic(s) in service \(service.uuid):")
        
        for char in characteristics {
            let props = char.properties
            var propsStr: [String] = []
            if props.contains(.read) { propsStr.append("Read") }
            if props.contains(.write) { propsStr.append("Write") }
            if props.contains(.writeWithoutResponse) { propsStr.append("WriteWithoutResponse") }
            if props.contains(.notify) { propsStr.append("Notify") }
            if props.contains(.indicate) { propsStr.append("Indicate") }
            
            print("   \(char.uuid): \(propsStr.joined(separator: ", "))")
            
            // Use FFF2 for writing (WriteWithoutResponse)
            if char.uuid.uuidString == "FFF2" {
                writeCharacteristic = char
                print("   ⭐ Will use FFF2 for LED commands")
            }
            
            // Subscribe to FFF4 for button notifications (helpful for debugging)
            if char.uuid.uuidString == "FFF4" && props.contains(.notify) {
                notifyCharacteristic = char
                peripheral.setNotifyValue(true, for: char)
                print("   📡 Subscribed to FFF4 notifications (button presses)")
            }
        }
        
        if writeCharacteristic != nil {
            print("\n" + String(repeating: "=", count: 80))
            print("🧪 STARTING PATTERN-BASED LED TESTS")
            print(String(repeating: "=", count: 80))
            print("\n📋 Test Strategy:")
            print("   Based on Console.app logs, button notifications use: 01 A1 16/17/18/19")
            print("   Testing if LEDs use similar pattern with A0 (OFF) and A1 (ON)")
            print("")
            print("⚠️  WATCH THE PHYSICAL LEDs ON YOUR PG_BT4!")
            print("   • Note which test number causes LED changes")
            print("   • Press Ctrl+C to stop at any time")
            print("   • Each test runs for 2 seconds\n")
            
            // Wait 2 seconds then start testing
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.runNextTest()
            }
        } else {
            print("❌ FFF2 characteristic not found - cannot test")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateNotificationStateFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print("   ⚠️  Notification subscription error: \(error.localizedDescription)")
        } else {
            print("   ✅ Subscribed to \(characteristic.uuid)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid.uuidString == "FFF4" {
            if let data = characteristic.value {
                let hexString = data.map { String(format: "%02X", $0) }.joined(separator: " ")
                print("   📨 Button press received: \(hexString)")
            }
        }
    }
    
    // MARK: - Testing
    
    func runNextTest() {
        guard let peripheral = peripheral,
              let writeChar = writeCharacteristic else {
            print("❌ Not ready to test")
            return
        }
        
        guard testIndex < testCommands.count else {
            print("\n" + String(repeating: "=", count: 80))
            print("✅ ALL \(testCommands.count) TESTS COMPLETE!")
            print(String(repeating: "=", count: 80))
            print("\n📊 Results:")
            print("   • If LEDs changed: Note the test # and command format")
            print("   • If no changes: LED control may use FFF3 (Indicate) instead")
            print("   • Try pressing physical buttons to see FFF4 notifications")
            print("\n💡 Next steps:")
            print("   1. If you saw LED changes, report which test # worked")
            print("   2. If no changes, we may need hardware BLE sniffer ($40)")
            print("   3. Press Ctrl+C to exit\n")
            return
        }
        
        let test = testCommands[testIndex]
        let hexString = test.data.map { String(format: "%02X", $0) }.joined(separator: " ")
        
        print("[\(testIndex + 1)/\(testCommands.count)] \(test.description)")
        print("        Hex: \(hexString)")
        print("        👀 Watch LEDs... ", terminator: "")
        fflush(stdout)
        
        // Write the command
        peripheral.writeValue(
            test.data,
            for: writeChar,
            type: .withoutResponse
        )
        
        testIndex += 1
        
        // Wait 2 seconds between tests so you can observe
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            print("Done")
            self?.runNextTest()
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        if let error = error {
            print(" ❌ Write failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - Main

@available(macOS 12.0, *)
@main
struct LEDTesterApp {
    static func main() {
        print("""
        ╔════════════════════════════════════════════════════════════════════════════╗
        ║              PG_BT4 PATTERN-BASED LED COMMAND TESTER v2.0                  ║
        ╚════════════════════════════════════════════════════════════════════════════╝
        
        🔍 DISCOVERY FROM CONSOLE.APP LOGS:
           • Buttons send: 01 A1 16 (btn1), 01 A1 17 (btn2), etc.
           • Testing if LEDs use: 01 A0 XX (OFF) and 01 A1 XX (ON)
           • Also testing original B1 10 XX MIDI-like format
        
        📋 BEFORE STARTING:
           1. ⚠️  CLOSE THE IPHONE APP! (must disconnect first)
           2. Make sure PG_BT4 is turned ON
           3. Keep your eyes on the physical LEDs
           4. Have a pen ready to note which test # works
        
        ⏱️  Test Duration:
           • \(49) different command patterns
           • 2 seconds per test = ~100 seconds total
           • Press Ctrl+C to stop early
        
        👀 IMPORTANT:
           • Watch the LEDs carefully!
           • If any LED turns OFF/ON, note the test number!
           • Button presses will show in console for debugging
        
        ════════════════════════════════════════════════════════════════════════════
        
        """)
        
        _ = LEDTester()
        
        // Keep running
        RunLoop.main.run()
    }
}
