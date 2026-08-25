import Foundation

/// 写真の置き場。Firestore には URL だけを持たせ、実体はこちらに置く。
/// unsigned upload preset を使うので、アプリに秘密鍵を持たせなくて済む。
enum CloudinaryClient {

    /// JPEG を1枚アップロードして、その URL を返す。
    static func upload(data: Data, filename: String) async throws -> String {
        guard SyncConfig.isConfigured, let url = SyncConfig.cloudinaryUploadURL else {
            throw SyncError.notConfigured
        }

        let boundary = "rotash-\(UUID().uuidString)"
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("multipart/form-data; boundary=\(boundary)",
                         forHTTPHeaderField: "Content-Type")
        request.httpBody = multipartBody(boundary: boundary,
                                         data: data,
                                         filename: filename,
                                         preset: SyncConfig.cloudinaryUploadPreset)

        let (responseData, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw SyncError.uploadFailed }
        guard (200..<300).contains(http.statusCode) else {
            throw SyncError.badResponse(http.statusCode)
        }
        guard let object = try? JSONSerialization.jsonObject(with: responseData) as? [String: Any],
              let secureURL = object["secure_url"] as? String
        else { throw SyncError.uploadFailed }

        return secureURL
    }

    /// URL から写真を取ってくる。
    static func download(from urlString: String) async throws -> Data {
        guard let url = URL(string: urlString) else { throw SyncError.malformedPayload }
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw SyncError.badResponse(http.statusCode)
        }
        return data
    }

    private static func multipartBody(boundary: String,
                                      data: Data,
                                      filename: String,
                                      preset: String) -> Data {
        var body = Data()

        func append(_ string: String) {
            body.append(Data(string.utf8))
        }

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"upload_preset\"\r\n\r\n")
        append("\(preset)\r\n")

        append("--\(boundary)\r\n")
        append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n")
        append("Content-Type: image/jpeg\r\n\r\n")
        body.append(data)
        append("\r\n")

        append("--\(boundary)--\r\n")
        return body
    }
}
