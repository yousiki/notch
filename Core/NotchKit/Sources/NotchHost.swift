import AppKit
import Foundation

@objc public protocol NotchHost: NSObjectProtocol {

    // MARK: - Slot registration
    @objc func register(tab: NotchTabContribution)
    @objc func register(homeFragment: NotchHomeFragmentContribution)
    @objc func register(closedChinItem: NotchClosedChinContribution)
    @objc func register(sneakPeek: NotchSneakPeekContribution)
    @objc func register(expandedItem: NotchExpandedItemContribution)
    @objc func register(hudReplacement: NotchHUDContribution)
    @objc func register(settingsPane: NotchSettingsPaneContribution)
    @objc func register(menuBarItems: [NotchMenuItemContribution])
    @objc func register(onboardingStep: NotchOnboardingContribution)
    @objc func register(keyboardShortcut: NotchKeyboardShortcutContribution)
    @objc func register(permission: NotchPermissionRequest)

    // MARK: - Settings, permissions, logging
    @objc var settings: NotchSettingsStore { get }
    @objc var permissions: NotchPermissionsAPI { get }
    @objc var logger: NotchLogger { get }

    // MARK: - Host services
    @objc func service(of kind: String) -> NSObject?
    @objc func service(of kind: String, screenUUID: String) -> NSObject?
}
