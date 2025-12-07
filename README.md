# bt4bridge

A macOS bridge application that connects the PG_BT4 Bluetooth foot controller to CoreMIDI, enabling seamless integration with your DAW and music production workflow.

## Overview

bt4bridge acts as a transparent bridge between the PG_BT4 Bluetooth foot controller and macOS's CoreMIDI system. It automatically discovers the device, connects, and routes all button presses as MIDI Control Change messages to a virtual MIDI port that can be accessed by any CoreMIDI-compatible application.

## Features

- **Automatic Discovery**: Scans for and connects to the PG_BT4 device automatically
- **Full Button Support**: All 4 buttons mapped to MIDI CC 80-83 on channel 0
- **Transparent Bridging**: Routes all MIDI messages between Bluetooth and CoreMIDI
- **Low Latency**: Optimized for real-time music performance with minimal latency
- **Virtual MIDI Ports**: Creates "PG_BT4 Bridge" source and destination ports
- **Automatic Reconnection**: Maintains connections and reconnects when the device becomes available
- **Comprehensive Logging**: Detailed logging for troubleshooting and monitoring

## Requirements

- macOS 12.0 (Monterey) or later
- Swift 6.2+ runtime
- Bluetooth 4.0+ capable Mac
- PG_BT4 Bluetooth foot controller

## Installation

### Building from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/bt4bridge.git
cd bt4bridge

# Build the project
swift build -c release

# The executable will be at .build/release/bt4bridge
```

### Running

```bash
# Run directly with Swift
swift run bt4bridge

# Or run the built executable
.build/release/bt4bridge
```

## Usage

### Basic Operation

1. Start bt4bridge:
   ```bash
   .build/release/bt4bridge
   ```

2. Turn on your PG_BT4 controller

3. bt4bridge will automatically discover and connect to the device

4. The device will appear as "PG_BT4 Bridge" in your DAW's MIDI input list

5. Press the foot switches - they will send MIDI CC messages:
   - Button 1: CC 80
   - Button 2: CC 81
   - Button 3: CC 82
   - Button 4: CC 83
   - All buttons use MIDI channel 0 (channel 1 in most DAWs)
   - Values: 127 (pressed), 0 (released)

### MIDI Mapping in Your DAW

The bridge creates virtual MIDI ports named "PG_BT4 Bridge":
- **Source Port**: Receives button presses from the controller
- **Destination Port**: Available for future bidirectional communication

To use in your DAW:
1. Open your DAW's MIDI preferences
2. Enable "PG_BT4 Bridge" as an input device
3. Map the CC messages (80-83) to your desired functions
4. Example uses: Scene switching, track muting, transport control, effect toggles

## Development

### Project Structure

```
bt4bridge/
├── Sources/
│   └── bt4bridge/
│       ├── bt4bridge.swift           # Main application entry point
│       ├── Bridge.swift               # Core bridge coordinator
│       ├── Bluetooth/
│       │   └── BluetoothScanner.swift # BLE device discovery and connection
│       ├── MIDI/
│       │   ├── MIDIPortManager.swift  # Virtual MIDI port management
│       │   └── MIDIParser.swift       # MIDI message parsing
│       ├── Models/
│       │   └── MIDIMessage.swift      # MIDI data structures
│       ├── PacketAnalyzer/
│       │   └── PG_BT4Parser.swift     # PG_BT4 protocol parser
│       └── Utilities/
│           └── Logger.swift           # Logging system
├── Package.swift                      # Swift package manifest
└── specs/                             # Project specifications
```

### Building for Development

```bash
# Debug build
swift build

# Run tests
swift test

