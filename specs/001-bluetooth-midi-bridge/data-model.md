# Data Model: PG_BT4 Foot Controller Bridge

**Date**: 2024-12-06  
**Feature**: 001-bluetooth-midi-bridge (PG_BT4 Foot Controller)

## Entity Definitions

### PG_BT4Device

Represents the PG_BT4 foot controller state and connection.

**Properties**:
- `peripheralId: UUID` - CoreBluetooth peripheral identifier
- `connectionState: ConnectionState` - Current connection status
- `signalStrength: Int?` - RSSI value in dBm (when connected)
- `lastSeen: Date` - Timestamp of last advertisement or activity
- `isPortVisible: Bool` - Whether virtual MIDI port is visible
- `sessionId: UUID?` - Current connection session (nil if disconnected)
- `discoveredCCs: Set<UInt8>` - CC numbers discovered from PG_BT4
- `lastProgramSent: UInt8?` - Last PC sent to PG_BT4 for sync tracking

**State Transitions**:
```
Scanning → Connected → Scanning
     ↑                      ↓
     └──────────────────────┘
```

**Constants**:
- `deviceName: String = "PG_BT4"` - Hardcoded device name
- `portName: String = "bt4bridge: PG_BT4"` - Virtual port name
- `midiServiceUUID: String = "03B80E5A-EDE8-4B33-A751-6CE34EC4C700"` - BLE-MIDI

### ControlChangeMessage

Represents a Control Change message for expression/volume/switches.

**Properties**:
- `timestamp: UInt64` - Message timestamp (mach_absolute_time)
- `channel: UInt8` - MIDI channel (0-15, displayed as 1-16)
- `controller: UInt8` - CC number (0-127)
- `value: UInt8` - CC value (0-127)
- `source: MessageSource` - Origin of message

**Common CC Numbers** (to be discovered):
- Expression Pedal: Likely CC #11
- Volume: Likely CC #7
- Bank Select MSB: CC #0
- Bank Select LSB: CC #32
- Custom switches: TBD via packet analysis

**Validation Rules**:
- Channel must be 0-15
- Controller must be 0-127
- Value must be 0-127

### ProgramChangeMessage

Represents a Program Change message for channel/preset switching.

**Properties**:
- `timestamp: UInt64` - Message timestamp (mach_absolute_time)
- `channel: UInt8` - MIDI channel (0-15)
- `program: UInt8` - Program number (0-127)
- `bankMSB: UInt8?` - Bank select MSB if preceded by CC #0
- `bankLSB: UInt8?` - Bank select LSB if preceded by CC #32
- `source: MessageSource` - Origin of message
- `direction: MessageDirection` - To or from PG_BT4

**Validation Rules**:
- Channel must be 0-15
- Program must be 0-127
- Bank values must be 0-127 if present

### ConnectionSession

Tracks the current connection session with PG_BT4.

**Properties**:
- `id: UUID` - Unique session identifier
- `startTime: Date` - Connection established time
- `endTime: Date?` - Connection ended time (nil if active)
- `ccMessagesReceived: UInt64` - Count of CC messages from PG_BT4
- `pcMessagesReceived: UInt64` - Count of PC messages from PG_BT4
- `pcMessagesSent: UInt64` - Count of PC messages sent to PG_BT4
- `reconnectAttempts: Int` - Number of reconnection attempts
- `peakMessageRate: Int` - Highest messages/second observed
- `averageCCLatency: Double?` - Average CC message latency

**Computed Properties**:
- `duration: TimeInterval` - Session duration
- `isActive: Bool` - Whether session is currently active
- `totalMessages: UInt64` - Total messages in both directions

### ExpressionPedalState

Tracks expression pedal position and movement.

**Properties**:
- `ccNumber: UInt8?` - Discovered CC number for expression
- `currentValue: UInt8` - Current pedal position (0-127)
- `lastUpdateTime: Date` - Last position update
- `movementRate: Double` - Messages per second during movement
- `isMoving: Bool` - Whether pedal is actively moving

**Methods**:
```swift
mutating func updatePosition(_ value: UInt8) {
    let now = Date()
    let timeDelta = now.timeIntervalSince(lastUpdateTime)
    
    if timeDelta < 0.1 {  // Movement if updates within 100ms
        isMoving = true
        movementRate = 1.0 / timeDelta
    } else {
        isMoving = false
        movementRate = 0
    }
    
    currentValue = value
    lastUpdateTime = now
}
```

## Enumerations

### ConnectionState
```swift
enum ConnectionState: String {
    case scanning = "Scanning for PG_BT4"
    case connected = "Connected to PG_BT4"
    
    var isConnected: Bool {
        self == .connected
    }
}
```

### MessageSource
```swift
enum MessageSource {
    case pg_bt4      // From foot controller
    case daw         // From DAW/software
}
```

### MessageDirection
```swift
enum MessageDirection {
    case toDaw       // PG_BT4 → DAW (CC and PC)
    case toPG_BT4    // DAW → PG_BT4 (PC only)
}
```

### FootControllerFunction
```swift
enum FootControllerFunction {
    case expressionPedal(cc: UInt8)
    case volumePedal(cc: UInt8)
    case channelSwitch(program: UInt8)
    case bankSelect(msb: UInt8, lsb: UInt8?)
    case customSwitch(cc: UInt8)
}
```

## Supporting Types

