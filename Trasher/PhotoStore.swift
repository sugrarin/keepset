import Foundation
import Observation

enum WorkspaceMode: Equatable {
    case select
    case confirm
}

@MainActor
@Observable
final class PhotoStore {
    var photos: [Photo] = []
    var selectedIDs: Set<Photo.ID> = []
    var mode: WorkspaceMode = .select
    var columnCount: Double = 5
    var isBusy = false
    var errorMessage: String?
    var directory: URL
    var isDragSelecting = false

    private var library: FolderPhotoLibrary
    private var dragAnchorID: Photo.ID?
    private var dragSnapshot: Set<Photo.ID> = []
    private var dragDidMove = false

    var displayedPhotos: [Photo] {
        switch mode {
        case .select:
            return photos
        case .confirm:
            return photos.filter { selectedIDs.contains($0.id) }
        }
    }

    var selectedCount: Int { selectedIDs.count }

    var pendingDeleteCount: Int {
        max(photos.count - selectedCount, 0)
    }

    var columns: Int {
        Int(columnCount.rounded())
    }

    init() {
        let directory = WorkingPhotosDirectory.resolve()
        self.directory = directory
        self.library = FolderPhotoLibrary(directory: directory)
    }

    func load() async {
        isBusy = true
        defer { isBusy = false }
        do {
            photos = try library.loadPhotos()
            selectedIDs = selectedIDs.intersection(Set(photos.map(\.id)))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        switch mode {
        case .select:
            selectedIDs = []
        case .confirm:
            mode = .select
        }
    }

    func toggle(_ photo: Photo) {
        guard mode == .select else { return }
        if selectedIDs.contains(photo.id) {
            selectedIDs.remove(photo.id)
        } else {
            selectedIDs.insert(photo.id)
        }
    }

    func handleDragSelect(at photo: Photo) {
        guard mode == .select else { return }
        if dragAnchorID == nil {
            dragAnchorID = photo.id
            dragSnapshot = selectedIDs
            dragDidMove = false
            return
        }
        if photo.id != dragAnchorID {
            dragDidMove = true
            isDragSelecting = true
        }
        guard dragDidMove else { return }
        applyDragRange(to: photo.id)
    }

    func endDragSelect() {
        guard let anchorID = dragAnchorID else { return }
        if !dragDidMove, let photo = displayedPhotos.first(where: { $0.id == anchorID }) {
            toggle(photo)
        }
        dragAnchorID = nil
        dragSnapshot = []
        dragDidMove = false
        isDragSelecting = false
    }

    private func applyDragRange(to currentID: Photo.ID) {
        guard let anchorID = dragAnchorID,
              let start = displayedPhotos.firstIndex(where: { $0.id == anchorID }),
              let end = displayedPhotos.firstIndex(where: { $0.id == currentID })
        else { return }
        var next = dragSnapshot
        for photo in displayedPhotos[min(start, end)...max(start, end)] {
            next.insert(photo.id)
        }
        selectedIDs = next
    }

    func selectAll() {
        guard mode == .select else { return }
        selectedIDs = Set(photos.map(\.id))
    }

    func keep() {
        guard mode == .select, !selectedIDs.isEmpty else { return }
        mode = .confirm
    }

    func confirmKeep() async {
        guard mode == .confirm, !selectedIDs.isEmpty else { return }
        let toDelete = photos.filter { !selectedIDs.contains($0.id) }
        isBusy = true
        defer { isBusy = false }
        do {
            try library.deletePhotos(toDelete)
            photos.removeAll { !selectedIDs.contains($0.id) }
            selectedIDs = []
            mode = .select
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func resetSandbox() async {
        isBusy = true
        defer { isBusy = false }
        do {
            try library.resetFromSeed()
            selectedIDs = []
            mode = .select
            photos = try library.loadPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
