import Foundation

/// Principal-class protocol that every `.notchext` bundle must implement.
///
/// Exactly one class in the bundle conforms to this protocol and is declared
/// as `NSPrincipalClass` in the bundle's `Info.plist`. The host loader
/// instantiates that class via `make()` after `Bundle.load()`.
@objc public protocol NotchExtension: NSObjectProtocol {
    /// Factory called by the loader after the bundle is loaded.
    @objc static func make() -> NotchExtension

    /// Reverse-DNS identifier, e.g. `"com.theboredteam.music"`.
    @objc var identifier: String { get }

    /// Human-readable display name shown in Settings → Extensions.
    @objc var displayName: String { get }

    /// Called once after instantiation. The extension uses the supplied host
    /// to register every contribution it makes. After `activate(host:)`
    /// returns, the extension's contributions are visible to the host.
    @objc func activate(host: NotchHost)

    @objc optional func deactivate()
    @objc optional func screenConfigurationChanged()
    @objc optional func screenLocked()
    @objc optional func screenUnlocked()
}
