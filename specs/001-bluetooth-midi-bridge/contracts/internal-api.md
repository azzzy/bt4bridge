# Internal API Contracts: PG_BT4 Foot Controller Bridge

**Date**: 2024-12-06  
**Feature**: 001-bluetooth-midi-bridge (PG_BT4 Foot Controller)

## Overview

This document defines the internal API contracts for the PG_BT4 foot controller bridge, optimized for Control Change (expression/volume) and Program Change (channel/bank) message handling with bidirectional support.

## Core Protocols

### PG_BT4ManagerProtocol

Manages PG_BT4 foot controller discovery and connection.

```swift
protocol PG_BT4ManagerProtocol {
    /// Start scanning for PG_BT4
    func startScanning() async throws
    
    /// Connect to PG_BT4 when found
    func connect(to peripheral: CBPeripheral) async throws
    
    /// Disconnect from PG_BT4
    func disconnect() async
    
    /// Send Program Change to PG_BT4 for preset sync
    func sendProgramChange(_ program: UInt8, channel: UInt8) async throws
    
    /// Get current connection state
    var connectionState: ConnectionState { get async }
    
    /// Connection state changes
    var connectionStateStream: AsyncStream<ConnectionState> { get }
    
    /// Incoming CC messages from PG_BT4
    var controlChangeStream: AsyncStream<ControlChangeMessage> { get }
    
    /// Incoming PC messages from PG_BT4
    var programChangeStream: AsyncStream<ProgramChangeMessage> { get }
}
```

### MIDIPortManagerProtocol

Manages the virtual MIDI port with bidirectional support.

```swift
protocol MIDIPortManagerProtocol {
    /// Initialize virtual port for PG_BT4
    func initialize() async throws
    
    /// Set port visibility based on connection
    func setPortVisibility(_ visible: Bool) async
    
    /// Send CC message to DAW
    func sendControlChange(_ message: ControlChangeMessage) async throws
    
    /// Send PC message to DAW
    func sendProgramChange(_ message: ProgramChangeMessage) async throws
    
    /// Program Changes from DAW for preset sync
    var programChangeFromDAW: AsyncStream<ProgramChangeMessage> { get }
}
```

### FootControllerRouterProtocol

Routes messages between PG_BT4 and DAW with optimization for foot controller patterns.

```swift
protocol FootControllerRouterProtocol {
    /// Start routing with coalescing
    func startRouting() async
    
    /// Stop routing and flush buffers
    func stopRouting() async
    
    /// Configure coalescing window for expression pedal
    func setCoalescingWindow(_ milliseconds: UInt) async
    
    /// Get routing statistics
    func getStatistics() async -> RoutingStatistics
    
    /// Get current CC latency
    func getCCLatency() async -> Double?
}
```

### PacketAnalyzerProtocol

Analyzes MIDI packets to discover PG_BT4's CC assignments.

```swift
protocol PacketAnalyzerProtocol {
    /// Start packet analysis mode
    func startAnalysis() async
    
    /// Stop analysis and get report
    func stopAnalysis() async -> PacketAnalysisReport
    
    /// Analyze incoming CC message
    func analyzeCC(_ cc: UInt8, value: UInt8) async
    
    /// Analyze incoming PC message
    func analyzePC(_ program: UInt8) async
    
    /// Get identified expression pedal CC
    func getExpressionCC() async -> UInt8?
    
    /// Get all discovered CCs
    func getDiscoveredCCs() async -> Set<UInt8>
}
```

### MessageLoggerProtocol

Enhanced logging for CC/PC messages.

```swift
protocol MessageLoggerProtocol {
    /// Log CC message with analysis
    func logControlChange(_ message: ControlChangeMessage, latency: Double?)
    
    /// Log PC message with direction
    func logProgramChange(_ message: ProgramChangeMessage, direction: MessageDirection)
    
    /// Log burst event
    func logBurst(rate: Int, duration: TimeInterval)
    
    /// Log packet analysis discovery
    func logDiscovery(_ discovery: String)
    
    /// Set verbosity level
    func setVerbosity(_ verbose: Bool)
}
```

## Actor Implementations

### PG_BT4Manager Actor

