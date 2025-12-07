<!-- 
Sync Impact Report
==================
Version change: [PLACEHOLDER] → 1.0.0
Modified principles: Initial constitution creation
Added sections: All sections (initial creation)
Removed sections: None
Templates requiring updates:
  ✅ constitution.md - completed
  ⚠ plan-template.md - needs alignment with Swift/CoreMIDI context
  ⚠ spec-template.md - needs alignment with Bluetooth/MIDI requirements
  ⚠ tasks-template.md - needs alignment with Swift testing practices
Follow-up TODOs: 
  - Confirm ratification date with project owner
  - Define specific performance latency targets
-->

# bt4bridge Constitution

## Core Principles

### I. Test-Driven Development
Every feature implementation MUST follow strict TDD practices. Tests are written first, reviewed for completeness, then implementation follows. The red-green-refactor cycle is mandatory for all new functionality. This ensures reliability in real-time MIDI processing where timing and data integrity are critical.

### II. Async-First Architecture
All Bluetooth and MIDI operations MUST use Swift's modern concurrency model (async/await, actors). Synchronous blocking calls are prohibited except where CoreBluetooth/CoreMIDI frameworks require delegate patterns. This principle ensures the bridge maintains low latency and doesn't block the main thread.

### III. Zero Data Loss
The bridge MUST guarantee delivery of all MIDI messages between Bluetooth and CoreMIDI. Message buffering, retry mechanisms, and proper error handling are mandatory. Silent failures are unacceptable - all errors must be logged and recoverable where possible.

### IV. Resource Safety
All system resources (Bluetooth connections, MIDI ports, memory buffers) MUST be properly managed with explicit cleanup. Use Swift's automatic reference counting correctly, implement proper deinit methods, and ensure no resource leaks. Connection state must be monitored and cleaned up on disconnection.

### V. Observability
Every significant operation MUST produce observable output. Structured logging is required for connection events, MIDI message flow, and error conditions. Debug builds should support verbose tracing. Production builds must log errors and warnings without impacting performance.

## Performance Standards

### Latency Requirements
- MIDI message forwarding latency MUST NOT exceed 10ms under normal conditions
- Bluetooth connection establishment should complete within 5 seconds
- Reconnection attempts must use exponential backoff (1s, 2s, 4s, 8s, max 30s)

### Resource Constraints
- Memory usage MUST remain under 50MB for typical operation
- CPU usage should not exceed 5% during active MIDI streaming
- Support at least 8 simultaneous Bluetooth MIDI devices

## Development Workflow

### Code Quality Gates
- All code MUST compile with Swift 6.2+ strict concurrency checking enabled
- No compiler warnings allowed in release builds
- Swift API Design Guidelines must be followed
- Documentation comments (///) required for all public APIs

### Testing Requirements
- Unit tests required for all MIDI message parsing/encoding logic
- Integration tests required for Bluetooth connection lifecycle
- Performance tests must verify latency requirements
- Mock implementations required for CoreBluetooth/CoreMIDI in tests

### Review Process
- All changes require code review before merge
- Performance-critical paths need benchmarking data
- Breaking changes to MIDI routing require migration plan
- Security review required for any network-facing changes

## Governance

This constitution supersedes all other development practices for the bt4bridge project. Any amendments require:

1. Documentation of the proposed change with clear rationale
2. Impact assessment on existing functionality
3. Migration plan if breaking changes are introduced
4. Team consensus or project owner approval

All pull requests MUST verify compliance with these principles. Violations require explicit justification in PR description. The AGENTS.md file provides runtime development guidance that supplements but does not override this constitution.

**Version**: 1.0.0 | **Ratified**: TODO(RATIFICATION_DATE): Pending project owner confirmation | **Last Amended**: 2024-12-06