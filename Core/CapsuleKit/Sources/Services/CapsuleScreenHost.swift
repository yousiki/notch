import Foundation

@objc public protocol CapsuleScreenHost: NSObjectProtocol {
    @objc var selectedScreenUUID: String { get }
    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> CapsuleObservation
}
