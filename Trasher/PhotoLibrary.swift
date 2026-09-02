import Foundation

enum PhotoLibraryError: LocalizedError {
    case directoryMissing(URL)
    case seedMissing

    var errorDescription: String? {
        switch self {
        case .directoryMissing(let url):
            return "Photos folder not found: \(url.path)"
        case .seedMissing:
            return "Bundled demo photos are missing."
        }
    }
}

enum WorkingPhotosDirectory {
    static let imageExtensions: Set<String> = [
        "jpg", "jpeg", "png", "heic", "heif", "webp", "avif", "gif", "tif", "tiff", "bmp"
    ]

    static func resolve() -> URL {
        let fm = FileManager.default

        if let env = ProcessInfo.processInfo.environment["TRASHER_PHOTOS_DIR"], !env.isEmpty {
            let url = URL(fileURLWithPath: env, isDirectory: true)
            try? fm.createDirectory(at: url, withIntermediateDirectories: true)
            return url
        }

        let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath, isDirectory: true).standardizedFileURL
        let roots: [URL] = [
            URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true),
            bundleURL
        ]

        for root in roots {
            var dir = root.standardizedFileURL
            for _ in 0..<12 {
                let candidate = dir.appendingPathComponent("photos", isDirectory: true)
                if fm.fileExists(atPath: candidate.path), !isInsideAppBundle(candidate, bundleURL: bundleURL) {
                    return candidate
                }
                dir.deleteLastPathComponent()
            }
        }

        let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Trasher/photos", isDirectory: true)
        try? fm.createDirectory(at: support, withIntermediateDirectories: true)
        if isEmpty(support), let seed = seedURL {
            try? copyImages(from: seed, to: support)
        }
        return support
    }

    private static func isInsideAppBundle(_ url: URL, bundleURL: URL) -> Bool {
        let path = url.standardizedFileURL.path
        let bundlePath = bundleURL.path
        return path == bundlePath || path.hasPrefix(bundlePath + "/")
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

struct FolderPhotoLibrary: Sendable {
    let directory: URL

    func loadPhotos() throws -> [Photo] {
        let fm = FileManager.default
        var isDirectory: ObjCBool = false
        guard fm.fileExists(atPath: directory.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw PhotoLibraryError.directoryMissing(directory)
        }

        let keys: [URLResourceKey] = [.contentModificationDateKey, .isRegularFileKey]
        let files = try fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: keys)
        return files.compactMap { url -> Photo? in
            guard WorkingPhotosDirectory.isImage(url) else { return nil }
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile != false else { return nil }
            return Photo(
                id: url.path,
                url: url,
                filename: url.lastPathComponent,
                modifiedAt: values?.contentModificationDate ?? .distantPast
            )
        }
        .sorted {
            $0.filename.localizedStandardCompare($1.filename) == .orderedAscending
        }
    }

    func deletePhotos(_ photos: [Photo]) throws {
        let fm = FileManager.default
        let bundlePath = URL(fileURLWithPath: Bundle.main.bundlePath).standardizedFileURL.path
        for photo in photos {
            let path = photo.url.standardizedFileURL.path
            if path == bundlePath || path.hasPrefix(bundlePath + "/") {
                continue
            }
            guard fm.fileExists(atPath: photo.url.path) else { continue }
            try fm.trashItem(at: photo.url, resultingItemURL: nil)
        }
    }

    func resetFromSeed() throws {
        guard let seed = WorkingPhotosDirectory.seedURL else {
            throw PhotoLibraryError.seedMissing
        }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let existing = try loadPhotos()
        for photo in existing {
            try? fm.removeItem(at: photo.url)
        }
        try WorkingPhotosDirectory.copyImages(from: seed, to: directory)
    }
}
