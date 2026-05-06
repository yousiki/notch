import Foundation
import CapsuleKit
import os

final class HostLogger: NSObject, CapsuleLogger {
    private let logger = os.Logger(subsystem: "moe.siki.Capsule", category: "extension")

    @objc func log(level: NotchLogLevel, message: String) {
        switch level {
        case .debug:   logger.debug("\(message, privacy: .public)")
        case .info:    logger.info("\(message, privacy: .public)")
        case .notice:  logger.notice("\(message, privacy: .public)")
        case .warning: logger.warning("\(message, privacy: .public)")
        case .error:   logger.error("\(message, privacy: .public)")
        @unknown default:
            logger.info("\(message, privacy: .public)")
        }
    }
}
