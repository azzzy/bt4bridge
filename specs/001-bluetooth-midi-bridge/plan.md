# Implementation Plan: PG_BT4 Foot Controller Bridge

**Branch**: `001-bluetooth-midi-bridge` | **Date**: 2024-12-06 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-bluetooth-midi-bridge/spec.md`

## Summary

Implement a macOS bridge application for the PG_BT4 Bluetooth foot controller, enabling wireless channel switching, MIDI bank selection, and volume/expression pedal control for virtual amplifiers and DAWs. The application is hardcoded specifically for PG_BT4, with bidirectional MIDI support (CC/PC from PG_BT4, PC to PG_BT4 for preset sync), automatic reconnection, and sub-10ms latency during expression pedal use.

## Technical Context

**Language/Version**: Swift 6.2+ with strict concurrency enabled  
**Primary Dependencies**: CoreBluetooth (system framework), CoreMIDI (system framework)  
**Storage**: N/A (no persistent storage required)  
**Testing**: XCTest with mock implementations for CoreBluetooth/CoreMIDI delegates  
**Target Platform**: macOS 12.0+ (Monterey and later)
**Project Type**: single (command-line executable)  
**Performance Goals**: <10ms MIDI CC/PC message latency, handle 50 msg/sec peak during expression pedal use  
**Constraints**: Hardcoded for PG_BT4 foot controller, bidirectional MIDI (PC sync to device)  
**Scale/Scope**: Single executable, ~800 LOC estimated, focused on CC/PC message optimization

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

### Principle Compliance

- ✅ **I. Test-Driven Development**: Plan includes XCTest with mocks for foot controller behavior
- ✅ **II. Async-First Architecture**: Swift concurrency model (async/await, actors) specified
- ✅ **III. Zero Data Loss**: Message buffering optimized for 50 msg/sec bursts
- ✅ **IV. Resource Safety**: Proper cleanup via Swift ARC and deinit methods planned
- ✅ **V. Observability**: Enhanced logging for CC/PC messages to aid packet analysis

### Performance Standards Compliance

- ✅ **Latency**: <10ms forwarding latency for CC/PC messages
- ✅ **Connection Time**: 10-second discovery/connection meets requirements
- ✅ **Memory**: <50MB usage with optimized buffers for foot controller traffic
- ⚠️ **Device Support**: Single PG_BT4 device (justified per user requirements)

### Development Workflow Compliance

- ✅ **Swift 6.2+**: Specified with strict concurrency checking
- ✅ **Testing Strategy**: Unit, integration, and performance tests for CC/PC handling
- ✅ **Documentation**: Focus on foot controller use cases

**GATE STATUS**: ✅ PASSED - All constitution requirements met or justified

## Project Structure

### Documentation (this feature)

```text
specs/001-bluetooth-midi-bridge/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
├── checklists/          # Quality validation checklists
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
Sources/
└── bt4bridge/
    ├── main.swift                         # Application entry point with CLI argument parsing
    ├── Core/
    │   ├── PG_BT4Manager.swift           # CoreBluetooth manager for PG_BT4 foot controller
    │   ├── MIDIPortManager.swift         # CoreMIDI virtual port with bidirectional support
    │   └── FootControllerRouter.swift    # Optimized CC/PC message routing
    ├── Models/
    │   ├── PG_BT4Device.swift            # PG_BT4 foot controller representation
    │   ├── ControlChangeMessage.swift    # CC message model (expression/volume)
    │   ├── ProgramChangeMessage.swift    # PC message model (channel/bank switching)
    │   └── ConnectionSession.swift       # Connection session tracking
    ├── Services/
    │   ├── PacketAnalyzer.swift          # CC number discovery via packet logging
    │   ├── ReconnectionService.swift     # Auto-reconnection with backoff
    │   └── MessageLogger.swift           # Enhanced CC/PC message logging
    └── Extensions/
        ├── CBPeripheral+MIDI.swift       # CoreBluetooth MIDI extensions
        └── MIDIPacket+Extensions.swift   # CoreMIDI packet helpers

Tests/
├── bt4bridgeTests/
│   ├── Unit/
│   │   ├── ControlChangeTests.swift      # CC message parsing/encoding
│   │   ├── ProgramChangeTests.swift      # PC message handling
│   │   └── FootControllerRouterTests.swift
│   ├── Integration/
│   │   ├── PG_BT4ConnectionTests.swift
│   │   ├── BidirectionalMIDITests.swift  # PC sync to PG_BT4
│   │   └── ExpressionPedalTests.swift    # 50 msg/sec burst handling
│   ├── Performance/
│   │   ├── CCLatencyTests.swift          # Expression pedal latency
│   │   └── BurstThroughputTests.swift    # 50+ msg/sec scenarios
│   └── Mocks/
│       ├── MockPG_BT4.swift              # Mock foot controller
│       ├── MockCBPeripheral.swift
│       └── MockMIDIClient.swift
```

**Structure Decision**: Foot controller-optimized structure with focus on CC/PC message handling. Added PacketAnalyzer service for discovering PG_BT4's specific CC numbers, separate models for ControlChange and ProgramChange messages to optimize parsing, and bidirectional routing support for preset synchronization. The structure follows Swift Package Manager conventions.

## Complexity Tracking

> **No violations to track** - All implementation decisions comply with constitution principles. Foot controller focus simplifies implementation while meeting performance requirements for expression pedal use.

## Post-Design Constitution Check

*Re-evaluated after Phase 1 design completion*

### Principle Compliance (Phase 1 Validation)

- ✅ **I. Test-Driven Development**: Mock foot controller with realistic CC/PC patterns for testing
- ✅ **II. Async-First Architecture**: All actors use async/await with optimized CC/PC streams  
- ✅ **III. Zero Data Loss**: Coalescing buffer preserves latest values while reducing load
- ✅ **IV. Resource Safety**: Fixed-size buffers and proper cleanup for foot controller
- ✅ **V. Observability**: Enhanced CC/PC logging with packet analysis for discovery

### Performance Standards Compliance (Phase 1 Validation)

- ✅ **Latency**: Fast-path CC/PC parsing ensures <10ms for expression pedal
- ✅ **Memory**: Minimal buffers (~5KB total) well under 50MB limit
- ✅ **Throughput**: Coalescing handles 50+ msg/sec expression pedal bursts

### Development Workflow Compliance (Phase 1 Validation)

- ✅ **Code Structure**: Clear separation of CC/PC handling with packet analysis
- ✅ **Testability**: Mock PG_BT4 simulates realistic foot controller behavior
- ✅ **Documentation**: Comprehensive foot controller usage guide

**PHASE 1 GATE STATUS**: ✅ PASSED - Design optimized for PG_BT4 foot controller use cases