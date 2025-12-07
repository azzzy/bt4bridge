---

description: "Task list for PG_BT4 Foot Controller Bridge implementation"
---

# Tasks: PG_BT4 Foot Controller Bridge

**Input**: Design documents from `/specs/001-bluetooth-midi-bridge/`
**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

**Tests**: Test tasks are included per Constitution Principle I (Test-Driven Development is mandatory).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Single project**: `Sources/`, `Tests/` at repository root
- Swift Package Manager structure for macOS executable

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Project initialization and basic structure

- [ ] T001 Verify Swift 6.2+ and Xcode 15+ installation
- [ ] T002 Update Package.swift with strict concurrency checking and macOS 12.0+ platform
- [ ] T003 [P] Create directory structure under Sources/bt4bridge per plan.md
- [ ] T004 [P] Create directory structure under Tests/bt4bridgeTests per plan.md
- [ ] T005 Configure .gitignore for Swift/Xcode artifacts

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core infrastructure that MUST be complete before ANY user story can be implemented

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [ ] T006 Define MIDI message type enums in Sources/bt4bridge/Models/MIDITypes.swift
- [ ] T007 [P] Create Logger configuration in Sources/bt4bridge/Services/MessageLogger.swift
- [ ] T008 [P] Define connection state enum in Sources/bt4bridge/Models/ConnectionState.swift
- [ ] T009 [P] Create circular buffer implementation in Sources/bt4bridge/Core/CircularBuffer.swift
- [ ] T010 Create mock protocol definitions in Tests/bt4bridgeTests/Mocks/MockProtocols.swift
- [ ] T011 [P] Implement MockCBPeripheral in Tests/bt4bridgeTests/Mocks/MockCBPeripheral.swift
- [ ] T012 [P] Implement MockMIDIClient in Tests/bt4bridgeTests/Mocks/MockMIDIClient.swift
- [ ] T013 [P] Create test helper utilities in Tests/bt4bridgeTests/Helpers/TestHelpers.swift

**Checkpoint**: Foundation ready - user story implementation can now begin in parallel

---

## Phase 3: User Story 1 - Basic Device Connection and Bridging (Priority: P1) 🎯 MVP

**Goal**: Connect to PG_BT4 foot controller and bridge CC/PC messages to DAW with bidirectional PC sync

**Independent Test**: Start app, connect PG_BT4, verify expression pedal CC and channel switch PC messages in DAW, verify preset sync from DAW

### Tests for User Story 1 ⚠️

> **NOTE: Write these tests FIRST, ensure they FAIL before implementation**

- [ ] T014 [P] [US1] Write unit test for PG_BT4Device model in Tests/bt4bridgeTests/Unit/PG_BT4DeviceTests.swift
- [ ] T015 [P] [US1] Write unit test for ControlChangeMessage parsing in Tests/bt4bridgeTests/Unit/ControlChangeTests.swift
- [ ] T016 [P] [US1] Write unit test for ProgramChangeMessage handling in Tests/bt4bridgeTests/Unit/ProgramChangeTests.swift
- [ ] T017 [US1] Write integration test for PG_BT4 connection in Tests/bt4bridgeTests/Integration/PG_BT4ConnectionTests.swift
- [ ] T018 [US1] Write integration test for bidirectional MIDI routing in Tests/bt4bridgeTests/Integration/BidirectionalMIDITests.swift
- [ ] T019 [US1] Write performance test for expression pedal latency in Tests/bt4bridgeTests/Performance/CCLatencyTests.swift

### Implementation for User Story 1

