import CoreGraphics
import Foundation
import ImageIO

final class ThumbnailLoader: @unchecked Sendable {
    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, CGImage>()

    private init() {
        cache.countLimit = 400
    }

    func image(for url: URL, maxPixel: Int) async -> CGImage? {
        let key = "\(url.path)::\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let path = url.path
        let image = await Task.detached(priority: .userInitiated) {
            Self.makeThumbnail(path: path, maxPixel: maxPixel)
        }.value
        if let image {
            cache.setObject(image, forKey: key)
        }
        return image
    }

    private static func makeThumbnail(path: String, maxPixel: Int) -> CGImage? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(
            url as CFURL,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ) else {
            return nil
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
            kCGImageSourceShouldCacheImmediately: true
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary)
    }
}
