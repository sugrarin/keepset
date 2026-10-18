import Foundation
import Testing
@testable import Keepset

final class WorkingDirectoryTests {
    let root: URL
    let seed: URL
    let support: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeepsetWorkingDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        seed = root.appendingPathComponent("Keepset.app/Contents/Resources/photos", isDirectory: true)
        support = root.appendingPathComponent("Application Support/Keepset/photos", isDirectory: true)
        try FileManager.default.createDirectory(at: seed, withIntermediateDirectories: true)
        try Data().write(to: seed.appendingPathComponent("seed.jpg"))
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    private func resolve(environment: [String: String] = [:], savedFolder: String? = nil) -> URL {
        WorkingPhotosDirectory.resolve(
            environment: environment,
            savedFolder: savedFolder,
            seed: seed,
            applicationSupport: support
        )
    }

    private func names(in folder: URL) throws -> Set<String> {
        Set(try FileManager.default.contentsOfDirectory(atPath: folder.path))
    }

    private func isMarked(_ folder: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: folder.appendingPathComponent(WorkingPhotosDirectory.sandboxMarker).path
        )
    }

    @Test func ignoresPhotosFolderNextToTheApp() throws {
        let userPhotos = root.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: userPhotos, withIntermediateDirectories: true)
        try Data().write(to: userPhotos.appendingPathComponent("family.jpg"))

        #expect(resolve() == support)
    }

    @Test func seedsAndMarksApplicationSupportFolder() throws {
        let folder = resolve()

        #expect(try names(in: folder).contains("seed.jpg"))
        #expect(isMarked(folder))
    }

    @Test func environmentOverrideWins() throws {
        let custom = root.appendingPathComponent("custom", isDirectory: true)

        let folder = resolve(environment: ["KEEPSET_PHOTOS_DIR": custom.path])

        #expect(folder == custom)
        #expect(isMarked(custom))
    }

    @Test func existingEnvironmentFolderIsNotMarked() throws {
        let existing = root.appendingPathComponent("existing", isDirectory: true)
        try FileManager.default.createDirectory(at: existing, withIntermediateDirectories: true)

        _ = resolve(environment: ["KEEPSET_PHOTOS_DIR": existing.path])

        #expect(!isMarked(existing))
    }

    @Test func savedFolderReplacesApplicationSupport() throws {
        let chosen = root.appendingPathComponent("chosen", isDirectory: true)
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)

        #expect(resolve(savedFolder: chosen.path) == chosen)
    }

    @Test func savedFolderIsNeverMarkedOrSeeded() throws {
        let chosen = root.appendingPathComponent("chosen", isDirectory: true)
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)

        _ = resolve(savedFolder: chosen.path)

        #expect(!isMarked(chosen))
        #expect(try names(in: chosen).isEmpty)
    }

    @Test func missingSavedFolderFallsBackToApplicationSupport() {
        let gone = root.appendingPathComponent("gone", isDirectory: true)

        #expect(resolve(savedFolder: gone.path) == support)
    }

    @Test func environmentOverrideBeatsSavedFolder() throws {
        let chosen = root.appendingPathComponent("chosen", isDirectory: true)
        let custom = root.appendingPathComponent("custom", isDirectory: true)
        try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)

        #expect(resolve(environment: ["KEEPSET_PHOTOS_DIR": custom.path], savedFolder: chosen.path) == custom)
    }

    @Test func resetRefusesUnmarkedFolder() throws {
        let folder = root.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data().write(to: folder.appendingPathComponent("family.jpg"))
        let library = FolderPhotoLibrary(directory: folder, seed: seed)

        #expect(throws: PhotoLibraryError.self) { try library.resetFromSeed() }
        #expect(try names(in: folder) == ["family.jpg"])
    }

    @Test func resetReplacesPhotosInMarkedFolder() throws {
        let folder = resolve()
        try Data().write(to: folder.appendingPathComponent("old.jpg"))
        let library = FolderPhotoLibrary(directory: folder, seed: seed)

        try library.resetFromSeed()

        #expect(try names(in: folder) == ["seed.jpg", WorkingPhotosDirectory.sandboxMarker])
    }

    @Test func repositoryPhotosFolderIsMarked() {
        let repoPhotos = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("photos", isDirectory: true)

        #expect(isMarked(repoPhotos))
    }
}
