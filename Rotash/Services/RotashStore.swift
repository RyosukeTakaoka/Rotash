import Foundation

/// 保存層のインターフェース。
/// MVP はローカル JSON だが、後から Firebase / API 実装に差し替えられるようにしておく。
protocol RotashStore {
    func load() -> RotashGroup?
    func save(_ group: RotashGroup?)
}

final class FileRotashStore: RotashStore {

    private let fileURL: URL
    private let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()
    private let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(fileURL: URL = RotashPaths.stateFile) {
        self.fileURL = fileURL
        RotashPaths.prepareDirectories()
    }

    func load() -> RotashGroup? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(RotashGroup.self, from: data)
    }

    func save(_ group: RotashGroup?) {
        guard let group else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        do {
            let data = try encoder.encode(group)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("[Rotash] save failed:", error)
        }
    }
}

enum RotashPaths {
    static var documents: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    static var root: URL { documents.appendingPathComponent("Rotash", isDirectory: true) }
    static var photos: URL { root.appendingPathComponent("photos", isDirectory: true) }
    static var stateFile: URL { root.appendingPathComponent("state.json") }

    static func prepareDirectories() {
        let manager = FileManager.default
        for url in [root, photos] where !manager.fileExists(atPath: url.path) {
            try? manager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
