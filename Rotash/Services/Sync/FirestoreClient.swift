import Foundation

/// Firestore の REST API を直接叩く薄い層。
///
/// Firebase SDK（Swift Package）を足すとプロジェクトファイルに依存を追加することになるので、
/// MVP のあいだは URLSession だけで完結する REST を使う。
/// そのぶんリアルタイム購読は使えないので、更新は「開いたとき」と「撮ったとき」に取りに行く。
///
/// 状態はフィールドを細かく分けず、グループ全体を JSON 文字列 1 個として持つ。
/// 既存の Codable のモデルとマージ処理をそのまま使えるため、MVP では扱いが単純になる。
enum FirestoreClient {

    private enum Field {
        static let payload = "payload"
        static let updatedAt = "updatedAt"
    }

    /// サーバー上の状態を読む。まだ無ければ nil。
    static func fetch(inviteCode: String) async throws -> RemoteGroupState? {
        guard SyncConfig.isConfigured, let url = SyncConfig.documentURL(inviteCode: inviteCode) else {
            throw SyncError.notConfigured
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        guard let http = response as? HTTPURLResponse else { throw SyncError.malformedPayload }
        if http.statusCode == 404 { return nil }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.badResponse(http.statusCode)
        }

        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let fields = object["fields"] as? [String: Any],
              let payloadField = fields[Field.payload] as? [String: Any],
              let payload = payloadField["stringValue"] as? String,
              let payloadData = payload.data(using: .utf8)
        else { throw SyncError.malformedPayload }

        return try RotashCoding.decoder.decode(RemoteGroupState.self, from: payloadData)
    }

    /// サーバー上の状態を書く。ドキュメントが無ければ作られる。
    static func push(_ state: RemoteGroupState) async throws {
        guard SyncConfig.isConfigured,
              let url = SyncConfig.documentURL(inviteCode: state.inviteCode)
        else { throw SyncError.notConfigured }

        let payloadData = try RotashCoding.encoder.encode(state)
        guard let payload = String(data: payloadData, encoding: .utf8) else {
            throw SyncError.malformedPayload
        }

        let body: [String: Any] = [
            "fields": [
                Field.payload: ["stringValue": payload],
                Field.updatedAt: ["timestampValue": ISO8601DateFormatter().string(from: Date())]
            ]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.malformedPayload }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.badResponse(http.statusCode)
        }
    }
}
