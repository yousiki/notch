import Foundation
import CapsuleKit

/// `UserDefaults`-backed settings store. Keys are *not* namespaced in v1 to
/// preserve existing user defaults across the refactor. v2 will introduce
/// extension-id prefixes via a migration step.
final class HostSettingsStore: NSObject, CapsuleSettingsStore {

    private let defaults = UserDefaults.standard
    private var observers: [String: Set<ObjectIdentifier>] = [:]
    private var observationCallbacks: [ObjectIdentifier: (Any?) -> Void] = [:]
    private let lock = NSLock()

    @objc override func setValue(_ value: Any?, forKey key: String) {
        defaults.set(value, forKey: key)
    }

    @objc override func value(forKey key: String) -> Any? {
        defaults.object(forKey: key)
    }

    @objc func observe(key: String,
                       handler: @escaping (Any?) -> Void) -> CapsuleObservation {
        let kvoToken = NSObject()
        let id = ObjectIdentifier(kvoToken)
        lock.lock()
        observers[key, default: []].insert(id)
        observationCallbacks[id] = handler
        lock.unlock()

        defaults.addObserver(self, forKeyPath: key, options: [.new], context: nil)

        return CapsuleObservation { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.observers[key]?.remove(id)
            self.observationCallbacks.removeValue(forKey: id)
            self.lock.unlock()
            self.defaults.removeObserver(self, forKeyPath: key)
        }
    }

    override func observeValue(forKeyPath keyPath: String?,
                               of object: Any?,
                               change: [NSKeyValueChangeKey : Any]?,
                               context: UnsafeMutableRawPointer?) {
        guard let keyPath else { return }
        let value = change?[.newKey]
        lock.lock()
        let ids = observers[keyPath] ?? []
        let callbacks = ids.compactMap { observationCallbacks[$0] }
        lock.unlock()
        callbacks.forEach { $0(value) }
    }
}