```swift
actor PG_BT4Manager: NSObject {
    // Constants
    private let targetDevice = "PG_BT4"
    private let midiServiceUUID = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    
    // State
    private var centralManager: CBCentralManager!
    private var pg_bt4Peripheral: CBPeripheral?
    private var connectionState: ConnectionState = .scanning
    private var midiCharacteristic: CBCharacteristic?
    
    // Streams
    nonisolated let connectionStateStream: AsyncStream<ConnectionState>
    nonisolated let controlChangeStream: AsyncStream<ControlChangeMessage>
    nonisolated let programChangeStream: AsyncStream<ProgramChangeMessage>
    
    // Message parsing optimized for CC/PC
    private func parseMIDIPacket(_ data: Data) {
        guard data.count >= 2 else { return }
        
        let statusByte = data[0]
        let messageType = statusByte & 0xF0
        let channel = statusByte & 0x0F
        
        switch messageType {
        case 0xB0:  // Control Change - FAST PATH
            guard data.count >= 3 else { return }
            let message = ControlChangeMessage(
                timestamp: mach_absolute_time(),
                channel: channel,
                controller: data[1],
                value: data[2],
                source: .pg_bt4
            )
            controlChangeContinuation.yield(message)
            
        case 0xC0:  // Program Change - FAST PATH
            let message = ProgramChangeMessage(
                timestamp: mach_absolute_time(),
                channel: channel,
                program: data[1],
                bankMSB: nil,
                bankLSB: nil,
                source: .pg_bt4,
                direction: .toDaw
            )
            programChangeContinuation.yield(message)
            
        default:
            // Other messages ignored for optimization
            break
        }
    }
}
```

### FootControllerRouter Actor

```swift
actor FootControllerRouter {
    // Dependencies
    private let pg_bt4Manager: PG_BT4ManagerProtocol
    private let portManager: MIDIPortManagerProtocol
    private let analyzer: PacketAnalyzerProtocol
    private let logger: MessageLoggerProtocol
    
    // State
    private var isRouting = false
    private var coalescer = MessageCoalescer()
    private var statistics = RoutingStatistics()
    private var coalescingWindowMs: UInt = 20
    
    // Routing tasks
    private var ccRoutingTask: Task<Void, Never>?
    private var pcRoutingTask: Task<Void, Never>?
    private var pcSyncTask: Task<Void, Never>?
    private var flushTask: Task<Void, Never>?
    
    func startRouting() async {
        guard !isRouting else { return }
        isRouting = true
        
        // Route CC from PG_BT4 with coalescing
        ccRoutingTask = Task {
            for await cc in pg_bt4Manager.controlChangeStream {
                await handleCCWithCoalescing(cc)
            }
        }
        
        // Route PC from PG_BT4 immediately (no coalescing)
        pcRoutingTask = Task {
            for await pc in pg_bt4Manager.programChangeStream {
                let startTime = mach_absolute_time()
                try? await portManager.sendProgramChange(pc)
                recordPCLatency(from: startTime)
                statistics.pcMessagesRouted += 1
                logger.logProgramChange(pc, direction: .toDaw)
            }
        }
        
        // Sync PC from DAW to PG_BT4
        pcSyncTask = Task {
            for await pc in portManager.programChangeFromDAW {
                try? await pg_bt4Manager.sendProgramChange(pc.program, channel: pc.channel)
                statistics.pcMessagesSynced += 1
                logger.logProgramChange(pc, direction: .toPG_BT4)
            }
        }
        
        // Periodic flush for coalesced messages
        flushTask = Task {
            while isRouting {
                try? await Task.sleep(nanoseconds: coalescingWindowMs * 1_000_000)
                await flushCoalescedMessages()
            }
        }
    }
    
    private func handleCCWithCoalescing(_ cc: ControlChangeMessage) async {
        let shouldSend = coalescer.addCC(
            controller: cc.controller,
            value: cc.value,
            timestamp: cc.timestamp
        )
        
        if shouldSend {
            // Send immediately if outside coalescing window
            let startTime = mach_absolute_time()
            try? await portManager.sendControlChange(cc)
            let latency = recordCCLatency(from: startTime)
            statistics.ccMessagesRouted += 1
            logger.logControlChange(cc, latency: latency)
            
            // Analyze for discovery
            await analyzer.analyzeCC(cc.controller, value: cc.value)
        }
    }
    
    private func flushCoalescedMessages() async {
        let messages = coalescer.flush()
        for (controller, value) in messages {
            let cc = ControlChangeMessage(
                timestamp: mach_absolute_time(),
                channel: 0,  // Default channel
                controller: controller,
                value: value,
                source: .pg_bt4
            )
            try? await portManager.sendControlChange(cc)
            statistics.ccMessagesCoalesced += 1
        }
    }
}
```

### PacketAnalyzer Actor

