import Foundation

enum PhotoLibraryError: LocalizedError {
    case directoryMissing(URL)

    var errorDescription: String? {
        switch self {
        case .directoryMissing(let url):
            return "Photos folder not found: \(url.path)"
        }
    }
}

enum WorkingPhotosDirectory {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "gif", "tif", "tiff", "bmp"
    ]

    static func existingFolder(atPath path: String?) -> URL? {
        guard let path else { return nil }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    static func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }
}

protocol PhotoFolder: Sendable {
    var directory: URL { get }
    func loadPhotos() throws -> [Photo]
    func loadTrashedPhotos() throws -> [Photo]
    func moveToTrash(_ photos: [Photo]) throws
    func restorePhotos(_ photos: [Photo]) throws
    func emptyTrash() throws
}

struct FolderPhotoLibrary: PhotoFolder {
    let directory: URL

    var trashDirectory: URL {
        directory.appendingPathComponent(".Trash", isDirectory: true)
    }

    func loadPhotos() throws -> [Photo] {
        try loadPhotos(from: directory)
    }

    func loadTrashedPhotos() throws -> [Photo] {
        try loadPhotos(from: trashDirectory, missingOK: true)
    }

    func moveToTrash(_ photos: [Photo]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: trashDirectory, withIntermediateDirectories: true)
        for photo in photos {
            guard let url = photo.fileURL, canMutate(url) else { continue }
            let destination = uniqueURL(in: trashDirectory, named: photo.filename)
            try fm.moveItem(at: url, to: destination)
        }
    }

    func restorePhotos(_ photos: [Photo]) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for photo in photos {
            guard let url = photo.fileURL, canMutate(url) else { continue }
            let destination = uniqueURL(in: directory, named: photo.filename)
            try fm.moveItem(at: url, to: destination)
        }
    }

    func emptyTrash() throws {
        let fm = FileManager.default
        guard fm.fileExists(atPath: trashDirectory.path) else { return }
        let trashed = try loadTrashedPhotos()
        for photo in trashed {
            guard let url = photo.fileURL, canMutate(url) else { continue }
            try fm.removeItem(at: url)
        }
    }

    private func loadPhotos(from folder: URL, missingOK: Bool = false) throws -> [Photo] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: folder.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            if missingOK { return [] }
            throw PhotoLibraryError.directoryMissing(folder)
        }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let files = try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: keys)
        return files.compactMap { url -> Photo? in
            guard WorkingPhotosDirectory.isImage(url) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile != false else { return nil }
            return Photo(
                id: url.path,
                source: .file(url),
                filename: url.lastPathComponent,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted {
            $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
        }
    }

    private func canMutate(_ url: URL) -> Bool {
        let fm = FileManager.default
        let bundlePath = URL(fileURLWithPath: Bundle.main.bundlePath).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path == bundlePath || path.hasPrefix(bundlePath + "/") {
            return false
        }
        return fm.fileExists(atPath: url.path)
    }

    private func uniqueURL(in folder: URL, named filename: String) -> URL {
        let fm = FileManager.default
        let ext = URL(fileURLWithPath: filename).pathExtension
        let stem = URL(fileURLWithPath: filename).deletingPathExtension().lastPathComponent
        var index = 1
        while true {
            let name: String
            if index == 1 {
                name = filename
            } else if ext.isEmpty {
                name = "\(stem)-\(index)"
            } else {
                name = "\(stem)-\(index).\(ext)"
            }
            let candidate = folder.appendingPathComponent(name)
            if !fm.fileExists(atPath: candidate.path) {
                return candidate
            }
            index += 1
        }
    }
}
