import SwiftUI

@main
struct DoiTaApp: App {
    @StateObject private var store = CoupleStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .tint(Theme.accent)
        }
    }
}
