import Foundation
import OSLog

@MainActor
class LogStore: ObservableObject {
    static let shared = LogStore()
    @Published var entries: [LogEntry] = []
    private let maxEntries = 500

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let level: LogLevel

        var formattedTime: String {
            let df = DateFormatter()
            df.dateFormat = "HH:mm:ss.SSS"
            return df.string(from: timestamp)
        }
    }

    enum LogLevel: String, CaseIterable {
        case debug = "DEBUG"
        case info = "INFO"
        case warn = "WARN"
        case error = "ERROR"
    }

    private init() {
        // Capture stderr (where NSLog writes to)
        Task { [weak self] in
            await self?.captureStderr()
        }
    }

    func log(_ message: String, level: LogLevel = .info) {
        let entry = LogEntry(timestamp: Date(), message: message, level: level)
        if entries.count >= maxEntries {
            entries.removeFirst(entries.count - maxEntries + 1)
        }
        entries.append(entry)
        // Also print to stderr so device logs still see it
        print("[\(level.rawValue)] \(message)")
    }

    func clear() {
        entries.removeAll()
    }

    private func captureStderr() {
        // Read from a pipe that captures stderr output
        let pipe = Pipe()
        setvbuf(stderr, nil, _IONBF, 0)
        dup2(pipe.fileHandleForWriting.fileDescriptor, STDERR_FILENO)

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                Task { @MainActor in
                    let level: LogLevel = str.contains("error") || str.contains("fail") ? .error :
                                              str.contains("warn") ? .warn : .info
                    self?.log("[stderr] \(str.trimmingCharacters(in: .whitespacesAndNewlines))", level: level)
                }
            }
        }
    }
}

// Simple logging function that the app can use
func AppLog(_ message: String, level: LogStore.LogLevel = .info) {
    Task { @MainActor in
        LogStore.shared.log(message, level: level)
    }
}