### MessageCoalescer
```swift
struct MessageCoalescer {
    private var pendingCCs: [UInt8: (value: UInt8, timestamp: UInt64)] = [:]
    private let windowNanoseconds: UInt64 = 20_000_000  // 20ms
    
    mutating func addCC(controller: UInt8, value: UInt8, timestamp: UInt64) -> Bool {
        if let pending = pendingCCs[controller] {
            if timestamp - pending.timestamp < windowNanoseconds {
                // Update value, keep original timestamp
                pendingCCs[controller] = (value, pending.timestamp)
                return false  // Don't send yet
            }
        }
        pendingCCs[controller] = (value, timestamp)
        return true  // Send immediately
    }
    
    mutating func flush() -> [(controller: UInt8, value: UInt8)] {
        let messages = pendingCCs.map { ($0.key, $0.value.value) }
        pendingCCs.removeAll()
        return messages
    }
}
```

### PacketAnalysis
```swift
struct PacketAnalysis {
    var discoveredCCs: Set<UInt8> = []
    var ccUsageCount: [UInt8: Int] = [:]
    var ccValueRanges: [UInt8: (min: UInt8, max: UInt8)] = [:]
    var programChanges: Set<UInt8> = []
    
    mutating func analyzeCC(_ cc: UInt8, value: UInt8) {
        discoveredCCs.insert(cc)
        ccUsageCount[cc, default: 0] += 1
        
        if let range = ccValueRanges[cc] {
            ccValueRanges[cc] = (min(range.min, value), max(range.max, value))
        } else {
            ccValueRanges[cc] = (value, value)
        }
    }
    
    func identifyExpressionCC() -> UInt8? {
        // Expression pedal likely has wide value range and high usage
        return ccValueRanges
            .filter { $0.value.max - $0.value.min > 100 }  // Wide range
            .max { ccUsageCount[$0.key] ?? 0 < ccUsageCount[$1.key] ?? 0 }?
            .key
    }
}
```

### PerformanceMetrics
```swift
struct PerformanceMetrics {
    var ccLatencySamples: CircularBuffer<Double>
    var burstEvents: Int = 0
    var maxBurstRate: Int = 0
    var totalCCMessages: UInt64 = 0
    var totalPCMessages: UInt64 = 0
    
    init() {
        ccLatencySamples = CircularBuffer(capacity: 100)
    }
    
    mutating func recordCCLatency(_ latencyMs: Double) {
        ccLatencySamples.append(latencyMs)
        totalCCMessages += 1
    }
    
    mutating func recordBurst(rate: Int) {
        burstEvents += 1
        maxBurstRate = max(maxBurstRate, rate)
    }
    
    var percentile95: Double? {
        let sorted = ccLatencySamples.sorted()
        guard sorted.count >= 95 else { return nil }
        return sorted[94]
    }
}
```

### ReconnectionState
```swift
struct ReconnectionState {
    var attemptCount: Int = 0
    var nextRetryTime: Date?
    var currentDelay: TimeInterval = 1.0
    
    mutating func recordAttempt() {
        attemptCount += 1
        currentDelay = min(currentDelay * 2.0, 30.0)
        let jitter = Double.random(in: 0.8...1.2)
        nextRetryTime = Date().addingTimeInterval(currentDelay * jitter)
    }
    
    mutating func reset() {
        attemptCount = 0
        currentDelay = 1.0
        nextRetryTime = nil
    }
}
```

## State Management

### Global Application State
```swift
actor ApplicationState {
    // Device state
    private var pg_bt4Device: PG_BT4Device
    private var connectionState: ConnectionState = .scanning
    private var currentSession: ConnectionSession?
    
    // Message handling
    private var coalescer: MessageCoalescer
    private var packetAnalysis: PacketAnalysis
    private var expressionState: ExpressionPedalState
    
    // Performance tracking
    private var performanceMetrics: PerformanceMetrics
    private var reconnectionState: ReconnectionState
    
    // CoreBluetooth/CoreMIDI
    private var peripheral: CBPeripheral?
    private var midiPort: MIDIPortRef?
    
    init() {
        pg_bt4Device = PG_BT4Device(/* ... */)
        coalescer = MessageCoalescer()
        packetAnalysis = PacketAnalysis()
        expressionState = ExpressionPedalState()
        performanceMetrics = PerformanceMetrics()
        reconnectionState = ReconnectionState()
    }
}
```

## Usage Patterns

### CC Message Flow (Expression Pedal)
```
1. Receive CC from PG_BT4 (e.g., CC #11, value 0-127)
2. Check coalescer for recent updates
3. If coalesced, update pending value
4. If not coalesced or timeout, send to DAW
5. Update expression pedal state
6. Record performance metrics
```

### PC Message Flow (Channel Switch)
```
1. Receive PC from PG_BT4 (e.g., Program 1)
2. Forward immediately to DAW (no coalescing)
3. Update last program for tracking
```

### PC Sync Flow (DAW → PG_BT4)
```
1. Receive PC from DAW
2. Check if different from last sent
3. Send to PG_BT4 for preset sync
4. Update tracking
```

### Packet Analysis Flow
```
1. In verbose mode, analyze all messages
2. Identify CC numbers and value ranges
3. Detect expression pedal CC (wide range, high frequency)
4. Log discoveries for user reference
```

## Memory Management

- Coalescer buffer: Fixed pending CC map (~1KB)
- Performance samples: Circular buffer of 100 (~800B)
- Packet analysis: Bounded sets/maps (~2KB)
- Total overhead: < 5KB
- No unbounded growth

## Thread Safety

All mutable state protected by actor isolation:
- Device state changes on main actor
- Message routing on dedicated actor
- Performance metrics updated atomically
- Coalescer protected by actor boundaries