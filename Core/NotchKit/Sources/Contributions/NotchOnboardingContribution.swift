import AppKit
import Foundation

@objc public final class NotchOnboardingContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let priority: Int
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        priority: Int,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.priority = priority
        self.makeViewController = makeViewController
        super.init()
    }
}
