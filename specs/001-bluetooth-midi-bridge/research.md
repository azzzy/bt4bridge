# Research & Technical Decisions: PG_BT4 Foot Controller Bridge

**Date**: 2024-12-06  
**Feature**: 001-bluetooth-midi-bridge (PG_BT4 Foot Controller)

## Executive Summary

This document captures technical decisions for implementing the PG_BT4 foot controller bridge on macOS. All decisions are optimized for foot controller functionality: channel switching, MIDI bank selection, volume/expression pedal control, and preset synchronization.

## Technical Decisions

### 1. MIDI Message Prioritization Strategy

**Decision**: Implement fast-path parsing for CC and PC messages

**Rationale**: 
- PG_BT4 primarily sends Control Change (expression/volume) and Program Change (channel/bank) messages
- These represent 95%+ of expected traffic
- Fast-path optimization reduces latency for critical messages

**Implementation**:
```swift
enum MIDIMessageType {
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case programChange(channel: UInt8, program: UInt8)
    case other([UInt8])  // Fallback for less common messages
}

// Fast path detection
func parseMessage(_ data: [UInt8]) -> MIDIMessageType {
    guard !data.isEmpty else { return .other(data) }
    let status = data[0] & 0xF0
    let channel = data[0] & 0x0F
    
    switch status {
    case 0xB0:  // Control Change - FAST PATH
        return .controlChange(channel: channel, 
                             controller: data[1], 
                             value: data[2])
    case 0xC0:  // Program Change - FAST PATH
        return .programChange(channel: channel, 
                            program: data[1])
    default:
        return .other(data)
    }
}
```

**Alternatives Considered**:
- Generic MIDI parsing: Slower for common messages
- Hardcoded CC numbers: Too rigid before packet analysis

### 2. CC Number Discovery Approach

**Decision**: Runtime packet logging with analysis mode

**Rationale**:
- PG_BT4's specific CC numbers unknown until packet analysis
- Need flexibility to adapt to firmware variations
- Verbose mode provides visibility during setup

**Implementation**:
```swift
actor PacketAnalyzer {
    private var discoveredCCs: Set<UInt8> = []
    private var ccUsageCount: [UInt8: Int] = [:]
    
    func analyzeCC(_ cc: UInt8, value: UInt8) {
        discoveredCCs.insert(cc)
        ccUsageCount[cc, default: 0] += 1
        
        if ccUsageCount[cc] == 1 {
            Logger.analysis.info("Discovered new CC: #\(cc) with value \(value)")
        }
    }
    
    func getMostUsedCC() -> UInt8? {
        ccUsageCount.max(by: { $0.value < $1.value })?.key
    }
}
```

**Alternatives Considered**:
- Static CC mapping: Inflexible
- External configuration file: Unnecessary complexity

### 3. Expression Pedal Burst Handling

**Decision**: Coalescing buffer with 20ms window

**Rationale**:
- Expression pedal can generate 50+ messages/sec
- DAWs don't need every intermediate value
- 20ms coalescing reduces load while maintaining responsiveness

**Implementation**:
```swift
actor ExpressionCoalescer {
    private var pendingCC: [UInt8: UInt8] = [:]  // controller: latest value
    private var flushTask: Task<Void, Never>?
    
    func handleCC(controller: UInt8, value: UInt8) async {
        pendingCC[controller] = value
        
        if flushTask == nil {
            flushTask = Task {
                try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
                await flush()
            }
        }
    }
    
    private func flush() async {
        for (controller, value) in pendingCC {
            await sendToDAW(controller: controller, value: value)
        }
        pendingCC.removeAll()
        flushTask = nil
    }
}
```

**Alternatives Considered**:
- No coalescing: Potential DAW overload
- Fixed rate limiting: Lost intermediate positions
- Larger window: Too much latency for performance

### 4. Bidirectional MIDI Routing

**Decision**: Asymmetric routing - all from PG_BT4, only PC to PG_BT4

**Rationale**:
- PG_BT4 sends CC and PC messages to DAW
- PG_BT4 only needs PC messages for preset sync
- Reduces unnecessary Bluetooth traffic

**Routing Rules**:
```swift
// PG_BT4 → DAW: All messages
// DAW → PG_BT4: Only Program Change

func routeFromDAW(_ message: MIDIMessage) async {
    switch message.type {
    case .programChange:
        await sendToPG_BT4(message)  // Preset sync
    default:
        // Drop other messages - PG_BT4 doesn't need them
        break
    }
}
```

**Alternatives Considered**:
- Full bidirectional: Unnecessary traffic
- No DAW→PG_BT4: No preset synchronization

### 5. Connection State Machine

**Decision**: Simplified two-state model with persistent scanning

