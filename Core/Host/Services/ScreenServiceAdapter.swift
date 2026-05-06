import Foundation
import NotchKit

final class ScreenServiceAdapter: NSObject, NotchScreenHost {

    private let coordinator: BoringViewCoordinator
    private var observers: [UUID: (String) -> Void] = [:]
    private let lock = NSLock()

    init(coordinator: BoringViewCoordinator) {
        self.coordinator = coordinator
        super.init()
        NotificationCenter.default.addObserver(self,
            selector: #selector(screenChanged),
            name: .selectedScreenChanged, object: nil)
    }

    @objc var selectedScreenUUID: String {
        MainActor.assumeIsolated { coordinator.selectedScreenUUID }
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
        let uuid = MainActor.assumeIsolated { coordinator.selectedScreenUUID }
        lock.lock(); let copy = Array(observers.values); lock.unlock()
        copy.forEach { $0(uuid) }
    }
}
