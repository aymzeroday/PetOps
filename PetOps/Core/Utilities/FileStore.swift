import Foundation

enum FileStoreError: Error { case failedToWrite }

final class FileStore {
    static let shared = FileStore()
    private init() {}

    private var baseURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let url = dir.appendingPathComponent("PetOpsFiles", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
        return url
    }

    func save(data: Data, ext: String) throws -> String {
        let name = UUID().uuidString + "." + ext
        let url = baseURL.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic])
            return url.path
        } catch {
            throw FileStoreError.failedToWrite
        }
    }

    func fileURL(path: String) -> URL {
        URL(fileURLWithPath: path)
    }

    func delete(path: String) {
        try? FileManager.default.removeItem(atPath: path)
    }
}
