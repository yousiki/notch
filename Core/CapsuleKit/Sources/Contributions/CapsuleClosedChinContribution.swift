import AppKit
import Foundation

@objc public enum NotchClosedChinSide: Int { case left = 0, right = 1 }

@objc public final class CapsuleClosedChinContribution: NSObject {
    @objc public let identifier: String
    @objc public let side: NotchClosedChinSide
    @objc public let priority: Int
    @objc public let lifecyclePolicy: CapsuleSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        side: NotchClosedChinSide,
        priority: Int,
        lifecyclePolicy: CapsuleSlotLifecycle,
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
