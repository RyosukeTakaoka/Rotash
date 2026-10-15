import Foundation

/// 同期の接続先。
///
/// ここが未設定のあいだ、アプリはこれまでどおりローカル保存だけで動く
/// （同期は一切走らず、バトンでの受け渡しがそのまま使える）。
/// 値を入れた時点で自動的に同期が有効になる。
///
/// ここに書く2つの値は、どちらもクライアントに配る前提のもので秘密鍵ではない。
///   - Firebase の Web API キー: 公開前提。守るのは鍵ではなくセキュリティルール。
///   - Cloudinary の unsigned upload preset: 公開前提。API Secret は絶対に置かないこと。
///
/// ただし「秘密ではない」と「誰でも書き換えてよい」は別なので、
/// セキュリティルールの注意点は README を参照。
enum SyncConfig {

    // MARK: - Firebase (Firestore REST)

    /// Firebase コンソール > プロジェクトの設定 > プロジェクト ID
    static let firebaseProjectID = "rotash-f83a4"

    /// Firebase コンソール > プロジェクトの設定 > ウェブ API キー
    static let firebaseAPIKey = "AIzaSyCSxFupls4erwflZmoSi9mferU0fNNvw-k"

    /// グループを置くコレクション名。
    static let collection = "rotash"

    // MARK: - Cloudinary

    /// Cloudinary ダッシュボードの Cloud name
    static let cloudinaryCloudName = "dw71feikq"

    /// Settings > Upload > Upload presets で作った unsigned preset の名前
    static let cloudinaryUploadPreset = "rotash_unsigned"

    // MARK: -

    static var isConfigured: Bool {
        !firebaseProjectID.isEmpty
            && !firebaseAPIKey.isEmpty
            && !cloudinaryCloudName.isEmpty
            && !cloudinaryUploadPreset.isEmpty
    }

    static func documentURL(inviteCode: String) -> URL? {
        var components = URLComponents(
            string: "https://firestore.googleapis.com/v1/projects/\(firebaseProjectID)"
                + "/databases/(default)/documents/\(collection)/\(inviteCode)"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: firebaseAPIKey)]
        return components?.url
    }

    /// 報告を置くコレクション（`FirestoreClient.send(_:)`）。
    static var reportsURL: URL? {
        var components = URLComponents(
            string: "https://firestore.googleapis.com/v1/projects/\(firebaseProjectID)"
                + "/databases/(default)/documents/reports"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: firebaseAPIKey)]
        return components?.url
    }

    /// 押し出し通知の宛先（`FirestoreClient.saveDevice`）。
    static func deviceURL(uid: String) -> URL? {
        var components = URLComponents(
            string: "https://firestore.googleapis.com/v1/projects/\(firebaseProjectID)"
                + "/databases/(default)/documents/devices/\(uid)"
        )
        components?.queryItems = [URLQueryItem(name: "key", value: firebaseAPIKey)]
        return components?.url
    }

    // MARK: - 問い合わせ先

    /// 報告・問い合わせを受ける連絡先（App Store ガイドライン 1.2 で、公開した連絡先が必要）。
    /// 空のあいだは、設定画面に連絡先を出さない。App Store に出す前に必ず入れること。
    static let supportEmail = ""

    static var cloudinaryUploadURL: URL? {
        URL(string: "https://api.cloudinary.com/v1_1/\(cloudinaryCloudName)/image/upload")
    }
}

/// 同期まわりの共通エンコーダ。端末をまたぐので日付の形式を固定しておく。
enum RotashCoding {
    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()
}

enum SyncError: LocalizedError {
    case notConfigured
    case badResponse(Int)
    case malformedPayload
    case uploadFailed
    /// 入ろうとしたグループが定員（`RotashGroup.capacity`）に達している。
    case groupFull

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return String(localized: "同期の接続先が設定されていません。")
        case .badResponse(let code):
            return String(localized: "サーバーとの通信に失敗しました（\(code)）。")
        case .malformedPayload:
            return String(localized: "サーバー上のデータを読めませんでした。")
        case .uploadFailed:
            return String(localized: "写真のアップロードに失敗しました。")
        case .groupFull:
            return String(localized: "このグループは7人でいっぱいです。")
        }
    }
}
