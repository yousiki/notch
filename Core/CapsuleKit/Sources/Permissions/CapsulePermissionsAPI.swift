import Foundation

@objc public protocol CapsulePermissionsAPI: NSObjectProtocol {
    @objc func status(for permission: CapsulePermissionKind) -> NotchPermissionStatus
    @objc func request(_ permission: CapsulePermissionKind,
                       completion: @escaping (NotchPermissionStatus) -> Void)
}
