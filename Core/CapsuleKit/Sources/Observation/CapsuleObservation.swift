import Foundation

@objc public final class CapsuleObservation: NSObject {
    private let cancelHandler: () -> Void
    private var cancelled = false
    private let lock = NSLock()

    public init(cancel: @escaping () -> Void) {
        self.cancelHandler = cancel
        super.init()
    }

    @objc public func cancel() {
        lock.lock()
        defer { lock.unlock() }
        guard !cancelled else { return }
        cancelled = true
        cancelHandler()
    }

    deinit { cancel() }
}
