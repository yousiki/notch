import AppKit
import CapsuleKit
import SwiftUI

@objc(BatteryExtension)
public final class BatteryExtension: NSObject, CapsuleExtension {

    @objc public static func make() -> CapsuleExtension { BatteryExtension() }

    @objc public var identifier: String { "moe.siki.Capsule.battery" }
    @objc public var displayName: String { "Battery" }

    @objc public func activate(host: CapsuleHost) {
        let coordinator = host.service(of: "coordinator") as? CapsuleCoordinatorHost
        BatteryStatusViewModel.shared.configure(coordinatorHost: coordinator)

        host.register(closedChinItem: CapsuleClosedChinContribution(
            identifier: "moe.siki.Capsule.battery.chin",
            side: .right,
            priority: 100,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: BatteryChinView())
            }))

        host.register(expandedItem: CapsuleExpandedItemContribution(
            kind: "battery",
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: BatteryExpandedNotificationView())
            }))
    }
}

private struct BatteryChinView: View {
    @StateObject private var model = BatteryStatusViewModel.shared

    var body: some View {
        CapsuleBatteryView(
            batteryWidth: 30,
            isCharging: model.isCharging,
            isInLowPowerMode: model.isInLowPowerMode,
            isPluggedIn: model.isPluggedIn,
            levelBattery: model.levelBattery,
            maxCapacity: model.maxCapacity,
            timeToFullCharge: model.timeToFullCharge,
            isForNotification: false
        )
    }
}

private struct BatteryExpandedNotificationView: View {
    @StateObject private var model = BatteryStatusViewModel.shared

    var body: some View {
        HStack(spacing: 0) {
            HStack {
                Text(model.statusText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
            }
            .frame(width: 172, alignment: .center)

            Rectangle()
                .fill(Color.black)
                .frame(maxWidth: .infinity)

            HStack {
                CapsuleBatteryView(
                    batteryWidth: 30,
                    isCharging: model.isCharging,
                    isInLowPowerMode: model.isInLowPowerMode,
                    isPluggedIn: model.isPluggedIn,
                    levelBattery: model.levelBattery,
                    maxCapacity: model.maxCapacity,
                    timeToFullCharge: model.timeToFullCharge,
                    isForNotification: true
                )
            }
            .frame(width: 76, alignment: .trailing)
        }
        .frame(width: 640)
        .foregroundColor(.white)
    }
}
