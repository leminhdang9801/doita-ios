import CloudKit
import CoreLocation
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
    @Published private(set) var space = CoupleSpace()
    @Published var errorMessage: String?
    @Published var showInvite = false

    @Published var displayName: String {
        didSet { UserDefaults.standard.set(displayName, forKey: "displayName") }
    }

    var partnerDisplayName: String { partnerName ?? "Người ấy" }

    // MARK: Số liệu dẫn xuất cho màn hình chính

    /// Số ngày hai đứa đã bên nhau (kể cả ngày bắt đầu).
    var daysTogether: Int? {
        guard let start = space.anniversaryDate else { return nil }
        let cal = Calendar.current
        let days = cal.dateComponents([.day], from: cal.startOfDay(for: start), to: cal.startOfDay(for: Date())).day ?? 0
        return max(0, days) + 1
    }

    var completedGoals: [Goal] { goals.filter(\.isCompleted) }

    var visitedPlaces: [Goal] { goals.filter { $0.kind == .place && $0.isCompleted } }

    /// Mục chưa xong, có ngày dự kiến, sắp đến gần nhất.
    var upcomingGoal: Goal? {
        goals
            .filter { !$0.isCompleted && $0.targetDate != nil }
            .min { ($0.targetDate ?? .distantFuture) < ($1.targetDate ?? .distantFuture) }
    }

    var nextMilestone: Milestone? {
        guard let start = space.anniversaryDate else { return nil }
        return Milestones.next(from: start)
    }

    /// Kỷ niệm "ngày này năm xưa" (cùng ngày–tháng, năm trước).
    var onThisDay: [Memory] {
        let cal = Calendar.current
        let today = cal.dateComponents([.month, .day], from: Date())
        return memories.filter {
            let c = cal.dateComponents([.month, .day, .year], from: $0.createdAt)
            return c.month == today.month && c.day == today.day && c.year != cal.component(.year, from: Date())
        }
    }

    /// Một kỷ niệm ngẫu nhiên nhưng ổn định trong ngày (đổi mỗi ngày).
    var memoryOfTheDay: Memory? {
        guard !memories.isEmpty else { return nil }
        let day = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        return memories[day % memories.count]
    }

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

        // Thông tin chung của cặp đôi (ngày kỷ niệm…)
        if let spaceRecord = all.first(where: { $0.recordType == CoupleSpace.recordType }) {
            space = CoupleSpace(record: spaceRecord)
        }

        WidgetSync.write(daysTogether: daysTogether,
                         upcomingTitle: upcomingGoal?.title,
                         upcomingDate: upcomingGoal?.targetDate,
                         memoryImageURL: memoryOfTheDay?.imageURL)
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
        space = CoupleSpace()
        WidgetSync.clear()
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
    func addGoal(title: String, note: String, kind: GoalKind, category: GoalCategory, placeName: String, targetDate: Date?) async -> Bool {
        let ok = await perform {
            guard let record = newRecord(Goal.recordType) else { return }
            record["title"] = title
            record["note"] = note
            record["kind"] = kind.rawValue
            record["category"] = category.rawValue
            record["placeName"] = kind == .place ? placeName : ""
            record["targetDate"] = targetDate
            record["isCompleted"] = 0
            record["createdBy"] = displayName
            record["creatorID"] = myUserID ?? ""
            try await save([record])
        }
        if ok, kind == .place, !placeName.trimmingCharacters(in: .whitespaces).isEmpty {
            await geocodePlaces()
        }
        return ok
    }

    @discardableResult
    func updateGoal(id: String, title: String, note: String, kind: GoalKind, category: GoalCategory, placeName: String, targetDate: Date?) async -> Bool {
        let ok = await perform {
            guard let record = existingRecord(id) else { return }
            let oldPlace = record["placeName"] as? String ?? ""
            record["title"] = title
            record["note"] = note
            record["kind"] = kind.rawValue
            record["category"] = category.rawValue
            record["placeName"] = kind == .place ? placeName : ""
            record["targetDate"] = targetDate
            // Địa điểm đổi → xoá tọa độ cũ để geocode lại.
            if oldPlace != placeName {
                record["latitude"] = nil
                record["longitude"] = nil
            }
            try await save([record])
        }
        if ok, kind == .place, !placeName.trimmingCharacters(in: .whitespaces).isEmpty {
            await geocodePlaces()
        }
        return ok
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
    /// `coordinate` là vị trí lúc lưu kỷ niệm (nếu người dùng cho phép) để hiện lên bản đồ.
    @discardableResult
    func saveMemory(goalID: String, images: [UIImage], mood: Mood?, text: String, coordinate: CLLocationCoordinate2D? = nil) async -> Bool {
        await perform {
            guard let goalRecord = existingRecord(goalID) else { return }
            var toSave: [CKRecord] = []
            var goalChanged = false

            if (goalRecord["isCompleted"] as? Int ?? 0) != 1 {
                goalRecord["isCompleted"] = 1
                goalRecord["completedAt"] = Date()
                goalChanged = true
            }

            // Gắn tọa độ cho mục nếu chưa có và đang có vị trí.
            if let coordinate, goalRecord["latitude"] == nil {
                goalRecord["latitude"] = coordinate.latitude
                goalRecord["longitude"] = coordinate.longitude
                goalChanged = true
            }

            if goalChanged { toSave.append(goalRecord) }

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

    // MARK: - Thông tin chung của cặp đôi

    @discardableResult
    func updateSpace(anniversaryDate: Date?, coupleName: String) async -> Bool {
        await perform {
            guard let zoneID else { return }
            let record = existingRecord(CoupleSpace.fixedName)
                ?? CKRecord(recordType: CoupleSpace.recordType,
                            recordID: CKRecord.ID(recordName: CoupleSpace.fixedName, zoneID: zoneID))
            record["anniversaryDate"] = anniversaryDate
            record["coupleName"] = coupleName
            try await save([record])
            space = CoupleSpace(anniversaryDate: anniversaryDate, coupleName: coupleName)
        }
    }

    @discardableResult
    func setAnniversary(_ date: Date?) async -> Bool {
        await updateSpace(anniversaryDate: date, coupleName: space.coupleName)
    }

    // MARK: - Geocode địa điểm → tọa độ (không cần quyền vị trí)

    private var isGeocoding = false

    /// Tìm tọa độ cho các mục địa điểm chưa có tọa độ, để hiện lên bản đồ.
    func geocodePlaces() async {
        guard !isGeocoding else { return }
        isGeocoding = true
        defer { isGeocoding = false }

        let pending = goals.filter { $0.kind == .place && !$0.hasCoordinate && !$0.placeName.trimmed.isEmpty }
        let geocoder = CLGeocoder()

        for goal in pending {
            guard let placemark = try? await geocoder.geocodeAddressString(goal.placeName).first,
                  let loc = placemark.location else { continue }
            _ = await perform {
                guard let record = existingRecord(goal.id) else { return }
                record["latitude"] = loc.coordinate.latitude
                record["longitude"] = loc.coordinate.longitude
                try await save([record])
            }
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
