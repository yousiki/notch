import AppKit
import CapsuleKit
import Defaults
import SwiftUI

@objc(CalendarExtension)
public final class CalendarExtension: NSObject, CapsuleExtension {

    @objc public static func make() -> CapsuleExtension { CalendarExtension() }

    @objc public var identifier: String { "moe.siki.Capsule.calendar" }
    @objc public var displayName: String { "Calendar" }

    @objc public func activate(host: CapsuleHost) {
        CalendarStateBridge.shared.configure(host: host)

        host.register(permission: CapsulePermissionRequest(
            kind: .calendar,
            rationale: "Show today's events on the notch."))

        host.register(permission: CapsulePermissionRequest(
            kind: .reminders,
            rationale: "Surface reminders alongside calendar events."))

        host.register(homeFragment: CapsuleHomeFragmentContribution(
            identifier: "moe.siki.Capsule.calendar.home-fragment",
            priority: 200,
            lifecyclePolicy: .preInstantiated,
            makeViewController: {
                NSHostingController(rootView: CalendarHomeFragmentView())
            }))

        host.register(settingsPane: CapsuleSettingsPaneContribution(
            identifier: "moe.siki.Capsule.calendar.settings",
            title: "Calendar",
            systemImage: "calendar",
            priority: 200,
            makeViewController: {
                NSHostingController(rootView: CalendarSettingsView())
            }))
    }
}

private struct CalendarHomeFragmentView: View {
    @Default(.showCalendar) private var showCalendar

    var body: some View {
        Group {
            if showCalendar {
                CalendarView()
                    .frame(width: 215)
                    .transition(.opacity)
            }
        }
    }
}
