import CoreLocation
import PhotosUI
import SwiftUI

/// Hoàn thành một mục: chụp / chọn ảnh, chọn cảm xúc và viết cảm nhận.
struct AddMemoryView: View {
    let goalID: String
    @EnvironmentObject private var store: CoupleStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var location = LocationProvider()

    @State private var images: [UIImage] = []
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var mood: Mood?
    @State private var text = ""
    @State private var attachLocation = true

    private var goal: Goal? { store.goals.first { $0.id == goalID } }
    private var cameraAvailable: Bool { UIImagePickerController.isSourceTypeAvailable(.camera) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let goal {
                        Text(goal.title).font(.title3.bold())
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Ảnh kỷ niệm").font(.headline)

                        if !images.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(images.indices, id: \.self) { index in
                                        thumbnail(index)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 10) {
                            if cameraAvailable {
                                Button {
                                    showCamera = true
                                } label: {
                                    Label("Chụp ảnh", systemImage: "camera.fill")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            PhotosPicker(selection: $pickerItems, maxSelectionCount: 10, matching: .images) {
                                Label("Chọn từ thư viện", systemImage: "photo.on.rectangle")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)
                        }
                        .controlSize(.large)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cảm xúc của bạn").font(.headline)
                        MoodPicker(selection: $mood)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Cảm nhận").font(.headline)
                        TextField("Hôm nay thế nào? Viết vài dòng nhé…", text: $text, axis: .vertical)
                            .lineLimit(4...10)
                            .padding(12)
                            .background(Theme.card, in: RoundedRectangle(cornerRadius: 14))
                    }

                    Toggle(isOn: $attachLocation) {
                        Label("Lưu vị trí nơi này", systemImage: "location.fill")
                            .font(.subheadline)
                    }
                    .tint(Theme.accent)
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .navigationTitle(goal?.isCompleted == true ? "Thêm kỷ niệm" : "Hoàn thành 🎉")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Huỷ") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") { save() }.fontWeight(.semibold)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { images.append($0) }
                    .ignoresSafeArea()
            }
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    for item in newItems {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            images.append(image)
                        }
                    }
                    pickerItems = []
                }
            }
        }
    }

    private func thumbnail(_ index: Int) -> some View {
        ZStack(alignment: .topTrailing) {
            Image(uiImage: images[index])
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 96)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            Button {
                images.remove(at: index)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.white, .black.opacity(0.6))
                    .font(.title3)
            }
            .padding(4)
        }
    }

    private func save() {
        let photos = images
        let chosenMood = mood
        let feeling = text
        Task {
            var coordinate: CLLocationCoordinate2D?
            if attachLocation {
                coordinate = await location.requestLocation()
            }
            if await store.saveMemory(goalID: goalID, images: photos, mood: chosenMood, text: feeling, coordinate: coordinate) {
                dismiss()
            }
        }
    }
}
