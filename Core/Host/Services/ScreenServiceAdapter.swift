import Foundation
import NotchKit

final class ScreenServiceAdapter: NSObject, NotchScreenHost {

    private let coordinator: BoringViewCoordinator
    private var observers: [(String) -> Void] = []
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
        lock.lock(); observers.append(handler); lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers.removeAll { ($0 as AnyObject) === (handler as AnyObject) }
            self.lock.unlock()
        }
    }

    @objc private func screenChanged() {
        let uuid = MainActor.assumeIsolated { coordinator.selectedScreenUUID }
        lock.lock(); let copy = observers; lock.unlock()
        copy.forEach { $0(uuid) }
    }
}
