import AppKit
import Foundation

@objc public final class CapsuleSettingsPaneContribution: NSObject {
    @objc public let identifier: String
    @objc public let title: String
    @objc public let systemImage: String
    @objc public let priority: Int
    @objc public let makeViewController: @convention(block) () -> NSViewController

    @objc public init(
        identifier: String,
        title: String,
        systemImage: String,
        priority: Int,
        makeViewController: @escaping @convention(block) () -> NSViewController
    ) {
        self.identifier = identifier
        self.title = title
        self.systemImage = systemImage
        self.priority = priority
        self.makeViewController = makeViewController
        super.init()
    }
}
