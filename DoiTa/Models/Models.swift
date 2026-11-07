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
    var placeName: String
    var targetDate: Date?
    var isCompleted: Bool
    var completedAt: Date?
    var createdBy: String
    var creatorID: String
    var createdAt: Date

    init?(record: CKRecord) {
        guard record.recordType == Goal.recordType else { return nil }
        id = record.recordID.recordName
        title = record["title"] as? String ?? ""
        note = record["note"] as? String ?? ""
        kind = GoalKind(rawValue: record["kind"] as? String ?? "") ?? .goal
        placeName = record["placeName"] as? String ?? ""
        targetDate = record["targetDate"] as? Date
        isCompleted = (record["isCompleted"] as? Int ?? 0) == 1
        completedAt = record["completedAt"] as? Date
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
