import Foundation

@objc public final class NotchPermissionRequest: NSObject {
    @objc public let kind: NotchPermissionKind
    @objc public let rationale: String

    @objc public init(kind: NotchPermissionKind, rationale: String) {
        self.kind = kind
        self.rationale = rationale
        super.init()
    }
}
