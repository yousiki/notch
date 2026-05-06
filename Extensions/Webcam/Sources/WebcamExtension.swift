import AppKit
import CapsuleKit
import SwiftUI

@objc(WebcamExtension)
public final class WebcamExtension: NSObject, CapsuleExtension {

    @objc public static func make() -> CapsuleExtension { WebcamExtension() }

    @objc public var identifier: String { "moe.siki.Capsule.webcam" }
    @objc public var displayName: String { "Webcam" }

    @objc public func activate(host: CapsuleHost) {
        host.register(permission: CapsulePermissionRequest(
            kind: .camera,
            rationale: "Used for Capsule's mirror feature."))

        host.register(homeFragment: CapsuleHomeFragmentContribution(
            identifier: "moe.siki.Capsule.webcam.home-fragment",
            priority: 300,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: WebcamHomeFragmentView())
            }))
    }
}

private struct WebcamHomeFragmentView: View {
    @StateObject private var manager = WebcamManager.shared
    @State private var showMirror = UserDefaults.standard.bool(forKey: "showMirror")

    var body: some View {
        Group {
            if showMirror {
                CameraPreviewView(webcamManager: manager)
                    .scaledToFit()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)) { _ in
            showMirror = UserDefaults.standard.bool(forKey: "showMirror")
        }
    }
}
