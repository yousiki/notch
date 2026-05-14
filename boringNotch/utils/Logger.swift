import Foundation
import OSLog
import SwiftUI

enum LogCategory: String {
    case lifecycle = "🔄"
    case memory = "💾"
    case performance = "⚡️"
    case ui = "🎨"
    case network = "🌐"
    case error = "❌"
    case warning = "⚠️"
    case success = "✅"
    case debug = "🔍"
}

struct AppLogger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "theboringteam.boringnotch"
    private static let loggers: [LogCategory: Logger] = Dictionary(
        uniqueKeysWithValues: LogCategory.allCases.map {
            ($0, Logger(subsystem: subsystem, category: $0.name))
        })

    static func log(
        _ message: String,
        category: LogCategory,
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        let fileName = (file as NSString).lastPathComponent
        let formatted = "\(category.rawValue) [\(fileName):\(line)] \(function) - \(message)"

        switch category {
        case .error:
            logger(for: category).error("\(formatted, privacy: .public)")
        case .warning:
            logger(for: category).warning("\(formatted, privacy: .public)")
        case .debug:
            logger(for: category).debug("\(formatted, privacy: .public)")
        default:
            logger(for: category).info("\(formatted, privacy: .public)")
        }
    }

    static func trackMemory(
        file: String = #file,
        function: String = #function,
        line: Int = #line
    ) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count)
            }
        }

        if kerr == KERN_SUCCESS {
            let usedMB = Double(info.resident_size) / 1024.0 / 1024.0
            log(
                String(format: "Memory used: %.2f MB", usedMB),
                category: .memory,
                file: file,
                function: function,
                line: line)
        }
    }

    private static func logger(for category: LogCategory) -> Logger {
        loggers[category] ?? Logger(subsystem: subsystem, category: category.name)
    }
}

extension LogCategory: CaseIterable {
    var name: String {
        switch self {
        case .lifecycle:
            "lifecycle"
        case .memory:
            "memory"
        case .performance:
            "performance"
        case .ui:
            "ui"
        case .network:
            "network"
        case .error:
            "error"
        case .warning:
            "warning"
        case .success:
            "success"
        case .debug:
            "debug"
        }
    }
}

extension View {
    func trackLifecycle(_ identifier: String) -> some View {
        self.modifier(ViewLifecycleTracker(identifier: identifier))
    }
}

struct ViewLifecycleTracker: ViewModifier {
    let identifier: String

    func body(content: Content) -> some View {
        content
            .onAppear {
                AppLogger.log("\(identifier) appeared", category: .lifecycle)
                AppLogger.trackMemory()
            }
            .onDisappear {
                AppLogger.log("\(identifier) disappeared", category: .lifecycle)
                AppLogger.trackMemory()
            }
    }
}
