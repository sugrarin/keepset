import Foundation

protocol SelectionStorage {
    func load() -> [String: Set<Photo.ID>]
    func save(_ selections: [String: Set<Photo.ID>])
}

struct SelectionFile: SelectionStorage {
    let url: URL

    static var standard: SelectionFile {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return SelectionFile(url: support.appendingPathComponent("Keepset/selections.json"))
    }

    func load() -> [String: Set<Photo.ID>] {
        guard let data = try? Data(contentsOf: url),
              let stored = try? JSONDecoder().decode([String: [Photo.ID]].self, from: data)
        else { return [:] }
        return stored.mapValues(Set.init)
    }

    func save(_ selections: [String: Set<Photo.ID>]) {
        let stored = selections.mapValues { $0.sorted() }
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder().encode(stored).write(to: url, options: .atomic)
        } catch {
            // Losing a save only costs the hearts since the previous one; not worth interrupting culling.
        }
    }
}
