# Đôi Ta 💕 — app iOS cho các cặp đôi

Hai bạn cùng đặt **mục tiêu** và **địa điểm** muốn đến. Mỗi khi hoàn thành, chụp ảnh lại, chọn cảm xúc và để lại **cảm nhận**. Mọi thứ được đồng bộ qua **iCloud (CloudKit Sharing)**: mỗi người dùng iPhone và Apple ID của mình.

## Tính năng (MVP)
- Tạo "không gian của hai ta" và gửi **link mời** cho người ấy (qua Tin nhắn, Zalo, Messenger…)
- Thêm / sửa / xoá **mục tiêu** hoặc **địa điểm**, ngày dự kiến, đếm ngược, ghi chú, gợi ý ý tưởng
- **Hoàn thành & lưu kỷ niệm**: chụp ảnh / chọn nhiều ảnh, chọn cảm xúc 🥰😄🤪🥹😌, viết cảm nhận
- Tab **Kỷ niệm**: dòng thời gian ảnh theo từng mục tiêu, xem ảnh toàn màn hình, lưu về thư viện Ảnh
- Bình luận / cảm nhận của cả hai người trên từng mục tiêu
- Mở địa điểm trong Apple Maps

## Tính năng mới — Giai đoạn 1
- Tab **Chúng mình**: đếm số ngày yêu nhau, cột mốc kế tiếp, thống kê (đã hoàn thành / nơi đã đến / số ảnh), mục tiêu sắp tới, "ngày này năm xưa", kỷ niệm trong ngày
- **Ngày kỷ niệm & cột mốc**: chọn ngày bắt đầu yêu, tự tính mốc 100/200/…/1000 ngày và tròn năm, nhắc bằng **local notification** lúc 9h sáng
- **Phân loại mục tiêu**: Du lịch / Ăn uống / Hẹn hò / Cột mốc / Khác + lọc theo nhãn ở tab Hành trình
- **Bản đồ kỷ niệm** (MapKit): lấy vị trí khi lưu kỷ niệm (tùy chọn) và geocode tên địa điểm, hiện các nơi hai đứa đã đến, chạm để xem chi tiết
- **Widget** màn hình khoá/chính: số ngày bên nhau + đếm ngược mục tiêu sắp tới + ảnh kỷ niệm (qua App Group)

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
   - **Team**: chọn team developer của bạn (đặt cho **cả 2 target**: `DoiTa` và `DoiTaWidget`).
   - **Bundle Identifier**: mặc định `com.danle.doita` (widget là `com.danle.doita.widget`; đổi nếu bị trùng).
   - Mục **iCloud**: bật **CloudKit**, bấm `+` để tạo container `iCloud.com.danle.doita`
     (nếu đổi tên container → sửa luôn `CoupleStore.containerID` trong `DoiTa/Services/CoupleStore.swift`
     và file `Config/DoiTa.entitlements`).
   - Mục **App Groups**: bật nhóm `group.com.danle.doita` cho **cả 2 target** (app ghi dữ liệu cho widget đọc).
     Đổi tên nhóm → sửa `WidgetShared.appGroup` và 2 file entitlements.
3. Cắm iPhone, chọn thiết bị và bấm ▶︎ Run.
4. Trên máy 1: nhập tên → **Tạo không gian của hai ta** → **Gửi link mời**.
5. Trên máy 2 (đã cài app): bấm vào link → app tự kết nối.

> Lần chạy đầu ở môi trường Development, CloudKit tự tạo schema (`Goal`, `Memory`, `Comment`, `Space`).
> Trước khi phát hành TestFlight/App Store: vào **CloudKit Console** › **Deploy Schema Changes to Production**.

## Cấu trúc code
```
DoiTa/
├── App/DoiTaApp.swift            # @main + nhận lời mời CloudKit (SceneDelegate)
├── Models/Models.swift           # Goal, Memory, Comment, Mood, GoalCategory, CoupleSpace, Milestone
├── Services/
│   ├── CoupleStore.swift         # Logic CloudKit: zone, share, đồng bộ, lưu ảnh, số liệu màn hình chính
│   ├── LocationProvider.swift    # Lấy vị trí one-shot khi lưu kỷ niệm (CoreLocation)
│   ├── LoveNotifications.swift   # Lên lịch local notification nhắc cột mốc
│   └── WidgetSync.swift          # Ghi dữ liệu ra App Group cho widget
├── Components/Components.swift   # Theme, Avatar, ảnh có cache, lưới ảnh, Camera
└── Views/                        # Chúng mình (Home), Hành trình, Bản đồ, Kỷ niệm, Cài đặt, Ngày kỷ niệm…
Shared/WidgetShared.swift         # Hằng số App Group + WidgetSnapshot (dùng chung app ↔ widget)
DoiTaWidget/                      # Widget extension (WidgetKit)
Config/                           # Info.plist + entitlements (iCloud + App Group)
project.yml                       # Cấu hình XcodeGen (sinh DoiTa.xcodeproj, 2 target)
```

**Mô hình dữ liệu** (tất cả trong một record zone `CoupleZone` được chia sẻ):

| Record | Trường |
|---|---|
| `Goal` | title, note, kind (goal/place), **category**, placeName, targetDate, isCompleted, completedAt, **latitude, longitude**, createdBy, creatorID |
| `Memory` | goal (reference, xoá theo goal), image (CKAsset), createdBy, creatorID |
| `Comment` | goal (reference), text, mood, author, creatorID |
| `Space` | anniversaryDate, coupleName — một record duy nhất (`couple-space`) cho thông tin chung |

`creatorID` là `recordName` của user iCloud, dùng để phân biệt "bạn" và "người ấy" trên từng bình luận.
`latitude/longitude` được gán khi lưu kỷ niệm (có bật vị trí) hoặc geocode từ tên địa điểm, dùng cho bản đồ.

## Gợi ý cho bước tiếp theo (Giai đoạn 2+)
- Push notification khi người ấy vừa thêm ảnh / hoàn thành mục tiêu (CKDatabaseSubscription)
- Thả tim / reaction nhanh trên mục tiêu & ảnh
- Câu hỏi mỗi ngày cho cặp đôi
- Caption riêng cho từng ảnh, album & lọc theo cảm xúc
- Cache dữ liệu offline bằng SwiftData

## Lưu ý
- Code được viết mà chưa biên dịch thử trên Xcode thật (môi trường tạo code không có Swift/Xcode). Nếu Xcode báo lỗi biên dịch, hãy mở issue hoặc gửi log để sửa.
- Đồng bộ dùng `recordZoneChanges` nên **không cần** tạo index "queryable" trong CloudKit Console; app tự làm mới mỗi 30 giây và khi mở lại app.
- Link mời đang để chế độ *ai có link đều tham gia được* — chỉ gửi cho người ấy thôi nhé.
- Người tạo bấm "Rời không gian chung" sẽ **xoá toàn bộ** dữ liệu của cả hai.
