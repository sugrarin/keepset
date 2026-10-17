import CoreGraphics
import Foundation
import Testing
@testable import Keepset

struct ThumbnailLoaderTests {
    @Test func cancelledRequestIsNeverDecoded() async throws {
        let decoder = GatedDecoder()
        let loader = ThumbnailLoader(maxConcurrentDecodes: 1, decodeFile: decoder.decode)
        let first = Task { await loader.image(for: Self.photo("a.jpg"), maxPixel: 64) }
        try await decoder.waitUntilStarted(1)

        let second = Task { await loader.image(for: Self.photo("b.jpg"), maxPixel: 64) }
        try await Task.sleep(for: .milliseconds(50))
        second.cancel()
        decoder.open()

        #expect(await first.value != nil)
        #expect(await second.value == nil)
        #expect(decoder.decodedNames == ["a.jpg"])
    }

    @Test func repeatedRequestComesFromCache() async {
        let decoder = GatedDecoder()
        decoder.open()
        let loader = ThumbnailLoader(maxConcurrentDecodes: 2, decodeFile: decoder.decode)

        _ = await loader.image(for: Self.photo("a.jpg"), maxPixel: 64)
        _ = await loader.image(for: Self.photo("a.jpg"), maxPixel: 64)

        #expect(decoder.decodedNames == ["a.jpg"])
    }

    @Test func cacheCostIsDecodedByteSize() throws {
        let image = try #require(GatedDecoder.makeImage(width: 40, height: 30))
        #expect(ThumbnailLoader.cost(of: image) == image.bytesPerRow * 30)
    }

    private static func photo(_ name: String) -> Photo {
        let url = URL(fileURLWithPath: "/tmp/\(name)")
        return Photo(id: url.path, source: .file(url), filename: name, modifiedAt: .distantPast)
    }
}

/// Blocks every decode until `open()` so tests can queue requests behind a busy one.
final class GatedDecoder: @unchecked Sendable {
    private let gate = DispatchSemaphore(value: 0)
    private let lock = NSLock()
    private var names: [String] = []
    private var isOpen = false

    var decodedNames: [String] { lock.withLock { names } }

    var decode: @Sendable (URL, Int) -> CGImage? {
        { [self] url, _ in
            lock.withLock { names.append(url.lastPathComponent) }
            if !lock.withLock({ isOpen }) {
                gate.wait()
                gate.signal()
            }
            return Self.makeImage(width: 8, height: 8)
        }
    }

    func open() {
        lock.withLock { isOpen = true }
        gate.signal()
    }

    func waitUntilStarted(_ count: Int) async throws {
        while decodedNames.count < count {
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    static func makeImage(width: Int, height: Int) -> CGImage? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )?.makeImage()
    }
}
