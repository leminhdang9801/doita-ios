import SwiftUI

/// Chọn ngày bắt đầu yêu nhau và xem các cột mốc sắp tới.
struct AnniversaryView: View {
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.dismiss) private var dismiss

    @State private var hasDate = false
    @State private var date = Date()
    @State private var loaded = false

    private var milestones: [Milestone] {
        guard hasDate else { return [] }
        return Milestones.all(from: date).filter { !$0.isPast }.prefix(6).map { $0 }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Đặt ngày kỷ niệm", isOn: $hasDate.animation())
                    if hasDate {
                        DatePicker("Ngày bắt đầu yêu nhau", selection: $date, in: ...Date(), displayedComponents: .date)
                    }
                } footer: {
                    Text("Đôi Ta sẽ đếm số ngày hai đứa bên nhau và nhắc các cột mốc đáng nhớ.")
                }

                if !milestones.isEmpty {
                    Section("Cột mốc sắp tới") {
                        ForEach(milestones) { milestone in
                            HStack {
                                Text(milestone.emoji)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(milestone.label).font(.subheadline.weight(.medium))
                                    Text(milestone.date.viLong).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text("còn \(milestone.daysAway) ngày")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                        }
                    }
                }
            }
            .environment(\.locale, Locale(identifier: "vi_VN"))
            .navigationTitle("Ngày kỷ niệm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }.fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        if let existing = store.space.anniversaryDate {
            hasDate = true
            date = existing
        }
    }

    private func save() {
        let chosen = hasDate ? date : nil
        Task {
            if await store.setAnniversary(chosen) {
                await LoveNotifications.scheduleMilestones(from: chosen)
                dismiss()
            }
        }
    }
}
