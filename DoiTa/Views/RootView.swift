import SwiftUI
import UIKit

struct RootView: View {
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        content
            .task { await store.bootstrap() }
            .task {
                // Làm mới định kỳ để thấy ngay thứ người ấy vừa thêm.
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if UIApplication.shared.applicationState == .active {
                        await store.refreshQuietly()
                    }
                }
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await store.refreshQuietly() }
                }
            }
            .sheet(isPresented: $store.showInvite) {
                InviteView()
            }
            .alert(
                "Có chút trục trặc",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { if !$0 { store.errorMessage = nil } }
                )
            ) {
                Button("Đóng", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
            .overlay {
                if store.isBusy {
                    ZStack {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        ProgressView()
                            .controlSize(.large)
                            .padding(24)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.phase {
        case .loading:
            ProgressView("Đang kết nối iCloud…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background)
        case .noAccount:
            MessageView(
                icon: "icloud.slash",
                title: "Cần đăng nhập iCloud",
                message: "Đôi Ta đồng bộ qua iCloud. Hãy đăng nhập Apple ID trong Cài đặt của iPhone rồi quay lại nhé.",
                buttonTitle: "Mở Cài đặt"
            ) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        case .failed(let message):
            MessageView(
                icon: "exclamationmark.triangle",
                title: "Không kết nối được",
                message: message,
                buttonTitle: "Thử lại"
            ) {
                Task { await store.bootstrap() }
            }
        case .needsSetup:
            OnboardingView()
        case .ready:
            if store.displayName.trimmed.isEmpty {
                NameView()
            } else {
                MainTabView()
            }
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            JourneyView()
                .tabItem { Label("Hành trình", systemImage: "heart.text.square.fill") }
            MemoriesView()
                .tabItem { Label("Kỷ niệm", systemImage: "photo.on.rectangle.angled") }
            SettingsView()
                .tabItem { Label("Cài đặt", systemImage: "gearshape.fill") }
        }
    }
}
