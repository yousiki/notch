import Foundation

@objc public protocol NotchSettingsStore: NSObjectProtocol {
    @objc func setValue(_ value: Any?, forKey key: String)
    @objc func value(forKey key: String) -> Any?
    @objc func observe(key: String,
                       handler: @escaping (Any?) -> Void) -> NotchObservation
}
