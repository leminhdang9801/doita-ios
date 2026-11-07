# Đôi Ta 💕 — app iOS cho các cặp đôi

Hai bạn cùng đặt **mục tiêu** và **địa điểm** muốn đến. Mỗi khi hoàn thành, chụp ảnh lại, chọn cảm xúc và để lại **cảm nhận**. Mọi thứ được đồng bộ qua **iCloud (CloudKit Sharing)**: mỗi người dùng iPhone và Apple ID của mình.

## Tính năng (MVP)
- Tạo "không gian của hai ta" và gửi **link mời** cho người ấy (qua Tin nhắn, Zalo, Messenger…)
- Thêm / sửa / xoá **mục tiêu** hoặc **địa điểm**, ngày dự kiến, đếm ngược, ghi chú, gợi ý ý tưởng
- **Hoàn thành & lưu kỷ niệm**: chụp ảnh / chọn nhiều ảnh, chọn cảm xúc 🥰😄🤪🥹😌, viết cảm nhận
- Tab **Kỷ niệm**: dòng thời gian ảnh theo từng mục tiêu, xem ảnh toàn màn hình, lưu về thư viện Ảnh
- Bình luận / cảm nhận của cả hai người trên từng mục tiêu
- Mở địa điểm trong Apple Maps

## Yêu cầu
- macOS + **Xcode 16 trở lên**
- iOS 17+
- **Tài khoản Apple Developer trả phí** (99 USD/năm) — CloudKit bắt buộc cần
- Hai iPhone thật đăng nhập **hai Apple ID khác nhau** để thử chia sẻ (Simulator chạy được nhưng không chụp ảnh được)

## Chạy lần đầu
1. Cài [XcodeGen](https://github.com/yonaskolb/XcodeGen) rồi sinh project (file `.xcodeproj` không đưa vào git):
   ```bash
   brew install xcodegen
   xcodegen generate
   open DoiTa.xcodeproj
   ```
2. Chọn target **DoiTa** › tab **Signing & Capabilities**:
   - **Team**: chọn team developer của bạn.
   - **Bundle Identifier**: mặc định `com.danle.doita` (đổi nếu bị trùng).
   - Mục **iCloud**: bật **CloudKit**, bấm `+` để tạo container `iCloud.com.danle.doita`
     (nếu đổi tên container → sửa luôn `CoupleStore.containerID` trong `DoiTa/Services/CoupleStore.swift`
     và file `Config/DoiTa.entitlements`).
3. Cắm iPhone, chọn thiết bị và bấm ▶︎ Run.
4. Trên máy 1: nhập tên → **Tạo không gian của hai ta** → **Gửi link mời**.
5. Trên máy 2 (đã cài app): bấm vào link → app tự kết nối.

> Lần chạy đầu ở môi trường Development, CloudKit tự tạo schema (`Goal`, `Memory`, `Comment`).
> Trước khi phát hành TestFlight/App Store: vào **CloudKit Console** › **Deploy Schema Changes to Production**.

## Cấu trúc code
```
DoiTa/
├── App/DoiTaApp.swift            # @main + nhận lời mời CloudKit (SceneDelegate)
├── Models/Models.swift           # Goal, Memory (ảnh), Comment (cảm nhận), Mood
├── Services/CoupleStore.swift    # Toàn bộ logic CloudKit: tạo zone, share, đồng bộ, lưu ảnh
├── Components/Components.swift   # Theme, Avatar, ảnh có cache, lưới ảnh, Camera
└── Views/                        # Onboarding, Hành trình, Chi tiết, Thêm kỷ niệm, Kỷ niệm, Cài đặt
Config/                           # Info.plist (CKSharingSupported) + entitlements iCloud
project.yml                       # Cấu hình XcodeGen (sinh DoiTa.xcodeproj)
```

**Mô hình dữ liệu** (tất cả trong một record zone `CoupleZone` được chia sẻ):

| Record | Trường |
|---|---|
| `Goal` | title, note, kind (goal/place), placeName, targetDate, isCompleted, completedAt, createdBy, creatorID |
| `Memory` | goal (reference, xoá theo goal), image (CKAsset), createdBy, creatorID |
| `Comment` | goal (reference), text, mood, author, creatorID |

`creatorID` là `recordName` của user iCloud, dùng để phân biệt "bạn" và "người ấy" trên từng bình luận.

## Gợi ý cho bước tiếp theo
- Thêm push notification khi người ấy vừa thêm ảnh (CKDatabaseSubscription)
- Thêm bản đồ hiển thị tất cả địa điểm hai đứa đã đi (MapKit + tìm kiếm địa điểm)
- Thêm ngày kỷ niệm yêu nhau và bộ đếm số ngày bên nhau ở màn hình chính
- Thêm widget màn hình khoá hiển thị ảnh kỷ niệm ngẫu nhiên
- Cache dữ liệu offline bằng SwiftData

## Lưu ý
- Code được viết mà chưa biên dịch thử trên Xcode thật (môi trường tạo code không có Swift/Xcode). Nếu Xcode báo lỗi biên dịch, hãy mở issue hoặc gửi log để sửa.
- Đồng bộ dùng `recordZoneChanges` nên **không cần** tạo index "queryable" trong CloudKit Console; app tự làm mới mỗi 30 giây và khi mở lại app.
- Link mời đang để chế độ *ai có link đều tham gia được* — chỉ gửi cho người ấy thôi nhé.
- Người tạo bấm "Rời không gian chung" sẽ **xoá toàn bộ** dữ liệu của cả hai.
