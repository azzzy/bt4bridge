# Feature Specification: Bluetooth MIDI Bridge

**Feature Branch**: `001-bluetooth-midi-bridge`  
**Created**: 2024-12-06  
**Status**: Draft  
**Input**: User description: "Implement Bluetooth MIDI bridge application that discovers BLE MIDI devices, connects to them, and creates virtual CoreMIDI ports for seamless integration with DAWs and music production software on macOS"

## Clarifications

### Session 2024-12-06

- Q: How should the application identify your specific device? → A: Hardcode exact device name
- Q: What is the exact device name to hardcode? → A: PG_BT4
- Q: Which features do you need for the single-device solution? → A: Keep all originally planned features
- Q: How should the app behave when PG_BT4 is not found at startup? → A: Keep scanning indefinitely until found
- Q: If PG_BT4 connection fails, what should happen? → A: Log error and retry with backoff
- Q: Which MIDI message types should be prioritized? → A: Control Change (CC) and Program Change (PC) messages
- Q: Which CC numbers does PG_BT4 use? → A: Reverse engineer with PacketLogger
- Q: What is the typical message rate from PG_BT4? → A: 10-50 messages per second during active use
- Q: Does PG_BT4 need to receive MIDI from DAW? → A: Only receives specific message types
- Q: Which message types does PG_BT4 receive? → A: Program Change (PC) for preset sync

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Basic Device Connection and Bridging (Priority: P1)

The application connects to the "PG_BT4" foot controller and bridges it to the DAW for channel switching, MIDI bank selection, and volume/expression pedal control. When started, the bridge application searches for and connects only to "PG_BT4", ignoring all other Bluetooth devices.

**Why this priority**: This is the core functionality that delivers immediate value - without this, no other features matter. It enables the fundamental use case of wireless MIDI connectivity.

**Independent Test**: Can be fully tested by starting the application, connecting a single Bluetooth MIDI device, and verifying MIDI messages are received in any DAW or MIDI monitoring application.

**Acceptance Scenarios**:

1. **Given** the bridge application is running and scanning, **When** PG_BT4 advertises its availability, **Then** the bridge automatically discovers and connects to PG_BT4 within 10 seconds (will continue scanning indefinitely if not initially found)
2. **Given** PG_BT4 is connected to the bridge, **When** Control Change or Program Change messages are sent from PG_BT4 (channel switching, bank selection, expression pedal), **Then** those messages appear in real-time at the virtual MIDI port accessible to DAWs
3. **Given** PG_BT4 is connected to the bridge, **When** the DAW sends a Program Change message, **Then** PG_BT4 receives it for preset synchronization
4. **Given** a connected PG_BT4, **When** the device is turned off or goes out of range, **Then** the bridge handles the disconnection gracefully and removes the virtual port

---

### User Story 2 - Multiple Device Management (Priority: P2)

[REMOVED - Not applicable for single-device PG_BT4 configuration]

---

### User Story 3 - Device Filtering and Selection (Priority: P3)

[REMOVED - Not needed as PG_BT4 is hardcoded as the only connectable device]

---

### User Story 2 - Connection Persistence and Auto-Reconnection (Priority: P2)

The user experiences temporary Bluetooth interference or briefly powers off the PG_BT4. The bridge automatically reconnects to PG_BT4 when it becomes available again without restarting the application or DAW.

**Why this priority**: Real-world Bluetooth connections can be unstable. Auto-reconnection ensures a smooth user experience without manual intervention.

**Independent Test**: Can be tested by disconnecting PG_BT4 (power off or interference) and verifying automatic reconnection when it returns.

**Acceptance Scenarios**:

1. **Given** PG_BT4 was connected and becomes unavailable, **When** PG_BT4 becomes available again within 5 minutes, **Then** the bridge automatically reconnects
2. **Given** PG_BT4 repeatedly connects and disconnects, **When** reconnection attempts fail multiple times, **Then** the bridge implements backoff to avoid excessive connection attempts

---

### User Story 3 - Device Discovery and Status Visibility (Priority: P3)

