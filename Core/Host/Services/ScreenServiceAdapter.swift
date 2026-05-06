import Foundation
import NotchKit

final class ScreenServiceAdapter: NSObject, NotchScreenHost {

    private let coordinator: CapsuleViewCoordinator
    private var observers: [UUID: (String) -> Void] = [:]
    private var cachedScreenUUID: String
    private let lock = NSLock()

    init(coordinator: CapsuleViewCoordinator) {
        self.coordinator = coordinator
        // Read once at init under MainActor (init is called from host start() on main).
        self.cachedScreenUUID = MainActor.assumeIsolated { coordinator.selectedScreenUUID }
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(screenChanged),
            name: .selectedScreenChanged, object: nil)
    }

    @objc var selectedScreenUUID: String {
        lock.lock(); defer { lock.unlock() }
        return cachedScreenUUID
    }

    @objc func observeSelectedScreen(_ handler: @escaping (String) -> Void) -> NotchObservation {
        let id = UUID()
        lock.lock(); observers[id] = handler; lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc private func screenChanged() {
        // Notification can fire on any thread; hop to MainActor to read the
        // @MainActor-isolated coordinator, then refresh the cached snapshot
        // and dispatch to observers.
        Task { @MainActor in
            let uuid = self.coordinator.selectedScreenUUID
            self.lock.lock()
            self.cachedScreenUUID = uuid
            let copy = Array(self.observers.values)
            self.lock.unlock()
            copy.forEach { $0(uuid) }
        }
    }
}
