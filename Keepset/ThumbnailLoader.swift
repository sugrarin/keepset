import AppKit
import CoreGraphics
import Foundation
import ImageIO
import os
import Photos

final class ThumbnailLoader: @unchecked Sendable {
    static let shared = ThumbnailLoader()

    private let cache = NSCache<NSString, CGImage>()
    private let imageManager = PHImageManager.default()
    private let decodeQueue = OperationQueue()
    private let decodeFile: @Sendable (URL, Int) -> CGImage?

    init(
        cacheCostLimit: Int = 300 * 1024 * 1024,
        maxConcurrentDecodes: Int = 4,
        decodeFile: @escaping @Sendable (URL, Int) -> CGImage? = ThumbnailLoader.makeThumbnail
    ) {
        self.decodeFile = decodeFile
        cache.totalCostLimit = cacheCostLimit
        decodeQueue.maxConcurrentOperationCount = maxConcurrentDecodes
        decodeQueue.qualityOfService = .userInitiated
    }

    static func cost(of image: CGImage) -> Int {
        image.bytesPerRow * image.height
    }

    func image(for photo: Photo, maxPixel: Int) async -> CGImage? {
        let key = "\(photo.id)::\(maxPixel)" as NSString
        if let cached = cache.object(forKey: key) {
            return cached
        }

        let image: CGImage?
        switch photo.source {
        case .file(let url):
            image = await decode(url, maxPixel: maxPixel)
        case .asset(let identifier):
            image = await loadAsset(identifier, maxPixel: maxPixel)
        }

        if let image {
            cache.setObject(image, forKey: key, cost: Self.cost(of: image))
        }
        return image
    }

    /// Queued so a fast scroll can't start hundreds of decodes; cancelling the cell's task drops a queued one.
    private func decode(_ url: URL, maxPixel: Int) async -> CGImage? {
        let decodeFile = decodeFile
        let operation = DecodeOperation { decodeFile(url, maxPixel) }
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                operation.completionBlock = {
                    continuation.resume(returning: operation.result)
                }
                decodeQueue.addOperation(operation)
            }
        } onCancel: {
            operation.cancel()
        }
    }

    static func makeThumbnail(url: URL, maxPixel: Int) -> CGImage? {
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
        let request = AssetImageRequest()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                request.begin(continuation)
                let id = imageManager.requestImage(
                    for: asset,
                    targetSize: size,
                    contentMode: .aspectFill,
                    options: options
                ) { image, _ in
                    request.finish(image?.cgImage(forProposedRect: nil, context: nil, hints: nil))
                }
                request.attach(id, manager: imageManager)
            }
        } onCancel: {
            request.cancel(manager: imageManager)
        }
    }
}

private final class DecodeOperation: Operation, @unchecked Sendable {
    private let work: @Sendable () -> CGImage?
    private(set) var result: CGImage?

    init(work: @escaping @Sendable () -> CGImage?) {
        self.work = work
    }

    override func main() {
        guard !isCancelled else { return }
        result = work()
    }
}

/// Resumes the continuation exactly once, whether Photos answers first or the cell's task is cancelled first.
private final class AssetImageRequest: Sendable {
    private struct State: Sendable {
        var continuation: CheckedContinuation<CGImage?, Never>?
        var requestID: PHImageRequestID?
        var isCancelled = false
    }

    private let state = OSAllocatedUnfairLock(initialState: State())

    func begin(_ continuation: CheckedContinuation<CGImage?, Never>) {
        state.withLock { $0.continuation = continuation }
    }

    func attach(_ requestID: PHImageRequestID, manager: PHImageManager) {
        let cancelledEarly = state.withLock { state -> Bool in
            state.requestID = requestID
            return state.isCancelled
        }
        if cancelledEarly {
            manager.cancelImageRequest(requestID)
        }
    }

    func finish(_ image: CGImage?) {
        state.withLock { state in
            let continuation = state.continuation
            state.continuation = nil
            return continuation
        }?.resume(returning: image)
    }

    func cancel(manager: PHImageManager) {
        let (requestID, continuation) = state.withLock { state in
            state.isCancelled = true
            let pending = (state.requestID, state.continuation)
            state.continuation = nil
            return pending
        }
        if let requestID {
            manager.cancelImageRequest(requestID)
        }
        continuation?.resume(returning: nil)
    }
}
