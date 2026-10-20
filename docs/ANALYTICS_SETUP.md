# Firebase Analytics 導入 — セットアップ手順

`docs/GROWTH_DIAGNOSIS.md` §1が指摘した「計測が1行も無い」状態と、
`docs/DEFENSIBILITY.md` §4の指標を実測するために、Firebase Analytics（Google Analytics
for Firebase）を導入した。**無料**で、イベント数の上限なくログを送れる
（詳細は[公式の料金ページ](https://firebase.google.com/pricing)を参照。有料なのは
BigQueryへの生データエクスポート等の追加機能で、標準の集計・ダッシュボード閲覧は無料）。

このドキュメントは**Xcodeでの作業手順**（コードは既に実装済み）をまとめる。
実装したコードの内容は [`Services/Analytics/AnalyticsService.swift`](../Rotash/Services/Analytics/AnalyticsService.swift) を参照。

> **2026-10-15 時点の状態**：1〜3章の作業は作者の環境では済んでいる
> （`GoogleService-Info.plist` は `Rotash/Services/` にあり、Firebase の Swift Package は 12.18.0 が入っている）。
> 自分の Firebase プロジェクトで一からやり直すときの手順として読む。

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
4. 「iOSバンドルID」に **`app.takaoka.com.Rorash`**（`project.yml`と`Rotash.xcodeproj`の
   `PRODUCT_BUNDLE_IDENTIFIER`と同じ値。綴りが `Rorash` なのは実際の値のまま）を入力する。ニックネームは任意（例: Rotash）
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

置き場所はどこでもよい（現在は `Rotash/Services/GoogleService-Info.plist`）。
`BUNDLE_ID` が Xcode の `PRODUCT_BUNDLE_IDENTIFIER` と一致していないと、イベントが届かない。

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
   `11.0.0` 以上を指定してAddを押す（作者の環境では `12.18.0`）
4. パッケージの内容が表示されたら、**Rotashターゲットに追加するProductとして**
   以下の2つ「だけ」にチェックを入れる：
   - **FirebaseCore**
   - **FirebaseAnalytics**
   （他にも大量のProductが一覧に出るが、今回使わないものにはチェックしない。
   ビルド時間とアプリサイズが不必要に増えるのを避けるため）

   > 作者の環境では、このとき他のProductも全部チェックされたまま追加されていて、
   > 現在は計24個がリンクされている（コードから使っているのは Core と Analytics だけ）。
   > 外す件は [`PENDING_DECISIONS.md`](PENDING_DECISIONS.md)。`project.yml` の `dependencies` も同じ24個。
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
対応不要。** ただし、**Rotash自身のコード**（`Design/Theme.swift` の `WorkShape` が
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

## 6. 送っているイベント

`AnalyticsService.swift` に定義があるのは9つ。**実際に送られているのは8つ**で、`member_added` は定義だけあって
どこからも呼ばれていない（途中参加の人数を測りたければ、呼ぶか、消すかを決める）。

| イベント | いつ送るか | 主なパラメータ |
|---|---|---|
| `group_created` | グループを作った | `from_origin_group`（`rotash://new?from=…` 経由か） |
| `group_joined` | 招待コードで参加した | — |
| `member_added` | （定義のみ。送られていない） | `member_count` |
| `photo_captured` | 担当日に撮った | `filled_count` |
| `photo_retaken` | 撮った直後の撮り直し | `seconds_after_first`（最初の1枚から何秒後か） |
| `week_completed` | 週が切り替わるとき、7/7 だった | `member_count`, `is_first_week` |
| `invite_share_tapped` | 招待の共有シートを開いた | — |
| `work_share_tapped` | 作品の共有シートを開いた | `filled_count`, `is_complete` |
| `work_share_completed` | 共有シートで送信まで完了した | `is_complete`, `destination`（送り先の種類。Instagram は `com.burbn.instagram.shareextension`、共有シートの「Instagram ストーリーズ」からは `app.rotash.instagram-story`） |
| `rotash_open` | アプリが前面に来た（起動・戻ってきた） | `is_my_day`（今日自分が担当か）, `today_filled`, `group_count` |
| `week_viewed` | 横にして今週の作品を見た | `is_my_day`, `today_filled` |
| `first_landscape` | そのグループで初めて横にした | `minutes_since_join`（招待で入ってから何分後か。作った人は -1） |
| `message_sent` | グループのメッセージを送った（2026-10-19 から） | `is_my_day`（送った日が自分の担当日か）, `member_count` |
| `messages_opened` | メッセージの画面を開いた（2026-10-19 から） | `unread`（開いたときに読んでいなかった数） |

`week_completed` は「その週が終わって次の週に切り替わった瞬間」に、全枠が写真で埋まっていた場合だけ送られる
（`AppViewModel.rolledWeek`）。7枚目を撮った瞬間ではない。

## 7. 今後の運用について

- 追加したイベントと、それが`docs/DEFENSIBILITY.md` §4のどの指標に対応するかは
  `Services/Analytics/AnalyticsService.swift`のコメントを参照
- 新しいイベントを増やしたくなったら、**まず「それがK-3のどの指標に効くか」を
  先に言葉にしてから追加する**（`AnalyticsService.swift`冒頭のコメントの通り）。
  目的のないイベントを増やすと、後で何を見ればいいか分からなくなる
- 配布段階が近づいたら、§5-2の申告内容をGoogle公式ページで再確認し、
  `PrivacyInfo.xcprivacy`の`NSPrivacyCollectedDataTypes`（現在は空のまま）も
  合わせて埋める

---

## 8. 見方 — オーナーの3つの指標と、どこを見ればいいか（2026-10-14 追記）

オーナーが置いた戦略の指標は3つ。

| 指標 | 見る場所 | 使うイベント・数字 |
|---|---|---|
| ① 1人がどれくらい招待するか（何グループ作るか・何人誘うか） | Firebase コンソール → Analytics → イベント | `group_created`・`invite_share_tapped` を「ユーザーあたり」で。実際に入った人は `group_joined` |
| ② グループの稼働率（作品が完成するか・翌週も続くか） | `tools/rotash-stats.py` | 完成率・週次継続率（Firestore の実データから出す。Analytics より確実） |
| ③ ストーリーなどにあげる割合 | Firebase コンソール → Analytics → イベント | `work_share_completed`（`is_complete` が true）÷ `week_completed`。Instagram に出した分は `destination` で分ける |
| （コア仮説）担当日以外にも開くか | 同上 | `rotash_open` のうち `is_my_day` が false の割合。横にしたかは `week_viewed` |

結果としての数字は `GROWTH_STRATEGY.md` K の **WCG（その週に作品が完成したグループ数）**。
①〜③はそれを増やすための3つのレバーで、`WCG(t+1) = WCG(t) × (R + K) + S` の S・R・K にほぼ対応する。

### 注意

- `GoogleService-Info.plist` の `IS_ANALYTICS_ENABLED` は `false` だが、**イベントは実際に記録されている**
  （2026-10-13 にオーナーが書き出したレポートで確認）。今の SDK はこの値を見ていないので気にしなくてよい
- **開発者自身の操作も数に入る。** テスト期間の数字は、オーナーの端末の分を差し引いて読む
- 国が US と出る利用者がいる。iCloud プライベートリレーや TestFlight の審査端末の可能性があり、実在の米国ユーザーとは限らない
- `tools/rotash-stats.py` は、Firestore のルールで一覧の読み取りが止められているため、
  そのままだと 403 になる。`--codes ABC123,DEF456` のように招待コードを渡して1つずつ読む
- イベントの数は登録なしで見られる。**パラメータ（`is_complete` など）で分けて見るには**、
  Analytics → カスタム定義 で、パラメータ名をカスタムディメンションとして登録する（登録した日以降の分だけ集計される）
- ③は「共有シートで送信まで完了した」までしか分からない。`destination` が `app.rotash.instagram-story` のものは
  ストーリーズを開いたところまでで、実際に投稿したかは分からない（Instagram は結果を返さない）
- レポートへの反映は最大24時間後。すぐ確かめたいときは 4章の DebugView
- 公開した作品から生まれたグループ（K）は、今は測れない。`group_created` の `from_origin_group` は、
  `rotash://new?from=…` から作られたときだけ true になるが、そのリンクをどの共有にも載せていないため（README「リンク」）

---

## 8. 開発者の操作を数えない（2026-10-16）

開発者がいちばんよく触るので、その操作が混ざると数字が実際より良く見える。次の3つで外している。

### 8-1. Xcode から動かすとき（DEBUG ビルド）

いつも計測を止める（`AnalyticsService.applyDeviceSetting`。起動直後に `RotashApp.init` から呼ぶ）。
コンソールの `📊 …` の表示はこれまでどおり出るので、送ろうとしたイベントは確かめられる。
**DebugView で確かめたいときだけ**は、4章の起動引数 `-FIRAnalyticsDebugEnabled` を付ければ送られる。

### 8-2. TestFlight 版・App Store 版（自分の端末だけ）

1. 設定（SETTINGS）を開き、いちばん下の小さな `VERSION 0.2 (…)` を **5回** 押す
2. 「開発者」の欄が出るので、**「この端末を計測に含めない」をオン**にする

- オンのあいだは、自分で送るイベントも、Firebase が自動で送るもの（セッション・画面表示など）も止まる
  （`Analytics.setAnalyticsCollectionEnabled(false)`）
- TestFlight 版と App Store 版は同じアプリなので、どちらでも効く。アップデートしても残る
- **アプリを消して入れ直すとオフに戻る**ので、入れ直したらもう一度オンにする。
  入れ直した直後の起動で、Firebase が自動で送る `first_open` だけは1回届いてしまう（止める前なので）
- **オンにする前に送ったデータは消せない**。オンにした日から先がきれいになるので、
  集計は「その日以降」で区切って見る

### 8-3. 集計スクリプト（`tools/rotash-stats.py`）

こちらは Analytics ではなく、Firestore のグループそのものを数えている。
自分が友達と本当に使っているグループは数えてよいが、**動作確認のために作ったグループ**は外す。

```
python3 tools/rotash-stats.py --exclude ABC123,DEF456
```

毎回書くのが面倒なら、`tools/stats-exclude.txt` に1行1つずつ招待コードを書いておく（`#` から後はメモ）。
招待コードは知っていれば誰でも入れるので、このファイルは Git に上げない（`.gitignore` 済み）。
