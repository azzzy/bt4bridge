# Feature Specification: Menu Bar Application

**Feature Branch**: `002-menu-bar-application`  
**Created**: 2024-12-07  
**Status**: Draft  
**Input**: User description: "Convert bt4bridge from CLI to native macOS menu bar application with SwiftUI"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Background Service with Menu Bar Access (Priority: P1)

As a music producer, I want the PG_BT4 bridge to run as a background service with a menu bar icon, so I can access bridge functionality without cluttering my Dock or requiring a terminal window.

**Why this priority**: This is the core value proposition of the menu bar app - making the bridge accessible and non-intrusive.

**Independent Test**: Can be fully tested by launching the app from Applications folder and verifying: (1) no Dock icon appears, (2) menu bar icon is visible, (3) clicking the icon shows a menu.

**Acceptance Scenarios**:

1. **Given** app is not running, **When** user launches from Applications folder, **Then** app appears in menu bar only (no Dock icon, no window)
2. **Given** app is running, **When** user clicks menu bar icon, **Then** dropdown menu appears with current status
3. **Given** app is running, **When** user quits via menu, **Then** app cleanly exits and icon disappears from menu bar

---

### User Story 2 - Visual Connection Status (Priority: P1)

As a user, I want to see the PG_BT4 connection status at a glance in the menu bar, so I know if my device is connected without opening the menu.

**Why this priority**: Immediate visual feedback is essential for confirming the bridge is working before starting a performance or recording session.

**Independent Test**: Can be tested by observing menu bar icon changes when device connects/disconnects.

**Acceptance Scenarios**:

1. **Given** PG_BT4 is not connected, **When** viewing menu bar, **Then** icon shows disconnected state (gray/inactive)
2. **Given** PG_BT4 connects, **When** connection establishes, **Then** icon changes to connected state (colored/active)
3. **Given** PG_BT4 is connected, **When** MIDI messages flow, **Then** icon shows activity indicator
4. **Given** menu is open, **When** viewing status section, **Then** detailed status shows: connection state, device name, RSSI, MIDI port status

---

### User Story 3 - LED State Monitoring (Priority: P2)

As a user, I want to see the current state of all 4 LEDs in the menu, so I can verify LED states set by my DAW without looking at the hardware.

**Why this priority**: Provides valuable visual feedback but is not critical for basic bridge operation.

**Independent Test**: Can be tested by sending MIDI CC 16-19 from DAW and verifying menu updates match LED states.

**Acceptance Scenarios**:

1. **Given** menu is open, **When** viewing LED section, **Then** 4 LED indicators show current on/off states (red ● = on, gray ○ = off)
2. **Given** DAW sends CC 16 value 127, **When** menu refreshes, **Then** LED 1 indicator shows red ●
3. **Given** DAW sends CC 16 value 0, **When** menu refreshes, **Then** LED 1 indicator shows gray ○
4. **Given** all LEDs have different states, **When** menu opens, **Then** each indicator accurately reflects its LED state

---

### User Story 4 - Quick Reconnection (Priority: P2)

As a user, I want a "Reconnect" action in the menu, so I can force a reconnection if the device becomes unresponsive without restarting the entire app.

**Why this priority**: Useful for troubleshooting but not critical for initial MVP.

**Independent Test**: Can be tested by selecting Reconnect and verifying bridge disconnects then reconnects.

**Acceptance Scenarios**:

1. **Given** device is connected, **When** user selects "Reconnect", **Then** bridge disconnects from current device and starts scanning
2. **Given** reconnect is initiated, **When** scanning, **Then** menu shows "Scanning for PG_BT4..."
3. **Given** reconnect completes, **When** device found, **Then** menu shows connected status

---

### User Story 5 - Launch at Login (Priority: P3)

As a user, I want the app to launch automatically at login, so the bridge is always available when I start my Mac.

**Why this priority**: Convenience feature that can be added after core functionality is stable.

**Independent Test**: Can be tested by enabling toggle and restarting Mac.

**Acceptance Scenarios**:

1. **Given** app is running, **When** user enables "Launch at Login", **Then** preference is saved
2. **Given** "Launch at Login" is enabled, **When** Mac restarts and user logs in, **Then** app launches automatically in menu bar
3. **Given** "Launch at Login" is disabled, **When** Mac restarts, **Then** app does not launch

---

### User Story 6 - Clean Shutdown (Priority: P1)

As a user, I want to quit the app cleanly via the menu, so all Bluetooth and MIDI resources are properly released.

**Why this priority**: Essential for system resource management and preventing orphaned connections.

**Independent Test**: Can be tested by quitting app and verifying MIDI ports are destroyed and Bluetooth disconnects.

**Acceptance Scenarios**:

1. **Given** app is running and connected, **When** user selects "Quit PG_BT4 Bridge", **Then** device disconnects cleanly
2. **Given** quit is initiated, **When** cleanup occurs, **Then** virtual MIDI ports are destroyed
3. **Given** quit completes, **When** checking system, **Then** no bt4bridge processes remain and menu bar icon is gone

---

### Edge Cases

