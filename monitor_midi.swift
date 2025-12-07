#!/usr/bin/env swift
import Foundation
import CoreMIDI

print("🎹 MIDI Monitor - Listening for messages from PG_BT4 Bridge...")
print("Press buttons on PG_BT4 device to see MIDI messages")
print("Press Ctrl+C to stop\n")

// Create MIDI client
var client: MIDIClientRef = 0
var status = MIDIClientCreate("Monitor" as CFString, nil, nil, &client)

guard status == noErr else {
    print("❌ Failed to create MIDI client")
    exit(1)
}

// Find PG_BT4 Bridge source
let srcCount = MIDIGetNumberOfSources()
var bridgeSource: MIDIEndpointRef = 0

for i in 0..<srcCount {
    let src = MIDIGetSource(i)
    var name: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(src, kMIDIPropertyName, &name)
    
    if let portName = name?.takeRetainedValue() as String? {
        if portName.contains("PG_BT4 Bridge") {
            bridgeSource = src
            print("✅ Found '\(portName)'\n")
            break
        }
    }
}

guard bridgeSource != 0 else {
    print("❌ 'PG_BT4 Bridge' source not found")
    print("Make sure bt4bridge is running")
    MIDIClientDispose(client)
    exit(1)
}

// Create input port with legacy API to avoid memory issues
var inputPort: MIDIPortRef = 0
status = MIDIInputPortCreate(
    client,
    "Monitor Input" as CFString,
    { packetList, readProcRefCon, srcConnRefCon in
        var packet = packetList.pointee.packet
        
        for _ in 0..<packetList.pointee.numPackets {
            // Extract MIDI data
            let data = withUnsafePointer(to: &packet.data) { ptr in
                Data(bytes: ptr, count: Int(packet.length))
            }
            
            // Parse CC messages
            if data.count >= 3 && data[0] >= 0xB0 && data[0] <= 0xBF {
                let status = data[0]
                let controller = data[1]
                let value = data[2]
                let channel = status & 0x0F
                
                let timestamp = Date()
                let formatter = DateFormatter()
                formatter.dateFormat = "HH:mm:ss.SSS"
                let timeStr = formatter.string(from: timestamp)
                
                print("📥 [\(timeStr)] CC\(controller) = \(value) (channel \(channel))")
            }
            
            // Move to next packet
            packet = MIDIPacketNext(&packet).pointee
        }
    },
    nil,
    &inputPort
)

guard status == noErr else {
    print("❌ Failed to create input port")
    MIDIClientDispose(client)
    exit(1)
}

// Connect to source
status = MIDIPortConnectSource(inputPort, bridgeSource, nil)
guard status == noErr else {
    print("❌ Failed to connect to source")
    MIDIPortDispose(inputPort)
    MIDIClientDispose(client)
    exit(1)
}

print("👂 Listening... (press buttons on PG_BT4)\n")

// Run loop
RunLoop.main.run()
