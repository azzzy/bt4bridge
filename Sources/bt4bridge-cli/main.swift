import Foundation
import CoreBluetooth
import CoreMIDI
import Dispatch
import BT4BridgeCore

@available(macOS 12.0, *)
@main
struct BT4BridgeApp {
    
    static func main() {
        // Check for --test-leds flag
        let args = CommandLine.arguments
        let testMode = args.contains("--test-leds")
        
        if testMode {
            print("🧪 PG_BT4 LED Pattern Tester")
        } else {
            print("🎸 PG_BT4 Bridge v1.0.0")
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print(testMode ? "Starting LED pattern tests..." : "Starting bridge...")
        fflush(stdout)
        
        Task {
            if testMode {
                await runLEDTests()
            } else {
                await runBridge()
            }
        }
        
        // Keep running
        dispatchMain()
    }
    
    static func runBridge() async {
        // Configure logger  
        await Logger.shared.setLevel(.trace)  // Enable TRACE to see all TX/RX
        await Logger.shared.setConsoleEnabled(true)
        
        // Create and start bridge
        let bridge = Bridge()
        
        do {
            try await bridge.start()
            print("✅ Bridge started successfully")
            print("• Scanning for PG_BT4...")
            print("• Virtual MIDI ports created")
            print("\nPress Ctrl+C to stop")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            fflush(stdout)
            
            // Monitor status
            var lastStatus = ""
            while true {
                try await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                
                let stats = await bridge.getStatistics()
                let btStats = await bridge.getBluetoothStatistics()
                
                let status: String
                if btStats.isConnected {
                    let ccs = await bridge.getDiscoveredCCs()
                    var statusParts = ["✅ Connected to PG_BT4"]
                    if let rssi = btStats.rssi {
                        statusParts.append("RSSI: \(rssi)")
                    }
                    statusParts.append("Messages: \(stats.totalMessagesForwarded)")
                    if !ccs.isEmpty {
                        statusParts.append("CCs: \(ccs.count)")
                    }
                    status = statusParts.joined(separator: " | ")
                } else {
                    status = "⏳ Scanning for PG_BT4..."
                }
                
                if status != lastStatus {
                    print(status)
                    fflush(stdout)
                    lastStatus = status
                }
            }
            
        } catch {
            print("❌ Failed to start bridge: \(error)")
            fflush(stdout)
            exit(1)
        }
    }
    
    static func runLEDTests() async {
        // Configure logger
        await Logger.shared.setLevel(.debug)
        await Logger.shared.setConsoleEnabled(true)
        
        print("\n🧪 LED Pattern Testing Mode")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("This will try 49 different LED command patterns")
        print("Watch the LEDs on your PG_BT4 device")
        print("Each pattern runs for 2 seconds")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        fflush(stdout)
        
        // LED commands CONFIRMED working from PacketLogger capture!
        // Format: A2 [LED_NUMBER] [STATE]
        // LED_NUMBER: 0x10=LED1, 0x11=LED2, 0x12=LED3, 0x13=LED4
        // STATE: 0x00=ON, 0x01=OFF (REVERSED LOGIC!)
        let testCommands: [(String, Data)] = [
            // Test each LED individually
            ("A2 10 00 - LED 1 ON", Data([0xA2, 0x10, 0x00])),
            ("A2 10 01 - LED 1 OFF", Data([0xA2, 0x10, 0x01])),
            
            ("A2 11 00 - LED 2 ON", Data([0xA2, 0x11, 0x00])),
            ("A2 11 01 - LED 2 OFF", Data([0xA2, 0x11, 0x01])),
            
            ("A2 12 00 - LED 3 ON", Data([0xA2, 0x12, 0x00])),
            ("A2 12 01 - LED 3 OFF", Data([0xA2, 0x12, 0x01])),
            
            ("A2 13 00 - LED 4 ON", Data([0xA2, 0x13, 0x00])),
            ("A2 13 01 - LED 4 OFF", Data([0xA2, 0x13, 0x01])),
            
            // Test all LEDs ON
            ("A2 10 00 - All LEDs ON - Step 1", Data([0xA2, 0x10, 0x00])),
            ("A2 11 00 - All LEDs ON - Step 2", Data([0xA2, 0x11, 0x00])),
            ("A2 12 00 - All LEDs ON - Step 3", Data([0xA2, 0x12, 0x00])),
            ("A2 13 00 - All LEDs ON - Step 4", Data([0xA2, 0x13, 0x00])),
            
            // Test all LEDs OFF
            ("A2 10 01 - All LEDs OFF - Step 1", Data([0xA2, 0x10, 0x01])),
            ("A2 11 01 - All LEDs OFF - Step 2", Data([0xA2, 0x11, 0x01])),
            ("A2 12 01 - All LEDs OFF - Step 3", Data([0xA2, 0x12, 0x01])),
            ("A2 13 01 - All LEDs OFF - Step 4", Data([0xA2, 0x13, 0x01])),
        ]
        
        print("\n💡 LED Command Format Discovered:")
        print("   A2 [LED] [STATE]")
        print("   LED: 10=LED1, 11=LED2, 12=LED3, 13=LED4")
        print("   STATE: 00=ON, 01=OFF (reversed logic!)")
        print("")
        fflush(stdout)
        
        // Create bridge to connect
        let bridge = Bridge()
        
        do {
            try await bridge.start()
            print("✅ Bridge started")
            print("• Waiting for PG_BT4 connection...\n")
            fflush(stdout)
            
            // Wait for connection
            var connected = false
            for _ in 0..<30 { // Wait up to 30 seconds
                let stats = await bridge.getBluetoothStatistics()
                if stats.isConnected {
                    connected = true
                    break
                }
                try await Task.sleep(nanoseconds: 1_000_000_000)
            }
            
            guard connected else {
                print("❌ Failed to connect to PG_BT4 after 30 seconds")
                print("   Make sure:")
                print("   1. PG_BT4 is turned ON")
                print("   2. Not connected to other apps (close iPhone app!)")
                print("   3. Close enough to Mac")
                exit(1)
            }
            
            print("✅ Connected to PG_BT4!\n")
            print(String(repeating: "=", count: 80))
            print("STARTING TESTS - Watch the LEDs!")
            print(String(repeating: "=", count: 80))
            fflush(stdout)
            
            // Run tests
            for (index, (description, data)) in testCommands.enumerated() {
                let testNum = index + 1
                print("\n[\(testNum)/\(testCommands.count)] Testing: \(description)")
                print("   Sending: \(data.map { String(format: "%02X", $0) }.joined(separator: " "))")
                fflush(stdout)
                
                // Send the test command via bridge
                await bridge.sendTestCommand(data)
                
                // Wait 3 seconds before next test (slower timing for visibility)
                try await Task.sleep(nanoseconds: 3_000_000_000)
            }
            
            print("\n" + String(repeating: "=", count: 80))
            print("✅ All \(testCommands.count) tests completed!")
            print(String(repeating: "=", count: 80))
            print("\nDid you see any LED changes? If so, note which test number worked!")
            fflush(stdout)
            
            exit(0)
            
        } catch {
            print("❌ Failed to run LED tests: \(error)")
            fflush(stdout)
            exit(1)
        }
    }
}