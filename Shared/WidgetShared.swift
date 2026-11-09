import Foundation

/// Hằng số & dữ liệu dùng chung giữa app và widget (qua App Group).
enum WidgetShared {
    static let appGroup = "group.com.danle.doita"
    static let widgetKind = "DoiTaWidget"

    enum Key {
        static let daysTogether = "daysTogether"
        static let upcomingTitle = "upcomingTitle"
        static let upcomingDate = "upcomingDate"
    }

    static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    static var containerURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)
    }

    /// Ảnh kỷ niệm mà app sao chép ra cho widget đọc.
    static var snapshotImageURL: URL? {
        containerURL?.appendingPathComponent("widget-photo.jpg")
    }
}

/// Dữ liệu widget đọc để hiển thị.
struct WidgetSnapshot {
    var daysTogether: Int?
    var upcomingTitle: String?
    var upcomingDate: Date?
    var hasImage: Bool

    static let placeholder = WidgetSnapshot(
        daysTogether: 365,
        upcomingTitle: "Đà Lạt cuối tuần",
        upcomingDate: Calendar.current.date(byAdding: .day, value: 12, to: Date()),
        hasImage: false
    )

    static func load() -> WidgetSnapshot {
        let d = WidgetShared.defaults
        let days = d?.object(forKey: WidgetShared.Key.daysTogether) as? Int
        let title = d?.string(forKey: WidgetShared.Key.upcomingTitle)
        let date = d?.object(forKey: WidgetShared.Key.upcomingDate) as? Date
        let hasImage = WidgetShared.snapshotImageURL.map {
            FileManager.default.fileExists(atPath: $0.path)
        } ?? false
        return WidgetSnapshot(daysTogether: days, upcomingTitle: title, upcomingDate: date, hasImage: hasImage)
    }
}
