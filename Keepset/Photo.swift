import Foundation

enum PhotoSource: Hashable, Sendable {
    case file(URL)
    case asset(String)
}

struct Photo: Identifiable, Hashable, Sendable {
    let id: String
    let source: PhotoSource
    let filename: String
    let modifiedAt: Date

    var fileURL: URL? {
        if case .file(let url) = source { return url }
        return nil
    }
}