# Clean build artifacts
swift package clean
```

### Architecture

bt4bridge uses:
- **CoreBluetooth**: For BLE device discovery and communication
- **CoreMIDI**: For creating virtual MIDI ports and routing messages
- **Swift Concurrency**: For handling asynchronous Bluetooth and MIDI operations with actors

The application follows an event-driven architecture:
1. `BluetoothScanner` discovers and connects to PG_BT4 via BLE
2. `PG_BT4Parser` decodes the custom protocol (B1 XX YY format) into MIDI messages
3. `Bridge` coordinates between Bluetooth and MIDI components
4. `MIDIPortManager` forwards MIDI messages to virtual ports
5. DAWs receive MIDI CC messages from the virtual port

### PG_BT4 Protocol

The PG_BT4 uses a custom (non-standard MIDI) BLE protocol:
- **Service UUID**: 1910
- **Characteristic FFF4** (Notify): Receives button press data
- **Packet Format**: `B1 [10-13] [00/01]`
  - `B1` = Header byte
  - `10-13` = Switch 1-4 identifier
  - `00/01` = Released (0) / Pressed (1)

The bridge converts these to MIDI CC messages (80-83) for universal DAW compatibility.

## Troubleshooting

### Device Not Connecting

1. Ensure Bluetooth is enabled on your Mac
2. Check that the PG_BT4 is powered on and in range
3. Try resetting the Bluetooth module: `sudo pkill bluetoothd`
4. Check logs for connection errors (output is displayed in the terminal)
5. Make sure no other app is connected to the PG_BT4 (disconnect from phone apps)

### MIDI Port Not Visible in DAW

1. Restart your DAW after starting bt4bridge
2. Check Audio MIDI Setup utility (Applications > Utilities > Audio MIDI Setup)
3. Verify "PG_BT4 Bridge" appears in the MIDI Studio window
4. Ensure bt4bridge process is running

### Button Presses Not Working

1. Check the terminal output for "RAW RX" messages when pressing buttons
2. If you see `B1 10 01` style messages, the Bluetooth connection is working
3. Verify your DAW is receiving MIDI input from "PG_BT4 Bridge"
4. Check your DAW's MIDI monitor to see incoming CC messages
5. Ensure the CC numbers (80-83) aren't filtered in your DAW

### LED Behavior

Note: LED control from the bridge is not currently implemented. The LEDs will:
- Turn ON when bt4bridge connects (this is normal hardware behavior)
- Flash briefly when you press a physical button (built-in feedback)
- Cannot be controlled via MIDI input at this time

For LED control implementation status, see LED_NEXT_STEPS.md

**Want to discover the LED protocol?** Use the included `pg4simulator` tool - see SIMULATOR_GUIDE.md

### High Latency

1. Move closer to the Bluetooth device (reduce interference)
2. Disconnect other Bluetooth devices if possible
3. Check for Wi-Fi interference on 2.4GHz band (use 5GHz if available)

## Known Limitations

1. **LED Control Not Implemented**: The PG_BT4's LEDs cannot currently be controlled from the bridge. The LEDs will turn on when connected but cannot be toggled via MIDI input. See LED_NEXT_STEPS.md for investigation details.

2. **Single Device Support**: Currently designed for one PG_BT4 controller. Multiple device support would require extending the scanner logic.

3. **macOS Only**: Uses CoreBluetooth and CoreMIDI frameworks which are macOS-specific.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

### Development Guidelines

- Follow Swift API Design Guidelines
- Use Swift 6+ concurrency features (async/await, actors)
- Ensure all code is properly documented
- Add tests for new functionality
- Update this README for user-facing changes

## License

[Specify License - e.g., MIT, Apache 2.0, GPL]

## Acknowledgments

- Built with Swift 6.2+ and Apple's Core frameworks
- Developed for the PG_BT4 Bluetooth foot controller
- Protocol reverse-engineered through BLE packet analysis

## Related Documentation

- **SIMULATOR_GUIDE.md**: Use the BLE peripheral simulator to discover LED protocol
- **LED_NEXT_STEPS.md**: Investigation status and options for LED control
- **PROTOCOL_CAPTURE_GUIDE.md**: How to analyze BLE protocols
- **specs/001-bluetooth-midi-bridge/**: Complete technical specifications

## Support

For issues, questions, or suggestions, please open an issue on GitHub.