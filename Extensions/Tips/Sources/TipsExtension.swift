import AppKit
import CapsuleKit
import SwiftUI

@objc(TipsExtension)
public final class TipsExtension: NSObject, CapsuleExtension {

    @objc public static func make() -> CapsuleExtension { TipsExtension() }

    @objc public var identifier: String { "moe.siki.Capsule.tips" }
    @objc public var displayName: String { "Tips" }

    @objc public func activate(host: CapsuleHost) {
        let factory: @convention(block) () -> NSViewController = {
            NSHostingController(rootView: TipsTabView())
        }

        host.register(tab: CapsuleTabContribution(
            identifier: "moe.siki.Capsule.tips.tab",
            title: "Tips",
            systemImage: "lightbulb",
            lifecyclePolicy: .onDemand,
            makeViewController: factory))
    }
}

// Minimal placeholder UI for Phase A. Real content is wired up in Phase C.
private struct TipsTabView: View {
    var body: some View {
        VStack {
            Image(systemName: "lightbulb.fill")
                .font(.system(size: 32))
            Text("Tips")
                .font(.headline)
            Text("Loaded from TipsExtension.notchext")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
