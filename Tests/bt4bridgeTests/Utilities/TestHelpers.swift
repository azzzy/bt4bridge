import Foundation
import XCTest
@testable import bt4bridge

/// Test helper utilities for bt4bridge tests
public enum TestHelpers {
    
    // MARK: - MIDI Message Helpers
    
    /// Create a sample Control Change message
    public static func createCC(channel: UInt8 = 0, controller: UInt8 = 11, value: UInt8 = 64) -> MIDIMessage {
        return .controlChange(channel: channel, controller: controller, value: value)
    }
    
    /// Create a sample Program Change message
    public static func createPC(channel: UInt8 = 0, program: UInt8 = 1) -> MIDIMessage {
        return .programChange(channel: channel, program: program)
    }
    
    /// Create raw MIDI CC bytes
    public static func createCCBytes(channel: UInt8 = 0, controller: UInt8 = 11, value: UInt8 = 64) -> Data {
        return Data([
            0xB0 | (channel & 0x0F),
            controller & 0x7F,
            value & 0x7F
        ])
    }
    
    /// Create raw MIDI PC bytes
    public static func createPCBytes(channel: UInt8 = 0, program: UInt8 = 1) -> Data {
        return Data([
            0xC0 | (channel & 0x0F),
            program & 0x7F
        ])
    }
    
    /// Create a BLE MIDI packet with timestamp
    public static func createBLEMIDIPacket(midiData: Data, timestamp: UInt8 = 0x80) -> Data {
        var packet = Data()
        packet.append(timestamp) // Simplified timestamp
        packet.append(contentsOf: midiData)
        return packet
    }
    
    /// Generate a sequence of expression pedal values
    public static func generateExpressionSequence(from: UInt8, to: UInt8, steps: Int) -> [UInt8] {
        guard steps > 1 else { return [from] }
        
        var values: [UInt8] = []
        for i in 0..<steps {
            let progress = Double(i) / Double(steps - 1)
            let value = Double(from) + (Double(to) - Double(from)) * progress
            values.append(UInt8(min(127, max(0, value))))
        }
        return values
    }
    
    // MARK: - Async Testing Helpers
    
    /// Wait for a condition with timeout
    public static func waitFor(
        _ condition: @escaping () async -> Bool,
        timeout: TimeInterval = 5.0,
        interval: TimeInterval = 0.1
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
        }
        
        throw TestError.timeout
    }
    
    /// Wait for an async operation with timeout
    public static func withTimeout<T: Sendable>(
        _ seconds: TimeInterval,
        operation: @escaping @Sendable () async throws -> T
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TestError.timeout
            }
            
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    // MARK: - Performance Testing
    
    /// Measure async operation performance
    public static func measureAsync(
        iterations: Int = 10,
        operation: @escaping () async throws -> Void
    ) async throws -> PerformanceMetrics {
        var durations: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let start = Date()
            try await operation()
            let duration = Date().timeIntervalSince(start)
            durations.append(duration)
        }
        
        return PerformanceMetrics(durations: durations)
    }
    
    public struct PerformanceMetrics {
        let durations: [TimeInterval]
        
        var average: TimeInterval {
            guard !durations.isEmpty else { return 0 }
            return durations.reduce(0, +) / Double(durations.count)
        }
        
        var min: TimeInterval {
            durations.min() ?? 0
        }
        
        var max: TimeInterval {
            durations.max() ?? 0
        }
        
        var median: TimeInterval {
            guard !durations.isEmpty else { return 0 }
            let sorted = durations.sorted()
            let mid = sorted.count / 2
            if sorted.count % 2 == 0 {
                return (sorted[mid - 1] + sorted[mid]) / 2
            } else {
                return sorted[mid]
            }
        }
    }
    
    // MARK: - Data Helpers
    
    /// Convert hex string to Data
    public static func dataFromHex(_ hex: String) -> Data? {
        let hex = hex.replacingOccurrences(of: " ", with: "")
        var data = Data()
        var index = hex.startIndex
        
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard nextIndex <= hex.endIndex else { return nil }
            
            let byteString = hex[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            
            data.append(byte)
            index = nextIndex
        }
        
        return data
    }
    
    /// Convert Data to hex string
    public static func hexFromData(_ data: Data) -> String {
        return data.map { String(format: "%02X", $0) }.joined(separator: " ")
    }
    
    // MARK: - Assertion Helpers
    
    /// Assert two MIDI messages are equal with detailed failure message
    public static func assertMIDIEqual(
        _ actual: MIDIMessage?,
        _ expected: MIDIMessage,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard let actual = actual else {
            XCTFail("Expected \(expected) but got nil", file: file, line: line)
            return
        }
        
        XCTAssertEqual(actual, expected, "MIDI messages don't match", file: file, line: line)
    }
    
    /// Assert Data contains expected bytes
    public static func assertDataEqual(
        _ actual: Data,
        _ expected: Data,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if actual != expected {
            let actualHex = hexFromData(actual)
            let expectedHex = hexFromData(expected)
            XCTFail("Data mismatch:\nActual:   \(actualHex)\nExpected: \(expectedHex)", file: file, line: line)
        }
    }
}

// MARK: - Test Errors

public enum TestError: Error, LocalizedError {
    case timeout
    case conditionNotMet
    case unexpectedValue(Any)
    
    public var errorDescription: String? {
        switch self {
        case .timeout:
            return "Test operation timed out"
        case .conditionNotMet:
            return "Test condition was not met"
        case .unexpectedValue(let value):
            return "Unexpected value: \(value)"
        }
    }
}

// MARK: - XCTestCase Extensions

public extension XCTestCase {
    
    /// Run an async test with automatic timeout
    func runAsyncTest(
        timeout: TimeInterval = 10,
        _ test: @escaping @Sendable () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")
        
        Task {
            do {
                try await TestHelpers.withTimeout(timeout) {
                    try await test()
                }
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout + 1)
    }
}