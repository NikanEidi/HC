//
//  TrackerViewModel.swift
//  HC
//
//  ╔═══════════════════════════════════════════════════════════════╗
//  ║  The Brain — @Observable ViewModel driving the entire app.   ║
//  ║                                                               ║
//  ║  Responsibilities:                                            ║
//  ║    - Multi-date selection with Set<DateComponents>            ║
//  ║    - Session creation/removal linked to date toggles         ║
//  ║    - Time binding factories for slider two-way data flow     ║
//  ║    - Duration calculations (per-session & aggregate)         ║
//  ║    - Calendar navigation (month forward/back)                ║
//  ║    - Clipboard report string generation                       ║
//  ║    - Gesture-driven actions (air-tap, slider adjustment)     ║
//  ╚═══════════════════════════════════════════════════════════════╝
//

import Foundation
import Observation

/// Central state container for the HC work tracker.
/// Uses the Observation framework for fine-grained SwiftUI reactivity.
@Observable
class TrackerViewModel {

    // ── Published State ──

    /// All active work sessions, sorted chronologically.
    var sessions: [WorkSession] = []

    /// Set of selected dates (start of day) for O(1) lookup.
    var selectedDates: Set<Date> = []

    /// The currently displayed month in the calendar.
    var currentMonth: Date = Date()

    /// Controls the timesheet visibility (used by flip container).
    var showingTimeInput: Bool = false

    // ── Dependencies ──

