import Foundation
import Observation

enum WorkspaceMode: String, Equatable, Hashable, CaseIterable, Identifiable {
    case sandbox
    case cameraRoll
    case trash

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sandbox: "Sandbox"
        case .cameraRoll: "Camera Roll"
        case .trash: "Trash"
        }
    }
}

enum PhotoFilter: Equatable {
    case all
    case keep
    case delete
}

@MainActor
@Observable
final class PhotoStore {
    var photos: [Photo] = []
    var cameraRollPhotos: [Photo] = []
    var trashedPhotos: [Photo] = []
    var selectedIDs: Set<Photo.ID> = []
    var mode: WorkspaceMode = .sandbox
    var columnCount: Double = 5
    var filter: PhotoFilter = .all
    var cameraRollAccess: PhotoAccess = .unknown
    var isBusy = false
    var errorMessage: String?
    var directory: URL
    var isDragSelecting = false

    private var library: FolderPhotoLibrary
    private var dragAnchorID: Photo.ID?
    private var dragSnapshot: Set<Photo.ID> = []
    private var dragSelects = true
    private var dragDidMove = false

    var workingPhotos: [Photo] {
        switch mode {
        case .sandbox: photos
        case .cameraRoll: cameraRollPhotos
        case .trash: trashedPhotos
        }
    }

    var displayedPhotos: [Photo] {
        switch mode {
        case .sandbox, .cameraRoll:
            let pool = workingPhotos
            switch filter {
            case .all:
                return pool
            case .keep:
                return pool.filter { selectedIDs.contains($0.id) }
            case .delete:
                return pool.filter { !selectedIDs.contains($0.id) }
            }
        case .trash:
            return trashedPhotos
        }
    }

    var selectedCount: Int { selectedIDs.count }

    var pendingDeleteCount: Int {
        max(workingPhotos.count - selectedCount, 0)
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
            selectedIDs = selectedIDs.intersection(Set(photos.map(\.id)))
            normalizeFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func cancel() {
        selectedIDs = []
        filter = .all
    }

    func setWorkspace(_ next: WorkspaceMode) {
        guard mode != next else { return }
        selectedIDs = []
        filter = .all
        mode = next
        if next == .cameraRoll {
            Task { await loadCameraRoll() }
        }
    }

    func openTrash() {
        setWorkspace(mode == .trash ? .sandbox : .trash)
    }

    func setFilter(_ next: PhotoFilter) {
        guard isFilterEnabled(next) else { return }
        filter = next
    }

    func isFilterEnabled(_ filter: PhotoFilter) -> Bool {
        switch filter {
        case .all:
            return !workingPhotos.isEmpty
        case .keep:
            return selectedCount > 0
        case .delete:
            return pendingDeleteCount > 0
        }
    }

    func toggle(_ photo: Photo) {
        if selectedIDs.contains(photo.id) {
            selectedIDs.remove(photo.id)
        } else {
            selectedIDs.insert(photo.id)
        }
        normalizeFilter()
    }

    func handleDragSelect(at photo: Photo) {
        guard mode == .trash || ((mode == .sandbox || mode == .cameraRoll) && filter == .all) else { return }
        if dragAnchorID == nil {
            dragAnchorID = photo.id
            dragSnapshot = selectedIDs
            dragSelects = !selectedIDs.contains(photo.id)
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
        dragSelects = true
        dragDidMove = false
        isDragSelecting = false
        normalizeFilter()
    }

    private func applyDragRange(to currentID: Photo.ID) {
        guard let anchorID = dragAnchorID,
              let start = displayedPhotos.firstIndex(where: { $0.id == anchorID }),
              let end = displayedPhotos.firstIndex(where: { $0.id == currentID })
        else { return }
        var next = dragSnapshot
        for photo in displayedPhotos[min(start, end)...max(start, end)] {
            if dragSelects {
                next.insert(photo.id)
            } else {
                next.remove(photo.id)
            }
        }
        selectedIDs = next
    }

    func selectAll() {
        selectedIDs = Set(workingPhotos.map(\.id))
        normalizeFilter()
    }

    func keep() async {
        guard mode == .sandbox || mode == .cameraRoll, !selectedIDs.isEmpty, !isBusy else { return }
        let toDelete = workingPhotos.filter { !selectedIDs.contains($0.id) }
        isBusy = true
        defer { isBusy = false }
        do {
            if !toDelete.isEmpty {
                switch mode {
                case .sandbox:
                    try library.moveToTrash(toDelete)
                    photos.removeAll { !selectedIDs.contains($0.id) }
                    trashedPhotos = try library.loadTrashedPhotos()
                case .cameraRoll:
                    try await CameraRollLibrary.deletePhotos(toDelete)
                    cameraRollPhotos.removeAll { !selectedIDs.contains($0.id) }
                case .trash:
                    break
                }
            }
            selectedIDs = []
            filter = .all
        } catch is CameraRollError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadCameraRoll() async {
        isBusy = true
        defer { isBusy = false }
        let access = await CameraRollLibrary.requestAccess()
        cameraRollAccess = access
        if access == .authorized {
            cameraRollPhotos = await Task.detached(priority: .userInitiated) {
                CameraRollLibrary.fetchPhotos()
            }.value
        } else {
            cameraRollPhotos = []
        }
        if mode == .cameraRoll {
            selectedIDs = selectedIDs.intersection(Set(cameraRollPhotos.map(\.id)))
            normalizeFilter()
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
            filter = .all
            mode = .sandbox
            photos = try library.loadPhotos()
            trashedPhotos = try library.loadTrashedPhotos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func normalizeFilter() {
        guard mode == .sandbox || mode == .cameraRoll, !isFilterEnabled(filter) else { return }
        filter = .all
    }
}
