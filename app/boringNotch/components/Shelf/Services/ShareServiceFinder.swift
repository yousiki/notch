//
//  ShareServiceFinder.swift
//  boringNotch
//
//  Created by Alexander on 2025-10-06.
//

import Cocoa

extension NSSharingService: @unchecked Sendable {}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var didResume = false

    func tryClaim() -> Bool {
        lock.lock()
        defer { lock.unlock() }

        guard !didResume else { return false }
        didResume = true
        return true
    }
}

final class ShareServiceFinder: NSObject, NSSharingServicePickerDelegate, @unchecked Sendable {

    @MainActor
    private var onServicesCaptured: (@Sendable ([NSSharingService]) -> Void)?

    /// Returns share services asynchronously without blocking the UI
    @MainActor
    func findApplicableServices(for items: [Any], timeout: TimeInterval = 2.0) async -> [NSSharingService] {

        let dummyView = NSView(frame: .zero)
        let picker = NSSharingServicePicker(items: items)
        picker.delegate = self

        return await withCheckedContinuation { continuation in
            let gate = ContinuationGate()

            // Capture services callback
            self.onServicesCaptured = { services in
                guard gate.tryClaim() else { return }
                continuation.resume(returning: services)
            }

            picker.show(relativeTo: dummyView.bounds, of: dummyView, preferredEdge: .minY)

            // Timeout task
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(timeout))
                guard gate.tryClaim() else { return }
                print("Warning: timed out waiting for sharing services")
                continuation.resume(returning: [])
            }
        }
    }

    // MARK: NSSharingServicePickerDelegate

    func sharingServicePicker(
        _ picker: NSSharingServicePicker,
        sharingServicesForItems items: [Any],
        proposedSharingServices proposed: [NSSharingService]
    ) -> [NSSharingService] {
        Task { @MainActor in
            self.onServicesCaptured?(proposed)
        }
        return proposed
    }
}
