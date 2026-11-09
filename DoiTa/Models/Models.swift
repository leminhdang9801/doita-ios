import CloudKit
import SwiftUI

// MARK: - Loại mục

enum GoalKind: String, CaseIterable, Identifiable {
    case goal
    case place

    var id: String { rawValue }

    var title: String {
        switch self {
        case .goal: return "Mục tiêu"
        case .place: return "Địa điểm"
        }
    }

    var icon: String {
        switch self {
        case .goal: return "flag.checkered"
        case .place: return "mappin.and.ellipse"
        }
    }
}

// MARK: - Phân loại

enum GoalCategory: String, CaseIterable, Identifiable {
    case travel, food, date, milestone, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .travel: return "Du lịch"
        case .food: return "Ăn uống"
        case .date: return "Hẹn hò"
        case .milestone: return "Cột mốc"
        case .other: return "Khác"
        }
    }

    var icon: String {
        switch self {
        case .travel: return "airplane"
        case .food: return "fork.knife"
        case .date: return "heart.fill"
        case .milestone: return "star.fill"
        case .other: return "sparkles"
        }
    }

    var color: Color {
        switch self {
        case .travel: return .blue
        case .food: return .orange
        case .date: return .pink
        case .milestone: return .purple
        case .other: return .teal
        }
    }
}

// MARK: - Cảm xúc

enum Mood: String, CaseIterable, Identifiable {
    case love, happy, silly, touched, calm

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .love: return "🥰"
        case .happy: return "😄"
        case .silly: return "🤪"
        case .touched: return "🥹"
        case .calm: return "😌"
        }
    }

    var label: String {
        switch self {
        case .love: return "Yêu thương"
        case .happy: return "Vui vẻ"
        case .silly: return "Nghịch ngợm"
        case .touched: return "Xúc động"
        case .calm: return "Bình yên"
        }
    }
}

// MARK: - Goal (mục tiêu / địa điểm)

struct Goal: Identifiable, Hashable {
    static let recordType = "Goal"

    let id: String
    var title: String
    var note: String
    var kind: GoalKind
    var category: GoalCategory
    var placeName: String
    var targetDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var latitude: Double?
    var longitude: Double?
    var createdBy: String
    var creatorID: String
    var createdAt: Date

    var hasCoordinate: Bool { latitude != nil && longitude != nil }

    init?(record: CKRecord) {
        guard record.recordType == Goal.recordType else { return nil }
        id = record.recordID.recordName
        title = record["title"] as? String ?? ""
        note = record["note"] as? String ?? ""
        kind = GoalKind(rawValue: record["kind"] as? String ?? "") ?? .goal
        category = GoalCategory(rawValue: record["category"] as? String ?? "") ?? .other
        placeName = record["placeName"] as? String ?? ""
        targetDate = record["targetDate"] as? Date
        isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        completedAt = record["completedAt"] as? Date
        latitude = record["latitude"] as? Double
        longitude = record["longitude"] as? Double
        createdBy = record["createdBy"] as? String ?? ""
        creatorID = record["creatorID"] as? String ?? ""
        createdAt = record.creationDate ?? Date()
    }
}

// MARK: - Memory (ảnh kỷ niệm)

struct Memory: Identifiable, Hashable {
    static let recordType = "Memory"

    let id: String
    let goalID: String
    let imageURL: URL?
    let createdBy: String
    let creatorID: String
    let createdAt: Date

    init?(record: CKRecord, imageURL: URL?) {
        guard record.recordType == Memory.recordType,
              let ref = record["goal"] as? CKRecord.Reference else { return nil }
        id = record.recordID.recordName
        goalID = ref.recordID.recordName
        self.imageURL = imageURL
        createdBy = record["createdBy"] as? String ?? ""
        creatorID = record["creatorID"] as? String ?? ""
        createdAt = record.creationDate ?? Date()
    }
}

// MARK: - Comment (cảm nhận)

struct Comment: Identifiable, Hashable {
    static let recordType = "Comment"

    let id: String
    let goalID: String
    let text: String
    let mood: Mood?
    let author: String
    let creatorID: String
    let createdAt: Date

    init?(record: CKRecord) {
        guard record.recordType == Comment.recordType,
              let ref = record["goal"] as? CKRecord.Reference else { return nil }
        id = record.recordID.recordName
        goalID = ref.recordID.recordName
        text = record["text"] as? String ?? ""
        mood = Mood(rawValue: record["mood"] as? String ?? "")
        author = record["author"] as? String ?? ""
        creatorID = record["creatorID"] as? String ?? ""
        createdAt = record.creationDate ?? Date()
    }
}

// MARK: - CoupleSpace (thông tin chung của hai người)

/// Lưu trong một record `Space` duy nhất (recordName cố định) trong zone,
/// nên cả hai người cùng thấy ngày kỷ niệm và tên cặp đôi.
struct CoupleSpace: Equatable {
    static let recordType = "Space"
    static let fixedName = "couple-space"

    var anniversaryDate: Date?
    var coupleName: String

    init(anniversaryDate: Date? = nil, coupleName: String = "") {
        self.anniversaryDate = anniversaryDate
        self.coupleName = coupleName
    }

    init(record: CKRecord) {
        anniversaryDate = record["anniversaryDate"] as? Date
        coupleName = record["coupleName"] as? String ?? ""
    }
}

// MARK: - Cột mốc tình yêu

struct Milestone: Identifiable, Hashable {
    let id = UUID()
    let label: String
    let date: Date
    let emoji: String

    var isPast: Bool { date < Calendar.current.startOfDay(for: Date()) }

    var daysAway: Int {
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: date)).day ?? 0
    }
}

enum Milestones {
    /// Các mốc ngày (100, 200, … 1000) và tròn năm (1–10 năm) tính từ ngày bắt đầu yêu.
    static func all(from start: Date) -> [Milestone] {
        let cal = Calendar.current
        let day0 = cal.startOfDay(for: start)
        var result: [Milestone] = []

        for n in stride(from: 100, through: 1000, by: 100) {
            if let d = cal.date(byAdding: .day, value: n, to: day0) {
                result.append(Milestone(label: "\(n) ngày", date: d, emoji: "💞"))
            }
        }
        for y in 1...10 {
            if let d = cal.date(byAdding: .year, value: y, to: day0) {
                result.append(Milestone(label: y == 1 ? "1 năm" : "\(y) năm", date: d, emoji: "🎂"))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    /// Mốc sắp tới gần nhất (chưa qua).
    static func next(from start: Date) -> Milestone? {
        all(from: start).first { !$0.isPast }
    }
}
