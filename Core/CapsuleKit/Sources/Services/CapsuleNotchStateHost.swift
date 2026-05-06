import Foundation

@objc public enum CapsuleOpenState: Int { case closed = 0, open = 1 }

@objc public protocol CapsuleNotchStateHost: NSObjectProtocol {
    @objc var notchState: CapsuleOpenState { get }
    @objc var hovering: Bool { get }
    @objc func observeNotchState(_ handler: @escaping (CapsuleOpenState) -> Void) -> CapsuleObservation
    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> CapsuleObservation
    @objc func open()
    @objc func close()
}
