import SwiftUI

struct PhotoCell: View {
    let photo: Photo
    let isSelected: Bool
    let isDragSelecting: Bool
    let columnCount: Int
    let onToggle: () -> Void
    let onPreview: (Bool) -> Void
    let onDragChanged: (CGPoint) -> Void
    let onDragEnded: () -> Void

    @State private var hovering = false
    @State private var image: CGImage?

    private var maxPixel: Int {
        switch columnCount {
        case ...3: 900
        case 4...6: 640
        default: 420
        }
    }

    var body: some View {
        Theme.canvas
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Theme.surface)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Theme.accent, lineWidth: 4)
                }
            }
            .overlay(alignment: .topTrailing) {
                SelectionHeart(
                    isSelected: isSelected,
                    isHovering: hovering && !isDragSelecting
                )
                .padding(8)
            }
            .overlay(alignment: .bottom) {
                LoupeButton(onPreview: onPreview)
                    .padding(.bottom, 8)
                    .opacity(hovering && !isDragSelecting ? 1 : 0)
                    .offset(y: hovering && !isDragSelecting ? 0 : 4)
                    .allowsHitTesting(!isDragSelecting)
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .scaleEffect(isSelected ? 0.97 : 1)
            .onHover { hovering = $0 }
            .onTapGesture(perform: onToggle)
            .gesture(
                DragGesture(minimumDistance: 4, coordinateSpace: .named("photoGrid"))
                    .onChanged { value in
                        onDragChanged(value.startLocation)
                        onDragChanged(value.location)
                    }
                    .onEnded { _ in
                        onDragEnded()
                    }
            )
            .animation(.easeOut(duration: 0.12), value: hovering)
            .animation(.easeOut(duration: 0.12), value: isSelected)
            .task(id: "\(photo.id)-\(maxPixel)") {
                image = await ThumbnailLoader.shared.image(for: photo, maxPixel: maxPixel)
            }
    }
}

private struct SelectionHeart: View {
    let isSelected: Bool
    let isHovering: Bool

    var body: some View {
        Image(systemName: isSelected ? "heart.fill" : "heart")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(isSelected ? Theme.accent : .white)
            .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
            .opacity(isSelected || isHovering ? 1 : 0)
            .accessibilityHidden(!isSelected && !isHovering)
    }
}

private struct LoupeButton: View {
    let onPreview: (Bool) -> Void
    @State private var previewTask: Task<Void, Never>?

    var body: some View {
        Image(systemName: "plus.magnifyingglass")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 28, height: 28)
            .background(.black.opacity(0.48), in: Circle())
            .overlay {
                Circle().stroke(.white.opacity(0.22), lineWidth: 1)
            }
            .help("Preview")
            .onHover { inside in
                previewTask?.cancel()
                if inside {
                    previewTask = Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(120))
                        guard !Task.isCancelled else { return }
                        onPreview(true)
                    }
                } else {
                    onPreview(false)
                }
            }
            .onDisappear {
                previewTask?.cancel()
                onPreview(false)
            }
            .highPriorityGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in }
                    .onEnded { _ in }
            )
    }
}
