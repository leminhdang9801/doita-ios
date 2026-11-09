import SwiftUI

/// Tab "Chúng mình" — tổng quan tình yêu của hai đứa.
struct HomeView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var showAnniversary = false
    @State private var viewer: Memory?

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<11: return "Chào buổi sáng"
        case 11..<14: return "Buổi trưa vui vẻ"
        case 14..<18: return "Buổi chiều của hai ta"
        default: return "Buổi tối ấm áp"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    heroCard
                    if let milestone = store.nextMilestone {
                        milestoneCard(milestone)
                    }
                    statsRow
                    if let goal = store.upcomingGoal {
                        upcomingCard(goal)
                    }
                    if !store.onThisDay.isEmpty {
                        onThisDaySection
                    }
                    if let memory = store.memoryOfTheDay {
                        memoryOfDaySection(memory)
                    }
                }
                .padding()
            }
            .background(Theme.background)
            .navigationTitle("Chúng mình")
            .navigationDestination(for: String.self) { GoalDetailView(goalID: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAnniversary = true } label: {
                        Image(systemName: "heart.circle")
                    }
                    .accessibilityLabel("Ngày kỷ niệm")
                }
            }
            .sheet(isPresented: $showAnniversary) { AnniversaryView() }
            .fullScreenCover(item: $viewer) { memory in
                PhotoViewer(memories: [memory], startID: memory.id)
            }
            .refreshable { await store.refresh() }
        }
    }

    // MARK: Thẻ số ngày bên nhau

    private var heroCard: some View {
        VStack(spacing: 10) {
            Text(greeting)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.9))

            if let days = store.daysTogether {
                Text("\(days)")
                    .font(.system(size: 64, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                Text("ngày bên nhau 💕")
                    .font(.headline)
                    .foregroundStyle(.white)
                if let start = store.space.anniversaryDate {
                    Text("Từ \(start.viLong)")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.85))
                }
            } else {
                Text("💕").font(.system(size: 52))
                Text("Đặt ngày hai đứa bắt đầu yêu nhau")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Button {
                    showAnniversary = true
                } label: {
                    Text("Chọn ngày kỷ niệm")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(.white, in: Capsule())
                        .foregroundStyle(Theme.accent)
                }
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 20)
        .background(Theme.gradient, in: RoundedRectangle(cornerRadius: 24))
    }

    // MARK: Cột mốc kế tiếp

    private func milestoneCard(_ milestone: Milestone) -> some View {
        HStack(spacing: 14) {
            Text(milestone.emoji).font(.system(size: 34))
            VStack(alignment: .leading, spacing: 2) {
                Text("Cột mốc sắp tới").font(.caption).foregroundStyle(.secondary)
                Text(milestone.label).font(.headline)
                Text(milestone.date.viLong).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            VStack(spacing: 0) {
                Text("\(milestone.daysAway)")
                    .font(.title2.bold())
                    .foregroundStyle(Theme.accent)
                Text("ngày nữa").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }

    // MARK: Thống kê

    private var statsRow: some View {
        HStack(spacing: 12) {
            StatTile(value: store.completedGoals.count, label: "Đã hoàn thành", icon: "checkmark.seal.fill", color: .green)
            StatTile(value: store.visitedPlaces.count, label: "Nơi đã đến", icon: "mappin.circle.fill", color: .blue)
            StatTile(value: store.memories.count, label: "Tấm ảnh", icon: "photo.fill", color: Theme.accent)
        }
    }

    // MARK: Mục tiêu sắp tới

    private func upcomingCard(_ goal: Goal) -> some View {
        NavigationLink(value: goal.id) {
            HStack(spacing: 14) {
                Image(systemName: goal.category.icon)
                    .font(.title3)
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(goal.category.color.gradient, in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Sắp tới").font(.caption).foregroundStyle(.secondary)
                    Text(goal.title).font(.headline).foregroundStyle(.primary)
                    if let date = goal.targetDate { CountdownBadge(date: date) }
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }

    // MARK: Ngày này năm xưa

    private var onThisDaySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Ngày này năm xưa", systemImage: "clock.arrow.circlepath")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(store.onThisDay) { memory in
                        Button { viewer = memory } label: {
                            CachedImage(url: memory.imageURL, maxPixel: 400)
                                .frame(width: 130, height: 160)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(alignment: .bottomLeading) {
                                    Text(memory.createdAt.viRelative)
                                        .font(.caption2.weight(.semibold))
                                        .padding(6)
                                        .foregroundStyle(.white)
                                }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Kỷ niệm trong ngày

    private func memoryOfDaySection(_ memory: Memory) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Kỷ niệm hôm nay", systemImage: "sparkles")
                .font(.headline)
            Button { viewer = memory } label: {
                CachedImage(url: memory.imageURL, maxPixel: 800)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct StatTile: View {
    let value: Int
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text("\(value)").font(.title2.bold())
            Text(label).font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
