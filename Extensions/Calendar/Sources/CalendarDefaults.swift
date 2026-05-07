import Defaults
import Foundation

enum CalendarSelectionState: Codable, Defaults.Serializable {
    case all
    case selected(Set<String>)
}

extension Defaults.Keys {
    static let showCalendar = Key<Bool>("showCalendar", default: false)
    static let hideCompletedReminders = Key<Bool>("hideCompletedReminders", default: true)
    static let calendarSelectionState = Key<CalendarSelectionState>("calendarSelectionState", default: .all)
    static let hideAllDayEvents = Key<Bool>("hideAllDayEvents", default: false)
    static let showFullEventTitles = Key<Bool>("showFullEventTitles", default: false)
    static let autoScrollToNextEvent = Key<Bool>("autoScrollToNextEvent", default: true)

    // Re-declared so the extension can read it without depending on host symbols.
    // Host owns the canonical declaration in Constants.swift; both resolve to the
    // same UserDefaults entry because the string identifier matches.
    static let enableHaptics = Key<Bool>("enableHaptics", default: true)
}
