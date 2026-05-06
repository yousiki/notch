import Foundation
import CapsuleKit

final class CoordinatorServiceAdapter: NSObject, CapsuleCoordinatorHost {

    private let coordinator: CapsuleViewCoordinator
    private var tabHandlers: [UUID: (String) -> Void] = [:]
    private var cachedTabIdentifier: String
    private let lock = NSLock()

    init(coordinator: CapsuleViewCoordinator) {
        self.coordinator = coordinator
        // Read once at init under MainActor (init is called from host start() on main).
        self.cachedTabIdentifier = MainActor.assumeIsolated { coordinator.currentTabIdentifier }
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(currentTabChanged),
            name: .currentTabIdentifierChanged, object: nil)
    }

    @objc var currentTabIdentifier: String {
        lock.lock(); defer { lock.unlock() }
        return cachedTabIdentifier
    }

    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> CapsuleObservation {
        let id = UUID()
        lock.lock(); tabHandlers[id] = handler; lock.unlock()
        return CapsuleObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.tabHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func showTab(_ identifier: String) {
        // TODO(B4): writing currentTabIdentifier doesn't yet flow back to
        // ContentView's tab switch — ContentView still observes
        // coordinator.currentView (the NotchViews enum). Task B4 rewrites
        // ContentView to iterate ExtensionHost.shared.tabs keyed by
        // currentTabIdentifier; until then, calls to showTab from
        // extensions are visible to other adapters/observers but won't
        // change the rendered tab.
        Task { @MainActor in coordinator.currentTabIdentifier = identifier }
    }

    @objc func toggleSneakPeek(kind: String, value: Double, icon: String, durationSeconds: Double) {
        Task { @MainActor in
            coordinator.toggleSneakPeek(
                status: true, kind: kind, duration: durationSeconds, value: CGFloat(value), icon: icon)
        }
    }

    @objc func toggleExpandedItem(kind: String, value: Double, durationSeconds: Double) {
        Task { @MainActor in
            coordinator.toggleExpandingView(
                status: true, kind: kind, duration: durationSeconds, value: CGFloat(value))
        }
    }

    @objc private func currentTabChanged() {
        // Notification can fire on any thread; hop to MainActor to read the
        // @MainActor-isolated coordinator, then refresh the cached snapshot
        // and dispatch to observers.
        Task { @MainActor in
            let id = self.coordinator.currentTabIdentifier
            self.lock.lock()
            self.cachedTabIdentifier = id
            let copy = Array(self.tabHandlers.values)
            self.lock.unlock()
            copy.forEach { $0(id) }
        }
    }
}
