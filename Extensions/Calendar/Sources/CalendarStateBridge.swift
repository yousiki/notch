import CapsuleKit
import Foundation

final class CalendarStateBridge: ObservableObject {
    static let shared = CalendarStateBridge()

    @Published private(set) var notchState: CapsuleOpenState = .closed

    private var notchStateObservation: CapsuleObservation?

    private init() {}

    func configure(host: CapsuleHost) {
        guard let stateHost = host.service(of: "notch-state") as? CapsuleNotchStateHost else { return }
        let initial = stateHost.notchState
        DispatchQueue.main.async { [weak self] in
            self?.notchState = initial
        }
        notchStateObservation = stateHost.observeNotchState { [weak self] state in
            DispatchQueue.main.async {
                self?.notchState = state
            }
        }
    }
}
