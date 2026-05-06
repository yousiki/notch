import AppKit
import Foundation

@objc public final class CapsuleHUDContribution: NSObject {
    @objc public let kind: String
    @objc public let lifecyclePolicy: CapsuleSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        kind: String,
        lifecyclePolicy: CapsuleSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.kind = kind
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
