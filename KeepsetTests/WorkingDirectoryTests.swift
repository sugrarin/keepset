import Foundation
import Testing
@testable import Keepset

final class WorkingDirectoryTests {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeepsetWorkingDirectoryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit {
        try? FileManager.default.removeItem(at: root)
    }

    @Test func savedFolderIsRestoredWhenItStillExists() {
        #expect(WorkingPhotosDirectory.existingFolder(atPath: root.path) == root)
    }

    @Test func noSavedFolderMeansNoFolder() {
        #expect(WorkingPhotosDirectory.existingFolder(atPath: nil) == nil)
    }

    @Test func missingSavedFolderMeansNoFolder() {
        let gone = root.appendingPathComponent("gone", isDirectory: true)

        #expect(WorkingPhotosDirectory.existingFolder(atPath: gone.path) == nil)
    }

    @Test func aFileIsNotAFolder() throws {
        let file = root.appendingPathComponent("photo.jpg")
        try Data().write(to: file)

        #expect(WorkingPhotosDirectory.existingFolder(atPath: file.path) == nil)
    }
}
