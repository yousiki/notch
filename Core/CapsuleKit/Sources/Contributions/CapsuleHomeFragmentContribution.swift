import AppKit
import Foundation

@objc public final class CapsuleHomeFragmentContribution: NSObject {
    @objc public let identifier: String
    @objc public let priority: Int
    @objc public let lifecyclePolicy: CapsuleSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        priority: Int,
        lifecyclePolicy: CapsuleSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.priority = priority
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
