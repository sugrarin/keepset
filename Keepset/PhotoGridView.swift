import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    let columns: Int
    let tileShape: TileShape
    let selectedIDs: Set<Photo.ID>
    let isDragSelecting: Bool
    let onToggle: (Photo) -> Void
    let onPreview: (Photo?) -> Void
    let onDragSelect: (Photo) -> Void
    let onDragSelectEnd: () -> Void

    @State private var gridWidth: CGFloat = 0

    private static let spacing: CGFloat = 3
    private static let inset: CGFloat = 3

    private var items: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: Self.spacing), count: max(columns, 1))
    }

    private var geometry: GridGeometry {
        GridGeometry(width: gridWidth, columns: max(columns, 1), spacing: Self.spacing, inset: Self.inset)
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: items, spacing: Self.spacing) {
                ForEach(photos) { photo in
                    PhotoCell(
                        photo: photo,
                        isSelected: selectedIDs.contains(photo.id),
                        isDragSelecting: isDragSelecting,
                        columnCount: columns,
                        tileShape: tileShape,
                        onToggle: { onToggle(photo) },
                        onPreview: { hovering in
                            onPreview(hovering ? photo : nil)
                        },
                        onDragChanged: handleDragChanged,
                        onDragEnded: onDragSelectEnd
                    )
                }
            }
            .padding(Self.inset)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { gridWidth = $0 }
            .coordinateSpace(name: "photoGrid")
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }

    private func handleDragChanged(_ location: CGPoint) {
        guard let index = geometry.index(at: location, count: photos.count) else { return }
        onDragSelect(photos[index])
    }
}