```swift
actor PacketAnalyzer {
    private var isAnalyzing = false
    private var discoveredCCs: Set<UInt8> = []
    private var ccUsageCount: [UInt8: Int] = [:]
    private var ccValueRanges: [UInt8: (min: UInt8, max: UInt8)] = [:]
    private var programChanges: Set<UInt8> = []
    private let logger: MessageLoggerProtocol
    
    func analyzeCC(_ cc: UInt8, value: UInt8) async {
        guard isAnalyzing else { return }
        
        if !discoveredCCs.contains(cc) {
            discoveredCCs.insert(cc)
            logger.logDiscovery("New CC discovered: #\(cc)")
        }
        
        ccUsageCount[cc, default: 0] += 1
        
        if let range = ccValueRanges[cc] {
            ccValueRanges[cc] = (min(range.min, value), max(range.max, value))
        } else {
            ccValueRanges[cc] = (value, value)
        }
        
        // Check if this might be expression pedal
        if let range = ccValueRanges[cc], range.max - range.min > 100 {
            logger.logDiscovery("CC #\(cc) shows expression pedal characteristics (range: \(range.min)-\(range.max))")
        }
    }
    
    func getExpressionCC() async -> UInt8? {
        // Expression pedal has wide range and high usage
        return ccValueRanges
            .filter { $0.value.max - $0.value.min > 100 }
            .max { ccUsageCount[$0.key] ?? 0 < ccUsageCount[$1.key] ?? 0 }?
            .key
    }
}
```

## Supporting Types

### RoutingStatistics
```swift
struct RoutingStatistics {
    var ccMessagesRouted: UInt64 = 0
    var ccMessagesCoalesced: UInt64 = 0
    var pcMessagesRouted: UInt64 = 0
    var pcMessagesSynced: UInt64 = 0
    var sessionStartTime: Date = .now
    var currentCCLatency: Double?
    var averageCCLatency: Double?
    var peakMessageRate: Int = 0
    
    var coalescingRatio: Double {
        guard ccMessagesRouted > 0 else { return 0 }
        return Double(ccMessagesCoalesced) / Double(ccMessagesRouted)
    }
}
```

### PacketAnalysisReport
```swift
struct PacketAnalysisReport {
    let discoveredCCs: Set<UInt8>
    let expressionCC: UInt8?
    let volumeCC: UInt8?
    let bankSelectMSB: UInt8?
    let bankSelectLSB: UInt8?
    let customSwitches: [UInt8]
    let programChanges: Set<UInt8>
    let peakMessageRate: Int
    
    var summary: String {
        """
        PG_BT4 Packet Analysis Report:
        - Expression Pedal: CC #\(expressionCC ?? 0) \(expressionCC == nil ? "(not detected)" : "")
        - Volume: CC #\(volumeCC ?? 0) \(volumeCC == nil ? "(not detected)" : "")
        - Bank Select: MSB #\(bankSelectMSB ?? 0), LSB #\(bankSelectLSB ?? 0)
        - Custom Switches: \(customSwitches.map { "CC #\($0)" }.joined(separator: ", "))
        - Program Changes Used: \(programChanges.sorted().map { String($0) }.joined(separator: ", "))
        - Peak Message Rate: \(peakMessageRate) msg/sec
        """
    }
}
```

## Message Flow Contracts

### Expression Pedal Flow (CC)

1. PG_BT4 generates CC messages during pedal movement
2. **PG_BT4Manager** receives and parses CC quickly
3. Publishes to `controlChangeStream`
4. **FootControllerRouter** checks coalescing window
5. If within 20ms of previous, coalesce
6. Otherwise send immediately to DAW
7. **PacketAnalyzer** identifies CC number
8. **MessageLogger** logs if verbose

### Channel Switch Flow (PC from PG_BT4)

1. PG_BT4 sends PC when user switches channel
2. **PG_BT4Manager** receives and parses PC
3. Publishes to `programChangeStream`
4. **FootControllerRouter** forwards immediately (no coalescing)
5. **MIDIPortManager** sends to DAW
6. **MessageLogger** logs the switch

### Preset Sync Flow (PC from DAW)

1. DAW sends PC for preset change
2. **MIDIPortManager** receives from virtual port
3. Publishes to `programChangeFromDAW`
4. **FootControllerRouter** receives PC
5. **PG_BT4Manager** sends to PG_BT4 via Bluetooth
6. PG_BT4 updates its preset/display

## Performance Contracts

### Latency Requirements

- CC messages (expression): < 10ms (95th percentile)
- PC messages: < 5ms (immediate forwarding)
- Coalescing window: 20ms default, configurable

### Throughput Requirements

- Handle 50+ CC messages/second during pedal sweeps
- No message loss under burst conditions
- Coalesce to reduce DAW load

### Memory Contracts

- Coalescing buffer: < 1KB
- Analysis data: < 2KB
- Performance metrics: < 1KB
- Total overhead: < 5KB