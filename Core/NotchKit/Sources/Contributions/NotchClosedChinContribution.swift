import AppKit
import Foundation

@objc public enum NotchClosedChinSide: Int { case left = 0, right = 1 }

@objc public final class NotchClosedChinContribution: NSObject {
    @objc public let identifier: String
    @objc public let side: NotchClosedChinSide
    @objc public let priority: Int
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        side: NotchClosedChinSide,
        priority: Int,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.side = side
        self.priority = priority
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
