#!/usr/bin/env swift
import Foundation
import CoreMIDI

// Simple tool to send MIDI CC to PG_BT4 Bridge
// Usage: ./send_cc.swift <cc_number> <value>

guard CommandLine.arguments.count >= 3 else {
    print("Usage: \(CommandLine.arguments[0]) <cc_number> <value>")
    print("")
    print("Examples:")
    print("  \(CommandLine.arguments[0]) 16 127   # LED 1 ON")
    print("  \(CommandLine.arguments[0]) 16 0     # LED 1 OFF")
    print("  \(CommandLine.arguments[0]) 17 127   # LED 2 ON")
    print("  \(CommandLine.arguments[0]) 18 64    # LED 3 ON")
    exit(1)
}

guard let ccNumber = UInt8(CommandLine.arguments[1]),
      let ccValue = UInt8(CommandLine.arguments[2]) else {
    print("❌ Invalid CC number or value (must be 0-127)")
    exit(1)
}

// Find PG_BT4 Bridge destination
let destCount = MIDIGetNumberOfDestinations()
var bridgeDest: MIDIEndpointRef = 0

for i in 0..<destCount {
    let dest = MIDIGetDestination(i)
    var name: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &name)
    
    if let portName = name?.takeRetainedValue() as String? {
        if portName.contains("PG_BT4 Bridge") {
            bridgeDest = dest
            print("✅ Found '\(portName)'")
            break
        }
    }
}

guard bridgeDest != 0 else {
    print("❌ 'PG_BT4 Bridge' MIDI port not found")
    print("")
    print("Make sure bt4bridge is running:")
    print("  .build/release/bt4bridge")
    exit(1)
}

// Create MIDI client
var client: MIDIClientRef = 0
var status = MIDIClientCreate("SendCC" as CFString, nil, nil, &client)

guard status == noErr else {
    print("❌ Failed to create MIDI client: \(status)")
    exit(1)
}

// Create output port
var outputPort: MIDIPortRef = 0
status = MIDIOutputPortCreate(client, "Output" as CFString, &outputPort)

guard status == noErr else {
    print("❌ Failed to create output port: \(status)")
    MIDIClientDispose(client)
    exit(1)
}

// Create MIDI CC message
// Format: Bn cc vv (where n = channel 0-15)
let midiData: [UInt8] = [
    0xB0,      // Control Change on channel 0
    ccNumber,  // CC number
    ccValue    // CC value
]

// Send the message
var packetList = MIDIPacketList()
var packet = MIDIPacketListInit(&packetList)

packet = MIDIPacketListAdd(
    &packetList,
    1024,
    packet,
    0,  // timestamp (now)
    midiData.count,
    midiData
)

status = MIDISend(outputPort, bridgeDest, &packetList)

if status == noErr {
    let ledNum = ccNumber - 15
    let state = ccValue >= 64 ? "ON" : "OFF"
    print("📤 Sent CC\(ccNumber) = \(ccValue) → LED \(ledNum) \(state)")
} else {
    print("❌ Failed to send MIDI: \(status)")
    MIDIPortDispose(outputPort)
    MIDIClientDispose(client)
    exit(1)
}

// Cleanup
MIDIPortDispose(outputPort)
MIDIClientDispose(client)
