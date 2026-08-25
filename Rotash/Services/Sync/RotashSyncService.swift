import Foundation

/// 同期の段取り。
///
///   1. まだアップロードしていない自分の写真を Cloudinary に上げる
///   2. サーバーの状態を読む
///   3. ローカルと突き合わせる（写真は絶対に落とさない）
///   4. 手元に無い写真をダウンロードしてキャッシュする
///   5. 突き合わせた結果をサーバーに書き戻す
///
/// リアルタイム購読は使わないので、呼ぶのは「アプリを開いたとき」「撮ったとき」
/// 「引っぱって更新したとき」の3つだけ。友達と1日1枚ずつ撮る使い方には足りる。
enum RotashSyncService {

    static var isEnabled: Bool { SyncConfig.isConfigured }

    /// 同期の結果。写真のアップロードに失敗しても状態の同期は続けるので、
    /// 「何枚届かなかったか」を呼び出し側に返して知らせる。
    struct Outcome {
        var group: RotashGroup
        var failedUploads: Int
        var failureReason: String?
    }

    /// 同期して、突き合わせ後のグループを返す。
    static func sync(group: RotashGroup) async throws -> Outcome {
        guard isEnabled else { throw SyncError.notConfigured }

        var failures = 0
        var failureReason: String?
        var working = await uploadPendingPhotos(in: group,
                                                failures: &failures,
                                                failureReason: &failureReason)

        if let remote = try await FirestoreClient.fetch(inviteCode: working.inviteCode) {
            working = RotashMerge.merge(local: working, remote: remote)
        }

        await cacheMissingPhotos(in: &working)

        try await FirestoreClient.push(RemoteGroupState(group: working))
        return Outcome(group: working, failedUploads: failures, failureReason: failureReason)
    }

    // MARK: - 写真

    /// ローカルにしか無い写真をアップロードして、URL を書き込む。
    private static func uploadPendingPhotos(in group: RotashGroup,
                                            failures: inout Int,
                                            failureReason: inout String?) async -> RotashGroup {
        var updated = group

        updated.currentWeek = await uploadPendingPhotos(in: updated.currentWeek,
                                                        failures: &failures,
                                                        failureReason: &failureReason)
        for index in updated.archive.indices {
            updated.archive[index] = await uploadPendingPhotos(in: updated.archive[index],
                                                               failures: &failures,
                                                               failureReason: &failureReason)
        }
        return updated
    }

    private static func uploadPendingPhotos(in week: RotashWeek,
                                            failures: inout Int,
                                            failureReason: inout String?) async -> RotashWeek {
        var updated = week
        for index in updated.slots.indices {
            let slot = updated.slots[index]
            guard slot.photoURL == nil,
                  let filename = slot.photoFilename,
                  let data = PhotoStore.shared.data(for: filename)
            else { continue }

            // 1枚失敗しても他の写真の同期は続ける。次回の同期で再試行される。
            // ただし黙って握りつぶさず、失敗したことは呼び出し側に伝える。
            do {
                updated.slots[index].photoURL = try await CloudinaryClient.upload(data: data,
                                                                                  filename: filename)
            } catch {
                failures += 1
                if failureReason == nil { failureReason = error.localizedDescription }
            }
        }
        return updated
    }

    /// URL はあるが手元に写真が無い枠を落としてくる。
    private static func cacheMissingPhotos(in group: inout RotashGroup) async {
        await cacheMissingPhotos(in: &group.currentWeek)
        for index in group.archive.indices {
            await cacheMissingPhotos(in: &group.archive[index])
        }
    }

    private static func cacheMissingPhotos(in week: inout RotashWeek) async {
        for index in week.slots.indices {
            let slot = week.slots[index]
            guard let urlString = slot.photoURL else { continue }
            if let filename = slot.photoFilename, PhotoStore.shared.exists(filename) { continue }

            guard let data = try? await CloudinaryClient.download(from: urlString),
                  let filename = try? PhotoStore.shared.save(data)
            else { continue }
            week.slots[index].photoFilename = filename
        }
    }
}
