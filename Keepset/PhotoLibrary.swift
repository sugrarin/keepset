import Foundation

enum PhotoLibraryError: LocalizedError {
    case directoryMissing(URL)
    case seedMissing
    case notSandbox(URL)

    var errorDescription: String? {
        switch self {
        case .directoryMissing(let url):
            return "Photos folder not found: \(url.path)"
        case .seedMissing:
            return "Bundled demo photos are missing."
        case .notSandbox(let url):
            return "Reset is only allowed in a Keepset sandbox folder. \(url.path) has no \(WorkingPhotosDirectory.sandboxMarker) file, so nothing was deleted."
        }
    }
}

enum WorkingPhotosDirectory {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "gif", "tif", "tiff", "bmp"
    ]

    /// Reset deletes images for good, so it only runs in folders that carry this file.
    static let sandboxMarker = ".keepset-sandbox"

    static var defaultApplicationSupport: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Keepset/photos", isDirectory: true)
    }

    static func resolve(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        seed: URL? = seedURL,
        applicationSupport: URL = defaultApplicationSupport
    ) -> URL {
        let fm = FileManager.default

        if let env = environment["KEEPSET_PHOTOS_DIR"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            if !fm.fileExists(atPath: url.path) {
                try? fm.createDirectory(at: url, withIntermediateDirectories: true)
                markAsSandbox(url)
            }
            return url
        }

        try? fm.createDirectory(at: applicationSupport, withIntermediateDirectories: true)
        markAsSandbox(applicationSupport)
        if isEmpty(applicationSupport), let seed {
            try? copyImages(from: seed, to: applicationSupport)
        }
        return applicationSupport
    }

    static func isSandbox(_ directory: URL) -> Bool {
        FileManager.default.fileExists(atPath: directory.appendingPathComponent(sandboxMarker).path)
    }

    private static func markAsSandbox(_ directory: URL) {
        guard !isSandbox(directory) else { return }
        try? Data().write(to: directory.appendingPathComponent(sandboxMarker))
    }

    static var seedURL: URL? {
        let bundled = Bundle.main.resourceURL?.appendingPathComponent("photos", isDirectory: true)
        if let bundled, FileManager.default.fileExists(atPath: bundled.path) {
            return bundled
        }
        return nil
    }

    static func isImage(_ url: URL) -> Bool {
        imageExtensions.contains(url.pathExtension.lowercased())
    }

    static func isEmpty(_ directory: URL) -> Bool {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        return files.filter(isImage).isEmpty
    }

    static func copyImages(from source: URL, to destination: URL) throws {
        let fm = FileManager.default
        try fm.createDirectory(at: destination, withIntermediateDirectories: true)
        let files = try fm.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        for file in files where isImage(file) {
            let target = destination.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: target.path) {
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: file, to: target)
        }
    }
}

protocol PhotoFolder: Sendable {
    var directory: URL { get }
    func loadPhotos() throws -> [Photo]
    func loadTrashedPhotos() throws -> [Photo]
    func moveToTrash(_ photos: [Photo]) throws
    func restorePhotos(_ photos: [Photo]) throws
    func emptyTrash() throws
    func resetFromSeed() throws
}

struct FolderPhotoLibrary: PhotoFolder {
    let directory: URL
    var seed: URL? = WorkingPhotosDirectory.seedURL

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

    func resetFromSeed() throws {
        guard WorkingPhotosDirectory.isSandbox(directory) else {
            throw PhotoLibraryError.notSandbox(directory)
        }
        guard let seed else {
            throw PhotoLibraryError.seedMissing
        }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = try loadPhotos()
        for photo in existing {
            if let url = photo.fileURL {
                try? fm.removeItem(at: url)
            }
        }
        try? emptyTrash()
        try WorkingPhotosDirectory.copyImages(from: seed, to: directory)
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
