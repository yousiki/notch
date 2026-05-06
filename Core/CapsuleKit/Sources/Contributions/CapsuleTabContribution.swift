import AppKit
import Foundation

@objc public final class CapsuleTabContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let lifecyclePolicy: CapsuleSlotLifecycle
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        systemImage: String,
        lifecyclePolicy: CapsuleSlotLifecycle,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.lifecyclePolicy = lifecyclePolicy
        self.makeViewController = makeViewController
        super.init()
    }
}
