import Foundation

@objc public enum CapsulePermissionKind: Int {
    case calendar      = 0
    case reminders     = 1
    case accessibility = 2
    case camera        = 3
    case microphone    = 4
    case mediaLibrary  = 5
    case fileShelf     = 6
}

@objc public enum NotchPermissionStatus: Int {
    case notDetermined = 0
    case granted       = 1
    case denied        = 2
    case unsupported   = 3
}
