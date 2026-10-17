import SwiftUI

struct PreviewOverlay: View {
    let photo: Photo
    @State private var image: CGImage?
    @State private var assetFilename: String?

    var body: some View {
        ZStack {
            Theme.canvas.opacity(0.88)

            VStack(spacing: 12) {
                Group {
                    if let image {
                        Image(decorative: image, scale: 1)
                            .resizable()
                            .scaledToFit()
                            .shadow(color: .black.opacity(0.5), radius: 28, y: 12)
                    } else {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Text(assetFilename ?? photo.filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .padding(.bottom, 18)
            }
            .padding(36)
        }
        .ignoresSafeArea()
        .task(id: photo.id) {
            image = await ThumbnailLoader.shared.image(for: photo, maxPixel: 2200)
        }
        .task(id: photo.id) {
            guard case .asset(let identifier) = photo.source else { return }
            assetFilename = await Task.detached {
                CameraRollLibrary.originalFilename(for: identifier)
            }.value
        }
    }
}
