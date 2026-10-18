import Foundation
@testable import Keepset

@MainActor
final class TestEnvironment {
    let root: URL
    let photosDirectory: URL
    let selectionURL: URL
    let defaults: UserDefaults
    let cameraRoll = FakeCameraRoll()

    init(files: [String]) throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeepsetTests-\(UUID().uuidString)", isDirectory: true)
        photosDirectory = root.appendingPathComponent("photos", isDirectory: true)
        selectionURL = root.appendingPathComponent("selections.json")
        defaults = UserDefaults(suiteName: root.lastPathComponent)!
        try FileManager.default.createDirectory(at: photosDirectory, withIntermediateDirectories: true)
        for name in files {
            try Data().write(to: photosDirectory.appendingPathComponent(name))
        }
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    func makeStore(folder: (any PhotoFolder)? = nil) -> PhotoStore {
        PhotoStore(
            folder: folder ?? FolderPhotoLibrary(directory: photosDirectory),
            cameraRoll: cameraRoll,
            selectionStorage: SelectionFile(url: selectionURL),
            defaults: defaults,
            resolveDefaultDirectory: { [photosDirectory] in photosDirectory }
        )
    }

    func remove(_ name: String) throws {
        try FileManager.default.removeItem(at: photosDirectory.appendingPathComponent(name))
    }
}

final class FakeCameraRoll: CameraRoll, @unchecked Sendable {
    var access: PhotoAccess = .authorized
    var photos: [Photo] = []
    private(set) var fetchCount = 0
    private(set) var changeHandler: (@Sendable () -> Void)?

    func requestAccess() async -> PhotoAccess { access }

    func fetchPhotos() -> [Photo] {
        fetchCount += 1
        return photos
    }

    func deletePhotos(_ photos: [Photo]) async throws {}

    func observeChanges(_ onChange: @escaping @Sendable () -> Void) {
        changeHandler = onChange
    }

    static func asset(_ id: String) -> Photo {
        Photo(id: id, source: .asset(id), filename: "", modifiedAt: .distantPast)
    }
}

/// Records whether each disk call ran on the main thread.
final class ThreadRecordingFolder: PhotoFolder, @unchecked Sendable {
    private let wrapped: FolderPhotoLibrary
    private let lock = NSLock()
    private var calls: [Bool] = []

    init(directory: URL) {
        wrapped = FolderPhotoLibrary(directory: directory)
    }

    var directory: URL { wrapped.directory }

    var mainThreadCalls: [Bool] {
        lock.withLock { calls }
    }

    private func record() {
        let isMain = Thread.isMainThread
        lock.withLock { calls.append(isMain) }
    }

    func loadPhotos() throws -> [Photo] { record(); return try wrapped.loadPhotos() }
    func loadTrashedPhotos() throws -> [Photo] { record(); return try wrapped.loadTrashedPhotos() }
    func moveToTrash(_ photos: [Photo]) throws { record(); try wrapped.moveToTrash(photos) }
    func restorePhotos(_ photos: [Photo]) throws { record(); try wrapped.restorePhotos(photos) }
    func emptyTrash() throws { record(); try wrapped.emptyTrash() }
    func resetFromSeed() throws { record(); try wrapped.resetFromSeed() }
}
