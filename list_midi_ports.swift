#!/usr/bin/env swift
import Foundation
import CoreMIDI

print("=== MIDI Destinations (where you can SEND to) ===\n")
let destCount = MIDIGetNumberOfDestinations()
for i in 0..<destCount {
    let dest = MIDIGetDestination(i)
    var name: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(dest, kMIDIPropertyName, &name)
    
    if let portName = name?.takeRetainedValue() as String? {
        print("[\(i)] \(portName)")
    }
}

print("\n=== MIDI Sources (where you can RECEIVE from) ===\n")
let srcCount = MIDIGetNumberOfSources()
for i in 0..<srcCount {
    let src = MIDIGetSource(i)
    var name: Unmanaged<CFString>?
    MIDIObjectGetStringProperty(src, kMIDIPropertyName, &name)
    
    if let portName = name?.takeRetainedValue() as String? {
        print("[\(i)] \(portName)")
    }
}
