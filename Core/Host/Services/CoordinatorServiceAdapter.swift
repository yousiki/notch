import Foundation
import NotchKit

final class CoordinatorServiceAdapter: NSObject, NotchCoordinatorHost {

    private let coordinator: BoringViewCoordinator
    private var tabHandlers: [(String) -> Void] = []
    private let lock = NSLock()

    init(coordinator: BoringViewCoordinator) {
        self.coordinator = coordinator
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(currentTabChanged),
            name: .currentTabIdentifierChanged, object: nil)
    }

    @objc var currentTabIdentifier: String {
        MainActor.assumeIsolated { coordinator.currentTabIdentifier }
    }

    @objc func observeCurrentTab(_ handler: @escaping (String) -> Void) -> NotchObservation {
        lock.lock(); tabHandlers.append(handler); lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.tabHandlers.removeAll { ($0 as AnyObject) === (handler as AnyObject) }
            self.lock.unlock()
        }
    }

    @objc func showTab(_ identifier: String) {
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
                status: true, kind: kind, value: CGFloat(value))
        }
    }

    @objc private func currentTabChanged() {
        let id = MainActor.assumeIsolated { coordinator.currentTabIdentifier }
        lock.lock(); let copy = tabHandlers; lock.unlock()
        copy.forEach { $0(id) }
    }
}

extension Notification.Name {
    static let currentTabIdentifierChanged = Notification.Name("CurrentTabIdentifierChanged")
}
