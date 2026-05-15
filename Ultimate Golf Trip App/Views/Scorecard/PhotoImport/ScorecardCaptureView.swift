import SwiftUI
import PhotosUI
import UIKit

/// Lets the user pick a scorecard photo from the library or take a new one with the camera.
struct ScorecardCaptureView: View {
    let onImage: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var photoItem: PhotosPickerItem?
    @State private var showingCamera = false
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "doc.viewfinder")
                .font(.system(size: 80, weight: .light))
                .foregroundStyle(Theme.primary)

            VStack(spacing: 8) {
                Text("Import from photo")
                    .font(.title2.weight(.bold))
                Text("Snap a clear photo of the filled-out scorecard. Make sure the hole-number row (1–9 / 10–18) is fully visible and the card is roughly flat.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()

            VStack(spacing: 12) {
                Button {
                    showingCamera = true
                } label: {
                    Label("Take Photo", systemImage: "camera.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(BoldPrimaryButtonStyle())

                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    Label("Choose from Library", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.cardBackground)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.border, lineWidth: 2))
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 24)
        }
        .navigationTitle("Photo Import")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel", action: onCancel)
            }
        }
        .alert("Couldn't load photo", isPresented: Binding(get: { loadError != nil }, set: { if !$0 { loadError = nil } })) {
            Button("OK") { loadError = nil }
        } message: {
            Text(loadError ?? "")
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let data = try await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        await MainActor.run { onImage(img) }
                    } else {
                        await MainActor.run { loadError = "That file doesn't look like an image." }
                    }
                } catch {
                    await MainActor.run { loadError = error.localizedDescription }
                }
                await MainActor.run { photoItem = nil }
            }
        }
        .sheet(isPresented: $showingCamera) {
            CameraPicker { image in
                showingCamera = false
                if let image { onImage(image) }
            }
            .ignoresSafeArea()
        }
    }
}

/// Thin UIKit bridge for the camera. PhotosPicker covers the library case;
/// camera capture still needs UIImagePickerController.
struct CameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = UIImagePickerController.isSourceTypeAvailable(.camera) ? .camera : .photoLibrary
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(completion: completion) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let completion: (UIImage?) -> Void
        init(completion: @escaping (UIImage?) -> Void) { self.completion = completion }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            let image = info[.originalImage] as? UIImage
            completion(image)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
        }
    }
}
