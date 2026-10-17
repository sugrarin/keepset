import Testing
@testable import Keepset

@MainActor
struct CameraRollLoadingTests {
    @Test func reenteringCameraRollDoesNotRefetch() async throws {
        let env = try TestEnvironment(files: [])
        env.cameraRoll.photos = [FakeCameraRoll.asset("x")]
        let store = env.makeStore()

        await store.loadCameraRollIfNeeded()
        await store.loadCameraRollIfNeeded()

        #expect(env.cameraRoll.fetchCount == 1)
        #expect(store.cameraRollPhotos.map(\.id) == ["x"])
    }

    @Test func libraryChangeRefetches() async throws {
        let env = try TestEnvironment(files: [])
        env.cameraRoll.photos = [FakeCameraRoll.asset("x")]
        let store = env.makeStore()
        await store.loadCameraRollIfNeeded()
        #expect(env.cameraRoll.changeHandler != nil)

        env.cameraRoll.photos.append(FakeCameraRoll.asset("y"))
        await store.cameraRollDidChange()

        #expect(env.cameraRoll.fetchCount == 2)
        #expect(store.cameraRollPhotos.map(\.id) == ["x", "y"])
    }

    @Test func deniedAccessFetchesNothingAndRetriesLater() async throws {
        let env = try TestEnvironment(files: [])
        env.cameraRoll.access = .denied
        let store = env.makeStore()

        await store.loadCameraRollIfNeeded()
        #expect(env.cameraRoll.fetchCount == 0)
        #expect(store.cameraRollAccess == .denied)

        env.cameraRoll.access = .authorized
        await store.loadCameraRollIfNeeded()
        #expect(env.cameraRoll.fetchCount == 1)
    }
}
