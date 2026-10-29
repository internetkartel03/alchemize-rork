import SwiftUI
import PhotosUI
import SwiftData

/// Image-picking row used by manifestation and food scan: library + camera.
struct PhotoSourceButtons: View {
    var onImage: (UIImage) -> Void
    @State private var item: PhotosPickerItem?
    @State private var showCamera = false

    var body: some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: $item, matching: .images) {
                Label("Library", systemImage: "photo.on.rectangle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.12)))
            }
            .buttonStyle(.squish)
            Button {
                Haptics.tap()
                showCamera = true
            } label: {
                Label("Camera", systemImage: "camera.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(AZ.violet.opacity(0.35), in: .rect(cornerRadius: 14))
                    .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(AZ.violetLight.opacity(0.4)))
            }
            .buttonStyle(.squish)
        }
        .onChange(of: item) { _, newItem in
            guard let newItem else { return }
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self), let img = UIImage(data: data) {
                    onImage(img)
                }
                item = nil
            }
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraCaptureView(onCapture: onImage)
        }
    }
}

/// Sheet header with Cancel / Save.
struct SheetToolbar: ToolbarContent {
    var saveTitle: String = "Save"
    var canSave: Bool
    var onCancel: () -> Void
    var onSave: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel", action: onCancel)
        }
        ToolbarItem(placement: .confirmationAction) {
            Button(saveTitle) {
                Haptics.success()
                onSave()
            }
            .fontWeight(.semibold)
            .disabled(!canSave)
        }
    }
}

/// Dark scrolling form canvas for sheets.
struct SheetCanvas<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(
            LinearGradient(colors: [AZ.night, AZ.deep], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
        )
    }
}

/// Reads or creates a singleton model (profile/notes).
extension ModelContext {
    func singleton<T: PersistentModel>(_ make: () -> T) -> T {
        if let existing = try? fetch(FetchDescriptor<T>()).first { return existing }
        let new = make()
        insert(new)
        return new
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }
}
