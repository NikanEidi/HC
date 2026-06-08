import Foundation

struct WorkSession: Identifiable, Equatable {
    let id: UUID = UUID()
    var date: Date
    var startTime: Date
    var endTime: Date

    var durationMinutes: Int {
        let comps = Calendar.current.dateComponents([.minute], from: startTime, to: endTime)
        return max(0, comps.minute ?? 0)
    }

    var startTimeString: String {
        formatTime(startTime)
    }

    var endTimeString: String {
        formatTime(endTime)
    }

    var durationString: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        return "\(h):\(String(format: "%02d", m))"
    }

    private func formatTime(_ date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let h = comps.hour ?? 0
        let m = comps.minute ?? 0
        return "\(h):\(String(format: "%02d", m))"
    }
}
