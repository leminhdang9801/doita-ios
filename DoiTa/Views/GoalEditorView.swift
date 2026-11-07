import SwiftUI

/// Thêm mới (goal == nil) hoặc sửa một mục tiêu / địa điểm.
struct GoalEditorView: View {
    var goal: Goal?
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.dismiss) private var dismiss

    @State private var kind: GoalKind = .goal
    @State private var title = ""
    @State private var placeName = ""
    @State private var note = ""
    @State private var hasDate = false
    @State private var date = Date()
    @State private var loaded = false

    private var canSave: Bool { !title.trimmed.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Loại", selection: $kind) {
                        ForEach(GoalKind.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section("Nội dung") {
                    TextField(kind == .goal ? "Hai đứa muốn làm gì?" : "Hai đứa muốn đến đâu?", text: $title)
                    if kind == .place {
                        TextField("Tên địa điểm (để mở Apple Maps)", text: $placeName)
                    }
                    TextField("Ghi chú", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section {
                    Toggle("Ngày dự kiến", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Chọn ngày", selection: $date, displayedComponents: .date)
                    }
                } footer: {
                    if hasDate { Text("Đôi Ta sẽ đếm ngược đến ngày này cho hai đứa.") }
                }

                Section("Gợi ý ý tưởng") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Ideas.suggestions(for: kind), id: \.self) { idea in
                                Button(idea) {
                                    title = idea
                                    if kind == .place, placeName.trimmed.isEmpty { placeName = idea }
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "vi_VN"))
            .navigationTitle(goal == nil ? "Thêm mới" : "Sửa")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }
                        .disabled(!canSave)
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let goal else { return }
        kind = goal.kind
        title = goal.title
        placeName = goal.placeName
        note = goal.note
        if let target = goal.targetDate {
            hasDate = true
            date = target
        }
    }

    private func save() {
        let targetDate: Date? = hasDate ? date : nil
        Task {
            let ok: Bool
            if let goal {
                ok = await store.updateGoal(
                    id: goal.id,
                    title: title.trimmed,
                    note: note.trimmed,
                    kind: kind,
                    placeName: placeName.trimmed,
                    targetDate: targetDate
                )
            } else {
                ok = await store.addGoal(
                    title: title.trimmed,
                    note: note.trimmed,
                    kind: kind,
                    placeName: placeName.trimmed,
                    targetDate: targetDate
                )
            }
            if ok { dismiss() }
        }
    }
}
