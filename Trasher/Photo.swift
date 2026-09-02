import Foundation

struct Photo: Identifiable, Hashable, Sendable {
    let id: String
    let url: URL
    let filename: String
    let modifiedAt: Date
}
