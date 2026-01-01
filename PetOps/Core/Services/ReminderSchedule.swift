import Foundation

enum ReminderKind: String, Codable {
    case once
    case daily
    case weekly
}

struct ReminderSchedule: Codable {
    var kind: ReminderKind

    // once
    var fireDate: Date?

    // daily/weekly time
    var hour: Int
    var minute: Int

    // weekly only (1=Sun..7=Sat)
    var weekday: Int?

    static func decode(json: String) throws -> ReminderSchedule {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(ReminderSchedule.self, from: data)
    }

    func encode() throws -> String {
        let data = try JSONEncoder().encode(self)
        return String(decoding: data, as: UTF8.self)
    }

    func summaryText() -> String {
        switch kind {
        case .once:
            if let fireDate {
                return "Once • \(fireDate.formatted(date: .abbreviated, time: .shortened))"
            }
            return "Once"
        case .daily:
            return "Daily • \(String(format: "%02d:%02d", hour, minute))"
        case .weekly:
            let day = weekdayName(weekday)
            return "Weekly • \(day) • \(String(format: "%02d:%02d", hour, minute))"
        }
    }

    private func weekdayName(_ w: Int?) -> String {
        guard let w else { return "?" }
        let symbols = Calendar.current.weekdaySymbols // Sunday-first
        let idx = max(1, min(7, w)) - 1
        return symbols[idx]
    }
}
