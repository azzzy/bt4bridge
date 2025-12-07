# bt4bridge

A macOS bridge application that connects the PG_BT4 Bluetooth foot controller to CoreMIDI, enabling seamless integration with your DAW and music production workflow.

## Overview

bt4bridge acts as a transparent bridge between the PG_BT4 Bluetooth foot controller and macOS's CoreMIDI system. It automatically discovers the device, connects, and routes all button presses as MIDI Control Change messages to a virtual MIDI port that can be accessed by any CoreMIDI-compatible application.

Available in two versions:
- **Menu Bar App** (recommended): Native macOS app with menu bar interface
- **Command-Line**: Terminal-based version for automation and headless use

## Features

### Core Features (Both Versions)
- **Automatic Discovery**: Scans for and connects to the PG_BT4 device automatically
- **Full Button Support**: All 4 buttons mapped to MIDI CC 80-83 on channel 0
- **LED Control**: Control all 4 LEDs via MIDI CC 16-19 from your DAW
- **Transparent Bridging**: Routes all MIDI messages between Bluetooth and CoreMIDI
- **Low Latency**: Optimized for real-time music performance with minimal latency
- **Virtual MIDI Ports**: Creates "PG_BT4 Bridge" source and destination ports
- **Automatic Reconnection**: Maintains connections and reconnects when the device becomes available

### Menu Bar App Exclusive
- **Native macOS Interface**: Runs as a menu bar application (no Dock icon)
- **Visual Status Indicators**: See connection status at a glance
- **LED State Monitoring**: View current LED states without looking at the hardware
- **Quick Actions**: Reconnect to device with one click
- **Launch at Login**: Optionally start automatically when you log in (coming soon)
- **Clean & Lightweight**: Minimal resource usage when idle

## Requirements

### Menu Bar App
- **macOS 13.0 (Ventura)** or later
- Swift 6.2+ runtime
- Bluetooth 4.0+ capable Mac
- PG_BT4 Bluetooth foot controller

### Command-Line Version
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

# Build the menu bar app as an .app bundle (recommended)
./build_app.sh

# Or build the executable directly
swift build -c release --product bt4bridge-app

# Or build the command-line version
swift build -c release --product bt4bridge
```

### Running

#### Menu Bar App (Recommended)

```bash
# If you built with build_app.sh, install to Applications:
cp -r '.build/release/PG_BT4 Bridge.app' /Applications/

# Then launch from Applications folder or via:
open '/Applications/PG_BT4 Bridge.app'

# Or run the executable directly (without installing):
.build/release/bt4bridge-app
```

The app will appear in your menu bar (no window or Dock icon). Click the icon to:
- View connection status and signal strength
- Monitor LED states in real-time
- Force reconnection to the device
- Access About information
- Quit the application

#### Command-Line Version

```bash
# Run the CLI version
.build/release/bt4bridge

# Or run directly with Swift
swift run bt4bridge
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
│   ├── bt4bridge/                     # Core bridge library (BT4BridgeCore)
│   │   ├── Bridge.swift               # Main bridge coordinator
│   │   ├── Bluetooth/
│   │   │   └── BluetoothScanner.swift # BLE device discovery
│   │   ├── MIDI/
│   │   │   ├── MIDIPortManager.swift  # Virtual MIDI ports
│   │   │   └── MIDIParser.swift       # MIDI message parsing
│   │   ├── Models/
│   │   │   ├── LEDController.swift    # LED state management
│   │   │   └── MIDIMessage.swift      # MIDI data structures
│   │   ├── PacketAnalyzer/
│   │   │   └── PG_BT4Parser.swift     # PG_BT4 protocol parser
│   │   └── Utilities/
│   │       └── Logger.swift           # Logging system
│   ├── bt4bridge-app/                 # Menu bar application
│   │   ├── BridgeApp.swift            # App entry point
│   │   ├── BridgeModel.swift          # Observable state wrapper
│   │   └── MenuBarView.swift          # Menu UI components
│   ├── bt4bridge-cli/                 # Command-line application
│   │   └── main.swift                 # CLI entry point
│   ├── pg4simulator/                  # BLE peripheral simulator
│   └── ledtester/                     # LED testing utility
├── Package.swift                      # Swift package manifest
└── specs/                             # Project specifications
    ├── 001-bluetooth-midi-bridge/     # Core bridge spec
    └── 002-menu-bar-application/      # Menu bar app spec
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

### LED Control

LED control is fully implemented! You can control the PG_BT4's 4 LEDs from your DAW:

**MIDI CC Mapping** (send to "PG_BT4 Bridge" MIDI output):
- **CC 16**: LED 1 control
- **CC 17**: LED 2 control  
- **CC 18**: LED 3 control
- **CC 19**: LED 4 control

**Values**:
- `0-63`: LED OFF
- `64-127`: LED ON

**Menu Bar App**: The LED states are also displayed in the menu, showing which LEDs are currently on/off with visual indicators (red ● for on, gray ○ for off).

### High Latency

1. Move closer to the Bluetooth device (reduce interference)
2. Disconnect other Bluetooth devices if possible
3. Check for Wi-Fi interference on 2.4GHz band (use 5GHz if available)

## Known Limitations

1. **Single Device Support**: Currently designed for one PG_BT4 controller. Multiple device support would require extending the scanner logic.

2. **macOS Only**: Uses CoreBluetooth and CoreMIDI frameworks which are macOS-specific.

3. **Launch at Login**: UI toggle is present in menu bar app but ServiceManagement integration is not yet complete.

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

- **specs/001-bluetooth-midi-bridge/**: Core bridge technical specifications
- **specs/002-menu-bar-application/**: Menu bar app specifications and implementation notes
- **SIMULATOR_GUIDE.md**: Use the BLE peripheral simulator for protocol testing
- **PROTOCOL_CAPTURE_GUIDE.md**: How to analyze BLE protocols

## Support

For issues, questions, or suggestions, please open an issue on GitHub.