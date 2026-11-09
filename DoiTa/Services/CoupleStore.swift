import CoreLocation
import SwiftUI
import UIKit

/// Đường dẫn lưu trữ cục bộ (Application Support).
enum LocalStorePaths {
    static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DoiTa", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    static let imagesDir: URL = {
        let dir = root.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let dataFile = root.appendingPathComponent("store.json")
}

/// Bản lưu trữ CỤC BỘ (một máy) — dùng cho tài khoản Apple ID free, chạy được trên Simulator.
/// Giữ nguyên tên `CoupleStore` và API để các màn hình không phải sửa.
/// Phần ghép đôi/CloudKit nằm ở nhánh `main`.
@MainActor
final class CoupleStore: ObservableObject {
    static let shared = CoupleStore()

    enum Phase: Equatable {
        case loading
        case noAccount
        case needsSetup
        case ready
        case failed(String)
    }

    // MARK: Trạng thái cho giao diện

    @Published private(set) var phase: Phase = .loading
    @Published private(set) var goals: [Goal] = []
    @Published private(set) var memories: [Memory] = []
    @Published private(set) var comments: [Comment] = []
    @Published private(set) var shareURL: URL? = nil
    @Published private(set) var isOwner = true
    @Published private(set) var partnerJoined = false
    @Published private(set) var partnerName: String? = nil
    @Published private(set) var isBusy = false
    @Published private(set) var space = CoupleSpace()
    @Published var errorMessage: String?
    @Published var showInvite = false

