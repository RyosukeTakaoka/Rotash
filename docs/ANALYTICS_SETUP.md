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

## 5. 今後の運用について

- 追加したイベントと、それが`docs/DEFENSIBILITY.md` §4のどの指標に対応するかは
  `Services/Analytics/AnalyticsService.swift`のコメントを参照
- 新しいイベントを増やしたくなったら、**まず「それがK-3のどの指標に効くか」を
  先に言葉にしてから追加する**（`AnalyticsService.swift`冒頭のコメントの通り）。
  目的のないイベントを増やすと、後で何を見ればいいか分からなくなる
- App Store提出前に、Firebase Analyticsが要求するプライバシー関連の申告
  （トラッキングの有無等）を`PrivacyInfo.xcprivacy`に反映する必要があるかもしれない。
  現時点（TestFlight配布前）では対応不要
