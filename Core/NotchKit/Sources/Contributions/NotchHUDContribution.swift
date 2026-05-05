import AppKit
import Foundation

@objc public final class NotchHUDContribution: NSObject {
    @objc public let kind: String
    @objc public let lifecyclePolicy: NotchSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        kind: String,
        lifecyclePolicy: NotchSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.kind = kind
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