The user wants to see PG_BT4's connection status and verify it's being detected. They run the application with a list option to see if PG_BT4 is in range and its current connection state.

**Why this priority**: Provides visibility for troubleshooting connection issues with PG_BT4.

**Independent Test**: Can be tested by running the application in list mode and verifying it displays PG_BT4's status.

**Acceptance Scenarios**:

1. **Given** the bridge is running in list mode, **When** PG_BT4 is in range, **Then** PG_BT4 is shown with its connection status
2. **Given** PG_BT4 status is being displayed, **When** PG_BT4 connection state changes, **Then** the displayed status updates in real-time

---

### Edge Cases

- What happens when PG_BT4 disconnects during active MIDI transmission?
- How does the system handle if another device is named PG_BT4?
- What occurs if PG_BT4 connection fails after discovery (e.g., pairing issues)?
- How does the bridge handle malformed or invalid MIDI messages from PG_BT4?
- What happens when system Bluetooth is disabled while the bridge is running?
- What happens if PG_BT4 is found but connection repeatedly fails?
- What happens during rapid expression pedal movements generating burst traffic (50+ msg/sec)?

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST search for and connect only to device named "PG_BT4"
- **FR-002**: System MUST ignore all Bluetooth devices except the one matching the hardcoded name  
- **FR-003**: System MUST create a single virtual MIDI port named "bt4bridge: PG_BT4"
- **FR-004**: System MUST route MIDI messages from PG_BT4 to DAW with full fidelity, with optimized handling for Control Change (CC) and Program Change (PC) messages
- **FR-014**: System MUST route Program Change messages from DAW to PG_BT4 for preset synchronization
- **FR-005**: System MUST handle device disconnection gracefully
- **FR-006**: System MUST automatically reconnect to PG_BT4 when it becomes available
- **FR-011**: System MUST continue scanning indefinitely at startup until PG_BT4 is found
- **FR-007**: System MUST maintain MIDI message ordering and timing information during routing
- **FR-008**: System MUST provide operational status information for the single device connection
- **FR-013**: System MUST log all MIDI CC and PC messages in verbose mode to help identify PG_BT4's actual CC numbers via PacketLogger or similar tools
- **FR-009**: System MUST implement connection retry with exponential backoff when PG_BT4 connection fails
- **FR-012**: System MUST log connection failures with PG_BT4 and continue retrying with backoff
- **FR-010**: System MUST preserve MIDI message integrity without dropping or corrupting messages under normal operation

### Key Entities

- **MIDI Device**: Represents a Bluetooth MIDI controller or instrument with unique identifier, name, connection state, and signal strength
- **Virtual Port**: Represents a system MIDI port that applications can access, linked to a specific MIDI device
- **MIDI Message**: Represents musical data being routed between devices and ports, preserving timing and channel information
- **Connection Session**: Represents an active connection between the bridge and a MIDI device with connection history and retry count

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: MIDI message forwarding latency remains under 10 milliseconds in 95% of messages during normal operation
- **SC-002**: Device discovery and initial connection completes within 10 seconds of device availability
- **SC-003**: System successfully maintains stable connection to PG_BT4
- **SC-004**: Automatic reconnection succeeds within 30 seconds of device re-availability in 90% of cases
- **SC-005**: Zero MIDI message loss during stable connection periods (100% message delivery)
- **SC-006**: Memory usage remains under 50MB during typical operation with 3 connected devices
- **SC-007**: 90% of users can successfully connect their first MIDI device without reading documentation
- **SC-008**: System handles 50 MIDI messages per second from PG_BT4 without message queue overflow (typical peak rate during expression pedal use)

## Assumptions

- Users have Bluetooth 4.0 or later capable hardware
- PG_BT4 complies with Bluetooth MIDI (BLE-MIDI) specification
- Operating system provides necessary Bluetooth and MIDI service access permissions
- Only one device (PG_BT4) will ever be connected
- PG_BT4 is within standard Bluetooth range (approximately 10 meters)
- Users understand basic MIDI concepts and DAW configuration
- PG_BT4 device name is unique in the environment
- PG_BT4's specific CC numbers will be discovered through packet analysis during initial testing