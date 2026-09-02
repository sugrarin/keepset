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
        Color.black
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(.white.opacity(0.06))
                }
            }
            .clipped()
            .overlay {
                if isSelected {
                    Rectangle()
                        .strokeBorder(.white, lineWidth: 2)
                }
            }
            .overlay(alignment: .topTrailing) {
                SelectionMarker(isSelected: isSelected)
                    .padding(8)
            }
            .overlay(alignment: .bottom) {
                LoupeButton(onPreview: onPreview)
                    .padding(.bottom, 8)
                    .opacity(hovering && !isDragSelecting ? 1 : 0)
                    .offset(y: hovering && !isDragSelecting ? 0 : 4)
                    .allowsHitTesting(!isDragSelecting)
            }
            .contentShape(Rectangle())
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
                image = await ThumbnailLoader.shared.image(for: photo.url, maxPixel: maxPixel)
            }
    }
}

private struct SelectionMarker: View {
    let isSelected: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(isSelected ? Color(red: 0.22, green: 0.72, blue: 0.42) : Color.black.opacity(0.38))
            Circle()
                .strokeBorder(.white.opacity(isSelected ? 1 : 0.9), lineWidth: 1.6)
            if isSelected {
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: 22, height: 22)
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
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
