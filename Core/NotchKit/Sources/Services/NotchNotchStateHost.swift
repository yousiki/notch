import Foundation

@objc public enum NotchOpenState: Int { case closed = 0, open = 1 }

@objc public protocol NotchNotchStateHost: NSObjectProtocol {
    @objc var notchState: NotchOpenState { get }
    @objc var hovering: Bool { get }
    @objc func observeNotchState(_ handler: @escaping (NotchOpenState) -> Void) -> NotchObservation
    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> NotchObservation
    @objc func open()
    @objc func close()
}
