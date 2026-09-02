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

    private var library: FolderPhotoLibrary

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
