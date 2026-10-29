import Foundation
import UserNotifications

enum Notifications {
    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Schedules a one-off reminder. Returns the identifier, or nil when not permitted / in the past.
    static func schedule(title: String, body: String, at date: Date) async -> String? {
        guard date > Date(), await requestAuthorization() else { return nil }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let id = UUID().uuidString
        do {
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
            return id
        } catch {
            return nil
        }
    }

    static func cancel(_ id: String?) {
        guard let id else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }
}
