import Testing
@testable import Keepset

@MainActor
struct TileShapeTests {
    @Test func tilesAreSquareByDefault() throws {
        let env = try TestEnvironment(files: [])
        #expect(env.makeStore().tileShape == .square)
    }

    @Test func chosenShapeIsRemembered() throws {
        let env = try TestEnvironment(files: [])
        env.makeStore().tileShape = .original
        #expect(env.makeStore().tileShape == .original)
    }
}
