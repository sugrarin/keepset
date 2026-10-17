import Foundation
import os
import Photos

enum PhotoAccess: Equatable {
    case unknown
    case authorized
    case denied
}

enum CameraRollError: Error {
    case cancelled
}

protocol CameraRoll: Sendable {
    func requestAccess() async -> PhotoAccess
    func fetchPhotos() -> [Photo]
    func deletePhotos(_ photos: [Photo]) async throws
    func observeChanges(_ onChange: @escaping @Sendable () -> Void)
}

final class CameraRollLibrary: NSObject, CameraRoll, PHPhotoLibraryChangeObserver {
    private let onChange = OSAllocatedUnfairLock<(@Sendable () -> Void)?>(initialState: nil)

    func requestAccess() async -> PhotoAccess {
        let status: PHAuthorizationStatus
        let current = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if current == .notDetermined {
            status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        } else {
            status = current
        }
        switch status {
        case .authorized, .limited:
            return .authorized
        default:
            return .denied
        }
    }

    func fetchPhotos() -> [Photo] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var photos: [Photo] = []
        photos.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            // The original filename costs a resource lookup per asset, so it is resolved lazily for the preview.
            photos.append(
                Photo(
                    id: asset.localIdentifier,
                    source: .asset(asset.localIdentifier),
                    filename: "",
                    modifiedAt: asset.modificationDate ?? asset.creationDate ?? .distantPast
                )
            )
        }
        return photos
    }

    static func originalFilename(for identifier: String) -> String? {
        guard let asset = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else {
            return nil
        }
        return PHAssetResource.assetResources(for: asset).first?.originalFilename
    }

    func deletePhotos(_ photos: [Photo]) async throws {
        let ids = photos.compactMap { photo -> String? in
            if case .asset(let id) = photo.source { return id }
            return nil
        }
        guard !ids.isEmpty else { return }
        let result = PHAsset.fetchAssets(withLocalIdentifiers: ids, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        guard !assets.isEmpty else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assets as NSArray)
            }
        } catch let error as PHPhotosError where error.code == .userCancelled {
            throw CameraRollError.cancelled
        }
    }

    func observeChanges(_ onChange: @escaping @Sendable () -> Void) {
        self.onChange.withLock { $0 = onChange }
        PHPhotoLibrary.shared().register(self)
    }

    func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange.withLock { $0 }?()
    }
}
