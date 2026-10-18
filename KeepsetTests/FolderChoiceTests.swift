import Foundation
import Testing
@testable import Keepset

@MainActor
struct FolderChoiceTests {
    private func makeFolder(in env: TestEnvironment, named name: String, files: [String]) throws -> URL {
        let folder = env.root.appendingPathComponent(name, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in files {
            try Data().write(to: folder.appendingPathComponent(file))
        }
        return folder
    }

    @Test func choosingAFolderShowsItsPhotos() async throws {
        let env = try TestEnvironment(files: ["a.jpg"])
        let store = env.makeStore()
        await store.load()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg", "y.jpg"])

        await store.chooseFolder(chosen)

        #expect(store.directory == chosen)
        #expect(store.photos.map(\.filename) == ["x.jpg", "y.jpg"])
    }

    @Test func choosingAFolderLeavesTrashAndMarksBehind() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        await store.keep()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)

        #expect(store.trashedPhotos.isEmpty)
        #expect(store.selectedIDs.isEmpty)
        #expect(store.lastDeletion == nil)
    }

    @Test func choosingAFolderReturnsToTheGrid() async throws {
        let env = try TestEnvironment(files: ["a.jpg"])
        let store = env.makeStore()
        await store.load()
        store.setWorkspace(.trash)
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)

        #expect(store.mode == .sandbox)
    }

    @Test func marksSurviveSwitchingBackToAFolder() async throws {
        let env = try TestEnvironment(files: ["a.jpg", "b.jpg"])
        let store = env.makeStore()
        await store.load()
        store.toggle(store.photos[0])
        let marked = store.selectedIDs
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)
        await store.chooseFolder(env.photosDirectory)

        #expect(store.selectedIDs == marked)
    }

    @Test func chosenFolderIsRememberedForTheNextLaunch() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStore()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)

        #expect(env.defaults.string(forKey: PhotoStore.photosFolderKey) == chosen.path)
    }

    @Test func chosenFolderIsNeverMarkedAsSandbox() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStore()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)
        await store.resetSandbox()

        #expect(!WorkingPhotosDirectory.isSandbox(chosen))
        #expect(store.photos.map(\.filename) == ["x.jpg"])
        #expect(store.errorMessage != nil)
    }

    @Test func defaultFolderIsRestoredAndForgetsTheChoice() async throws {
        let env = try TestEnvironment(files: ["a.jpg"])
        let store = env.makeStore()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])
        await store.chooseFolder(chosen)

        await store.useDefaultFolder()

        #expect(store.directory == env.photosDirectory)
        #expect(store.photos.map(\.filename) == ["a.jpg"])
        #expect(env.defaults.string(forKey: PhotoStore.photosFolderKey) == nil)
    }

    @Test func resetIsAllowedOnlyInMarkedFolders() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStore()
        try Data().write(to: env.photosDirectory.appendingPathComponent(WorkingPhotosDirectory.sandboxMarker))
        #expect(store.isSandboxFolder)

        await store.chooseFolder(try makeFolder(in: env, named: "shoot", files: []))

        #expect(!store.isSandboxFolder)
    }
}
