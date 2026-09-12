# Firebase Analytics 導入 — セットアップ手順

`docs/GROWTH_DIAGNOSIS.md` §1が指摘した「計測が1行も無い」状態と、
`docs/DEFENSIBILITY.md` §4の指標を実測するために、Firebase Analytics（Google Analytics
for Firebase）を導入した。**無料**で、イベント数の上限なくログを送れる
（詳細は[公式の料金ページ](https://firebase.google.com/pricing)を参照。有料なのは
BigQueryへの生データエクスポート等の追加機能で、標準の集計・ダッシュボード閲覧は無料）。

このドキュメントは**Xcodeでの作業手順**（コードはこの変更で既に実装済み）をまとめる。
実装したコードの内容は [`Services/Analytics/AnalyticsService.swift`](../Rotash/Services/Analytics/AnalyticsService.swift) を参照。

---

## 前提：RotashはすでにFirebaseプロジェクトを持っている

`Services/Sync/SyncConfig.swift` に既に以下が書かれている通り、Rotashは
Firestore用に**Firebaseプロジェクト（プロジェクトID: `rotash-f83a4`）を既に持っている。**

**新しいFirebaseプロジェクトを作る必要はない。同じプロジェクトにAnalytics用の
「iOSアプリ」を追加するだけでよい。**

---

## 1. Firebaseコンソールでの作業

1. [Firebaseコンソール](https://console.firebase.google.com/)を開き、既存のプロジェクト
   **`rotash-f83a4`** を選択する
2. 左上の歯車アイコン →「プロジェクトの設定」を開く
3. 「マイアプリ」セクションで「アプリを追加」→ iOSのアイコンを選ぶ
4. 「iOSバンドルID」に **`com.rotash.mvp`**（`project.yml`の
   `PRODUCT_BUNDLE_IDENTIFIER`と同じ値）を入力する。ニックネームは任意（例: Rotash）
5. 「アプリを登録」を押すと、**`GoogleService-Info.plist`** というファイルが
   ダウンロードできるようになる。これをダウンロードしておく
   （この後のXcode作業で使う）
6. 「Firebase SDKを追加」という画面が出るが、**その先の指示は無視してよい**
   （このドキュメントの手順3で改めて説明する）。「次へ」を押して登録を完了する
7. 左メニューの「Analytics」→「概要」を開き、**Google Analyticsが有効になっていること**
   を確認する（プロジェクト作成時に有効化されていれば、既にオンになっているはず）

---

## 2. `GoogleService-Info.plist` をXcodeプロジェクトに追加する

1. Xcodeで `Rotash.xcodeproj` を開く
2. 左のファイルナビゲータで `Rotash` グループ（フォルダアイコン）を右クリック →
   「Add Files to "Rotash"...」
3. 手順1でダウンロードした `GoogleService-Info.plist` を選択する
4. ダイアログで以下を必ず確認してからAddを押す：
   - **「Copy items if needed」にチェックが入っている**
   - **「Add to targets」で `Rotash` にチェックが入っている**

置き場所はどこでもよいが、`Rotash/Resources/` に置くと他のリソースと揃う。

> **Gitへのコミットについて**：`GoogleService-Info.plist`は秘密鍵ではない
> （`SyncConfig.swift`のFirebase APIキーと同じ性質。公開前提のクライアント設定値）。
> このプロジェクトは一人で開発しているため、**そのままコミットして問題ない。**

---

## 3. Firebase SDKをXcodeに追加する（File > Add Package Dependencies）

`project.yml`にも依存関係の記述を追加済みだが、**このプロジェクトは普段
`.xcodeproj`を直接Xcodeで開いて使っている**ため、確実なのはXcodeのGUIから
直接パッケージを追加する方法である。

1. Xcodeのメニューから **File → Add Package Dependencies...** を選ぶ
2. 右上の検索欄に以下のURLを貼り付ける：
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
3. 「Dependency Rule」は **Up to Next Major Version** のまま、バージョンは
   `11.0.0` 以上を指定してAddを押す
4. パッケージの内容が表示されたら、**Rotashターゲットに追加するProductとして**
   以下の2つ「だけ」にチェックを入れる：
   - **FirebaseCore**
   - **FirebaseAnalytics**
   （他にも大量のProductが一覧に出るが、今回使わないものにはチェックしない。
   ビルド時間とアプリサイズが不必要に増えるのを避けるため）
5. 「Add Package」を押すと、ダウンロード・リンクが始まる（数分かかることがある）

---

## 4. ビルドして確認する

1. 実機（またはシミュレータ）でビルド・実行する
2. コンソールログに `📊 group_created [...]` のような行が、
   グループ作成・参加・撮影・週完成・共有のたびに出ていれば、計測コードは動いている
   （`AnalyticsService.swift`がDEBUGビルドで`print`するようにしてある）

### FirebaseコンソールでリアルタイムのDebugViewを見る

通常のAnalyticsレポートは**反映まで最大24時間かかる**。今すぐ動作確認したい場合は
DebugViewを使う。

1. Xcodeで **Product → Scheme → Edit Scheme...** を開く
2. 「Run」→「Arguments」タブ →「Arguments Passed On Launch」に以下を追加：
   ```
   -FIRAnalyticsDebugEnabled
   ```
3. アプリを実行し、Firebaseコンソール →「Analytics」→「DebugView」を開く
4. 操作するたびに、送信したイベント（`group_created`等）がほぼリアルタイムで
   表示される
5. **確認が終わったら、Schemeに追加した`-FIRAnalyticsDebugEnabled`は削除しておく**
   （付けたままだと通常の集計データにデバッグ扱いの印がついてしまう）

---

## 5. App Store Connect側で必要になる設定

Firebase Analyticsを追加すると、**2つの別々の仕組み**でプライバシー対応が必要になる。
混同しやすいので分けて説明する。

### 5-1. Privacy Manifest（`PrivacyInfo.xcprivacy`）— コードレベルの申告

Appleは2024年5月以降、`UserDefaults`のような「Required Reason API」を使うアプリに、
その理由をアプリ自身の`PrivacyInfo.xcprivacy`で申告するよう義務付けている。

**Firebase SDK自身が使うAPIは、Firebase側が自分のマニフェストを既に同梱しているため
対応不要。** ただし、**Rotash自身のコード**（`AppViewModel.swift`が
`UserDefaults.standard.set`を直接呼んでいる）は対象で、これはFirebase追加とは無関係に
以前から必要だった申告である。今回、`Rotash/Resources/PrivacyInfo.xcprivacy`を
新規作成し、理由コード**`CA92.1`**（自分のアプリだけがアクセスする設定値の読み書き）を
申告済み。新しいファイルなのでXcodeでの追加作業は不要（`Rotash/`配下はファイルシステム
同期グループのため、追加するだけで自動的にターゲットに含まれる）。

### 5-2. App Store Connectの「App Privacy」（プライバシー"栄養成分表示"）— 手動の申告

これは`.xcprivacy`ファイルとは別物で、**App Store Connectの管理画面で手作業で
回答するアンケート**。App Store公開ページに表示される、あの表のことである。

Firebase Analyticsを追加すると、一般的に次のような申告が必要になる
（Google公式ガイド[Prepare for Apple's App Store data disclosure requirements](https://firebase.google.com/docs/ios/app-store-data-collection)に
最新の対応表がある。**このページを直接確認してから回答すること**。この文書を書いた
時点ではネットワーク制限により当該ページを直接開けなかったため、正確な最新表現は
必ず公式ページで確認してほしい）：

| データ種別 | 目的 | 備考 |
|---|---|---|
| 識別子（デバイスID相当） | 分析（Analytics） | Firebaseの「App Instance ID」がこれに該当 |
| 使用状況データ（製品とのやり取り） | 分析（Analytics） | どの画面・操作が行われたか |

**トラッキング（Appleが定義する意味でのTracking）には該当しない。**
Rotashは広告SDK（Google Mobile Ads等）を導入しておらず、広告IDを収集する設定もしていない。
Apple ATT（App Tracking Transparencyのポップアップ）は、**他社アプリ・Webサイトを
横断してユーザーを追跡する場合**にのみ必要で、自社アプリの利用状況を見るだけの
Firebase Analyticsは対象外である。**`NSUserTrackingUsageDescription`の追加や
ATT許諾ダイアログの実装は不要。**

### 5-3. プライバシーポリシーのURL

App Store Connectでアプリ情報を登録する際、データを収集するアプリには
**プライバシーポリシーのURL**の入力が必須になる。現時点（TestFlight配布前）では
急ぎではないが、実際に配布する段階では必要になる。

### 5-4. 今すぐやる必要があるか

**いいえ。** これらはすべて「App Store Connectで審査に出す・TestFlightで
社外の人に配布する」段階で必要になるものであり、**今のように自分の端末で
ビルド・実行して試すだけの段階では一切関係ない。**

---

## 6. 今後の運用について

- 追加したイベントと、それが`docs/DEFENSIBILITY.md` §4のどの指標に対応するかは
  `Services/Analytics/AnalyticsService.swift`のコメントを参照
- 新しいイベントを増やしたくなったら、**まず「それがK-3のどの指標に効くか」を
  先に言葉にしてから追加する**（`AnalyticsService.swift`冒頭のコメントの通り）。
  目的のないイベントを増やすと、後で何を見ればいいか分からなくなる
- 配布段階が近づいたら、§5-2の申告内容をGoogle公式ページで再確認し、
  `PrivacyInfo.xcprivacy`の`NSPrivacyCollectedDataTypes`（現在は空のまま）も
  合わせて埋める
