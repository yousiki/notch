import Foundation

@objc public final class NotchKeyboardShortcutContribution: NSObject {
    @objc public let identifier: String
    @objc public let displayName: String
    @objc public let action: @convention(block) () -> Void

    @objc public init(
        identifier: String,
        displayName: String,
        action: @escaping @convention(block) () -> Void
    ) {
        self.identifier = identifier
        self.displayName = displayName
        self.action = action
        super.init()
    }
}
