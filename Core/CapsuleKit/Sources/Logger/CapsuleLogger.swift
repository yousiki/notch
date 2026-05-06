import Foundation

@objc public enum NotchLogLevel: Int {
    case debug = 0, info = 1, notice = 2, warning = 3, error = 4
}

@objc public protocol CapsuleLogger: NSObjectProtocol {
    @objc func log(level: NotchLogLevel, message: String)
}
