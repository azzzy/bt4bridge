# Agent Guidelines for bt4bridge

## Build & Test Commands
- **Build**: `swift build` (debug) or `swift build -c release` (release)
- **Run**: `swift run` or `.build/debug/bt4bridge`
- **Test**: `swift test` (no tests currently defined)
- **Clean**: `swift package clean` or `rm -rf .build`

## Project Structure
- Swift 5.9+ executable target for macOS 12+
- Dependencies: CoreBluetooth, CoreMIDI frameworks
- Entry point: `Sources/bt4bridge/bt4bridge.swift`

## Code Style
- **Language**: Swift 6.2+ with strict concurrency enabled
- **Naming**: camelCase for variables/functions, PascalCase for types/protocols
- **Imports**: Group by system frameworks, then third-party, then local
- **Types**: Explicit types preferred; use type inference for obvious cases
- **Error Handling**: Use Swift's native `Result` and `throws`/`try`/`catch`
- **Formatting**: 4-space indentation, no trailing whitespace
- **Comments**: Use `//` for single-line, `///` for documentation comments

## Best Practices
- Leverage Swift concurrency (async/await, actors) for Bluetooth/MIDI operations
- Handle CoreBluetooth delegate callbacks appropriately
- Ensure proper resource cleanup for MIDI and Bluetooth connections
