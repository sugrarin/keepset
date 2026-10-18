import Foundation
import Testing
@testable import Keepset

@MainActor
struct UndoDeleteTests {
    @Test func keepOffersToUndoTheDeletion() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg", "c.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])

        await store.keep()

        #expect(store.lastDeletion?.count == 2)
    }

    @Test func nothingToUndoWhenNothingWasDeleted() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.selectAll()

        await store.keep()

        #expect(store.lastDeletion == nil)
    }

    @Test func undoBringsDeletedPhotosBack() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg", "c.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()

        await store.undoDelete()

        #expect(store.photos.map(\.filename) == ["a.jpg", "b.jpg", "c.jpg"])
        #expect(store.trashedPhotos.isEmpty)
        #expect(store.lastDeletion == nil)
    }

    @Test func undoRestoresTheKeepSelection() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        let kept = store.photos[0]
        store.toggle(kept)
        await store.keep()

        await store.undoDelete()

        #expect(store.selectedIDs == [kept.id])
    }

    @Test func undoLeavesEarlierTrashAlone() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg", "c.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[1])
        store.toggle(store.photos[2])
        await store.keep()
        store.toggle(store.photos[0])
        await store.keep()
        #expect(store.trashedPhotos.map(\.filename) == ["a.jpg", "c.jpg"])

        await store.undoDelete()

        #expect(store.trashedPhotos.map(\.filename) == ["a.jpg"])
        #expect(store.photos.map(\.filename) == ["b.jpg", "c.jpg"])
    }

    @Test func startingANewSelectionDropsTheOffer() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()

        store.toggle(store.photos[0])

        #expect(store.lastDeletion == nil)
    }

    @Test func restoringFromTrashDropsTheOffer() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()
        store.setWorkspace(.trash)
        store.toggle(store.trashedPhotos[0])

        await store.restoreSelected()

        #expect(store.lastDeletion == nil)
    }

    @Test func emptyingTrashDropsTheOffer() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()
        store.setWorkspace(.trash)

        await store.emptyTrash()

        #expect(store.lastDeletion == nil)
    }

    @Test func cameraRollDeletionCannotBeUndone() async throws {
        let env = try TestEnvironment(files: [])
        env.cameraRoll.photos = [FakeCameraRoll.asset("x"), FakeCameraRoll.asset("y")]
        let store = env.makeStore()
        store.setWorkspace(.cameraRoll)
        await store.loadCameraRoll()
        store.toggle(store.cameraRollPhotos[0])

        await store.keep()

        #expect(store.lastDeletion == nil)
    }
}
