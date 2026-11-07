import SwiftUI

struct JourneyView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var filter: Filter = .pending
    @State private var showEditor = false
    @State private var goalToDelete: Goal?

    enum Filter: String, CaseIterable, Identifiable {
        case pending = "Đang chờ"
        case done = "Đã xong"
        var id: String { rawValue }
    }

    private var filtered: [Goal] {
        switch filter {
        case .pending:
            return store.goals.filter { !$0.isCompleted }.sorted { a, b in
                switch (a.targetDate, b.targetDate) {
                case let (x?, y?): return x < y
                case (_?, nil): return true
                case (nil, _?): return false
                default: return a.createdAt > b.createdAt
                }
            }
        case .done:
            return store.goals.filter { $0.isCompleted }.sorted {
                ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast)
            }
        }
    }

    private var doneCount: Int { store.goals.filter(\.isCompleted).count }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ProgressCard(done: doneCount, total: store.goals.count)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if store.isOwner, !store.partnerJoined, let url = store.shareURL {
                    Section {
                        ShareLink(
                            item: url,
                            message: Text("Mình tạo không gian chung cho hai đứa trên Đôi Ta nè 💕 Bấm vào link để tham gia nhé!")
                        ) {
                            Label("Mời người ấy vào không gian chung", systemImage: "person.badge.plus")
                        }
                    } footer: {
                        Text("Người ấy chưa tham gia. Gửi link để cùng nhau thêm mục tiêu nhé.")
                    }
                }

                Section {
                    Picker("Lọc", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    if filtered.isEmpty {
                        emptyState
                    } else {
                        ForEach(filtered) { goal in
                            NavigationLink(value: goal.id) {
                                GoalRow(goal: goal, photoCount: store.memories(for: goal.id).count)
                            }
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    goalToDelete = goal
                                } label: {
                                    Label("Xoá", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Hành trình")
            .navigationDestination(for: String.self) { goalID in
                GoalDetailView(goalID: goalID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showEditor = true
                    } label: {
                        Image(systemName: "plus.circle.fill").font(.title3)
                    }
                    .accessibilityLabel("Thêm mục tiêu hoặc địa điểm")
                }
            }
            .sheet(isPresented: $showEditor) {
                GoalEditorView()
            }
            .refreshable { await store.refresh() }
            .confirmationDialog(
                "Xoá mục này?",
                isPresented: Binding(
                    get: { goalToDelete != nil },
                    set: { if !$0 { goalToDelete = nil } }
                ),
                titleVisibility: .visible,
                presenting: goalToDelete
            ) { goal in
                Button("Xoá \"\(goal.title)\"", role: .destructive) {
                    Task { await store.deleteGoal(goal.id) }
                }
            } message: { _ in
                Text("Ảnh và cảm nhận của mục này cũng sẽ bị xoá với cả hai người.")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text(filter == .pending ? "✨" : "📷").font(.largeTitle)
            Text(filter == .pending ? "Chưa có mục nào đang chờ" : "Chưa hoàn thành mục nào")
                .font(.headline)
            Text(filter == .pending
                 ? "Bấm dấu + để thêm mục tiêu hoặc địa điểm hai đứa muốn đến."
                 : "Hoàn thành một mục rồi lưu ảnh kỷ niệm nhé.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}

struct ProgressCard: View {
    let done: Int
    let total: Int

    private var fraction: Double { total == 0 ? 0 : Double(done) / Double(total) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(total == 0 ? "Bắt đầu hành trình của hai ta" : "Hai đứa đã hoàn thành \(done)/\(total) điều")
                .font(.headline)
                .foregroundStyle(.white)
            ProgressView(value: fraction)
                .tint(.white)
                .background(Color.white.opacity(0.25), in: Capsule())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 18))
    }
}

struct GoalRow: View {
    let goal: Goal
    let photoCount: Int

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle().fill(goal.isCompleted ? Color.green.opacity(0.15) : Theme.accentSoft)
                Image(systemName: goal.isCompleted ? "checkmark" : goal.kind.icon)
                    .foregroundStyle(goal.isCompleted ? Color.green : Theme.accent)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title).font(.headline)
                if goal.kind == .place, !goal.placeName.isEmpty {
                    Label(goal.placeName, systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if goal.isCompleted {
                    if let done = goal.completedAt {
                        Text("Xong ngày \(done.viLong)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else if let date = goal.targetDate {
                    CountdownBadge(date: date)
                }
            }

            Spacer()

            if photoCount > 0 {
                Label("\(photoCount)", systemImage: "photo")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
