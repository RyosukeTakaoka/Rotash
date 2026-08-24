import Foundation
import UniformTypeIdentifiers

/// サーバーを持たない MVP で「バトン」を実際に渡すための書き出し / 読み込み。
/// 今週の作品（進行中の 7 枠）とグループ情報だけを 1 ファイルにまとめる。
/// 過去作品は各自の端末にたまっていく。
struct BatonBundle: Codable {
    var version: Int = 1
    var groupID: UUID
    var groupName: String
    var inviteCode: String
    var members: [Member]
    var week: RotashWeek
    var photos: [String: Data]
    var passedAt: Date = Date()
}

enum BatonTransferError: LocalizedError {
    case unreadable
    case codeMismatch(expected: String, found: String)

    var errorDescription: String? {
        switch self {
        case .unreadable:
            return "バトンファイルを読み込めませんでした。"
        case let .codeMismatch(expected, found):
            return "招待コードが違います（このRotashは \(expected) / ファイルは \(found)）。"
        }
    }
}

enum BatonTransfer {

    static var fileType: UTType {
        UTType(filenameExtension: "rotash", conformingTo: .data) ?? .data
    }

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func export(group: RotashGroup) throws -> URL {
        var photos: [String: Data] = [:]
        for slot in group.currentWeek.slots {
            guard let filename = slot.photoFilename,
                  let data = PhotoStore.shared.data(for: filename) else { continue }
            photos[filename] = data
        }

        let bundle = BatonBundle(groupID: group.id,
                                 groupName: group.name,
                                 inviteCode: group.inviteCode,
                                 members: group.members,
                                 week: group.currentWeek,
                                 photos: photos)

        let data = try encoder.encode(bundle)
        let stamp = RotashDateFormat.fileStamp.string(from: group.currentWeek.startDate)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(group.inviteCode)-\(stamp).rotash")
        try data.write(to: url, options: .atomic)
        return url
    }

    static func read(from url: URL) throws -> BatonBundle {
        let needsScope = url.startAccessingSecurityScopedResource()
        defer { if needsScope { url.stopAccessingSecurityScopedResource() } }

        guard let data = try? Data(contentsOf: url),
              let bundle = try? decoder.decode(BatonBundle.self, from: data)
        else { throw BatonTransferError.unreadable }
        return bundle
    }

    /// 受け取った写真をローカルに展開する。
    static func materializePhotos(_ bundle: BatonBundle) {
        for (filename, data) in bundle.photos where !PhotoStore.shared.exists(filename) {
            try? PhotoStore.shared.save(data, filename: filename)
        }
    }
}
