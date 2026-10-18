import Foundation
import Observation

enum WorkspaceMode: String, Equatable, Hashable, CaseIterable, Identifiable {
    case folder
    case cameraRoll
    case trash

    var id: String { rawValue }
}

enum PhotoFilter: Equatable {
    case all
    case keep
    case delete
}

enum TileShape: String {
    case square
    case original
}

struct Deletion {
    let trashed: [Photo]
    let kept: Set<Photo.ID>

    var count: Int { trashed.count }
}

@MainActor
@Observable
final class PhotoStore {
    var photos: [Photo] = []
    var cameraRollPhotos: [Photo] = []
    var trashedPhotos: [Photo] = []
    var mode: WorkspaceMode = .folder
    var columnCount: Double = 5
    var filter: PhotoFilter = .all
    var cameraRollAccess: PhotoAccess = .unknown
    var isBusy = false
    var errorMessage: String?
    var isDragSelecting = false
    private(set) var lastDeletion: Deletion?
    var tileShape: TileShape {
        didSet { defaults.set(tileShape.rawValue, forKey: Self.tileShapeKey) }
    }

    /// Hearts per workspace, keyed by `selectionKey(for:)`, so switching folders keeps each one's work.
    private var selections: [String: Set<Photo.ID>]
    private var folder: (any PhotoFolder)?
    private let cameraRoll: any CameraRoll
    private let selectionStorage: any SelectionStorage
    private let defaults: UserDefaults
    private var isCameraRollLoaded = false
    private var isObservingCameraRoll = false
    private var dragAnchorID: Photo.ID?
    private var dragSnapshot: Set<Photo.ID> = []
    private var dragSelects = true
    private var dragDidMove = false

    private static let tileShapeKey = "tileShape"
    static let photosFolderKey = "photosFolder"

    var directory: URL? { folder?.directory }

    var hasFolder: Bool { folder != nil }

    var selectedIDs: Set<Photo.ID> {
        get { selections[selectionKey(for: mode)] ?? [] }
        set { setSelection(newValue, for: mode) }
    }

    var workingPhotos: [Photo] {
        switch mode {
        case .folder: photos
        case .cameraRoll: cameraRollPhotos
        case .trash: trashedPhotos
        }
    }