- [ ] T020 [P] [US1] Create PG_BT4Device model in Sources/bt4bridge/Models/PG_BT4Device.swift
- [ ] T021 [P] [US1] Create ControlChangeMessage model in Sources/bt4bridge/Models/ControlChangeMessage.swift
- [ ] T022 [P] [US1] Create ProgramChangeMessage model in Sources/bt4bridge/Models/ProgramChangeMessage.swift
- [ ] T023 [P] [US1] Create ConnectionSession model in Sources/bt4bridge/Models/ConnectionSession.swift
- [ ] T024 [US1] Implement PG_BT4Manager actor in Sources/bt4bridge/Core/PG_BT4Manager.swift
- [ ] T025 [US1] Implement MIDIPortManager actor in Sources/bt4bridge/Core/MIDIPortManager.swift
- [ ] T026 [US1] Implement FootControllerRouter actor in Sources/bt4bridge/Core/FootControllerRouter.swift
- [ ] T027 [US1] Create CBPeripheral+MIDI extension in Sources/bt4bridge/Extensions/CBPeripheral+MIDI.swift
- [ ] T028 [US1] Create MIDIPacket+Extensions in Sources/bt4bridge/Extensions/MIDIPacket+Extensions.swift
- [ ] T029 [US1] Implement PacketAnalyzer service in Sources/bt4bridge/Services/PacketAnalyzer.swift
- [ ] T030 [US1] Implement message coalescing in FootControllerRouter
- [ ] T031 [US1] Add CC/PC fast-path parsing in PG_BT4Manager
- [ ] T032 [US1] Implement bidirectional PC routing for preset sync
- [ ] T033 [US1] Create main.swift with basic lifecycle in Sources/bt4bridge/main.swift
- [ ] T034 [US1] Add --verbose flag for CC discovery in main.swift
- [ ] T035 [US1] Verify all User Story 1 tests pass

**Checkpoint**: PG_BT4 connection, CC/PC routing, and preset sync working

---

## Phase 4: User Story 2 - Connection Persistence and Auto-Reconnection (Priority: P2)

**Goal**: Automatically reconnect to PG_BT4 after disconnection with exponential backoff

**Independent Test**: Disconnect PG_BT4, verify automatic reconnection when available

### Tests for User Story 2 ⚠️

- [ ] T036 [P] [US2] Write unit test for ReconnectionState in Tests/bt4bridgeTests/Unit/ReconnectionStateTests.swift
- [ ] T037 [P] [US2] Write test for exponential backoff logic in Tests/bt4bridgeTests/Unit/BackoffTests.swift
- [ ] T038 [US2] Write integration test for reconnection scenarios in Tests/bt4bridgeTests/Integration/ReconnectionTests.swift

### Implementation for User Story 2

- [ ] T039 [P] [US2] Create ReconnectionState struct in Sources/bt4bridge/Models/ReconnectionState.swift
- [ ] T040 [US2] Implement ReconnectionService in Sources/bt4bridge/Services/ReconnectionService.swift
- [ ] T041 [US2] Add exponential backoff with jitter in ReconnectionService
- [ ] T042 [US2] Integrate reconnection into PG_BT4Manager disconnect handler
- [ ] T043 [US2] Add persistent scanning on connection loss in PG_BT4Manager
- [ ] T044 [US2] Update ConnectionSession to track reconnect attempts
- [ ] T045 [US2] Verify all User Story 2 tests pass

**Checkpoint**: Auto-reconnection working with proper backoff

---

## Phase 5: User Story 3 - Device Discovery and Status Visibility (Priority: P3)

**Goal**: Display PG_BT4 connection status and CC discovery information

**Independent Test**: Run with --list flag, verify PG_BT4 status display

### Tests for User Story 3 ⚠️

- [ ] T046 [P] [US3] Write unit test for status formatting in Tests/bt4bridgeTests/Unit/StatusFormatterTests.swift
- [ ] T047 [US3] Write test for packet analysis report in Tests/bt4bridgeTests/Unit/PacketAnalysisTests.swift

### Implementation for User Story 3

- [ ] T048 [US3] Create StatusFormatter for PG_BT4 display in Sources/bt4bridge/Services/StatusFormatter.swift
- [ ] T049 [US3] Add --list command-line option in Sources/bt4bridge/main.swift
- [ ] T050 [US3] Implement list mode showing PG_BT4 status in main.swift
- [ ] T051 [US3] Add CC discovery summary to verbose output
- [ ] T052 [US3] Display expression pedal CC identification in verbose mode
- [ ] T053 [US3] Show message rate statistics in status display
- [ ] T054 [US3] Verify all User Story 3 tests pass

