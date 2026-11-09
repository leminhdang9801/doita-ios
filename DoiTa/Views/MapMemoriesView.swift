import MapKit
import SwiftUI

/// Bản đồ các nơi hai đứa đã đến (mục có tọa độ).
struct MapMemoriesView: View {
    @EnvironmentObject private var store: CoupleStore
    @State private var selectedGoalID: String?
    @State private var position: MapCameraPosition = .automatic

    private var pins: [Goal] { store.goals.filter(\.hasCoordinate) }

    private var selectedGoal: Goal? {
        guard let id = selectedGoalID else { return nil }
        return store.goals.first { $0.id == id }
    }

    var body: some View {
        NavigationStack {
            Group {
                if pins.isEmpty {
                    ContentUnavailableView {
                        Label("Chưa có nơi nào trên bản đồ", systemImage: "map")
                    } description: {
                        Text("Khi hai đứa lưu kỷ niệm có bật vị trí, hoặc thêm địa điểm có tên, nơi đó sẽ hiện lên đây 💕")
                    }
                } else {
                    mapContent
                }
            }
            .background(Theme.background)
            .navigationTitle("Bản đồ")
            .navigationDestination(for: String.self) { GoalDetailView(goalID: $0) }
        }
    }

    private var mapContent: some View {
        Map(position: $position, selection: $selectedGoalID) {
            ForEach(pins) { goal in
                Marker(goal.title, systemImage: goal.category.icon, coordinate: coordinate(goal))
                    .tint(goal.category.color)
                    .tag(goal.id)
            }
        }
        .mapStyle(.standard(elevation: .realistic))
        .safeAreaInset(edge: .bottom) {
            if let goal = selectedGoal {
                selectionCard(goal)
                    .padding()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: selectedGoalID)
    }

    private func selectionCard(_ goal: Goal) -> some View {
        NavigationLink(value: goal.id) {
            HStack(spacing: 12) {
                let photos = store.memories(for: goal.id)
                if let first = photos.first {
                    CachedImage(url: first.imageURL, maxPixel: 200)
                        .frame(width: 54, height: 54)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                } else {
                    Image(systemName: goal.category.icon)
                        .foregroundStyle(.white)
                        .frame(width: 54, height: 54)
                        .background(goal.category.color.gradient, in: RoundedRectangle(cornerRadius: 10))
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(goal.title).font(.headline).foregroundStyle(.primary)
                    if !goal.placeName.isEmpty {
                        Text(goal.placeName).font(.caption).foregroundStyle(.secondary)
                    }
                    Text("\(photos.count) ảnh").font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.footnote).foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func coordinate(_ goal: Goal) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: goal.latitude ?? 0, longitude: goal.longitude ?? 0)
    }
}
