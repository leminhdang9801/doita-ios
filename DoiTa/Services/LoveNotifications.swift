import Foundation
import UserNotifications

/// Lên lịch local notification nhắc các cột mốc tình yêu (chạy được trên tài khoản free).
enum LoveNotifications {
    private static let prefix = "milestone-"

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let granted = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return granted ?? false
    }

    /// Xoá lịch cũ rồi đặt lại cho tối đa 6 cột mốc sắp tới, nhắc lúc 9h sáng.
    static func scheduleMilestones(from start: Date?) async {
        let center = UNUserNotificationCenter.current()

        let pending = await center.pendingNotificationRequests()
        let oldIDs = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: oldIDs)

        guard let start else { return }
        guard await requestAuthorization() else { return }

        let upcoming = Milestones.all(from: start).filter { !$0.isPast }.prefix(6)
        for milestone in upcoming {
            let content = UNMutableNotificationContent()
            content.title = "Đôi Ta 💕"
            content.body = "Hôm nay hai đứa đã bên nhau \(milestone.label) rồi \(milestone.emoji)"
            content.sound = .default

            var comps = Calendar.current.dateComponents([.year, .month, .day], from: milestone.date)
            comps.hour = 9
            comps.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: prefix + milestone.label,
                content: content,
                trigger: trigger
            )
            try? await center.add(request)
        }
    }
}
