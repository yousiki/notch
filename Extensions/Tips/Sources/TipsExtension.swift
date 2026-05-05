import AppKit
import NotchKit
import SwiftUI

@objc(TipsExtension)
public final class TipsExtension: NSObject, NotchExtension {

    @objc public static func make() -> NotchExtension { TipsExtension() }

    @objc public var identifier: String { "com.theboredteam.notch.tips" }
    @objc public var displayName: String { "Tips" }

    @objc public func activate(host: NotchHost) {
        let factory: @convention(block) () -> NSViewController = {
            NSHostingController(rootView: TipsTabView())
        }

        host.register(tab: NotchTabContribution(
            identifier: "com.theboredteam.notch.tips.tab",
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