    @Published var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "displayName") }
    }

    var partnerDisplayName: String { partnerName ?? "Người ấy" }

    // Người dùng cục bộ luôn là "mình".
    private let localUserID = "me"

    // MARK: Số liệu dẫn xuất cho màn hình chính

    var daysTogether: Int? {
        guard let start = space.anniversaryDate else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: Date())).day ?? 0
        return max(0, days) + 1
    }

    var completedGoals: [Goal] { goals.filter(\.isCompleted) }
    var visitedPlaces: [Goal] { goals.filter { $0.kind == .place && $0.isCompleted } }

    var upcomingGoal: Goal? {
        goals
            .filter { !$0.isCompleted && $0.targetDate != nil }
            .min { ($0.targetDate ?? .distantFuture) < ($1.targetDate ?? .distantFuture) }
    }

    var nextMilestone: Milestone? {
        guard let start = space.anniversaryDate else { return nil }
        return Milestones.next(from: start)
    }

    var onThisDay: [Memory] {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        return memories.filter {
            let c = cal.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == today.month && c.day == today.day && c.year != cal.component(.year, from: Date())
        }
    }

    var memoryOfTheDay: Memory? {
        guard !memories.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return memories[day % memories.count]
    }

    // MARK: Khởi tạo & lưu trữ

    private struct Snapshot: Codable {
        var goals: [Goal] = []
        var memories: [Memory] = []
        var comments: [Comment] = []
        var space = CoupleSpace()
    }

    private init() {
        displayName = UserDefaults.standard.string(forKey: "displayName") ?? ""
    }

    func bootstrap() async {
        load()
        phase = .ready
    }

    private func load() {
        guard let data = try? Data(contentsOf: LocalStorePaths.dataFile),
              let snapshot = try? JSONDecoder.doita.decode(Snapshot.self, from: data) else {
            return
        }
        goals = snapshot.goals.sorted { $0.createdAt > $1.createdAt }
        memories = snapshot.memories.sorted { $0.createdAt < $1.createdAt }
        comments = snapshot.comments.sorted { $0.createdAt < $1.createdAt }
        space = snapshot.space
    }

    private func persist() {
        let snapshot = Snapshot(goals: goals, memories: memories, comments: comments, space: space)
        if let data = try? JSONEncoder.doita.encode(snapshot) {
            try? data.write(to: LocalStorePaths.dataFile, options: .atomic)
        }
    }

    // MARK: Không dùng ở bản local (giữ API cho tương thích)

    func createSpace() async { phase = .ready }
    func refresh() async {}
    func refreshQuietly() async {}

    func leaveSpace() async {
        goals = []
        memories = []
        comments = []
        space = CoupleSpace()
        try? FileManager.default.removeItem(at: LocalStorePaths.imagesDir)
        try? FileManager.default.createDirectory(at: LocalStorePaths.imagesDir, withIntermediateDirectories: true)
        persist()
    }

    // MARK: Truy vấn cho giao diện

    func memories(for goalID: String) -> [Memory] {
        memories.filter { $0.goalID == goalID }
    }

    func comments(for goalID: String) -> [Comment] {
        comments.filter { $0.goalID == goalID }
    }

    /// Một máy → mọi thứ là của "mình".
    func isMine(_ creatorID: String) -> Bool { true }

    // MARK: Mục tiêu / địa điểm

    @discardableResult
    func addGoal(title: String, note: String, kind: GoalKind, category: GoalCategory, placeName: String, targetDate: Date?) async -> Bool {
        let goal = Goal(
            title: title,
            note: note,
            kind: kind,
            category: category,
            placeName: kind == .place ? placeName : "",
            targetDate: targetDate,
            createdBy: displayName,
            creatorID: localUserID
        )
        goals.insert(goal, at: 0)
        persist()
        if kind == .place, !placeName.trimmed.isEmpty { await geocodePlaces() }
        return true
    }

    @discardableResult
    func updateGoal(id: String, title: String, note: String, kind: GoalKind, category: GoalCategory, placeName: String, targetDate: Date?) async -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == id }) else { return false }
        let oldPlace = goals[index].placeName
        goals[index].title = title
        goals[index].note = note
        goals[index].kind = kind
        goals[index].category = category
        goals[index].placeName = kind == .place ? placeName : ""
        goals[index].targetDate = targetDate
        if oldPlace != placeName {
            goals[index].latitude = nil
            goals[index].longitude = nil
        }
        persist()
        if kind == .place, !placeName.trimmed.isEmpty { await geocodePlaces() }
        return true
    }

    @discardableResult
    func deleteGoal(_ id: String) async -> Bool {
        // Xoá ảnh của mục này trên đĩa.
        for memory in memories.filter({ $0.goalID == id }) {
            if let url = memory.imageURL { try? FileManager.default.removeItem(at: url) }
        }
        goals.removeAll { $0.id == id }
        memories.removeAll { $0.goalID == id }
        comments.removeAll { $0.goalID == id }
        persist()
        return true
    }

    // MARK: Hoàn thành & kỷ niệm

    @discardableResult
    func saveMemory(goalID: String, images: [UIImage], mood: Mood?, text: String, coordinate: CLLocationCoordinate2D? = nil) async -> Bool {
        guard let index = goals.firstIndex(where: { $0.id == goalID }) else { return false }

        if !goals[index].isCompleted {
            goals[index].isCompleted = true
            goals[index].completedAt = Date()
        }
        if let coordinate, !goals[index].hasCoordinate {
            goals[index].latitude = coordinate.latitude
            goals[index].longitude = coordinate.longitude
        }

        for image in images {
            guard let data = Self.jpegData(from: image) else { continue }
            let name = UUID().uuidString + ".jpg"
            let url = LocalStorePaths.imagesDir.appendingPathComponent(name)
            guard (try? data.write(to: url, options: .atomic)) != nil else { continue }
            let memory = Memory(
                id: UUID().uuidString,
                goalID: goalID,
                imageFileName: name,
                createdBy: displayName,
                creatorID: localUserID,
                createdAt: Date()
            )
            memories.append(memory)
        }

        let trimmed = text.trimmed
        if !trimmed.isEmpty || mood != nil {
            comments.append(Comment(
                id: UUID().uuidString,
                goalID: goalID,
                text: trimmed,
                mood: mood,
                author: displayName,
                creatorID: localUserID,
                createdAt: Date()
            ))
        }

        persist()
        return true
    }

    @discardableResult
    func addComment(goalID: String, text: String, mood: Mood?) async -> Bool {
        let trimmed = text.trimmed
        guard !trimmed.isEmpty else { return false }
        comments.append(Comment(
            id: UUID().uuidString,
            goalID: goalID,
            text: trimmed,
            mood: mood,
            author: displayName,
            creatorID: localUserID,
            createdAt: Date()
        ))
        persist()
        return true
    }

    @discardableResult
    func deleteMemory(_ id: String) async -> Bool {
        if let memory = memories.first(where: { $0.id == id }), let url = memory.imageURL {
            try? FileManager.default.removeItem(at: url)
        }
        memories.removeAll { $0.id == id }
        persist()
        return true
    }

    // MARK: Thông tin chung của cặp đôi

    @discardableResult
    func updateSpace(anniversaryDate: Date?, coupleName: String) async -> Bool {
        space = CoupleSpace(anniversaryDate: anniversaryDate, coupleName: coupleName)
        persist()
        return true
    }

    @discardableResult
    func setAnniversary(_ date: Date?) async -> Bool {
        await updateSpace(anniversaryDate: date, coupleName: space.coupleName)
    }

    // MARK: Geocode địa điểm → tọa độ

    private var isGeocoding = false

    func geocodePlaces() async {
        guard !isGeocoding else { return }
        isGeocoding = true
        defer { isGeocoding = false }

        let pending = goals.filter { $0.kind == .place && !$0.hasCoordinate && !$0.placeName.trimmed.isEmpty }
        let geocoder = CLGeocoder()

        for goal in pending {
            guard let placemark = try? await geocoder.geocodeAddressString(goal.placeName).first,
                  let loc = placemark.location,
                  let index = goals.firstIndex(where: { $0.id == goal.id }) else { continue }
            goals[index].latitude = loc.coordinate.latitude
            goals[index].longitude = loc.coordinate.longitude
        }
        persist()
    }

    // MARK: Tiện ích

    static func jpegData(from image: UIImage, maxDimension: CGFloat = 2000) -> Data? {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > 0 else { return nil }
        let scale = min(1, maxDimension / longest)
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        return resized.jpegData(compressionQuality: 0.8)
    }
}

private extension JSONEncoder {
    static let doita: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

private extension JSONDecoder {
    static let doita: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
