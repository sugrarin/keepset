import SwiftUI

struct PhotoGridView: View {
    let photos: [Photo]
    let columns: Int
    let selectedIDs: Set<Photo.ID>
    let isSelectMode: Bool
    let onToggle: (Photo) -> Void
    let onPreview: (Photo?) -> Void

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
                        isSelectMode: isSelectMode,
                        columnCount: columns,
                        onToggle: { onToggle(photo) },
                        onPreview: { hovering in
                            onPreview(hovering ? photo : nil)
                        }
                    )
                }
            }
            .padding(3)
            .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
    }
}
