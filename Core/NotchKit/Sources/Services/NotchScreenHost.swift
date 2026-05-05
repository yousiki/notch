import Foundation

@objc public protocol NotchScreenHost: NSObjectProtocol {
    @objc var selectedScreenUUID: String { get }
    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> NotchObservation
}
