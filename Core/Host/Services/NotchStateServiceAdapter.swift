import Combine
import Foundation
import CapsuleKit

/// Adapts a single `CapsuleViewModel` to the `CapsuleNotchStateHost` protocol.
final class NotchStateServiceAdapter: NSObject, CapsuleNotchStateHost {

    private let viewModel: CapsuleViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var notchStateHandlers: [UUID: (CapsuleOpenState) -> Void] = [:]
    private var hoverHandlers: [UUID: (Bool) -> Void] = [:]
    private let lock = NSLock()

    init(viewModel: CapsuleViewModel) {
        self.viewModel = viewModel
        super.init()

        viewModel.$notchState.sink { [weak self] state in
            guard let self else { return }
            let mapped: CapsuleOpenState = (state == .open ? .open : .closed)
            self.lock.lock()
            let handlers = Array(self.notchStateHandlers.values)
            self.lock.unlock()
            handlers.forEach { $0(mapped) }
        }.store(in: &cancellables)

        viewModel.$hovering.sink { [weak self] hovering in
            guard let self else { return }
            self.lock.lock()
            let handlers = Array(self.hoverHandlers.values)
            self.lock.unlock()
            handlers.forEach { $0(hovering) }
        }.store(in: &cancellables)
    }

    @objc var notchState: CapsuleOpenState {
        viewModel.notchState == .open ? .open : .closed
    }

    @objc var hovering: Bool { viewModel.hovering }

    @objc func observeNotchState(_ handler: @escaping (CapsuleOpenState) -> Void) -> CapsuleObservation {
        let id = UUID()
        lock.lock(); notchStateHandlers[id] = handler; lock.unlock()
        return CapsuleObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.notchStateHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> CapsuleObservation {
        let id = UUID()
        lock.lock(); hoverHandlers[id] = handler; lock.unlock()
        return CapsuleObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.hoverHandlers.removeValue(forKey: id)
            self.lock.unlock()
        }
    }

    @objc func open()  { Task { @MainActor in viewModel.open()  } }
    @objc func close() { Task { @MainActor in viewModel.close() } }
}
