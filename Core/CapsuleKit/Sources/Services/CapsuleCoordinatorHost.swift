import Foundation

@objc public protocol CapsuleCoordinatorHost: NSObjectProtocol {
    @objc var currentTabIdentifier: String { get }
    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> CapsuleObservation
    @objc func showTab(_ identifier: String)
    @objc func toggleSneakPeek(kind: String,
                               value: Double,
                               icon: String,
                               durationSeconds: Double)
    @objc func toggleExpandedItem(kind: String,
                                  value: Double,
                                  durationSeconds: Double)
}