    private let calendar = Calendar.current

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Date Selection
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Toggles a date's selection state. Selecting creates a new session
    /// with default 7:00-16:00 hours. Deselecting removes the session.
    func toggleDate(_ date: Date) {
        let dayStart = calendar.startOfDay(for: date)

        if selectedDates.contains(dayStart) {
            selectedDates.remove(dayStart)
            sessions.removeAll {
                calendar.startOfDay(for: $0.date) == dayStart
            }
        } else {
            selectedDates.insert(dayStart)
            let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: dayStart) ?? dayStart
            let end = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: dayStart) ?? dayStart
            sessions.append(WorkSession(date: dayStart, startTime: start, endTime: end))
            sessions.sort { $0.date < $1.date }
        }
    }

    /// Returns `true` if the given date is currently selected.
    func isSelected(_ date: Date) -> Bool {
        selectedDates.contains(calendar.startOfDay(for: date))
    }

    /// Returns `true` if the date falls on Saturday (7) or Sunday (1).
    func isWeekend(_ date: Date) -> Bool {
        let wd = calendar.component(.weekday, from: date)
        return wd == 1 || wd == 7
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Calculations
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Formatted duration string for a single session.
    func calculateDailyHours(for session: WorkSession) -> String {
        session.durationString
    }

    /// Aggregate total of all session durations, formatted as "H:MM".
    func calculateTotalHours() -> String {
        let total = sessions.reduce(0) { $0 + $1.durationMinutes }
        return "\(total / 60):\(String(format: "%02d", total % 60))"
    }

    /// Generates a plain-text clipboard report matching the required format:
    /// ```
    /// 8 Jun: 7:00 to 16:00
    /// Hour: 9:00
    /// Total Hours: 9:00
    /// ```
    func generateReportString() -> String {
        guard !sessions.isEmpty else { return "" }
        let df = DateFormatter()
        df.dateFormat = "d MMM"

        var out: [String] = []
        for s in sessions {
            out.append("\(df.string(from: s.date)): \(s.startTimeString) to \(s.endTimeString)")
            out.append("Hour: \(s.durationString)")
        }
        out.append("Total Hours: \(calculateTotalHours())")
        return out.joined(separator: "\n")
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Time Binding Factories
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Creates a get/set pair for the start time of a session (in minutes since midnight).
    /// Used by NeonTimeSlider to provide two-way binding without @Binding limitations.
    func startMinutesBinding(for id: UUID) -> (get: () -> Int, set: (Int) -> Void) {
        (
            get: {
                guard let s = self.sessions.first(where: { $0.id == id }) else { return 420 }
                let c = self.calendar.dateComponents([.hour, .minute], from: s.startTime)
                return (c.hour ?? 0) * 60 + (c.minute ?? 0)
            },
            set: { val in
                guard let idx = self.sessions.firstIndex(where: { $0.id == id }) else { return }
                if let t = self.calendar.date(bySettingHour: val / 60, minute: val % 60, second: 0,
                                              of: self.sessions[idx].date) {
                    self.sessions[idx].startTime = t
                }
            }
        )
    }

    /// Creates a get/set pair for the end time of a session (in minutes since midnight).
    func endMinutesBinding(for id: UUID) -> (get: () -> Int, set: (Int) -> Void) {
        (
            get: {
                guard let s = self.sessions.first(where: { $0.id == id }) else { return 960 }
                let c = self.calendar.dateComponents([.hour, .minute], from: s.endTime)
                return (c.hour ?? 0) * 60 + (c.minute ?? 0)
            },
            set: { val in
                guard let idx = self.sessions.firstIndex(where: { $0.id == id }) else { return }
                if let t = self.calendar.date(bySettingHour: val / 60, minute: val % 60, second: 0,
                                              of: self.sessions[idx].date) {
                    self.sessions[idx].endTime = t
                }
            }
        )
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Calendar Navigation
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Display string for the current month header (e.g. "June 2026").
    var monthYearString: String {
        let f = DateFormatter(); f.dateFormat = "MMMM yyyy"
        return f.string(from: currentMonth)
    }

    /// Navigates the calendar one month backward.
    func previousMonth() {
        if let d = calendar.date(byAdding: .month, value: -1, to: currentMonth) { currentMonth = d }
    }

    /// Navigates the calendar one month forward.
    func nextMonth() {
        if let d = calendar.date(byAdding: .month, value: 1, to: currentMonth) { currentMonth = d }
    }

    /// Computes the day grid for the current month.
    /// Returns `nil` entries for leading/trailing blank cells to align the grid.
    var daysInMonth: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let first = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: first) else { return [] }

        let offset = (calendar.component(.weekday, from: first) + 5) % 7
        var days: [Date?] = Array(repeating: nil, count: offset)

        for d in range {
            if let date = calendar.date(byAdding: .day, value: d - 1, to: first) { days.append(date) }
        }
        while days.count % 7 != 0 { days.append(nil) }
        return days
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // MARK: - Gesture-Driven Actions
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Returns the date at a given grid index (used for air-tap hit testing).
    func dateForGridIndex(_ index: Int) -> Date? {
        let days = daysInMonth
        guard index >= 0, index < days.count else { return nil }
        return days[index]
    }

    /// Adjusts a session's start or end time by a delta in minutes, snapped to 15-min intervals.
    func adjustSliderMinutes(sessionIndex: Int, isStartTime: Bool, delta: Int) {
        guard sessionIndex >= 0, sessionIndex < sessions.count else { return }
        let step = 15
        if isStartTime {
            let c = calendar.dateComponents([.hour, .minute], from: sessions[sessionIndex].startTime)
            let cur = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            let snapped = max(0, min(1440, ((cur + delta) / step) * step))
            if let t = calendar.date(bySettingHour: snapped / 60, minute: snapped % 60, second: 0,
                                      of: sessions[sessionIndex].date) {
                sessions[sessionIndex].startTime = t
            }
        } else {
            let c = calendar.dateComponents([.hour, .minute], from: sessions[sessionIndex].endTime)
            let cur = (c.hour ?? 0) * 60 + (c.minute ?? 0)
            let snapped = max(0, min(1440, ((cur + delta) / step) * step))
            if let t = calendar.date(bySettingHour: snapped / 60, minute: snapped % 60, second: 0,
                                      of: sessions[sessionIndex].date) {
                sessions[sessionIndex].endTime = t
            }
        }
    }
}
