//
//  Logger.swift
//  Gym_API
//
//  Sistema centralizado de logging con niveles, contexto y persistencia
//  Created as part of error handling optimization phase
//

import Foundation
import os.log

// MARK: - Log Level
public enum LogLevel: Int, CaseIterable, Comparable, Codable {
    case verbose = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
    case critical = 5

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }

    var emoji: String {
        switch self {
        case .verbose: return "🔍"
        case .debug: return "🐛"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        case .critical: return "🚨"
        }
    }

    var prefix: String {
        switch self {
        case .verbose: return "VERBOSE"
        case .debug: return "DEBUG"
        case .info: return "INFO"
        case .warning: return "WARNING"
        case .error: return "ERROR"
        case .critical: return "CRITICAL"
        }
    }

    var osLogType: OSLogType {
        switch self {
        case .verbose, .debug: return .debug
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}

// MARK: - Log Category
public enum LogCategory: String, CaseIterable, Codable {
    case auth = "🔐 Auth"
    case network = "🌐 Network"
    case ui = "🎨 UI"
    case database = "💾 Database"
    case cache = "📦 Cache"
    case memory = "🧠 Memory"
    case service = "⚙️ Service"
    case chat = "💬 Chat"
    case event = "📅 Event"
    case gym = "🏋️ Gym"
    case membership = "💳 Membership"
    case notification = "🔔 Notification"
    case general = "📝 General"
    case performance = "⏱️ Performance"
    case security = "🔒 Security"

    var subsystem: String {
        return "com.gymapi.Gym-API.\(self.rawValue)"
    }
}

// MARK: - Log Entry
public struct LogEntry: Codable, Identifiable {
    public let id = UUID()
    let timestamp: Date
    let level: LogLevel
    let category: LogCategory
    let message: String
    let file: String
    let function: String
    let line: Int
    let metadata: [String: String]?

    var formattedMessage: String {
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        return "\(level.emoji) [\(level.prefix)] \(category.rawValue): \(message) (\(fileName):\(line))"
    }

    var detailedMessage: String {
        var result = formattedMessage
        if let metadata = metadata, !metadata.isEmpty {
            let metadataString = metadata.map { "  \($0.key): \($0.value)" }.joined(separator: "\n")
            result += "\n📎 Metadata:\n\(metadataString)"
        }
        return result
    }
}

// MARK: - Logger Configuration
public struct LoggerConfiguration {
    var minimumLevel: LogLevel = .info
    var enabledCategories: Set<LogCategory> = Set(LogCategory.allCases)
    var enableConsoleOutput: Bool = true
    var enableOSLog: Bool = true
    var enableFileLogging: Bool = false
    var maxFileSize: Int = 10 * 1024 * 1024 // 10 MB
    var maxLogFiles: Int = 5
    var includeTimestamp: Bool = true
    var includeLocation: Bool = true

    #if DEBUG
    static let development = LoggerConfiguration(
        minimumLevel: .debug,
        enableConsoleOutput: true,
        enableOSLog: true,
        enableFileLogging: false
    )
    #else
    static let production = LoggerConfiguration(
        minimumLevel: .warning,
        enableConsoleOutput: false,
        enableOSLog: true,
        enableFileLogging: true
    )
    #endif
}

// MARK: - Logger
@MainActor
public final class Logger {

    // MARK: - Singleton
    public static let shared = Logger()

    // MARK: - Properties
    private var configuration: LoggerConfiguration
    private var logEntries: [LogEntry] = []
    private let logQueue = DispatchQueue(label: "com.gymapi.logger", qos: .utility)
    private var osLoggers: [LogCategory: OSLog] = [:]
    private var fileHandle: FileHandle?
    private let dateFormatter: DateFormatter

    // Performance metrics
    private var logCounts: [LogLevel: Int] = [:]
    private var categoryUsage: [LogCategory: Int] = [:]

    // MARK: - Initialization
    private init() {
        #if DEBUG
        self.configuration = .development
        #else
        self.configuration = .production
        #endif

        self.dateFormatter = DateFormatter()
        self.dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"

        // Initialize OS loggers
        for category in LogCategory.allCases {
            osLoggers[category] = OSLog(subsystem: category.subsystem, category: category.rawValue)
        }

        // Setup file logging if enabled
        if configuration.enableFileLogging {
            setupFileLogging()
        }

        print("✅ Logger initialized with level: \(configuration.minimumLevel.prefix)")
    }

    // MARK: - Configuration
    public func configure(_ configuration: LoggerConfiguration) {
        self.configuration = configuration

        if configuration.enableFileLogging && fileHandle == nil {
            setupFileLogging()
        } else if !configuration.enableFileLogging && fileHandle != nil {
            cleanupFileLogging()
        }

        print("⚙️ Logger reconfigured with level: \(configuration.minimumLevel.prefix)")
    }

    // MARK: - Main Logging Function
    public func log(
        _ level: LogLevel,
        _ message: String,
        category: LogCategory = .general,
        metadata: [String: String]? = nil,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        // Check if we should log this
        guard level >= configuration.minimumLevel else { return }
        guard configuration.enabledCategories.contains(category) else { return }

        // Create log entry
        let entry = LogEntry(
            timestamp: Date(),
            level: level,
            category: category,
            message: message,
            file: file,
            function: function,
            line: line,
            metadata: metadata
        )

        // Process log on background queue
        logQueue.async { [weak self] in
            Task { @MainActor in
                self?.processLogEntry(entry)
            }
        }

        // Update metrics
        logCounts[level, default: 0] += 1
        categoryUsage[category, default: 0] += 1
    }

    private func processLogEntry(_ entry: LogEntry) {
        // Store in memory (limited)
        logEntries.append(entry)
        if logEntries.count > 1000 {
            logEntries.removeFirst(100) // Keep last 900 entries
        }

        // Console output
        if configuration.enableConsoleOutput {
            printToConsole(entry)
        }

        // OS Log
        if configuration.enableOSLog {
            logToOSLog(entry)
        }

        // File logging
        if configuration.enableFileLogging {
            logToFile(entry)
        }
    }

    // MARK: - Output Methods
    private func printToConsole(_ entry: LogEntry) {
        if configuration.includeTimestamp {
            let timestamp = dateFormatter.string(from: entry.timestamp)
            print("[\(timestamp)] \(entry.formattedMessage)")
        } else {
            print(entry.formattedMessage)
        }

        if let metadata = entry.metadata, !metadata.isEmpty {
            for (key, value) in metadata {
                print("  → \(key): \(value)")
            }
        }
    }

    private func logToOSLog(_ entry: LogEntry) {
        guard let osLog = osLoggers[entry.category] else { return }

        os_log("%{public}@", log: osLog, type: entry.level.osLogType, entry.message)
    }

    // MARK: - File Logging
    private func setupFileLogging() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let logDirectory = documentsPath.appendingPathComponent("Logs")

        // Create logs directory
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)

        // Create log file
        let fileName = "gym_api_\(Date().timeIntervalSince1970).log"
        let logFileURL = logDirectory.appendingPathComponent(fileName)

        // Create file if doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }

        // Open file handle
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()

        // Clean old log files
        cleanOldLogFiles(in: logDirectory)
    }

    private func logToFile(_ entry: LogEntry) {
        guard let fileHandle = fileHandle else { return }

        let timestamp = dateFormatter.string(from: entry.timestamp)
        var logLine = "[\(timestamp)] \(entry.level.prefix) | \(entry.category.rawValue) | \(entry.message)"

        if configuration.includeLocation {
            let fileName = URL(fileURLWithPath: entry.file).lastPathComponent
            logLine += " | \(fileName):\(entry.line)"
        }

        if let metadata = entry.metadata {
            let metadataString = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ", ")
            logLine += " | metadata: {\(metadataString)}"
        }

        logLine += "\n"

        if let data = logLine.data(using: .utf8) {
            fileHandle.write(data)
        }

        // Check file size and rotate if needed
        checkAndRotateLogFile()
    }

    private func checkAndRotateLogFile() {
        guard let fileHandle = fileHandle else { return }

        do {
            let fileSize = try fileHandle.seekToEnd()
            if fileSize > configuration.maxFileSize {
                // Close current file
                fileHandle.closeFile()
                self.fileHandle = nil

                // Setup new file
                setupFileLogging()
            }
        } catch {
            print("❌ Error checking log file size: \(error)")
        }
    }

    private func cleanOldLogFiles(in directory: URL) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.creationDateKey])
            let logFiles = files.filter { $0.lastPathComponent.hasPrefix("gym_api_") }

            if logFiles.count > configuration.maxLogFiles {
                // Sort by creation date and remove oldest
                let sortedFiles = logFiles.sorted {
                    let date1 = try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate
                    let date2 = try? $1.resourceValues(forKeys: [.creationDateKey]).creationDate
                    return date1 ?? Date() < date2 ?? Date()
                }

                for i in 0..<(sortedFiles.count - configuration.maxLogFiles) {
                    try FileManager.default.removeItem(at: sortedFiles[i])
                }
            }
        } catch {
            print("❌ Error cleaning old log files: \(error)")
        }
    }

    private func cleanupFileLogging() {
        fileHandle?.closeFile()
        fileHandle = nil
    }

    // MARK: - Convenience Methods
    public func verbose(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.verbose, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func debug(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.debug, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func info(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.info, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func warning(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.warning, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func error(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.error, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    public func critical(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        log(.critical, message, category: category, metadata: metadata, file: file, function: function, line: line)
    }

    // MARK: - Performance Logging
    public func logPerformance<T>(
        operation: String,
        category: LogCategory = .performance,
        metadata: [String: String]? = nil,
        block: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let result = try await block()
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            var finalMetadata = metadata ?? [:]
            finalMetadata["duration"] = String(format: "%.3f seconds", timeElapsed)

            let level: LogLevel = timeElapsed > 1.0 ? .warning : .debug
            log(level, "Performance: \(operation) completed", category: category, metadata: finalMetadata)

            return result
        } catch {
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

            var finalMetadata = metadata ?? [:]
            finalMetadata["duration"] = String(format: "%.3f seconds", timeElapsed)
            finalMetadata["error"] = error.localizedDescription

            log(.error, "Performance: \(operation) failed", category: category, metadata: finalMetadata)
            throw error
        }
    }

    // MARK: - Error Logging
    public func logError(_ error: Error, context: String? = nil, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
        var finalMetadata = metadata ?? [:]
        finalMetadata["error_type"] = String(describing: type(of: error))
        finalMetadata["error_description"] = error.localizedDescription

        if let context = context {
            finalMetadata["context"] = context
        }

        let message = context ?? "Error occurred"
        log(.error, message, category: category, metadata: finalMetadata, file: file, function: function, line: line)
    }

    // MARK: - Analytics
    public var analytics: LogAnalytics {
        LogAnalytics(
            totalLogs: logEntries.count,
            logsByLevel: logCounts,
            logsByCategory: categoryUsage,
            recentErrors: logEntries.filter { $0.level >= .error }.suffix(10),
            errorRate: calculateErrorRate()
        )
    }

    private func calculateErrorRate() -> Double {
        let totalLogs = logCounts.values.reduce(0, +)
        let errorLogs = (logCounts[.error] ?? 0) + (logCounts[.critical] ?? 0)
        return totalLogs > 0 ? Double(errorLogs) / Double(totalLogs) : 0
    }

    // MARK: - Export
    public func exportLogs(level: LogLevel? = nil, category: LogCategory? = nil) -> String {
        var logs = logEntries

        if let level = level {
            logs = logs.filter { $0.level >= level }
        }

        if let category = category {
            logs = logs.filter { $0.category == category }
        }

        return logs.map { $0.detailedMessage }.joined(separator: "\n\n")
    }

    public func clearLogs() {
        logQueue.async { [weak self] in
            Task { @MainActor in
                self?.logEntries.removeAll()
                self?.logCounts.removeAll()
                self?.categoryUsage.removeAll()
            }
        }
    }

    deinit {
        // Cannot call MainActor methods from deinit
        // File handle will be cleaned up automatically by the system
        fileHandle?.closeFile()
        fileHandle = nil
        #if DEBUG
        print("🗑️ Logger deinitialized")
        #endif
    }
}

// MARK: - Log Analytics
public struct LogAnalytics {
    let totalLogs: Int
    let logsByLevel: [LogLevel: Int]
    let logsByCategory: [LogCategory: Int]
    let recentErrors: ArraySlice<LogEntry>
    let errorRate: Double

    var summary: String {
        """
        📊 Log Analytics:
        Total Logs: \(totalLogs)
        Error Rate: \(String(format: "%.2f%%", errorRate * 100))

        By Level:
        \(logsByLevel.map { "  \($0.key.emoji) \($0.key.prefix): \($0.value)" }.joined(separator: "\n"))

        Top Categories:
        \(logsByCategory.sorted { $0.value > $1.value }.prefix(5).map { "  \($0.key.rawValue): \($0.value)" }.joined(separator: "\n"))
        """
    }
}

// MARK: - Global Convenience Functions
public func logVerbose(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.verbose(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

public func logDebug(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.debug(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

public func logInfo(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.info(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

public func logWarning(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.warning(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

public func logError(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.error(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}

public func logCritical(_ message: String, category: LogCategory = .general, metadata: [String: String]? = nil, file: String = #file, function: String = #function, line: Int = #line) {
    Task { @MainActor in
        Logger.shared.critical(message, category: category, metadata: metadata, file: file, function: function, line: line)
    }
}