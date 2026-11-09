import SwiftUI
import UIKit
import WidgetKit

// MARK: - Dữ liệu cho widget

struct DoiTaEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
    let image: UIImage?
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> DoiTaEntry {
        DoiTaEntry(date: Date(), snapshot: .placeholder, image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (DoiTaEntry) -> Void) {
        completion(load())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DoiTaEntry>) -> Void) {
        // Làm mới mỗi vài giờ để số ngày bên nhau luôn đúng.
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date().addingTimeInterval(21_600)
        completion(Timeline(entries: [load()], policy: .after(next)))
    }

    private func load() -> DoiTaEntry {
        let snapshot = WidgetSnapshot.load()
        var image: UIImage?
        if let url = WidgetShared.snapshotImageURL, let data = try? Data(contentsOf: url) {
            image = UIImage(data: data)
        }
        return DoiTaEntry(date: Date(), snapshot: snapshot, image: image)
    }
}

// MARK: - Giao diện

private enum WidgetTheme {
    static let accent = Color(red: 1.0, green: 0.36, blue: 0.5)
    static let gradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.42, blue: 0.55), Color(red: 1.0, green: 0.62, blue: 0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct DoiTaWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: Provider.Entry

    private var hasImage: Bool { entry.image != nil }

    var body: some View {
        content
            .containerBackground(for: .widget) { background }
    }

    @ViewBuilder
    private var background: some View {
        if let image = entry.image {
            ZStack {
                Image(uiImage: image).resizable().scaledToFill()
                LinearGradient(
                    colors: [.black.opacity(0.05), .black.opacity(0.65)],
                    startPoint: .top, endPoint: .bottom
                )
            }
        } else {
            WidgetTheme.gradient
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(alignment: .leading, spacing: 2) {
            Spacer(minLength: 0)

            if let days = entry.snapshot.daysTogether {
                Text("\(days)")
                    .font(.system(size: family == .systemSmall ? 40 : 48, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("ngày bên nhau 💕")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.95))
            } else {
                Text("💕").font(.system(size: 34))
                Text("Đặt ngày kỷ niệm trong Đôi Ta")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
            }

            if family != .systemSmall,
               let title = entry.snapshot.upcomingTitle,
               let date = entry.snapshot.upcomingDate {
                Spacer(minLength: 6)
                HStack(spacing: 5) {
                    Image(systemName: "calendar")
                    Text("\(title) · \(countdown(to: date))")
                        .lineLimit(1)
                }
                .font(.caption2.weight(.medium))
                .foregroundStyle(.white.opacity(0.95))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(.white.opacity(0.22), in: Capsule())
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        .shadow(color: hasImage ? .black.opacity(0.4) : .clear, radius: 3, y: 1)
    }

    private func countdown(to date: Date) -> String {
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
        if days > 0 { return "còn \(days) ngày" }
        if days == 0 { return "hôm nay!" }
        return "đã qua"
    }
}

// MARK: - Khai báo widget

struct DoiTaWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: WidgetShared.widgetKind, provider: Provider()) { entry in
            DoiTaWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("Đôi Ta")
        .description("Số ngày bên nhau và kỷ niệm của hai đứa.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct DoiTaWidgetBundle: WidgetBundle {
    var body: some Widget {
        DoiTaWidget()
    }
}
