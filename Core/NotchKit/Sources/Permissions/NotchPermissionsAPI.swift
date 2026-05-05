import Foundation

@objc public protocol NotchPermissionsAPI: NSObjectProtocol {
    @objc func status(for permission: NotchPermissionKind) -> NotchPermissionStatus
    @objc func request(_ permission: NotchPermissionKind,
                       completion: @escaping (NotchPermissionStatus) -> Void)
}
