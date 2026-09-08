import Foundation
import Photos

enum PhotoAccess: Equatable {
    case unknown
    case authorized
    case denied
}

enum CameraRollError: Error {
    case cancelled
}

enum CameraRollLibrary {
    static func requestAccess() async -> PhotoAccess {
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

    static func fetchPhotos() -> [Photo] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeHiddenAssets = false
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var photos: [Photo] = []
        photos.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            let filename = PHAssetResource.assetResources(for: asset).first?.originalFilename ?? "Photo"
            photos.append(
                Photo(
                    id: asset.localIdentifier,
                    source: .asset(asset.localIdentifier),
                    filename: filename,
                    modifiedAt: asset.modificationDate ?? asset.creationDate ?? .distantPast
                )
            )
        }
        return photos
    }

    static func deletePhotos(_ photos: [Photo]) async throws {
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
}
