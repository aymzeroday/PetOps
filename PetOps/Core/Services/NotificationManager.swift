import Foundation
import UserNotifications

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    func requestAuthorizationIfNeeded() async throws -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        @unknown default:
            return false
        }
    }

    func schedule(rule: ReminderRule) async throws {
        guard rule.enabled else {
            await cancel(ruleID: rule.idString)
            return
        }

        guard let request = try buildRequest(rule: rule) else { return }

        let center = UNUserNotificationCenter.current()
        await cancel(ruleID: rule.idString) // replace existing
        try await center.add(request)
    }

    func cancel(ruleID: String?) async {
        guard let ruleID else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [ruleID])
    }

    private func buildRequest(rule: ReminderRule) throws -> UNNotificationRequest? {
        guard let id = rule.idString else { return nil }
        guard let json = rule.scheduleJSON, !json.isEmpty else { return nil }

        let schedule = try ReminderSchedule.decode(json: json)

        var content = UNMutableNotificationContent()
        content.title = rule.title ?? "Reminder"
        if let body = rule.body, !body.isEmpty { content.body = body }
        content.sound = .default

        let trigger: UNNotificationTrigger

        switch schedule.kind {
        case .once:
            guard let date = schedule.fireDate else { return nil }
            let comps = Calendar.current.dateComponents([.year,.month,.day,.hour,.minute], from: date)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

        case .daily:
            let comps = DateComponents(hour: schedule.hour, minute: schedule.minute)
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        case .weekly:
            guard let weekday = schedule.weekday else { return nil }
            var comps = DateComponents()
            comps.weekday = weekday // 1=Sun ... 7=Sat
            comps.hour = schedule.hour
            comps.minute = schedule.minute
            trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        }

        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }
}

extension ReminderRule {
    var idString: String? {
        (id as UUID?)?.uuidString
    }
}
