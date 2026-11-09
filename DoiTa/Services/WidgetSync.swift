import Foundation
import WidgetKit

/// App ghi dữ liệu ra App Group để widget đọc, rồi yêu cầu widget làm mới.
enum WidgetSync {
    static func write(daysTogether: Int?, upcomingTitle: String?, upcomingDate: Date?, memoryImageURL: URL?) {
        let d = WidgetShared.defaults
        set(d, WidgetShared.Key.daysTogether, daysTogether)
        set(d, WidgetShared.Key.upcomingTitle, upcomingTitle)
        set(d, WidgetShared.Key.upcomingDate, upcomingDate)

        // Sao chép ảnh kỷ niệm sang container dùng chung cho widget.
        if let memoryImageURL, let dest = WidgetShared.snapshotImageURL {
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: memoryImageURL, to: dest)
        }

        WidgetCenter.shared.reloadAllTimelines()
    }

    static func clear() {
        let d = WidgetShared.defaults
        [WidgetShared.Key.daysTogether, WidgetShared.Key.upcomingTitle, WidgetShared.Key.upcomingDate]
            .forEach { d?.removeObject(forKey: $0) }
        if let dest = WidgetShared.snapshotImageURL {
            try? FileManager.default.removeItem(at: dest)
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func set(_ defaults: UserDefaults?, _ key: String, _ value: Any?) {
        if let value {
            defaults?.set(value, forKey: key)
        } else {
            defaults?.removeObject(forKey: key)
        }
    }
}
