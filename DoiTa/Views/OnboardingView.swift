import SwiftUI

/// Màn hình đầu tiên: nhập tên rồi tạo "không gian của hai ta".
struct OnboardingView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var name = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Spacer(minLength: 40)

                Text("💕")
                    .font(.system(size: 72))
                    .padding(28)
                    .background(Theme.accentSoft, in: Circle())

                VStack(spacing: 8) {
                    Text("Đôi Ta")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.gradient)
                    Text("Cùng đặt mục tiêu, cùng đi những nơi mình muốn đến, và giữ lại mọi kỷ niệm của hai đứa.")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tên của bạn").font(.subheadline.weight(.semibold))
                    TextField("Ví dụ: Dan", text: $name)
                        .textInputAutocapitalization(.words)
                        .padding(14)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    store.displayName = name.trimmed
                    Task { await store.createSpace() }
                } label: {
                    Text("Tạo không gian của hai ta")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
                .disabled(name.trimmed.isEmpty)
                .opacity(name.trimmed.isEmpty ? 0.5 : 1)

                VStack(spacing: 6) {
                    Text("Người ấy đã tạo rồi?")
                        .font(.subheadline.weight(.semibold))
                    Text("Bấm vào link mời mà người ấy gửi (qua Tin nhắn, Zalo, Messenger…). Đôi Ta sẽ tự kết nối hai bạn.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
            }
            .padding(24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .onAppear { name = store.displayName }
    }
}

/// Dành cho người vừa nhận lời mời nhưng chưa nhập tên.
struct NameView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var name = ""

    var body: some View {
        VStack(spacing: 20) {
            Text("🥰").font(.system(size: 64))
            Text("Chào mừng đến với không gian của hai ta")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            Text("Hãy cho người ấy biết bạn là ai nhé.")
                .foregroundStyle(.secondary)
            TextField("Tên của bạn", text: $name)
                .textInputAutocapitalization(.words)
                .padding(14)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
            Button {
                store.displayName = name.trimmed
            } label: {
                Text("Tiếp tục")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
            }
            .disabled(name.trimmed.isEmpty)
            .opacity(name.trimmed.isEmpty ? 0.5 : 1)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }
}

/// Hiện ngay sau khi tạo không gian: gửi link mời cho người ấy.
struct InviteView: View {
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Text("💌").font(.system(size: 72))
            Text("Gửi link mời cho người ấy")
                .font(.title2.bold())
            Text("Người ấy cần cài Đôi Ta trên iPhone của họ, rồi bấm vào link này để vào chung không gian với bạn.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            if let url = store.shareURL {
                ShareLink(
                    item: url,
                    subject: Text("Lời mời vào Đôi Ta"),
                    message: Text("Mình tạo không gian chung cho hai đứa trên Đôi Ta nè 💕 Bấm vào link để tham gia nhé!")
                ) {
                    Label("Gửi link mời", systemImage: "paperplane.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14))
                        .foregroundStyle(.white)
                }
            } else {
                ProgressView()
            }

            Text("Ai có link đều tham gia được — chỉ gửi cho người ấy thôi nhé.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button("Để sau") { dismiss() }
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .presentationDetents([.large])
    }
}