**Checkpoint**: Status visibility and CC discovery reporting complete

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Performance optimization and production readiness

- [ ] T055 [P] Optimize CC coalescing window in Sources/bt4bridge/Core/FootControllerRouter.swift
- [ ] T056 [P] Add burst detection in Sources/bt4bridge/Services/PacketAnalyzer.swift
- [ ] T057 [P] Write MockPG_BT4 with expression sweep simulation in Tests/bt4bridgeTests/Mocks/MockPG_BT4.swift
- [ ] T058 Write expression pedal burst test in Tests/bt4bridgeTests/Integration/ExpressionPedalTests.swift
- [ ] T059 Write burst throughput test in Tests/bt4bridgeTests/Performance/BurstThroughputTests.swift
- [ ] T060 Add --help and --version options in Sources/bt4bridge/main.swift
- [ ] T061 Optimize memory usage with fixed-size buffers
- [ ] T062 Add performance monitoring for CC latency percentiles
- [ ] T063 Update README.md with PG_BT4 specific instructions
- [ ] T064 Run quickstart.md validation with real PG_BT4 device
- [ ] T065 Profile CPU usage during 50 msg/sec bursts
- [ ] T066 Create release build configuration with optimizations

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - can start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Stories (Phase 3+)**: All depend on Foundational phase completion
  - User stories can proceed in priority order (US1 → US2 → US3)
  - US2 and US3 can start after US1 core is working
- **Polish (Final Phase)**: Depends on all user stories being complete

### User Story Dependencies

- **User Story 1 (P1)**: Can start after Foundational - Core foot controller functionality
- **User Story 2 (P2)**: Can start after US1 connection works - Adds reconnection
- **User Story 3 (P3)**: Can start after US1 - Adds visibility features

### Within Each User Story

- Tests MUST be written and FAIL before implementation
- Models before services
- Services before integration
- Core implementation before UI/CLI features
- Story complete before moving to next priority

### Parallel Opportunities

- All Setup tasks marked [P] can run in parallel
- All Foundational tasks marked [P] can run in parallel
- All model creation tasks marked [P] within a story can run in parallel
- All test writing tasks marked [P] can run in parallel

---

## Parallel Example: User Story 1

```bash
# Launch all model creation tasks together:
Task: "Create PG_BT4Device model in Sources/bt4bridge/Models/PG_BT4Device.swift"
Task: "Create ControlChangeMessage model in Sources/bt4bridge/Models/ControlChangeMessage.swift"
Task: "Create ProgramChangeMessage model in Sources/bt4bridge/Models/ProgramChangeMessage.swift"
Task: "Create ConnectionSession model in Sources/bt4bridge/Models/ConnectionSession.swift"

# Launch all test writing tasks together:
Task: "Write unit test for PG_BT4Device model"
Task: "Write unit test for ControlChangeMessage parsing"
Task: "Write unit test for ProgramChangeMessage handling"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup
2. Complete Phase 2: Foundational (CRITICAL - blocks all stories)
3. Complete Phase 3: User Story 1
4. **STOP and VALIDATE**: Test PG_BT4 connection, CC/PC routing, preset sync
5. Deploy/demo if ready

### Incremental Delivery

1. Complete Setup + Foundational → Foundation ready
2. Add User Story 1 → Test with real PG_BT4 → Deploy (MVP!)
3. Add User Story 2 → Test reconnection → Deploy
4. Add User Story 3 → Test status display → Deploy
5. Polish phase → Production ready

### CC Discovery Process

During User Story 1 implementation:
1. Run with --verbose flag
2. Use expression pedal from min to max
3. PacketAnalyzer identifies CC numbers
4. Log shows discovered CCs
5. Document findings for users

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Each user story should be independently completable and testable
- Tests written first per Constitution (TDD mandatory)
- Focus on CC/PC message optimization for foot controller
- Coalescing critical for expression pedal performance
- Packet analysis essential for CC discovery