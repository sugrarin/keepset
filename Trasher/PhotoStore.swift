import Foundation
import Observation

enum WorkspaceMode: Equatable {
    case select
    case confirm
    case trash
}

@MainActor
@Observable
final class PhotoStore {
    var photos: [Photo] = []
    var trashedPhotos: [Photo] = []
    var selectedIDs: Set<Photo.ID> = []
    var mode: WorkspaceMode = .select
    var columnCount: Double = 5
    var isBusy = false
    var errorMessage: String?
    var directory: URL
    var isDragSelecting = false

    private var library: FolderPhotoLibrary
    private var reviewIDs: Set<Photo.ID> = []
    private var dragAnchorID: Photo.ID?
    private var dragSnapshot: Set<Photo.ID> = []
    private var dragDidMove = false

    var displayedPhotos: [Photo] {
        switch mode {
        case .select:
            return photos
        case .confirm:
            return photos.filter { reviewIDs.contains($0.id) }
        case .trash:
            return trashedPhotos
        }
    }

    var selectedCount: Int { selectedIDs.count }

    var pendingDeleteCount: Int {
        max(photos.count - selectedCount, 0)
    }

    var columns: Int {
        Int(columnCount.rounded())
    }

    var trashedCount: Int { trashedPhotos.count }

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
            trashedPhotos = try library.loadTrashedPhotos()
            selectedIDs = selectedIDs.intersection(Set(displayedPhotos.map(\.id)))
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
            reviewIDs = []
        case .trash:
            selectedIDs = []
            mode = .select
        }
    }

    func openTrash() {
        guard mode != .confirm else { return }
        selectedIDs = []
        mode = .trash
    }

    func toggle(_ photo: Photo) {
        switch mode {
        case .select, .trash:
            break
        case .confirm:
            guard reviewIDs.contains(photo.id) else { return }
        }
        if selectedIDs.contains(photo.id) {
            selectedIDs.remove(photo.id)
        } else {
            selectedIDs.insert(photo.id)
        }
    }

    func handleDragSelect(at photo: Photo) {
        guard mode == .select || mode == .trash else { return }
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
        selectedIDs = Set(displayedPhotos.map(\.id))
    }

    func keep() {
        guard mode == .select, !selectedIDs.isEmpty else { return }
        reviewIDs = selectedIDs
        mode = .confirm
    }

    func confirmKeep() async {
        guard mode == .confirm else { return }
        let toDelete = photos.filter { !selectedIDs.contains($0.id) }
        isBusy = true
        defer { isBusy = false }
        do {
            try library.moveToTrash(toDelete)
            photos.removeAll { !selectedIDs.contains($0.id) }
            trashedPhotos = try library.loadTrashedPhotos()
            selectedIDs = []
            reviewIDs = []
            mode = .select
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func restoreSelected() async {
        guard mode == .trash, !selectedIDs.isEmpty else { return }
        let toRestore = trashedPhotos.filter { selectedIDs.contains($0.id) }
        isBusy = true
        defer { isBusy = false }
        do {
            try library.restorePhotos(toRestore)
            photos = try library.loadPhotos()
            trashedPhotos = try library.loadTrashedPhotos()
            selectedIDs = []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func emptyTrash() async {
        guard mode == .trash else { return }
        isBusy = true
        defer { isBusy = false }
        do {
            try library.emptyTrash()
            trashedPhotos = []
            selectedIDs = []
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
            reviewIDs = []
            mode = .select
            photos = try library.loadPhotos()
            trashedPhotos = try library.loadTrashedPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