**Rationale**:
- Only two meaningful states: Scanning and Connected
- Persistent scanning ensures PG_BT4 always reconnects
- Simpler than multi-state alternatives

**States**:
```swift
enum ConnectionState {
    case scanning(since: Date)
    case connected(peripheral: CBPeripheral, since: Date)
}

// Transitions:
// scanning → connected (PG_BT4 found)
// connected → scanning (PG_BT4 lost)
```

**Alternatives Considered**:
- Multi-state (found, connecting, etc.): Unnecessary complexity
- Timeout-based scanning: User would need to restart

### 6. Performance Monitoring

**Decision**: Sliding window latency tracking for CC messages

**Rationale**:
- CC messages are most latency-sensitive (expression pedal)
- Need to verify <10ms requirement during pedal use
- Sliding window provides real-time performance view

**Implementation**:
```swift
struct LatencyMonitor {
    private var samples: CircularBuffer<Double> = CircularBuffer(capacity: 100)
    
    mutating func recordCCLatency(_ latencyMs: Double) {
        samples.append(latencyMs)
        
        if samples.count == 100 {
            let p95 = samples.sorted()[94]
            if p95 > 10.0 {
                Logger.performance.warning("CC latency exceeding 10ms: \(p95)ms")
            }
        }
    }
}
```

**Alternatives Considered**:
- All-message tracking: Dilutes critical CC metrics
- No monitoring: Can't verify requirements

### 7. Logging Strategy

**Decision**: Structured logging with CC/PC focus

**Rationale**:
- Need detailed logs for packet analysis
- CC/PC messages are primary interest
- Separate categories for filtering

**Categories**:
```swift
extension Logger {
    static let connection = Logger(subsystem: "bt4bridge", category: "connection")
    static let controlChange = Logger(subsystem: "bt4bridge", category: "cc")
    static let programChange = Logger(subsystem: "bt4bridge", category: "pc")
    static let analysis = Logger(subsystem: "bt4bridge", category: "analysis")
    static let performance = Logger(subsystem: "bt4bridge", category: "performance")
}

// Usage
Logger.controlChange.debug("CC #\(controller): \(value) @ channel \(channel)")
Logger.programChange.info("PC: \(program) @ channel \(channel)")
```

**Alternatives Considered**:
- Generic MIDI logging: Less useful for analysis
- File-based logging: OS integration preferred

### 8. Testing Approach

**Decision**: Mock foot controller with realistic CC patterns

**Rationale**:
- Need to simulate expression pedal sweeps
- Test burst scenarios (50+ msg/sec)
- Verify coalescing behavior

**Mock Implementation**:
```swift
class MockPG_BT4 {
    func simulateExpressionSweep(from: UInt8, to: UInt8, duration: TimeInterval) async {
        let steps = Int(duration * 50)  // 50 msg/sec
        let stepSize = Float(to - from) / Float(steps)
        
        for i in 0..<steps {
            let value = UInt8(Float(from) + stepSize * Float(i))
            await sendCC(controller: 11, value: value)  // CC#11 = Expression
            try? await Task.sleep(nanoseconds: 20_000_000)  // 20ms
        }
    }
    
    func simulateChannelSwitch(to channel: UInt8) async {
        await sendPC(program: channel)
    }
}
```

**Alternatives Considered**:
- Real device only: Can't test edge cases
- Random message generation: Not realistic

## Platform Considerations

### macOS Bluetooth MIDI

- BLE-MIDI uses 20-byte packets
- May need to fragment larger messages
- Connection interval affects latency (7.5-15ms typical)

### CoreMIDI Integration

- Virtual ports visible immediately
- No special handling for CC/PC messages
- Timestamps crucial for DAW synchronization

## Performance Optimizations

### For Expression Pedal

1. **Pre-allocated buffers** for CC messages
2. **Coalescing** to reduce message rate
3. **Direct routing** (no intermediate queues)
4. **Bypass general MIDI parsing** for CC

### For Channel Switching

1. **Immediate PC message forwarding**
2. **No buffering** for PC messages
3. **Priority over CC during bursts**

## Risk Mitigation

### Risk 1: Unknown CC Numbers
**Mitigation**: Packet analysis mode with comprehensive logging

### Risk 2: Expression Pedal Overload
**Mitigation**: Coalescing buffer with 20ms window

### Risk 3: Preset Sync Timing
**Mitigation**: PC messages bypass coalescing for immediate delivery

### Risk 4: Bluetooth Latency Spikes
**Mitigation**: Monitor and alert if >10ms sustained

## Next Steps

With all technical decisions resolved, proceed to Phase 1 for:
1. Foot controller-specific data model
2. Bidirectional routing contracts
3. Foot controller quick start guide