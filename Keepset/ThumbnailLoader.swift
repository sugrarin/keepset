import AppKit
import CoreGraphics
import Foundation
import ImageIO
import Photos

final class ThumbnailLoader: @unchecked Sendable {
    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, CGImage>()
    private let imageManager = PHImageManager.default()

    private init() {
        cache.countLimit = 400
    }

    func image(for photo: Photo, maxPixel: Int) async -> CGImage? {
        let key = "\(photo.id)::\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image: CGImage?
        switch photo.source {
        case .file(let url):
            let path = url.path
            image = await Task.detached(priority: .userInitiated) {
                Self.makeThumbnail(path: path, maxPixel: maxPixel)
            }.value
        case .asset(let identifier):
            image = await loadAsset(identifier, maxPixel: maxPixel)
        }

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

    private func loadAsset(_ identifier: String, maxPixel: Int) async -> CGImage? {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false

        let size = CGSize(width: maxPixel, height: maxPixel)
        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: asset,
                targetSize: size,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(
                    returning: image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                )
            }
        }
    }
}