    var displayedPhotos: [Photo] {
        switch mode {
        case .folder, .cameraRoll:
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

    init(
        folder: (any PhotoFolder)?,
        cameraRoll: any CameraRoll,
        selectionStorage: any SelectionStorage,
        defaults: UserDefaults
    ) {
        self.folder = folder
        self.cameraRoll = cameraRoll
        self.selectionStorage = selectionStorage
        self.defaults = defaults
        self.selections = selectionStorage.load()
        self.tileShape = defaults.string(forKey: Self.tileShapeKey).flatMap(TileShape.init) ?? .square
    }

    convenience init() {
        self.init(
            folder: WorkingPhotosDirectory
                .existingFolder(atPath: UserDefaults.standard.string(forKey: Self.photosFolderKey))
                .map { FolderPhotoLibrary(directory: $0) },
            cameraRoll: CameraRollLibrary(),
            selectionStorage: SelectionFile.standard,
            defaults: .standard
        )
    }

    func load() async {
        isBusy = true
        defer { isBusy = false }
        await reloadFolder()
    }

    func title(for workspace: WorkspaceMode) -> String {
        switch workspace {
        case .folder: directory?.lastPathComponent ?? "No Folder"
        case .cameraRoll: "Camera Roll"
        case .trash: "Trash"
        }
    }

    func chooseFolder(_ url: URL) async {
        guard !isBusy else { return }
        defaults.set(url.path, forKey: Self.photosFolderKey)
        folder = FolderPhotoLibrary(directory: url)
        lastDeletion = nil
        filter = .all
        mode = .folder
        photos = []
        trashedPhotos = []
        await load()
    }

    func cancel() {
        selectedIDs = []
        filter = .all
        saveSelections()
    }

    func setWorkspace(_ next: WorkspaceMode) {
        guard mode != next else { return }
        filter = .all
        mode = next
        if next == .cameraRoll {
            Task { await loadCameraRollIfNeeded() }
        }
    }

    func openTrash() {
        setWorkspace(mode == .trash ? .folder : .trash)
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
        saveSelections()
    }

    func handleDragSelect(at photo: Photo) {
        guard mode == .trash || ((mode == .folder || mode == .cameraRoll) && filter == .all) else { return }
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
        saveSelections()
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
        saveSelections()
    }

    func keep() async {
        guard mode == .folder || mode == .cameraRoll, !selectedIDs.isEmpty, !isBusy else { return }
        // Captured up front: the user may switch folders while the move is in flight.
        let workspace = mode
        let keptIDs = selectedIDs
        let toDelete = workingPhotos.filter { !keptIDs.contains($0.id) }
        let trashedBefore = Set(trashedPhotos.map(\.id))
        isBusy = true
        defer { isBusy = false }
        do {
            if !toDelete.isEmpty {
                switch workspace {
                case .folder:
                    if let folder {
                        try await offMain { try folder.moveToTrash(toDelete) }
                    }
                case .cameraRoll:
                    try await cameraRoll.deletePhotos(toDelete)
                    cameraRollPhotos.removeAll { !keptIDs.contains($0.id) }
                case .trash:
                    break
                }
            }
            setSelection([], for: workspace)
            if mode == workspace {
                filter = .all
            }
        } catch is CameraRollError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
        if workspace == .folder {
            await reloadFolder()
            let moved = trashedPhotos.filter { !trashedBefore.contains($0.id) }
            lastDeletion = moved.isEmpty ? nil : Deletion(trashed: moved, kept: keptIDs)
        }
        saveSelections()
    }

    func undoDelete() async {
        guard let deletion = lastDeletion, let folder, !isBusy else { return }
        lastDeletion = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await offMain { try folder.restorePhotos(deletion.trashed) }
        } catch {
            errorMessage = error.localizedDescription
        }
        await reloadFolder()
        setSelection(deletion.kept, for: .folder)
        saveSelections()
    }

    func loadCameraRollIfNeeded() async {
        guard !isCameraRollLoaded else { return }
        await loadCameraRoll()
    }

    func loadCameraRoll() async {
        isBusy = true
        defer { isBusy = false }
        let access = await cameraRoll.requestAccess()
        cameraRollAccess = access
        guard access == .authorized else {
            cameraRollPhotos = []
            return
        }
        if !isObservingCameraRoll {
            isObservingCameraRoll = true
            cameraRoll.observeChanges { [weak self] in
                guard let self else { return }
                Task { @MainActor in await self.cameraRollDidChange() }
            }
        }
        await fetchCameraRoll()
    }

    func cameraRollDidChange() async {
        guard isCameraRollLoaded else { return }
        await fetchCameraRoll()
    }

    func restoreSelected() async {
        guard mode == .trash, let folder, !selectedIDs.isEmpty, !isBusy else { return }
        lastDeletion = nil
        let toRestore = trashedPhotos.filter { selectedIDs.contains($0.id) }
        isBusy = true
        defer { isBusy = false }
        do {
            try await offMain { try folder.restorePhotos(toRestore) }
            setSelection([], for: .trash)
        } catch {
            errorMessage = error.localizedDescription
        }
        await reloadFolder()
        saveSelections()
    }

    func emptyTrash() async {
        guard mode == .trash, let folder, !isBusy else { return }
        lastDeletion = nil
        isBusy = true
        defer { isBusy = false }
        do {
            try await offMain { try folder.emptyTrash() }
            setSelection([], for: .trash)
        } catch {
            errorMessage = error.localizedDescription
        }
        await reloadFolder()
        saveSelections()
    }

    private func reloadFolder() async {
        guard let folder else {
            photos = []
            trashedPhotos = []
            return
        }
        do {
            let (live, trashed) = try await offMain {
                (try folder.loadPhotos(), try folder.loadTrashedPhotos())
            }
            photos = live
            trashedPhotos = trashed
            pruneSelection(for: .folder, to: live)
            pruneSelection(for: .trash, to: trashed)
            normalizeFilter()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchCameraRoll() async {
        let cameraRoll = cameraRoll
        cameraRollPhotos = await Task.detached(priority: .userInitiated) {
            cameraRoll.fetchPhotos()
        }.value
        isCameraRollLoaded = true
        pruneSelection(for: .cameraRoll, to: cameraRollPhotos)
        normalizeFilter()
    }

    private func offMain<T: Sendable>(_ work: @escaping @Sendable () throws -> T) async throws -> T {
        try await Task.detached(priority: .userInitiated, operation: work).value
    }

    private func selectionKey(for workspace: WorkspaceMode) -> String {
        let path = directory?.path ?? ""
        return switch workspace {
        case .folder: "folder:\(path)"
        case .trash: "trash:\(path)"
        case .cameraRoll: "cameraRoll"
        }
    }

    private func setSelection(_ ids: Set<Photo.ID>, for workspace: WorkspaceMode) {
        // A fresh selection means the user moved on; undoing would overwrite it.
        if workspace == .folder, !ids.isEmpty {
            lastDeletion = nil
        }
        selections[selectionKey(for: workspace)] = ids.isEmpty ? nil : ids
    }

    private func pruneSelection(for workspace: WorkspaceMode, to existing: [Photo]) {
        let key = selectionKey(for: workspace)
        guard let selected = selections[key] else { return }
        let kept = selected.intersection(existing.map(\.id))
        guard kept != selected else { return }
        setSelection(kept, for: workspace)
        saveSelections()
    }

    private func saveSelections() {
        selectionStorage.save(selections)
    }

    private func normalizeFilter() {
        guard mode == .folder || mode == .cameraRoll, !isFilterEnabled(filter) else { return }
        filter = .all
    }
}
