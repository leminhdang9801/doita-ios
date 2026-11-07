import CloudKit
import SwiftUI
import UIKit

/// Toàn bộ logic CloudKit của app:
/// - Người tạo: dùng private database, tạo record zone `CoupleZone` rồi chia sẻ cả zone (CKShare).
/// - Người được mời: nhận link → zone xuất hiện trong shared database.
/// - Đồng bộ bằng `recordZoneChanges` (không cần tạo index "queryable" trong CloudKit Console).
@MainActor
final class CoupleStore: ObservableObject {
    static let shared = CoupleStore()

    /// Nếu đổi tên container: sửa ở đây, trong `Config/DoiTa.entitlements` và `project.yml`.
    static let containerID = "iCloud.com.danle.doita"
    static let zoneName = "CoupleZone"

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
    @Published private(set) var shareURL: URL?
    @Published private(set) var isOwner = true
    @Published private(set) var partnerJoined = false
    @Published private(set) var partnerName: String?
    @Published private(set) var isBusy = false
    @Published var errorMessage: String?
    @Published var showInvite = false

    @Published var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "displayName") }
    }

    var partnerDisplayName: String { partnerName ?? "Người ấy" }

    // MARK: Nội bộ

    private let container: CKContainer
    private var database: CKDatabase
    private var zoneID: CKRecordZone.ID?
    private var records: [CKRecord.ID: CKRecord] = [:]
    private var changeToken: CKServerChangeToken?
    private var myUserID: String?

    static let imageCacheDir: URL = {
        let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("memories", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() {
        let c = CKContainer(identifier: Self.containerID)
        container = c
        database = c.privateCloudDatabase
        displayName = UserDefaults.standard.string(forKey: "displayName") ?? ""
    }

    // MARK: - Khởi động

    func bootstrap() async {
        if phase != .ready { phase = .loading }
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                phase = .noAccount
                return
            }
            myUserID = try await container.userRecordID().recordName

            // 1. Đã tham gia không gian của người ấy chưa? (shared database)
            let sharedZones = try await container.sharedCloudDatabase.allRecordZones()
            if let zone = sharedZones.first(where: { $0.zoneID.zoneName == Self.zoneName }) {
                database = container.sharedCloudDatabase
                zoneID = zone.zoneID
                isOwner = false
                partnerJoined = true
            } else {
                // 2. Hoặc mình là người tạo không gian? (private database)
                let zones = try await container.privateCloudDatabase.allRecordZones()
                guard let zone = zones.first(where: { $0.zoneID.zoneName == Self.zoneName }) else {
                    resetLocal()
                    phase = .needsSetup
                    return
                }
                database = container.privateCloudDatabase
                zoneID = zone.zoneID
                isOwner = true
            }

            try await syncOnce()
            phase = .ready
        } catch {
            phase = .failed(Self.describe(error))
        }
    }

    // MARK: - Tạo không gian & mời

    func createSpace() async {
        isBusy = true
        defer { isBusy = false }
        do {
            if myUserID == nil { myUserID = try await container.userRecordID().recordName }

            let zone = CKRecordZone(zoneName: Self.zoneName)
            _ = try await container.privateCloudDatabase.save(zone)
            database = container.privateCloudDatabase
            zoneID = zone.zoneID
            isOwner = true

            // Chia sẻ cả zone; ai có link đều tham gia được (đọc + ghi).
            let share = CKShare(recordZoneID: zone.zoneID)
            share[CKShare.SystemFieldKey.title] = "Không gian của hai ta 💕"
            share.publicPermission = .readWrite
            let result = try await database.modifyRecords(saving: [share], deleting: [])
            if case .success(let saved)? = result.saveResults[share.recordID],
               let savedShare = saved as? CKShare {
                shareURL = savedShare.url
            }

            try await syncOnce()
            phase = .ready
            showInvite = true
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    /// Gọi khi người dùng bấm link mời (SceneDelegate).
    func accept(_ metadata: CKShare.Metadata) async {
        if phase == .ready, zoneID != nil {
            errorMessage = "Bạn đang ở trong một không gian chung. Hãy rời không gian hiện tại (Cài đặt) trước khi tham gia không gian mới."
            return
        }
        isBusy = true
        defer { isBusy = false }
        do {
            _ = try await container.accept(metadata)
            await bootstrap()
        } catch {
            errorMessage = Self.describe(error)
        }
    }

    func leaveSpace() async {
        guard let zoneID else { return }
        _ = await perform {
            _ = try await database.deleteRecordZone(withID: zoneID)
            resetLocal()
            phase = .needsSetup
        }
    }

    // MARK: - Đồng bộ

    /// Kéo-để-làm-mới: hiện lỗi nếu có.
    func refresh() async {
        guard phase == .ready else { return }
        do {
            try await syncOnce()
        } catch {
            handleSyncError(error, silent: false)
        }
    }

    /// Làm mới âm thầm (khi mở lại app, định kỳ).
    func refreshQuietly() async {
        guard phase == .ready else { return }
        do {
            try await syncOnce()
        } catch {
            handleSyncError(error, silent: true)
        }
    }

    private func handleSyncError(_ error: Error, silent: Bool) {
        if let ck = error as? CKError, ck.code == .zoneNotFound || ck.code == .userDeletedZone {
            resetLocal()
            phase = .needsSetup
            errorMessage = "Không gian chung không còn nữa (có thể người ấy đã rời đi)."
        } else if !silent {
            errorMessage = Self.describe(error)
        }
    }

    private func syncOnce() async throws {
        do {
            try await fetchChanges()
        } catch let e as CKError where e.code == .changeTokenExpired {
            changeToken = nil
            records = [:]
            try await fetchChanges()
        }
        if isOwner { await loadShare() }
        rebuild()
    }

    private func fetchChanges() async throws {
        guard let zoneID else { return }
        var more = true
        while more {
            let result = try await database.recordZoneChanges(inZoneWith: zoneID, since: changeToken)
            for (_, modification) in result.modificationResultsByID {
                if case .success(let m) = modification {
                    records[m.record.recordID] = m.record
                }
            }
            for deletion in result.deletions {
                records[deletion.recordID] = nil
            }
            changeToken = result.changeToken
            more = result.moreComing
        }
    }

    private func loadShare() async {
        guard let zoneID else { return }
        let shareID = CKRecord.ID(recordName: CKRecordNameZoneWideShare, zoneID: zoneID)
        guard let record = try? await database.record(for: shareID), let share = record as? CKShare else { return }
        shareURL = share.url
        partnerJoined = share.participants.contains {
            $0.role != .owner && $0.acceptanceStatus == .accepted
        }
    }

    private func rebuild() {
        let all = Array(records.values)

        goals = all.compactMap { Goal(record: $0) }
            .sorted { $0.createdAt > $1.createdAt }

        memories = all.compactMap { record -> Memory? in
            guard record.recordType == Memory.recordType else { return nil }
            return Memory(record: record, imageURL: cachedImageURL(for: record))
        }
        .sorted { $0.createdAt < $1.createdAt }

        comments = all.compactMap { Comment(record: $0) }
            .sorted { $0.createdAt < $1.createdAt }

        // Tên người ấy: lấy từ những thứ họ đã tạo.
        let theirNames = all.compactMap { record -> String? in
            guard let cid = record["creatorID"] as? String, !cid.isEmpty, cid != myUserID else { return nil }
            let name = (record["createdBy"] as? String) ?? (record["author"] as? String)
            return (name?.isEmpty == false) ? name : nil
        }
        partnerName = theirNames.first
        if partnerName != nil { partnerJoined = true }
    }

    private func cachedImageURL(for record: CKRecord) -> URL? {
        let dest = Self.imageCacheDir.appendingPathComponent(record.recordID.recordName + ".jpg")
        if FileManager.default.fileExists(atPath: dest.path) { return dest }
        guard let asset = record["image"] as? CKAsset, let src = asset.fileURL else { return nil }
        try? FileManager.default.copyItem(at: src, to: dest)
        return FileManager.default.fileExists(atPath: dest.path) ? dest : nil
    }

    private func resetLocal() {
        database = container.privateCloudDatabase
        zoneID = nil
        records = [:]
        changeToken = nil
        goals = []
        memories = []
        comments = []
        shareURL = nil
        partnerJoined = false
        partnerName = nil
        isOwner = true
        try? FileManager.default.removeItem(at: Self.imageCacheDir)
        try? FileManager.default.createDirectory(at: Self.imageCacheDir, withIntermediateDirectories: true)
    }

    // MARK: - Truy vấn cho giao diện

    func memories(for goalID: String) -> [Memory] {
        memories.filter { $0.goalID == goalID }
    }

    func comments(for goalID: String) -> [Comment] {
        comments.filter { $0.goalID == goalID }
    }

    func isMine(_ creatorID: String) -> Bool {
        guard let myUserID else { return false }
        return creatorID == myUserID
    }

    // MARK: - Mục tiêu / địa điểm

    @discardableResult
    func addGoal(title: String, note: String, kind: GoalKind, placeName: String, targetDate: Date?) async -> Bool {
        await perform {
            guard let record = newRecord(Goal.recordType) else { return }
            record["title"] = title
            record["note"] = note
            record["kind"] = kind.rawValue
            record["placeName"] = kind == .place ? placeName : ""
            record["targetDate"] = targetDate
            record["isCompleted"] = 0
            record["createdBy"] = displayName
            record["creatorID"] = myUserID ?? ""
            try await save([record])
        }
    }

    @discardableResult
    func updateGoal(id: String, title: String, note: String, kind: GoalKind, placeName: String, targetDate: Date?) async -> Bool {
        await perform {
            guard let record = existingRecord(id) else { return }
            record["title"] = title
            record["note"] = note
            record["kind"] = kind.rawValue
            record["placeName"] = kind == .place ? placeName : ""
            record["targetDate"] = targetDate
            try await save([record])
        }
    }

    @discardableResult
    func deleteGoal(_ id: String) async -> Bool {
        await perform {
            guard let recordID = recordID(for: id) else { return }
            // Memory và Comment tham chiếu goal với action .deleteSelf nên server tự xoá theo.
            try await save([], deleting: [recordID])
            try await syncOnce()
        }
    }

    // MARK: - Hoàn thành & kỷ niệm

    /// Lưu ảnh + cảm nhận cho một mục; nếu mục chưa xong thì đánh dấu hoàn thành.
    @discardableResult
    func saveMemory(goalID: String, images: [UIImage], mood: Mood?, text: String) async -> Bool {
        await perform {
            guard let goalRecord = existingRecord(goalID) else { return }
            var toSave: [CKRecord] = []

            if (goalRecord["isCompleted"] as? Int ?? 0) != 1 {
                goalRecord["isCompleted"] = 1
                goalRecord["completedAt"] = Date()
                toSave.append(goalRecord)
            }

            let reference = CKRecord.Reference(recordID: goalRecord.recordID, action: .deleteSelf)

            for image in images {
                guard let data = Self.jpegData(from: image),
                      let record = newRecord(Memory.recordType) else { continue }
                let fileURL = Self.imageCacheDir.appendingPathComponent(record.recordID.recordName + ".jpg")
                try data.write(to: fileURL, options: .atomic)
                record["goal"] = reference
                record["image"] = CKAsset(fileURL: fileURL)
                record["createdBy"] = displayName
                record["creatorID"] = myUserID ?? ""
                toSave.append(record)
            }

            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty || mood != nil, let record = newRecord(Comment.recordType) {
                record["goal"] = reference
                record["text"] = trimmed
                record["mood"] = mood?.rawValue
                record["author"] = displayName
                record["creatorID"] = myUserID ?? ""
                toSave.append(record)
            }

            guard !toSave.isEmpty else { return }
            try await save(toSave)
        }
    }

    @discardableResult
    func addComment(goalID: String, text: String, mood: Mood?) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return await perform {
            guard let goalRecord = existingRecord(goalID), let record = newRecord(Comment.recordType) else { return }
            record["goal"] = CKRecord.Reference(recordID: goalRecord.recordID, action: .deleteSelf)
            record["text"] = trimmed
            record["mood"] = mood?.rawValue
            record["author"] = displayName
            record["creatorID"] = myUserID ?? ""
            try await save([record])
        }
    }

    @discardableResult
    func deleteMemory(_ id: String) async -> Bool {
        await perform {
            guard let recordID = recordID(for: id) else { return }
            try await save([], deleting: [recordID])
            try? FileManager.default.removeItem(at: Self.imageCacheDir.appendingPathComponent(id + ".jpg"))
        }
    }

    // MARK: - Tiện ích

    private func recordID(for name: String) -> CKRecord.ID? {
        guard let zoneID else { return nil }
        return CKRecord.ID(recordName: name, zoneID: zoneID)
    }

    private func existingRecord(_ name: String) -> CKRecord? {
        guard let id = recordID(for: name) else { return nil }
        return records[id]
    }

    private func newRecord(_ type: String) -> CKRecord? {
        guard let zoneID else { return nil }
        return CKRecord(recordType: type, recordID: CKRecord.ID(recordName: UUID().uuidString, zoneID: zoneID))
    }

    private func save(_ toSave: [CKRecord], deleting: [CKRecord.ID] = []) async throws {
        let result = try await database.modifyRecords(saving: toSave, deleting: deleting, savePolicy: .changedKeys)
        for (id, outcome) in result.saveResults {
            switch outcome {
            case .success(let record): records[id] = record
            case .failure(let error): throw error
            }
        }
        for (id, outcome) in result.deleteResults {
            switch outcome {
            case .success: records[id] = nil
            case .failure(let error): throw error
            }
        }
        rebuild()
    }

    private func perform(_ work: () async throws -> Void) async -> Bool {
        isBusy = true
        defer { isBusy = false }
        do {
            try await work()
            return true
        } catch {
            errorMessage = Self.describe(error)
            return false
        }
    }

    /// Thu nhỏ ảnh (cạnh dài tối đa 2000px) và nén JPEG để tiết kiệm dung lượng iCloud.
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

    static func describe(_ error: Error) -> String {
        if let ck = error as? CKError {
            switch ck.code {
            case .notAuthenticated:
                return "Bạn chưa đăng nhập iCloud. Hãy đăng nhập trong Cài đặt của iPhone rồi thử lại."
            case .networkUnavailable, .networkFailure:
                return "Không có kết nối mạng. Thử lại sau nhé."
            case .quotaExceeded:
                return "Dung lượng iCloud đã đầy."
            case .permissionFailure:
                return "Bạn không có quyền thực hiện thao tác này."
            case .zoneNotFound, .userDeletedZone:
                return "Không gian chung không còn tồn tại (có thể người ấy đã rời đi)."
            default:
                return ck.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
