import Foundation

/// Firestore の REST API を直接叩く薄い層。
///
/// Firebase の Swift Package は計測（Analytics）のために入っているが、同期では使わず、
/// URLSession だけで完結する REST を使う（依存を増やさず、状態を JSON 1個として扱うだけなので足りる）。
/// そのぶんリアルタイム購読は使えないので、更新は「開いたとき」「撮ったとき」などに取りに行く。
///
/// 状態はフィールドを細かく分けず、グループ全体を JSON 文字列 1 個として持つ。
/// 既存の Codable のモデルとマージ処理をそのまま使えるため、MVP では扱いが単純になる。
/// 写真の報告（App Store ガイドライン 1.2）。
struct PhotoReport {
    var inviteCode: String
    var weekStart: Date
    var dayIndex: Int
    var photoURL: String
    var reversePhotoURL: String?
    var reportedMemberID: UUID?
    var reporterMemberID: UUID
}

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

        let (data, response) = try await URLSession.shared.data(for: await authorized(URLRequest(url: url)))
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

    /// 匿名ログインの ID トークンを添える（`AuthService`）。ログインできなければ、そのまま送る。
    private static func authorized(_ request: URLRequest) async -> URLRequest {
        var request = request
        if let token = await AuthService.shared.idToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    /// 押し出し通知の宛先を置く（`devices/{uid}`）。本人だけが書ける（firestore.rules）。
    static func saveDevice(uid: String, token: String, language: String) async throws {
        guard SyncConfig.isConfigured, let url = SyncConfig.deviceURL(uid: uid) else { throw SyncError.notConfigured }
        let body: [String: Any] = [
            "fields": [
                "token": ["stringValue": token],
                "language": ["stringValue": language],
                "updatedAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
            ]
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (_, response) = try await URLSession.shared.data(for: await authorized(request))
        guard let http = response as? HTTPURLResponse else { throw SyncError.malformedPayload }
        guard (200..<300).contains(http.statusCode) else { throw SyncError.badResponse(http.statusCode) }
    }

    /// 報告を1件書き込む（`reports` コレクションに新しいドキュメントを作る）。
    /// 報告は誰も読めず、書くだけ（セキュリティルールで読み取りを止める）。運営が Firebase コンソールで見る。
    static func send(_ report: PhotoReport) async throws {
        guard SyncConfig.isConfigured, let url = SyncConfig.reportsURL else { throw SyncError.notConfigured }

        var fields: [String: Any] = [
            "inviteCode": ["stringValue": report.inviteCode],
            "weekStart": ["timestampValue": ISO8601DateFormatter().string(from: report.weekStart)],
            "dayIndex": ["integerValue": String(report.dayIndex)],
            "photoURL": ["stringValue": report.photoURL],
            "reporterMemberID": ["stringValue": report.reporterMemberID.uuidString],
            "createdAt": ["timestampValue": ISO8601DateFormatter().string(from: Date())]
        ]
        if let reverse = report.reversePhotoURL { fields["reversePhotoURL"] = ["stringValue": reverse] }
        if let reported = report.reportedMemberID { fields["reportedMemberID"] = ["stringValue": reported.uuidString] }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["fields": fields])

        let (_, response) = try await URLSession.shared.data(for: await authorized(request))
        guard let http = response as? HTTPURLResponse else { throw SyncError.malformedPayload }
        guard (200..<300).contains(http.statusCode) else { throw SyncError.badResponse(http.statusCode) }
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

        let (_, response) = try await URLSession.shared.data(for: await authorized(request))
        guard let http = response as? HTTPURLResponse else { throw SyncError.malformedPayload }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.badResponse(http.statusCode)
        }
    }
}
