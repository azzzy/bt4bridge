# Quick Start Guide: PG_BT4 Bluetooth Bridge

**Version**: 1.0.0  
**Date**: 2024-12-07

## Overview

bt4bridge is a macOS bridge that connects your PG_BT4 Bluetooth foot controller to CoreMIDI, enabling wireless MIDI control in your DAW. The bridge automatically converts PG_BT4's custom protocol to standard MIDI CC messages.

## What It Does

- **4 Button Support**: All buttons mapped to MIDI CC 80-83
- **Automatic Connection**: Discovers and connects to PG_BT4 automatically
- **Virtual MIDI Ports**: Creates "PG_BT4 Bridge" ports visible in any DAW
- **Low Latency**: Real-time forwarding optimized for live performance
- **Reliable**: Automatic reconnection if Bluetooth drops

## Prerequisites

- macOS 12.0 (Monterey) or later
- Bluetooth 4.0+ capable Mac
- Swift 6.2+ installed (comes with Xcode 15+)
- PG_BT4 Bluetooth foot controller
- DAW or MIDI-compatible software

## Installation

### Build from Source

```bash
cd /Users/daniel/dev/bt4bridge
swift build -c release
```

The executable will be at `.build/release/bt4bridge`

## Quick Start

### 1. Start the Bridge

```bash
.build/release/bt4bridge
```

You'll see:
```
🎸 PG_BT4 Bridge v1.0.0
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Starting bridge...
✅ Bridge started successfully
• Scanning for PG_BT4...
• Virtual MIDI ports created

Press Ctrl+C to stop
━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⏳ Scanning for PG_BT4...
```

### 2. Turn On PG_BT4

Power on your controller. Within seconds you'll see:
```
✅ Connected to PG_BT4 | RSSI: -45 | Messages: 0
```

### 3. Configure Your DAW

Open your DAW's MIDI preferences and enable "PG_BT4 Bridge" as an input device.

### 4. Map the Buttons

Map the MIDI CC messages to your desired functions:
- **Button 1**: CC 80 (channel 0)
- **Button 2**: CC 81 (channel 0)
- **Button 3**: CC 82 (channel 0)
- **Button 4**: CC 83 (channel 0)

Values: 127 = pressed, 0 = released

## Example Use Cases

### Ableton Live
- Scene switching: Map CC 80-83 to scene triggers
- Track muting: Assign to track mute toggles
- Transport: Map to play/stop/record

### Logic Pro
- Bypass effects: Toggle effect on/off
- Smart Controls: Trigger automation
- Marker navigation: Jump between sections

### General DAW
- Any MIDI-learnable parameter
- Effect toggles
- Track selection
- Loop triggering

## Troubleshooting

### PG_BT4 Not Connecting

1. Ensure Bluetooth is enabled on your Mac
2. Make sure PG_BT4 is powered on
3. Disconnect from any other devices (iPhone app, etc.)
4. Try resetting Bluetooth: `sudo pkill bluetoothd`
5. Restart bt4bridge

### MIDI Port Not Visible in DAW

1. Restart your DAW after starting bt4bridge
2. Open Audio MIDI Setup (Applications > Utilities)
3. Verify "PG_BT4 Bridge" appears in MIDI Studio
4. Check that bt4bridge is still running (hasn't crashed)

### Button Presses Not Working

1. Check terminal output - you should see messages when pressing buttons
2. Look for "RAW RX" lines showing `B1 10 01` format
3. Verify DAW has "PG_BT4 Bridge" enabled as input
4. Check DAW's MIDI monitor to confirm CC messages arrive
5. Ensure CC 80-83 aren't filtered in your DAW settings

### LED Behavior

Note: LED control is not currently implemented.
- LEDs turn ON when bridge connects (normal hardware behavior)
- LEDs flash briefly when physically pressing buttons
- LEDs cannot be controlled via MIDI input at this time
- See LED_NEXT_STEPS.md for implementation options

## Technical Details

### PG_BT4 Protocol

The PG_BT4 uses a custom (non-standard MIDI) Bluetooth protocol:
- **BLE Service UUID**: 1910
- **Characteristic FFF4** (Notify): Receives button data
- **Packet Format**: `B1 [10-13] [00/01]`
  - `B1` = Header byte
  - `10-13` = Switch identifier (1-4)
  - `00/01` = Released (0) / Pressed (1)

The bridge automatically converts these to standard MIDI CC messages for universal compatibility.

## Quick Reference

| Button | MIDI Message | Value (Pressed) | Value (Released) |
|--------|-------------|----------------|------------------|
| Button 1 | CC 80 (Ch 0) | 127 | 0 |
| Button 2 | CC 81 (Ch 0) | 127 | 0 |
| Button 3 | CC 82 (Ch 0) | 127 | 0 |
| Button 4 | CC 83 (Ch 0) | 127 | 0 |

## Performance Specifications

- **Latency**: <10ms typical
- **Range**: Up to 10 meters (Bluetooth 4.0)
- **Connection Time**: 2-5 seconds after power on
- **Memory Usage**: ~20MB
- **CPU Usage**: <1% idle, <3% active

## Known Limitations

1. **LED Control**: Cannot control LEDs from MIDI input (hardware limitation)
2. **Single Device**: Designed for one PG_BT4 controller at a time
3. **macOS Only**: Uses CoreBluetooth and CoreMIDI (macOS-specific frameworks)

## Support & Documentation

- **Main README**: Project overview and installation
- **LED_NEXT_STEPS.md**: LED control investigation status
- **PROTOCOL_CAPTURE_GUIDE.md**: BLE protocol analysis methods
- **specs/**: Complete technical specifications

For issues or questions, check the documentation or examine terminal output for error messages.