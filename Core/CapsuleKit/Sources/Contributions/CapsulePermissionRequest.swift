import Foundation

@objc public final class CapsulePermissionRequest: NSObject {
    @objc public let kind: CapsulePermissionKind
    @objc public let rationale: String

    @objc public init(kind: CapsulePermissionKind, rationale: String) {
        self.kind = kind
        self.rationale = rationale
        super.init()
    }
}
