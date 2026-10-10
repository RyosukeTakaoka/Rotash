import Foundation

/// 端末に保存するもの。掛け持ちしているグループすべてと、いま開いているグループ。
struct RotashLibrary: Codable {
    var groups: [RotashGroup] = []
    var currentGroupID: UUID?
}

/// 保存層のインターフェース。
/// MVP はローカル JSON だが、後から Firebase / API 実装に差し替えられるようにしておく。
protocol RotashStore {
    func load() -> RotashLibrary
    func save(_ library: RotashLibrary)
}

final class FileRotashStore: RotashStore {

    private let fileURL: URL
    /// グループを1つしか持てなかった頃の保存ファイル。初めて開いたときに一度だけ読み替える。
    private let legacyFileURL: URL
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

    init(fileURL: URL = RotashPaths.libraryFile, legacyFileURL: URL = RotashPaths.stateFile) {
        self.fileURL = fileURL
        self.legacyFileURL = legacyFileURL
        RotashPaths.prepareDirectories()
    }

    func load() -> RotashLibrary {
        if let data = try? Data(contentsOf: fileURL),
           let library = try? decoder.decode(RotashLibrary.self, from: data) {
            return library
        }
        // 以前の形（グループ1つ）からの読み替え。
        if let data = try? Data(contentsOf: legacyFileURL),
           let group = try? decoder.decode(RotashGroup.self, from: data) {
            return RotashLibrary(groups: [group], currentGroupID: group.id)
        }
        return RotashLibrary()
    }

    func save(_ library: RotashLibrary) {
        do {
            let data = try encoder.encode(library)
            try data.write(to: fileURL, options: .atomic)
            // 新しい形で保存できたら、古いファイルは要らない（残すと、全部抜けたあとに読み戻されてしまう）。
            try? FileManager.default.removeItem(at: legacyFileURL)
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
    /// グループを1つしか持てなかった頃の保存ファイル（読み替え用）。
    static var stateFile: URL { root.appendingPathComponent("state.json") }
    /// 掛け持ちしているグループすべて。
    static var libraryFile: URL { root.appendingPathComponent("groups.json") }

    static func prepareDirectories() {
        let manager = FileManager.default
        for url in [root, photos] where !manager.fileExists(atPath: url.path) {
            try? manager.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
}
