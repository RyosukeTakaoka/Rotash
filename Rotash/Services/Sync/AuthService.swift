import FirebaseAuth
import Foundation

/// 匿名ログイン（Firebase Authentication）。
///
/// Rotash にはアカウント登録もログイン画面も無い。そのかわり、裏で「この端末の利用者」を
/// 1つ作っておき、その ID トークンを Firestore への読み書きに添える。
///
///   - サーバーのセキュリティルールで「ログインしている人だけ読み書きできる」にできる
///     （URL と API キーだけで誰でも全部を読み書きできる状態を終わらせる。`firestore.rules`）
///   - uid は端末に残る（キーチェーン）ので、アプリを入れ直しても同じ uid のまま。
///     同じグループに入り直したとき、新しい人ではなく前の自分として戻れる（`RotashSyncService`）
///
/// ログインできないとき（コンソールで匿名ログインを有効にしていない・通信できない）は、
/// これまでどおりトークンなしで送る。ルールで必須にするまでは、それで動き続ける。
actor AuthService {

    static let shared = AuthService()

    /// 失敗したあと、しばらくは試し直さない（毎回の同期でログインを待たされないように）。
    private var lastFailure: Date?
    private let retryInterval: TimeInterval = 10 * 60

    /// いまの利用者の uid。まだログインしていなければ、ログインを試してから返す。できなければ nil。
    func uid() async -> String? {
        await user()?.uid
    }

    /// Firestore に添える ID トークン。できなければ nil。
    func idToken() async -> String? {
        guard let user = await user() else { return nil }
        return try? await user.getIDToken()
    }

    private func user() async -> User? {
        if let current = Auth.auth().currentUser { return current }
        if let lastFailure, Date().timeIntervalSince(lastFailure) < retryInterval { return nil }
        do {
            let result = try await Auth.auth().signInAnonymously()
            lastFailure = nil
            return result.user
        } catch {
            lastFailure = Date()
            return nil
        }
    }
}
