import AppKit
import Combine
import Foundation
import NotchKit

/// Adapts a single `BoringViewModel` to the `NotchNotchStateHost` protocol.
final class NotchStateServiceAdapter: NSObject, NotchNotchStateHost {

    private let viewModel: BoringViewModel
    private var cancellables: Set<AnyCancellable> = []
    private var notchStateHandlers: [(NotchOpenState) -> Void] = []
    private var hoverHandlers: [(Bool) -> Void] = []
    private let lock = NSLock()

    init(viewModel: BoringViewModel) {
        self.viewModel = viewModel
        super.init()

        viewModel.$notchState.sink { [weak self] state in
            guard let self else { return }
            let mapped: NotchOpenState = (state == .open ? .open : .closed)
            self.lock.lock()
            let handlers = self.notchStateHandlers
            self.lock.unlock()
            handlers.forEach { $0(mapped) }
        }.store(in: &cancellables)

        viewModel.$hovering.sink { [weak self] hovering in
            guard let self else { return }
            self.lock.lock()
            let handlers = self.hoverHandlers
            self.lock.unlock()
            handlers.forEach { $0(hovering) }
        }.store(in: &cancellables)
    }

    @objc var notchState: NotchOpenState {
        viewModel.notchState == .open ? .open : .closed
    }

    @objc var hovering: Bool { viewModel.hovering }

    @objc func observeNotchState(_ handler: @escaping (NotchOpenState) -> Void) -> NotchObservation {
        lock.lock(); notchStateHandlers.append(handler); lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.notchStateHandlers.removeAll { ($0 as AnyObject) === (handler as AnyObject) }
            self.lock.unlock()
        }
    }

    @objc func observeHover(_ handler: @escaping (Bool) -> Void) -> NotchObservation {
        lock.lock(); hoverHandlers.append(handler); lock.unlock()
        return NotchObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.hoverHandlers.removeAll { ($0 as AnyObject) === (handler as AnyObject) }
            self.lock.unlock()
        }
    }

    @objc func open()  { Task { @MainActor in viewModel.open()  } }
    @objc func close() { Task { @MainActor in viewModel.close() } }
}
