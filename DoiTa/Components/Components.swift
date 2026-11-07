import ImageIO
import SwiftUI
import UIKit

// MARK: - Theme

enum Theme {
    static let accent = Color(red: 1.0, green: 0.36, blue: 0.5)
    static let accentSoft = accent.opacity(0.14)
    static let gradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.42, blue: 0.55), Color(red: 1.0, green: 0.62, blue: 0.45)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    static let card = Color(.secondarySystemGroupedBackground)
    static let background = Color(.systemGroupedBackground)
}

// MARK: - Tiện ích

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Date {
    private static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.dateStyle = .long
        f.timeStyle = .none
        return f
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let f = RelativeDateTimeFormatter()
        f.locale = Locale(identifier: "vi_VN")
        f.unitsStyle = .short
        return f
    }()

    var viLong: String { Self.longFormatter.string(from: self) }
    var viRelative: String { Self.relativeFormatter.localizedString(for: self, relativeTo: Date()) }
}

func appleMapsURL(for placeName: String) -> URL {
    var components = URLComponents(string: "https://maps.apple.com/")!
    components.queryItems = [URLQueryItem(name: "q", value: placeName)]
    return components.url ?? URL(string: "https://maps.apple.com/")!
}

// MARK: - Gợi ý ý tưởng

enum Ideas {
    static let goals = [
        "Cùng nhau tiết kiệm mua một món đồ chung",
        "Học nấu một món mới cùng nhau",
        "Chạy bộ / tập thể dục cùng nhau mỗi tuần",
        "Viết thư tay cho nhau",
        "Xem hết một bộ phim dài tập",
        "Chụp một bộ ảnh đôi"
    ]

    static let places = [
        "Ngắm hoàng hôn ở Hồ Tây",
        "Cà phê phố cổ Hà Nội",
        "Cuối tuần ở Đà Lạt",
        "Đà Nẵng – Hội An",
        "Picnic trong công viên",
        "Xem phim ở rạp",
        "Cắm trại / glamping",
        "Săn mây ở Sa Pa"
    ]

    static func suggestions(for kind: GoalKind) -> [String] {
        kind == .goal ? goals : places
    }
}

// MARK: - Avatar

struct Avatar: View {
    let name: String
    var size: CGFloat = 36

    private var initial: String {
        String(name.trimmed.first ?? "?").uppercased()
    }

    private var color: Color {
        let palette: [Color] = [.pink, .orange, .purple, .teal, .indigo, .mint]
        let sum = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return palette[sum % palette.count]
    }

    var body: some View {
        Text(initial)
            .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.gradient, in: Circle())
    }
}

// MARK: - Đếm ngược

struct CountdownBadge: View {
    let date: Date

    private var days: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }

    private var text: String {
        if days > 0 { return "Còn \(days) ngày" }
        if days == 0 { return "Hôm nay! 🎉" }
        return "Quá hạn \(-days) ngày"
    }

    private var color: Color { days < 0 ? Color.orange : Theme.accent }

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.15), in: Capsule())
            .foregroundStyle(color)
    }
}

// MARK: - Chọn cảm xúc

struct MoodPicker: View {
    @Binding var selection: Mood?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Mood.allCases) { mood in
                let selected = selection == mood
                Button {
                    selection = selected ? nil : mood
                } label: {
                    Text(mood.emoji)
                        .font(.title2)
                        .frame(width: 46, height: 46)
                        .background(selected ? Theme.accent.opacity(0.2) : Color(.tertiarySystemFill), in: Circle())
                        .overlay(Circle().stroke(selected ? Theme.accent : Color.clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(mood.label)
            }
        }
    }
}

// MARK: - Ảnh có cache

enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 150
        return c
    }()

    static func cached(_ key: String) -> UIImage? {
        cache.object(forKey: key as NSString)
    }

    static func store(_ image: UIImage, key: String) {
        cache.setObject(image, forKey: key as NSString)
    }

    /// Đọc ảnh từ file và thu nhỏ bằng ImageIO để không tốn RAM.
    static func downsample(url: URL, maxPixel: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
        let thumbOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions as CFDictionary) else { return nil }
        return UIImage(cgImage: cg)
    }

    static func load(url: URL, maxPixel: CGFloat) async -> UIImage? {
        let key = "\(url.path)#\(Int(maxPixel))"
        if let hit = cached(key) { return hit }
        let image = await Task.detached(priority: .userInitiated) {
            downsample(url: url, maxPixel: maxPixel)
        }.value
        if let image { store(image, key: key) }
        return image
    }
}

/// Ảnh tải từ file cache; người dùng tự đặt `.frame` + `.clipped()`.
struct CachedImage: View {
    let url: URL?
    var maxPixel: CGFloat = 600
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemFill)
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ProgressView()
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await ImageCache.load(url: url, maxPixel: maxPixel)
        }
    }
}

/// Lưới ảnh vuông 3 cột.
struct PhotoGrid: View {
    let memories: [Memory]
    var onTap: (Memory) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(memories) { memory in
                Color.clear
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(CachedImage(url: memory.imageURL, maxPixel: 400))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(memory) }
            }
        }
    }
}

// MARK: - Xem ảnh toàn màn hình

private struct FullImage: View {
    let url: URL?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ProgressView().tint(.white)
            }
        }
        .task(id: url) {
            guard let url else { return }
            image = await ImageCache.load(url: url, maxPixel: 2400)
        }
    }
}

struct PhotoViewer: View {
    let memories: [Memory]
    @State private var selection: String
    @State private var toast: String?
    @Environment(\.dismiss) private var dismiss

    init(memories: [Memory], startID: String) {
        self.memories = memories
        _selection = State(initialValue: startID)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            TabView(selection: $selection) {
                ForEach(memories) { memory in
                    FullImage(url: memory.imageURL).tag(memory.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .ignoresSafeArea()
        }
        .overlay(alignment: .top) {
            HStack {
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill").font(.title).symbolRenderingMode(.hierarchical)
                }
                Spacer()
                Button { saveCurrent() } label: {
                    Image(systemName: "square.and.arrow.down.fill").font(.title2)
                }
            }
            .foregroundStyle(.white)
            .padding()
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 40)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut, value: toast)
        .statusBarHidden()
    }

    private func saveCurrent() {
        guard let memory = memories.first(where: { $0.id == selection }),
              let url = memory.imageURL,
              let image = UIImage(contentsOfFile: url.path) else { return }
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        toast = "Đã lưu vào thư viện Ảnh 💕"
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            toast = nil
        }
    }
}

// MARK: - Camera

struct CameraPicker: UIViewControllerRepresentable {
    var onCapture: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker

        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Màn hình thông báo chung

struct MessageView: View {
    let icon: String
    let title: String
    let message: String
    var buttonTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 56))
                .foregroundStyle(Theme.gradient)
            Text(title).font(.title2.bold())
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            if let buttonTitle, let action {
                Button(buttonTitle, action: action)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}
