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

        #expect(store.mode == .folder)
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

    @Test func startsWithoutAFolderUntilOneIsChosen() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStoreWithoutFolder()

        await store.load()

        #expect(!store.hasFolder)
        #expect(store.directory == nil)
        #expect(store.photos.isEmpty)
        #expect(store.title(for: .folder) == "No Folder")
    }

    @Test func choosingAFolderWorksFromTheEmptyStart() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStoreWithoutFolder()
        let chosen = try makeFolder(in: env, named: "shoot", files: ["x.jpg"])

        await store.chooseFolder(chosen)

        #expect(store.hasFolder)
        #expect(store.photos.map(\.filename) == ["x.jpg"])
    }

    @Test func folderTabIsNamedAfterTheFolder() async throws {
        let env = try TestEnvironment(files: [])
        let store = env.makeStore()
        let chosen = try makeFolder(in: env, named: "shoot", files: [])

        #expect(store.title(for: .folder) == "photos")
        await store.chooseFolder(chosen)

        #expect(store.title(for: .folder) == "shoot")
        #expect(store.title(for: .cameraRoll) == "Camera Roll")
        #expect(store.title(for: .trash) == "Trash")
    }
}
