import AppKit
import Foundation
import NotchKit

/// Concrete implementation of `NotchHost`. Singleton owned by the host app.
final class ExtensionHost: NSObject, NotchHost {

    static let shared = ExtensionHost()

    // MARK: - Registries

    private(set) var tabs: [NotchTabContribution] = []
    private(set) var homeFragments: [NotchHomeFragmentContribution] = []
    private(set) var closedChinItems: [NotchClosedChinContribution] = []
    private(set) var sneakPeeks: [String: NotchSneakPeekContribution] = [:]
    private(set) var expandedItems: [String: NotchExpandedItemContribution] = [:]
    private(set) var hudReplacements: [String: NotchHUDContribution] = [:]
    private(set) var settingsPanes: [NotchSettingsPaneContribution] = []
    private(set) var menuBarItems: [NotchMenuItemContribution] = []
    private(set) var onboardingSteps: [NotchOnboardingContribution] = []
    private(set) var keyboardShortcuts: [NotchKeyboardShortcutContribution] = []
    private(set) var permissionRequests: [NotchPermissionRequest] = []

    static let didLoadExtensionsNotification = Notification.Name("NotchExtensionsDidLoad")

    // MARK: - Service registry (populated in Phase B)

    private var serviceFactories: [String: () -> NSObject?] = [:]
    private var screenScopedServiceFactories: [String: (String) -> NSObject?] = [:]

    func registerService(kind: String, factory: @escaping () -> NSObject?) {
        serviceFactories[kind] = factory
    }
    func registerScreenScopedService(kind: String, factory: @escaping (String) -> NSObject?) {
        screenScopedServiceFactories[kind] = factory
    }

    // MARK: - Boot

