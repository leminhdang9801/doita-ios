import SwiftUI

struct GoalDetailView: View {
    let goalID: String
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.dismiss) private var dismiss

    @State private var showEdit = false
    @State private var showAddMemory = false
    @State private var confirmDelete = false
    @State private var viewing: Memory?
    @State private var commentText = ""
    @State private var commentMood: Mood?

    private var goal: Goal? { store.goals.first { $0.id == goalID } }
    private var photos: [Memory] { store.memories(for: goalID) }
    private var comments: [Comment] { store.comments(for: goalID) }

    var body: some View {
        Group {
            if let goal {
                content(goal)
            } else {
                ContentUnavailableView("Mục này không còn nữa", systemImage: "heart.slash")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if goal != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Sửa", systemImage: "pencil") { showEdit = true }
                        Button("Xoá", systemImage: "trash", role: .destructive) { confirmDelete = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            if let goal { GoalEditorView(goal: goal) }
        }
        .sheet(isPresented: $showAddMemory) {
            AddMemoryView(goalID: goalID)
        }
        .fullScreenCover(item: $viewing) { memory in
            PhotoViewer(memories: photos, startID: memory.id)
        }
        .confirmationDialog("Xoá mục này?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Xoá", role: .destructive) {
                Task {
                    if await store.deleteGoal(goalID) { dismiss() }
                }
            }
        } message: {
            Text("Ảnh và cảm nhận của mục này cũng sẽ bị xoá với cả hai người.")
        }
    }

    // MARK: Nội dung

    private func content(_ goal: Goal) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header(goal)

                Button {
                    showAddMemory = true
                } label: {
                    Label(
                        goal.isCompleted ? "Thêm ảnh & cảm nhận" : "Hoàn thành & lưu kỷ niệm",
                        systemImage: goal.isCompleted ? "plus.circle.fill" : "checkmark.circle.fill"
                    )
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 14))
                    .foregroundStyle(.white)
                }

                if !photos.isEmpty {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ảnh kỷ niệm").font(.headline)
                        PhotoGrid(memories: photos) { viewing = $0 }
                    }
                }

                commentsSection
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background)
        .refreshable { await store.refresh() }
    }

    private func header(_ goal: Goal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(goal.kind.title, systemImage: goal.kind.icon)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.accentSoft, in: Capsule())
                    .foregroundStyle(Theme.accent)
                Spacer()
                if goal.isCompleted {
                    Label("Đã xong", systemImage: "checkmark.seal.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            Text(goal.title).font(.title2.bold())

            if !goal.note.isEmpty {
                Text(goal.note).foregroundStyle(.secondary)
            }

            if goal.kind == .place, !goal.placeName.isEmpty {
                Link(destination: appleMapsURL(for: goal.placeName)) {
                    Label("Mở \(goal.placeName) trong Apple Maps", systemImage: "map.fill")
                        .font(.subheadline.weight(.medium))
                }
            }

            if goal.isCompleted, let done = goal.completedAt {
                Label("Hoàn thành \(done.viLong)", systemImage: "calendar.badge.checkmark")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if let date = goal.targetDate {
                HStack(spacing: 8) {
                    Label(date.viLong, systemImage: "calendar")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    CountdownBadge(date: date)
                }
            }

            if !goal.createdBy.isEmpty {
                Text("Thêm bởi \(goal.createdBy)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cảm nhận của hai đứa").font(.headline)

            if comments.isEmpty {
                Text("Chưa có cảm nhận nào. Hãy viết điều bạn nghĩ nhé 💬")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, isMine: store.isMine(comment.creatorID))
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                MoodPicker(selection: $commentMood)
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Viết cảm nhận của bạn…", text: $commentText, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    Button {
                        let text = commentText
                        let mood = commentMood
                        Task {
                            if await store.addComment(goalID: goalID, text: text, mood: mood) {
                                commentText = ""
                                commentMood = nil
                            }
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 34))
                    }
                    .disabled(commentText.trimmed.isEmpty)
                }
            }
            .padding(.top, 4)
        }
    }
}

struct CommentRow: View {
    let comment: Comment
    let isMine: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Avatar(name: comment.author, size: 34)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(isMine ? "Bạn" : comment.author).font(.subheadline.weight(.semibold))
                    if let mood = comment.mood { Text(mood.emoji) }
                    Text(comment.createdAt.viRelative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if !comment.text.isEmpty {
                    Text(comment.text)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isMine ? Theme.accentSoft : Theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
    }
}
