import Foundation
import UserNotifications

@MainActor
final class ExpiryNotificationManager {
    static let shared = ExpiryNotificationManager()
    private let center = UNUserNotificationCenter.current()

    func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .badge, .sound])
    }

    func schedule(for items: [InventoryItem]) {
        center.removePendingNotificationRequests(withIdentifiers: items.map { "expiry-\($0.id.uuidString)" })
        let calendar = Calendar.current
        for item in items {
            guard let date = item.expiryDate,
                  let reminder = calendar.date(byAdding: .day, value: -1, to: date), reminder > .now else { continue }
            var components = calendar.dateComponents([.year, .month, .day], from: reminder)
            components.hour = 9
            let content = UNMutableNotificationContent()
            content.title = "À utiliser bientôt"
            content.body = "\(item.name) arrive à sa date limite demain."
            content.sound = .default
            let request = UNNotificationRequest(identifier: "expiry-\(item.id.uuidString)", content: content, trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false))
            center.add(request)
        }
    }
}
