import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var name = ""
    @State private var confirmLeave = false

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Của bạn") {
                    HStack(spacing: 12) {
                        Avatar(name: store.displayName, size: 40)
                        TextField("Tên của bạn", text: $name)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .onSubmit(commitName)
                    }
                }

                Section("Người ấy") {
                    HStack(spacing: 12) {
                        Avatar(name: store.partnerJoined ? store.partnerDisplayName : "?", size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.partnerJoined ? store.partnerDisplayName : "Chưa tham gia")
                            Text(store.partnerJoined ? "Đã kết nối qua iCloud" : "Gửi link mời để người ấy vào chung")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if store.isOwner, let url = store.shareURL {
                        ShareLink(
                            item: url,
                            message: Text("Mình tạo không gian chung cho hai đứa trên Đôi Ta nè 💕 Bấm vào link để tham gia nhé!")
                        ) {
                            Label("Gửi link mời", systemImage: "paperplane.fill")
                        }
                    }
                } footer: {
                    if store.isOwner {
                        Text("Link mời cho phép ai có link đều tham gia được — chỉ gửi cho người ấy thôi nhé.")
                    }
                }

                Section {
                    Button {
                        Task { await store.refresh() }
                    } label: {
                        Label("Làm mới dữ liệu", systemImage: "arrow.clockwise")
                    }
                } footer: {
                    Text("Bản này lưu dữ liệu ngay trên máy (local). Phần ghép đôi & đồng bộ iCloud sẽ bật khi có tài khoản Apple Developer trả phí.")
                }

                Section {
                    Button(role: .destructive) {
                        confirmLeave = true
                    } label: {
                        Label("Rời không gian chung", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } footer: {
                    Text(store.isOwner
                         ? "Bạn là người tạo: rời đi sẽ xoá toàn bộ mục tiêu, ảnh và cảm nhận của cả hai người."
                         : "Bạn sẽ không còn thấy dữ liệu chung nữa. Người ấy vẫn giữ nguyên dữ liệu của họ.")
                }

                Section {
                    HStack {
                        Text("Phiên bản")
                        Spacer()
                        Text(versionText).foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Cài đặt")
            .onAppear { name = store.displayName }
            .onDisappear(perform: commitName)
            .confirmationDialog(
                store.isOwner ? "Xoá toàn bộ dữ liệu của hai người?" : "Rời không gian chung?",
                isPresented: $confirmLeave,
                titleVisibility: .visible
            ) {
                Button(store.isOwner ? "Xoá và rời đi" : "Rời đi", role: .destructive) {
                    Task { await store.leaveSpace() }
                }
            } message: {
                Text(store.isOwner
                     ? "Hành động này không thể hoàn tác."
                     : "Bạn có thể tham gia lại nếu người ấy gửi link mời mới.")
            }
        }
    }

    private func commitName() {
        let trimmed = name.trimmed
        if !trimmed.isEmpty, trimmed != store.displayName {
            store.displayName = trimmed
        }
    }
}
