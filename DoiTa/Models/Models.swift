import Foundation
import SwiftUI

// MARK: - Loại mục

enum GoalKind: String, CaseIterable, Identifiable, Codable {
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

enum GoalCategory: String, CaseIterable, Identifiable, Codable {
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

enum Mood: String, CaseIterable, Identifiable, Codable {
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

struct Goal: Identifiable, Hashable, Codable {
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

    init(id: String = UUID().uuidString,
         title: String,
         note: String = "",
         kind: GoalKind = .goal,
         category: GoalCategory = .other,
         placeName: String = "",
         targetDate: Date? = nil,
         isCompleted: Bool = false,
         completedAt: Date? = nil,
         latitude: Double? = nil,
         longitude: Double? = nil,
         createdBy: String = "",
         creatorID: String = "",
         createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.note = note
        self.kind = kind
        self.category = category
        self.placeName = placeName
        self.targetDate = targetDate
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.latitude = latitude
        self.longitude = longitude
        self.createdBy = createdBy
        self.creatorID = creatorID
        self.createdAt = createdAt
    }
}

// MARK: - Memory (ảnh kỷ niệm)

struct Memory: Identifiable, Hashable, Codable {
    let id: String
    let goalID: String
    let imageFileName: String
    let createdBy: String
    let creatorID: String
    let createdAt: Date

    /// Ảnh được lưu trên máy; URL tính từ tên file.
    var imageURL: URL? {
        LocalStorePaths.imagesDir.appendingPathComponent(imageFileName)
    }
}

// MARK: - Comment (cảm nhận)

struct Comment: Identifiable, Hashable, Codable {
    let id: String
    let goalID: String
    let text: String
    let mood: Mood?
    let author: String
    let creatorID: String
    let createdAt: Date
}

// MARK: - CoupleSpace (thông tin chung của hai người)

struct CoupleSpace: Equatable, Codable {
    var anniversaryDate: Date?
    var coupleName: String

    init(anniversaryDate: Date? = nil, coupleName: String = "") {
        self.anniversaryDate = anniversaryDate
        self.coupleName = coupleName
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

    static func next(from start: Date) -> Milestone? {
        all(from: start).first { !$0.isPast }
    }
}