    func start() {
        // Single-display path: services bind to the AppDelegate's primary `vm`.
        // Multi-display path: callers pass a screenUUID; we look up per-screen
        // adapters from the AppDelegate's viewModels dictionary.
        // CapsuleViewModel is NOT @MainActor-isolated, so its NotchStateServiceAdapter
        // can be constructed lazily from any thread that resolves service(of:).
        registerService(kind: "notch-state") {
            guard let vm = (NSApp.delegate as? AppDelegate)?.vm else { return nil }
            return NotchStateServiceAdapter(viewModel: vm)
        }
        registerScreenScopedService(kind: "notch-state") { uuid in
            guard let vm = (NSApp.delegate as? AppDelegate)?.viewModels[uuid] else { return nil }
            return NotchStateServiceAdapter(viewModel: vm)
        }

        // Adapters that wrap @MainActor-isolated state (CapsuleViewCoordinator) must
        // be constructed on main so the snapshot seeding via MainActor.assumeIsolated
        // is safe. start() runs from applicationDidFinishLaunching (main); we capture
        // the instances here and the factories return them, regardless of which
        // thread service(of:) is called from.
        let screenAdapter = ScreenServiceAdapter(coordinator: CapsuleViewCoordinator.shared)
        let coordinatorAdapter = CoordinatorServiceAdapter(coordinator: CapsuleViewCoordinator.shared)

        registerService(kind: "screen") { screenAdapter }
        registerService(kind: "coordinator") { coordinatorAdapter }

        ExtensionLoader().load(into: self)
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: ExtensionHost.didLoadExtensionsNotification, object: nil)
        }
    }

    // MARK: - NotchHost

    @objc func register(tab: NotchTabContribution) {
        if tabs.contains(where: { $0.identifier == tab.identifier }) {
            NSLog("⚠️ NotchKit: tab identifier \(tab.identifier) already registered — dropping duplicate")
            return
        }
        tabs.append(tab)
    }
    @objc func register(homeFragment: NotchHomeFragmentContribution) {
        if homeFragments.contains(where: { $0.identifier == homeFragment.identifier }) {
            NSLog("⚠️ NotchKit: home-fragment identifier \(homeFragment.identifier) already registered — dropping duplicate")
            return
        }
        homeFragments.append(homeFragment)
        homeFragments.sort { $0.priority < $1.priority }
    }
    @objc func register(closedChinItem: NotchClosedChinContribution) {
        if closedChinItems.contains(where: { $0.identifier == closedChinItem.identifier }) {
            NSLog("⚠️ NotchKit: closed-chin identifier \(closedChinItem.identifier) already registered — dropping duplicate")
            return
        }
        closedChinItems.append(closedChinItem)
        closedChinItems.sort { $0.priority < $1.priority }
    }
    @objc func register(sneakPeek: NotchSneakPeekContribution) {
        if sneakPeeks[sneakPeek.kind] != nil {
            NSLog("⚠️ NotchKit: sneak-peek kind \(sneakPeek.kind) already registered — dropping duplicate")
            return
        }
        sneakPeeks[sneakPeek.kind] = sneakPeek
    }
    @objc func register(expandedItem: NotchExpandedItemContribution) {
        if expandedItems[expandedItem.kind] != nil {
            NSLog("⚠️ NotchKit: expanded-item kind \(expandedItem.kind) already registered — dropping duplicate")
            return
        }
        expandedItems[expandedItem.kind] = expandedItem
    }
    @objc func register(hudReplacement: NotchHUDContribution) {
        if hudReplacements[hudReplacement.kind] != nil {
            NSLog("⚠️ NotchKit: HUD kind \(hudReplacement.kind) already registered — dropping duplicate")
            return
        }
        hudReplacements[hudReplacement.kind] = hudReplacement
    }
    @objc func register(settingsPane: NotchSettingsPaneContribution) {
        if settingsPanes.contains(where: { $0.identifier == settingsPane.identifier }) {
            NSLog("⚠️ NotchKit: settings-pane identifier \(settingsPane.identifier) already registered — dropping duplicate")
            return
        }
        settingsPanes.append(settingsPane)
        settingsPanes.sort { $0.priority < $1.priority }
    }
    @objc func register(menuBarItems: [NotchMenuItemContribution]) {
        for item in menuBarItems {
            if self.menuBarItems.contains(where: { $0.title == item.title }) {
                NSLog("⚠️ NotchKit: menu-bar item title \(item.title) already registered — dropping duplicate")
                continue
            }
            self.menuBarItems.append(item)
        }
    }
    @objc func register(onboardingStep: NotchOnboardingContribution) {
        if onboardingSteps.contains(where: { $0.identifier == onboardingStep.identifier }) {
            NSLog("⚠️ NotchKit: onboarding-step identifier \(onboardingStep.identifier) already registered — dropping duplicate")
            return
        }
        onboardingSteps.append(onboardingStep)
        onboardingSteps.sort { $0.priority < $1.priority }
    }
    @objc func register(keyboardShortcut: NotchKeyboardShortcutContribution) {
        if keyboardShortcuts.contains(where: { $0.identifier == keyboardShortcut.identifier }) {
            NSLog("⚠️ NotchKit: keyboard-shortcut identifier \(keyboardShortcut.identifier) already registered — dropping duplicate")
            return
        }
        keyboardShortcuts.append(keyboardShortcut)
    }
    @objc func register(permission: NotchPermissionRequest) {
        if permissionRequests.contains(where: { $0.kind == permission.kind }) {
            NSLog("⚠️ NotchKit: permission kind \(permission.kind.rawValue) already registered — dropping duplicate")
            return
        }
        permissionRequests.append(permission)
    }

    @objc lazy var settings: NotchSettingsStore = HostSettingsStore()
    @objc lazy var permissions: NotchPermissionsAPI = HostPermissionsAPI()
    @objc lazy var logger: NotchLogger = HostLogger()

    @objc func service(of kind: String) -> NSObject? {
        serviceFactories[kind]?()
    }
    @objc func service(of kind: String, screenUUID: String) -> NSObject? {
        screenScopedServiceFactories[kind]?(screenUUID) ?? service(of: kind)
    }
}
