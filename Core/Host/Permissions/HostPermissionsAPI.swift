import AVFoundation
import EventKit
import Foundation
import NotchKit

final class HostPermissionsAPI: NSObject, NotchPermissionsAPI {

    @objc func status(for permission: NotchPermissionKind) -> NotchPermissionStatus {
        switch permission {
        case .calendar:      return mapEK(EKEventStore.authorizationStatus(for: .event))
        case .reminders:     return mapEK(EKEventStore.authorizationStatus(for: .reminder))
        case .camera:        return mapAV(AVCaptureDevice.authorizationStatus(for: .video))
        case .microphone:    return mapAV(AVCaptureDevice.authorizationStatus(for: .audio))
        case .accessibility: return AXIsProcessTrusted() ? .granted : .notDetermined
        case .mediaLibrary:  return .unsupported
        case .fileShelf:     return .granted
        @unknown default:    return .unsupported
        }
    }

    @objc func request(_ permission: NotchPermissionKind,
                       completion: @escaping (NotchPermissionStatus) -> Void) {
        switch permission {
        case .calendar:
            EKEventStore().requestFullAccessToEvents { granted, _ in
                completion(granted ? .granted : .denied)
            }
        case .reminders:
            EKEventStore().requestFullAccessToReminders { granted, _ in
                completion(granted ? .granted : .denied)
            }
        case .camera:
            AVCaptureDevice.requestAccess(for: .video) { completion($0 ? .granted : .denied) }
        case .microphone:
            AVCaptureDevice.requestAccess(for: .audio) { completion($0 ? .granted : .denied) }
        case .accessibility:
            Task { @MainActor in
                let granted = await XPCHelperClient.shared.ensureAccessibilityAuthorization(promptIfNeeded: true)
                completion(granted ? .granted : .denied)
            }
        case .mediaLibrary, .fileShelf:
            completion(status(for: permission))
        @unknown default:
            completion(.unsupported)
        }
    }

    private func mapEK(_ s: EKAuthorizationStatus) -> NotchPermissionStatus {
        switch s {
        case .notDetermined: return .notDetermined
        case .fullAccess, .authorized: return .granted
        case .denied, .restricted, .writeOnly: return .denied
        @unknown default: return .notDetermined
        }
    }

    private func mapAV(_ s: AVAuthorizationStatus) -> NotchPermissionStatus {
        switch s {
        case .notDetermined: return .notDetermined
        case .authorized:    return .granted
        case .denied, .restricted: return .denied
        @unknown default: return .notDetermined
        }
    }
}
