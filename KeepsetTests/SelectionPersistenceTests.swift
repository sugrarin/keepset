import Foundation
import Testing
@testable import Keepset

@MainActor
struct SelectionPersistenceTests {
    @Test func selectionSurvivesRelaunch() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])

        let relaunched = env.makeStore()
        await relaunched.load()

        #expect(relaunched.selectedIDs == [store.photos[0].id])
    }

    @Test func dragSelectionSurvivesRelaunch() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg", "c.jpg"])
        let store = env.makeStore()
        await store.load()
        store.handleDragSelect(at: store.photos[0])
        store.handleDragSelect(at: store.photos[1])
        store.endDragSelect()

        let relaunched = env.makeStore()
        await relaunched.load()

        #expect(relaunched.selectedIDs == Set(store.photos[0...1].map(\.id)))
    }

    @Test func selectionSurvivesSwitchingWorkspace() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[1])

        store.setWorkspace(.trash)
        #expect(store.selectedIDs.isEmpty)
        store.setWorkspace(.folder)

        #expect(store.selectedIDs == [store.photos[1].id])
    }

    @Test func eachFolderKeepsItsOwnSelection() async throws {
        let first = try TestEnvironment(files: ["a.jpg"])
        let second = try TestEnvironment(files: ["a.jpg"])
        let store = first.makeStore()
        await store.load()
        store.toggle(store.photos[0])

        let other = PhotoStore(
            folder: FolderPhotoLibrary(directory: second.photosDirectory),
            cameraRoll: second.cameraRoll,
            selectionStorage: SelectionFile(url: first.selectionURL),
            defaults: second.defaults
        )
        await other.load()

        #expect(other.selectedIDs.isEmpty)
    }

    @Test func vanishedPhotosDropOutOfSelection() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.selectAll()
        try env.remove("a.jpg")

        let relaunched = env.makeStore()
        await relaunched.load()

        #expect(relaunched.selectedIDs.map { URL(fileURLWithPath: $0).lastPathComponent } == ["b.jpg"])
    }

    @Test func cancelClearsSavedSelection() async throws {
        let env = try TestEnvironment(files: ["a.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        store.cancel()

        let relaunched = env.makeStore()
        await relaunched.load()

        #expect(relaunched.selectedIDs.isEmpty)
    }

    @Test func cameraRollSelectionSurvivesRelaunch() async throws {
        let env = try TestEnvironment(files: [])
        env.cameraRoll.photos = [FakeCameraRoll.asset("x"), FakeCameraRoll.asset("y")]
        let store = env.makeStore()
        store.setWorkspace(.cameraRoll)
        await store.loadCameraRoll()
        store.toggle(store.cameraRollPhotos[1])

        let relaunched = env.makeStore()
        relaunched.setWorkspace(.cameraRoll)
        await relaunched.loadCameraRoll()

        #expect(relaunched.selectedIDs == ["y"])
    }
}

@MainActor
struct BackgroundDiskTests {
    @Test func loadingReadsDiskOffTheMainThread() async throws {
        let env = try TestEnvironment(files: ["a.jpg"])
        let folder = ThreadRecordingFolder(directory: env.photosDirectory)
        let store = env.makeStore(folder: folder)

        await store.load()

        #expect(!folder.mainThreadCalls.isEmpty)
        #expect(!folder.mainThreadCalls.contains(true))
    }

    @Test func keepMovesFilesOffTheMainThread() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let folder = ThreadRecordingFolder(directory: env.photosDirectory)
        let store = env.makeStore(folder: folder)
        await store.load()
        store.toggle(store.photos[0])

        await store.keep()

        #expect(store.photos.map(\.filename) == ["a.jpg"])
        #expect(store.trashedPhotos.map(\.filename) == ["b.jpg"])
        #expect(!folder.mainThreadCalls.contains(true))
    }

    @Test func restoreAndEmptyTrashRunOffTheMainThread() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg", "c.jpg"])
        let folder = ThreadRecordingFolder(directory: env.photosDirectory)
        let store = env.makeStore(folder: folder)
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()
        store.setWorkspace(.trash)
        store.toggle(store.trashedPhotos[0])

        await store.restoreSelected()
        await store.emptyTrash()

        #expect(store.photos.map(\.filename) == ["a.jpg", "b.jpg"])
        #expect(store.trashedPhotos.isEmpty)
        #expect(!folder.mainThreadCalls.contains(true))
    }
}
