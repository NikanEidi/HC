import Foundation
import Observation

@Observable
class TrackerViewModel {
    var sessions: [WorkSession] = []
    var selectedDates: Set<DateComponents> = []
    var currentMonth: Date = Date()
    var showingTimeInput: Bool = false

    private let calendar = Calendar.current

    // MARK: - Date Selection

    func toggleDate(_ date: Date) {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        if selectedDates.contains(comps) {
            selectedDates.remove(comps)
            sessions.removeAll {
                calendar.dateComponents([.year, .month, .day], from: $0.date) == comps
            }
        } else {
            selectedDates.insert(comps)
            let start = calendar.date(bySettingHour: 7, minute: 0, second: 0, of: date) ?? date
            let end = calendar.date(bySettingHour: 16, minute: 0, second: 0, of: date) ?? date
            sessions.append(WorkSession(date: date, startTime: start, endTime: end))
            sessions.sort { $0.date < $1.date }
        }
    }

    func isSelected(_ date: Date) -> Bool {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        return selectedDates.contains(comps)
    }

    func isWeekend(_ date: Date) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    // MARK: - Calculations

    func calculateDailyHours(for session: WorkSession) -> String {
        session.durationString
    }

    func calculateTotalHours() -> String {
        let total = sessions.reduce(0) { $0 + $1.durationMinutes }
        let h = total / 60
        let m = total % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    func generateReportString() -> String {
        guard !sessions.isEmpty else { return "" }
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "d MMM"

        var lines: [String] = []
        for session in sessions {
            let dateStr = dateFormatter.string(from: session.date)
            lines.append("\(dateStr): \(session.startTimeString) to \(session.endTimeString)")
            lines.append("Hour: \(session.durationString)")
        }
        lines.append("Total Hours: \(calculateTotalHours())")
        return lines.joined(separator: "\n")
    }

    // MARK: - Time Bindings

    func startMinutesBinding(for sessionID: UUID) -> (get: () -> Int, set: (Int) -> Void) {
        (
            get: {
                guard let session = self.sessions.first(where: { $0.id == sessionID }) else { return 420 }
                let comps = self.calendar.dateComponents([.hour, .minute], from: session.startTime)
                return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            },
            set: { newValue in
                guard let index = self.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
                let date = self.sessions[index].date
                if let newTime = self.calendar.date(bySettingHour: newValue / 60, minute: newValue % 60, second: 0, of: date) {
                    self.sessions[index].startTime = newTime
                }
            }
        )
    }

    func endMinutesBinding(for sessionID: UUID) -> (get: () -> Int, set: (Int) -> Void) {
        (
            get: {
                guard let session = self.sessions.first(where: { $0.id == sessionID }) else { return 960 }
                let comps = self.calendar.dateComponents([.hour, .minute], from: session.endTime)
                return (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
            },
            set: { newValue in
                guard let index = self.sessions.firstIndex(where: { $0.id == sessionID }) else { return }
                let date = self.sessions[index].date
                if let newTime = self.calendar.date(bySettingHour: newValue / 60, minute: newValue % 60, second: 0, of: date) {
                    self.sessions[index].endTime = newTime
                }
            }
        )
    }

    // MARK: - Calendar Navigation

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentMonth)
    }

    func previousMonth() {
        if let date = calendar.date(byAdding: .month, value: -1, to: currentMonth) {
            currentMonth = date
        }
    }

    func nextMonth() {
        if let date = calendar.date(byAdding: .month, value: 1, to: currentMonth) {
            currentMonth = date
        }
    }

    var daysInMonth: [Date?] {
        let comps = calendar.dateComponents([.year, .month], from: currentMonth)
        guard let firstDay = calendar.date(from: comps),
              let range = calendar.range(of: .day, in: .month, for: firstDay) else {
            return []
        }

        let firstWeekday = calendar.component(.weekday, from: firstDay)
        let offset = (firstWeekday + 5) % 7

        var days: [Date?] = Array(repeating: nil, count: offset)
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstDay) {
                days.append(date)
            }
        }

        while days.count % 7 != 0 {
            days.append(nil)
        }

        return days
    }
}
