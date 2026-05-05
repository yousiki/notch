import AppKit
import Foundation

@objc public final class NotchMenuItemContribution: NSObject {
    @objc public let title: String
    @objc public let action: @convention(block) () -> Void
    @objc public let keyEquivalent: String
    @objc public let keyEquivalentModifiers: UInt

    @objc public init(
        title: String,
        keyEquivalent: String,
        keyEquivalentModifiers: UInt,
        action: @escaping @convention(block) () -> Void
    ) {
        self.title = title
        self.keyEquivalent = keyEquivalent
        self.keyEquivalentModifiers = keyEquivalentModifiers
        self.action = action
        super.init()
    }
}
