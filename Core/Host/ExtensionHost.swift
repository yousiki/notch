import AppKit
import Foundation
import CapsuleKit

/// Concrete implementation of `CapsuleHost`. Singleton owned by the host app.
final class ExtensionHost: NSObject, CapsuleHost {

    static let shared = ExtensionHost()

    // MARK: - Registries

    private(set) var tabs: [CapsuleTabContribution] = []
    private(set) var homeFragments: [CapsuleHomeFragmentContribution] = []
    private(set) var closedChinItems: [CapsuleClosedChinContribution] = []
    private(set) var sneakPeeks: [String: CapsuleSneakPeekContribution] = [:]
    private(set) var expandedItems: [String: CapsuleExpandedItemContribution] = [:]
    private(set) var hudReplacements: [String: CapsuleHUDContribution] = [:]
    private(set) var settingsPanes: [CapsuleSettingsPaneContribution] = []
    private(set) var menuBarItems: [CapsuleMenuItemContribution] = []
    private(set) var onboardingSteps: [CapsuleOnboardingContribution] = []
    private(set) var keyboardShortcuts: [CapsuleKeyboardShortcutContribution] = []
    private(set) var permissionRequests: [CapsulePermissionRequest] = []

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

    // MARK: - CapsuleHost

    @objc func register(tab: CapsuleTabContribution) {
        if tabs.contains(where: { $0.identifier == tab.identifier }) {
            NSLog("⚠️ CapsuleKit: tab identifier \(tab.identifier) already registered — dropping duplicate")
            return
        }
        tabs.append(tab)
    }
    @objc func register(homeFragment: CapsuleHomeFragmentContribution) {
        if homeFragments.contains(where: { $0.identifier == homeFragment.identifier }) {
            NSLog("⚠️ CapsuleKit: home-fragment identifier \(homeFragment.identifier) already registered — dropping duplicate")
            return
        }
        homeFragments.append(homeFragment)
        homeFragments.sort { $0.priority < $1.priority }
    }
    @objc func register(closedChinItem: CapsuleClosedChinContribution) {
        if closedChinItems.contains(where: { $0.identifier == closedChinItem.identifier }) {
            NSLog("⚠️ CapsuleKit: closed-chin identifier \(closedChinItem.identifier) already registered — dropping duplicate")
            return
        }
        closedChinItems.append(closedChinItem)
        closedChinItems.sort { $0.priority < $1.priority }
    }
    @objc func register(sneakPeek: CapsuleSneakPeekContribution) {
        if sneakPeeks[sneakPeek.kind] != nil {
            NSLog("⚠️ CapsuleKit: sneak-peek kind \(sneakPeek.kind) already registered — dropping duplicate")
            return
        }
        sneakPeeks[sneakPeek.kind] = sneakPeek
    }
    @objc func register(expandedItem: CapsuleExpandedItemContribution) {
        if expandedItems[expandedItem.kind] != nil {
            NSLog("⚠️ CapsuleKit: expanded-item kind \(expandedItem.kind) already registered — dropping duplicate")
            return
        }
        expandedItems[expandedItem.kind] = expandedItem
    }
    @objc func register(hudReplacement: CapsuleHUDContribution) {
        if hudReplacements[hudReplacement.kind] != nil {
            NSLog("⚠️ CapsuleKit: HUD kind \(hudReplacement.kind) already registered — dropping duplicate")
            return
        }
        hudReplacements[hudReplacement.kind] = hudReplacement
    }
    @objc func register(settingsPane: CapsuleSettingsPaneContribution) {
        if settingsPanes.contains(where: { $0.identifier == settingsPane.identifier }) {
            NSLog("⚠️ CapsuleKit: settings-pane identifier \(settingsPane.identifier) already registered — dropping duplicate")
            return
        }
        settingsPanes.append(settingsPane)
        settingsPanes.sort { $0.priority < $1.priority }
    }
    @objc func register(menuBarItems: [CapsuleMenuItemContribution]) {
        for item in menuBarItems {
            if self.menuBarItems.contains(where: { $0.title == item.title }) {
                NSLog("⚠️ CapsuleKit: menu-bar item title \(item.title) already registered — dropping duplicate")
                continue
            }
            self.menuBarItems.append(item)
        }
    }
    @objc func register(onboardingStep: CapsuleOnboardingContribution) {
        if onboardingSteps.contains(where: { $0.identifier == onboardingStep.identifier }) {
            NSLog("⚠️ CapsuleKit: onboarding-step identifier \(onboardingStep.identifier) already registered — dropping duplicate")
            return
        }
        onboardingSteps.append(onboardingStep)
        onboardingSteps.sort { $0.priority < $1.priority }
    }
    @objc func register(keyboardShortcut: CapsuleKeyboardShortcutContribution) {
        if keyboardShortcuts.contains(where: { $0.identifier == keyboardShortcut.identifier }) {
            NSLog("⚠️ CapsuleKit: keyboard-shortcut identifier \(keyboardShortcut.identifier) already registered — dropping duplicate")
            return
        }
        keyboardShortcuts.append(keyboardShortcut)
    }
    @objc func register(permission: CapsulePermissionRequest) {
        if permissionRequests.contains(where: { $0.kind == permission.kind }) {
            NSLog("⚠️ CapsuleKit: permission kind \(permission.kind.rawValue) already registered — dropping duplicate")
            return
        }
        permissionRequests.append(permission)
    }

    @objc lazy var settings: CapsuleSettingsStore = HostSettingsStore()
    @objc lazy var permissions: CapsulePermissionsAPI = HostPermissionsAPI()
    @objc lazy var logger: CapsuleLogger = HostLogger()

    @objc func service(of kind: String) -> NSObject? {
        serviceFactories[kind]?()
    }
    @objc func service(of kind: String, screenUUID: String) -> NSObject? {
        screenScopedServiceFactories[kind]?(screenUUID) ?? service(of: kind)
    }
}
