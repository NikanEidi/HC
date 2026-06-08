//
//  WorkSession.swift
//  HC
//
//  Core data model representing a single work session entry.
//  Each session captures a date with start/end times and computes
//  duration metrics used by the ViewModel and terminal output.
//
//  Architecture: Pure value type, no dependencies. Conforms to
//  Identifiable for SwiftUI lists and Equatable for onChange detection.
//

import Foundation

/// A single work session entry with date, time range, and computed duration.
struct WorkSession: Identifiable, Equatable {

    /// Unique identifier for SwiftUI list diffing and session lookup.
    let id: UUID = UUID()

    /// The calendar date this session belongs to (day-level precision).
    var date: Date

    /// Clock-in time for this session.
    var startTime: Date

    /// Clock-out time for this session.
    var endTime: Date

    // MARK: - Computed Properties

    /// Total duration in minutes. Clamped to zero to prevent negative values
    /// when endTime precedes startTime during slider adjustment.
    var durationMinutes: Int {
        let components = Calendar.current.dateComponents([.minute], from: startTime, to: endTime)
        return max(0, components.minute ?? 0)
    }

    /// Human-readable start time in "H:MM" format (e.g. "7:00", "14:30").
    var startTimeString: String {
        formatTime(startTime)
    }

    /// Human-readable end time in "H:MM" format.
    var endTimeString: String {
        formatTime(endTime)
    }

    /// Duration formatted as "H:MM" (e.g. "9:00", "10:30").
    var durationString: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    // MARK: - Private Helpers

    /// Extracts hour and minute from a Date and formats as "H:MM".
    /// Uses 24-hour format without leading zero on hours.
    private func formatTime(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return "\(h):\(String(format: "%02d", m))"
    }
}
