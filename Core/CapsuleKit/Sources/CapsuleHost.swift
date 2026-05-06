import AppKit
import Foundation

@objc public protocol CapsuleHost: NSObjectProtocol {

    // MARK: - Slot registration
    @objc func register(tab: CapsuleTabContribution)
    @objc func register(homeFragment: CapsuleHomeFragmentContribution)
    @objc func register(closedChinItem: CapsuleClosedChinContribution)
    @objc func register(sneakPeek: CapsuleSneakPeekContribution)
    @objc func register(expandedItem: CapsuleExpandedItemContribution)
    @objc func register(hudReplacement: CapsuleHUDContribution)
    @objc func register(settingsPane: CapsuleSettingsPaneContribution)
    @objc func register(menuBarItems: [CapsuleMenuItemContribution])
    @objc func register(onboardingStep: CapsuleOnboardingContribution)
    @objc func register(keyboardShortcut: CapsuleKeyboardShortcutContribution)
    @objc func register(permission: CapsulePermissionRequest)

    // MARK: - Settings, permissions, logging
    @objc var settings: CapsuleSettingsStore { get }
    @objc var permissions: CapsulePermissionsAPI { get }
    @objc var logger: CapsuleLogger { get }

    // MARK: - Host services
    @objc func service(of kind: String) -> NSObject?
    @objc func service(of kind: String, screenUUID: String) -> NSObject?
}
