import SwiftUI

/// Dòng thời gian kỷ niệm: ảnh theo từng mục đã hoàn thành.
struct MemoriesView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var viewer: ViewerItem?

    struct ViewerItem: Identifiable {
        let id = UUID()
        let memories: [Memory]
        let startID: String
    }

    private var entries: [Goal] {
        store.goals
            .filter { $0.isCompleted || !store.memories(for: $0.id).isEmpty }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView(
                        "Chưa có kỷ niệm nào",
                        systemImage: "photo.on.rectangle.angled",
                        description: Text("Hoàn thành một mục tiêu và chụp ảnh lại để lưu kỷ niệm của hai đứa nhé 💕")
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(entries) { goal in
                                section(for: goal)
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Theme.background)
            .navigationTitle("Kỷ niệm")
            .navigationDestination(for: String.self) { goalID in
                GoalDetailView(goalID: goalID)
            }
            .refreshable { await store.refresh() }
            .fullScreenCover(item: $viewer) { item in
                PhotoViewer(memories: item.memories, startID: item.startID)
            }
        }
    }

    private func section(for goal: Goal) -> some View {
        let photos = store.memories(for: goal.id)
        let comments = store.comments(for: goal.id)

        return VStack(alignment: .leading, spacing: 10) {
            NavigationLink(value: goal.id) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title).font(.headline)
                        Text((goal.completedAt ?? goal.createdAt).viLong)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if !photos.isEmpty {
                PhotoGrid(memories: photos) { memory in
                    viewer = ViewerItem(memories: photos, startID: memory.id)
                }
            }

            ForEach(comments.prefix(2)) { comment in
                HStack(alignment: .top, spacing: 8) {
                    Text(comment.mood?.emoji ?? "💬")
                    Text("\(store.isMine(comment.creatorID) ? "Bạn" : comment.author): \(comment.text)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
        }
    }
}
