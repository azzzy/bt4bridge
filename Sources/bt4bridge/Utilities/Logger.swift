import Foundation
import os

/// Logging system for bt4bridge with multiple log levels
public actor Logger {
    
    /// Log levels from least to most verbose
    public enum Level: Int, Comparable, CustomStringConvertible, Sendable {
        case error = 0
        case warning = 1
        case info = 2
        case debug = 3
        case trace = 4
        
        public static func < (lhs: Level, rhs: Level) -> Bool {
            return lhs.rawValue < rhs.rawValue
        }
        
        public var description: String {
            switch self {
            case .error: return "ERROR"
            case .warning: return "WARN"
            case .info: return "INFO"
            case .debug: return "DEBUG"
            case .trace: return "TRACE"
            }
        }
        
        public var emoji: String {
            switch self {
            case .error: return "❌"
            case .warning: return "⚠️"
            case .info: return "ℹ️"
            case .debug: return "🐛"
            case .trace: return "📝"
            }
        }
    }
    
    /// Categories for organizing log messages
    public enum Category: String, Sendable {
        case bluetooth = "BT"
        case midi = "MIDI"
        case bridge = "Bridge"
        case packet = "Packet"
        case system = "System"
    }
    
    // MARK: - Properties
    
    /// Shared logger instance
    public static let shared = Logger()
    
    /// Current log level
    private var level: Level
    
    /// Enable/disable console output
    private var consoleEnabled: Bool
    
    /// Enable/disable file logging
    private var fileEnabled: Bool
    
    /// File handle for logging to file
    private var fileHandle: FileHandle?
    
    /// OS Logger instances per category
    private let osLoggers: [Category: os.Logger] = [
        .bluetooth: os.Logger(subsystem: "com.bt4bridge", category: "Bluetooth"),
        .midi: os.Logger(subsystem: "com.bt4bridge", category: "MIDI"),
        .bridge: os.Logger(subsystem: "com.bt4bridge", category: "Bridge"),
        .packet: os.Logger(subsystem: "com.bt4bridge", category: "Packet"),
        .system: os.Logger(subsystem: "com.bt4bridge", category: "System")
    ]
    
    /// Date formatter for timestamps
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        return formatter
    }()
    
    // MARK: - Initialization
    
    private init(level: Level = .info, consoleEnabled: Bool = true, fileEnabled: Bool = false) {
        self.level = level
        self.consoleEnabled = consoleEnabled
        self.fileEnabled = fileEnabled
    }
    
    // MARK: - Configuration
    
    /// Set the logging level
    public func setLevel(_ level: Level) {
        self.level = level
    }
    
    /// Get the current logging level
    public func getLevel() -> Level {
        return level
    }
    
    /// Enable or disable console output
    public func setConsoleEnabled(_ enabled: Bool) {
        self.consoleEnabled = enabled
    }
    
    /// Enable or disable file logging
    public func setFileEnabled(_ enabled: Bool, logPath: String? = nil) {
        self.fileEnabled = enabled
        
        if enabled, let path = logPath {
            // Create log file if it doesn't exist
            let fileManager = FileManager.default
            if !fileManager.fileExists(atPath: path) {
                fileManager.createFile(atPath: path, contents: nil, attributes: nil)
            }
            
            // Open file handle
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                self.fileHandle = handle
            }
        } else {
            // Close file handle
            try? fileHandle?.close()
            fileHandle = nil
        }
    }
    
    // MARK: - Logging Methods
    
    /// Log an error message
    public func error(_ message: String, category: Category = .system, file: String = #file, line: Int = #line) {
        log(level: .error, message: message, category: category, file: file, line: line)
    }
    
    /// Log a warning message
    public func warning(_ message: String, category: Category = .system, file: String = #file, line: Int = #line) {
        log(level: .warning, message: message, category: category, file: file, line: line)
    }
    
    /// Log an info message
    public func info(_ message: String, category: Category = .system, file: String = #file, line: Int = #line) {
        log(level: .info, message: message, category: category, file: file, line: line)
    }
    
    /// Log a debug message
    public func debug(_ message: String, category: Category = .system, file: String = #file, line: Int = #line) {
        log(level: .debug, message: message, category: category, file: file, line: line)
    }
    
    /// Log a trace message
    public func trace(_ message: String, category: Category = .system, file: String = #file, line: Int = #line) {
        log(level: .trace, message: message, category: category, file: file, line: line)
    }
    
    // MARK: - Private Methods
    
    private func log(level: Level, message: String, category: Category, file: String, line: Int) {
        // Check if we should log this level
        guard level <= self.level else { return }
        
        // Format the message
        let timestamp = dateFormatter.string(from: Date())
        let filename = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "[\(timestamp)] [\(level)] [\(category.rawValue)] \(filename):\(line) - \(message)"
        
        // Log to console
        if consoleEnabled {
            print("\(level.emoji) \(formattedMessage)")
        }
        
        // Log to os_log
        if let osLogger = osLoggers[category] {
            switch level {
            case .error:
                osLogger.error("\(message, privacy: .public)")
            case .warning:
                osLogger.warning("\(message, privacy: .public)")
            case .info:
                osLogger.info("\(message, privacy: .public)")
            case .debug:
                osLogger.debug("\(message, privacy: .public)")
            case .trace:
                osLogger.trace("\(message, privacy: .public)")
            }
        }
        
        // Log to file
        if fileEnabled, let handle = fileHandle {
            if let data = "\(formattedMessage)\n".data(using: .utf8) {
                handle.write(data)
            }
        }
    }
    
    // MARK: - Specialized Logging
    
    /// Log MIDI message activity
    public func logMIDI(_ message: MIDIMessage, direction: String = "->") {
        debug("\(direction) \(message)", category: .midi)
    }
    
    /// Log Bluetooth activity
    public func logBluetooth(_ event: String, details: String? = nil) {
        let message = details != nil ? "\(event): \(details!)" : event
        debug(message, category: .bluetooth)
    }
    
    /// Log packet data for analysis
    public func logPacket(_ data: Data, label: String = "Packet") {
        let hex = data.map { String(format: "%02X", $0) }.joined(separator: " ")
        trace("\(label): \(hex) (\(data.count) bytes)", category: .packet)
    }
}

// MARK: - Global Convenience Functions

/// Global logging functions for convenience
public func logError(_ message: String, category: Logger.Category = .system, file: String = #file, line: Int = #line) async {
    await Logger.shared.error(message, category: category, file: file, line: line)
}

public func logWarning(_ message: String, category: Logger.Category = .system, file: String = #file, line: Int = #line) async {
    await Logger.shared.warning(message, category: category, file: file, line: line)
}

public func logInfo(_ message: String, category: Logger.Category = .system, file: String = #file, line: Int = #line) async {
    await Logger.shared.info(message, category: category, file: file, line: line)
}

public func logDebug(_ message: String, category: Logger.Category = .system, file: String = #file, line: Int = #line) async {
    await Logger.shared.debug(message, category: category, file: file, line: line)
}

public func logTrace(_ message: String, category: Logger.Category = .system, file: String = #file, line: Int = #line) async {
    await Logger.shared.trace(message, category: category, file: file, line: line)
}