- What happens when Bluetooth permission is denied after app launch?
- How does the menu handle rapid connection/disconnection cycles?
- What if menu is open when device disconnects?
- How does app behave if MIDI port creation fails?
- What happens if multiple instances are launched?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: App MUST run as an "Agent" (background application) with no Dock icon
- **FR-002**: App MUST display a persistent icon in the macOS menu bar
- **FR-003**: App MUST show a dropdown menu when menu bar icon is clicked
- **FR-004**: Menu MUST display current connection status (Disconnected/Scanning/Connected)
- **FR-005**: Menu MUST display device name when connected (e.g., "PG_BT4")
- **FR-006**: Menu MUST display signal strength (RSSI) when connected
- **FR-007**: Menu MUST display MIDI port status
- **FR-008**: Menu MUST display 4 LED indicators showing current on/off states
- **FR-009**: LED indicators MUST update in real-time when states change from DAW
- **FR-010**: Menu MUST provide "Reconnect" action to force reconnection
- **FR-011**: Menu MUST provide "Launch at Login" toggle
- **FR-012**: Menu MUST provide "About PG_BT4 Bridge" information
- **FR-013**: Menu MUST provide "Quit PG_BT4 Bridge" action
- **FR-014**: Quit action MUST cleanly disconnect Bluetooth and destroy MIDI ports
- **FR-015**: Menu bar icon MUST visually indicate connection state (disconnected/connected/active)
- **FR-016**: App MUST maintain all existing bridge functionality from CLI version
- **FR-017**: App MUST use SwiftUI for UI implementation
- **FR-018**: App MUST use MenuBarExtra scene for menu bar integration

### Technical Requirements

- **TR-001**: App target MUST be macOS 12.0 or later
- **TR-002**: App MUST reuse existing Bridge, MIDI, and Bluetooth code without modification
- **TR-003**: Bridge MUST run as singleton managed by app
- **TR-004**: Menu state updates MUST use SwiftUI's observation system (@Observable or ObservableObject)
- **TR-005**: Menu MUST only refresh when visible (minimize CPU usage when closed)
- **TR-006**: App MUST request same permissions as CLI version (Bluetooth, MIDI)
- **TR-007**: App MUST handle Swift 6.2+ strict concurrency checking
- **TR-008**: Memory usage MUST remain under 50MB during operation
- **TR-009**: CPU usage MUST not exceed 5% during active MIDI streaming

### Key Entities *(include if feature involves data)*

- **BridgeModel**: Observable wrapper around Bridge actor, publishes state changes to SwiftUI
- **AppDelegate**: Manages app lifecycle, prevents multiple instances
- **MenuBarView**: SwiftUI view defining menu structure and content
- **ConnectionStatus**: Enum representing connection states (disconnected, scanning, connected)
- **LEDState**: Struct representing current state of 4 LEDs

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: User can launch app from Applications folder and see menu bar icon within 2 seconds
- **SC-002**: Menu opens within 100ms of clicking menu bar icon
- **SC-003**: Connection status updates appear in menu within 500ms of state change
- **SC-004**: LED indicators update within 200ms of MIDI CC message from DAW
- **SC-005**: All existing bridge functionality works identically to CLI version (verified by running same MIDI test scenarios)
- **SC-006**: App quits cleanly with all resources released within 1 second
- **SC-007**: Memory usage remains stable under 50MB during 1 hour operation test
- **SC-008**: No CPU usage when idle (menu closed, no MIDI activity)

## Implementation Notes

### Architecture

The implementation will follow this structure:

1. **New Application Target**: Create `bt4bridge-app` target in Package.swift
2. **Reuse Core Logic**: Import and reuse existing `Bridge`, `BluetoothScanner`, `MIDIPortManager`, `LEDController`
3. **Observable Wrapper**: Create `BridgeModel` that wraps `Bridge` actor and publishes state to SwiftUI
4. **SwiftUI Menu**: Use `MenuBarExtra` scene with custom menu content
5. **Keep CLI Target**: Maintain existing `bt4bridge` CLI target for users who prefer terminal

### File Structure

```
Sources/
  bt4bridge-app/
    BridgeApp.swift           # @main App entry point
    BridgeModel.swift         # Observable wrapper for Bridge
    MenuBarView.swift         # Menu content
    StatusIndicator.swift     # LED indicators component
    LaunchAtLogin.swift       # Login item helper
  bt4bridge/                  # Existing CLI code (unchanged)
    ...
```

### SwiftUI Integration Pattern

```swift
@Observable
class BridgeModel {
    var connectionStatus: ConnectionStatus = .disconnected
    var deviceName: String? = nil
    var rssi: Int? = nil
    var ledStates: [Int: Bool] = [1: false, 2: false, 3: false, 4: false]
    
    private let bridge = Bridge()
    
    func start() async throws {
        try await bridge.start()
        // Poll for updates or use delegate pattern
    }
}
```

### Menu Structure

```
PG_BT4 Bridge
├─ Status Section
│  ├─ Connection: Connected/Scanning/Disconnected
│  ├─ Device: PG_BT4
│  ├─ Signal: -45 dBm
│  └─ MIDI: Active
├─ ───────────
├─ LED Indicators
│  ├─ LED 1: ● / ○
│  ├─ LED 2: ● / ○
│  ├─ LED 3: ● / ○
│  └─ LED 4: ● / ○
├─ ───────────
├─ Reconnect
├─ ───────────
├─ ☑ Launch at Login
├─ About PG_BT4 Bridge
└─ Quit PG_BT4 Bridge
```

## Out of Scope

- Preferences window (future enhancement)
- MIDI mapping customization UI
- Multiple device support
- Logging to file UI
- Crash reporting
- Auto-update mechanism
- Notification system (optional for MVP)
- Menu bar icon animations (optional for MVP)
