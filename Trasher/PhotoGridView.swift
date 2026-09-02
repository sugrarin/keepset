import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    let columns: Int
    let selectedIDs: Set<Photo.ID>
    let isDragSelecting: Bool
    let dimsIfUnselected: Bool
    let onToggle: (Photo) -> Void
    let onPreview: (Photo?) -> Void
    let onDragSelect: (Photo) -> Void
    let onDragSelectEnd: () -> Void

    @State private var cellFrames: [Photo.ID: CGRect] = [:]

    private var items: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 3), count: max(columns, 1))
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: items, spacing: 3) {
                ForEach(photos) { photo in
                    PhotoCell(
                        photo: photo,
                        isSelected: selectedIDs.contains(photo.id),
                        isDragSelecting: isDragSelecting,
                        dimsIfUnselected: dimsIfUnselected,
                        columnCount: columns,
                        onToggle: { onToggle(photo) },
                        onPreview: { hovering in
                            onPreview(hovering ? photo : nil)
                        },
                        onDragChanged: handleDragChanged,
                        onDragEnded: onDragSelectEnd
                    )
                    .background {
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: CellFramesKey.self,
                                value: [photo.id: geo.frame(in: .named("photoGrid"))]
                            )
                        }
                    }
                }
            }
            .padding(3)
            .padding(.bottom, 24)
            .coordinateSpace(name: "photoGrid")
            .onPreferenceChange(CellFramesKey.self) { cellFrames = $0 }
        }
        .scrollContentBackground(.hidden)
    }

    private func handleDragChanged(_ location: CGPoint) {
        guard let id = cellFrames.first(where: { $0.value.contains(location) })?.key,
              let photo = photos.first(where: { $0.id == id })
        else { return }
        onDragSelect(photo)
    }
}

private struct CellFramesKey: PreferenceKey {
    static let defaultValue: [Photo.ID: CGRect] = [:]

    static func reduce(value: inout [Photo.ID: CGRect], nextValue: () -> [Photo.ID: CGRect]) {
        value.merge(nextValue(), uniquingKeysWith: { $1 })
    }
}
