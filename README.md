# Rotash — MVP 試作

友達と一定期間をかけて、**1つの写真作品を完成させる**アプリの試作です。
App Store 公開版ではなく、実際に友人と使って体験価値を検証するためのものです。

---

## 体験の中心

- 1つの Rotash グループに複数人が参加する
- **1日に1人だけ**が撮る（全員が毎日投稿するのではない）
- 3人なら 月A 火B 水C 木A 金B 土C 日A と一巡し続ける
- 7枚そろうと、その週の作品が完成する
- 端末を**横向き**にすると、7分割された「今週の作品」が現れる

縦向きは準備するところ（作る / 参加 / 招待コード / Memories / 設定）。
進行中の作品の写真は縦では見せません。埋まり具合（◻︎◻︎◼︎…）だけが見えます。

---

## 動かし方

1. Xcode 16 以降で `Rotash.xcodeproj` を開く
2. `Rotash` ターゲットの Signing で自分の Team を選ぶ
   （`PRODUCT_BUNDLE_IDENTIFIER` は `com.rotash.mvp`。必要なら変更）
3. 実機を選んで Run（**カメラを使うので実機推奨**）

> `Rotash/` 配下は Xcode 16 のファイルシステム同期グループです。
> ファイルを増やしてもプロジェクトファイルを触る必要はありません。
> 古い Xcode で開けない場合は `xcodegen generate`（`project.yml` 同梱）でも生成できます。

シミュレータではカメラが無いため、シャッターを押すとダミー画像が入ります。
7分割が埋まっていく流れだけは確認できます。

---

## 実装した機能（MVP必須分）

| # | 機能 | 場所 |
|---|---|---|
| 1 | Rotash 作成（名前入力 → 招待コード生成） | `Views/Portrait/CreateRotashView.swift`, `InviteCodeView.swift` |
| 2 | 招待コードで参加 | `Views/Portrait/JoinRotashView.swift` |
| 3 | 横向き THIS WEEK（7分割・埋まっていく） | `Views/Landscape/ThisWeekView.swift` |
| 4 | 撮影（横向き写真を担当枠へ保存） | `Services/CameraController.swift` |
| 5 | 完成作品表示（7枚そろうと COMPLETE） | `ThisWeekView.swift` |
| 6 | Memories（過去作品一覧・簡易プレビュー） | `PortraitHomeView.swift`, `MemoryDetailView.swift` |
| 7 | Share（7枚 / 7分割1枚） | `Services/WorkExporter.swift` |

## 撮影のつくり

**通常のカメラプレビューは出しません。**

- 画面には最初から 7分割レイアウトがある
- ライブビューは**担当枠の中だけ**に出る
- そのため、撮る人は完成写真の全体を見ないまま撮ることになる
- 撮ると、その枠がそのまま写真で埋まる（確認画面なし）

操作は 2通りとも使えます。

- 担当枠をタップ（1回目で選択 / 2回目で撮影）
- 画面下中央の固定シャッター

写真は横長のまま保存します。縦への自動変換はしません。

## 共有

加工・テンプレート・装飾は入れていません。

- **7枚の写真そのもの**を書き出す（Instagram カルーセル用）
- **7分割のまま1枚**にしたコンタクトシート（アプリ内の見え方と同じ）

---

## サーバーを持たないので「バトン」はファイルで渡す

Firebase もアカウントも使わない指定なので、保存は端末ローカルのみです。
そのままだと友達と同じ作品を育てられないため、**バトンの受け渡し**だけ用意しました。

- 縦向きの「バトンを渡す」→ `.rotash` ファイルを AirDrop / LINE などで送る
- 受け取った人は「バトンを受け取る」から読み込む（AirDrop から直接開くのも可）
- 中身は「グループ情報 + 今週の7枠 + その写真」だけ
- 同じ週を別々に撮っていても、写真は消えずに合流します

過去作品（Memories）は各自の端末にたまります。
その週の最後のバトンを受け取った人の端末に、完成した作品が残ります。

**検証の進め方（おすすめ）**
- まず 1台を回す形でも体験は成立します（7分割が埋まる感覚の確認）
- 2台以上なら、撮ったらバトンを次の当番に送る運用で「待つ楽しさ」まで確認できます

---

## 当番と週の扱い

- 週の始まりは月曜
- 当番 = `members[(週のオフセット + 曜日) % 人数]`
- 週が変わると、当番は前の週の続きから一巡し続ける
- 撮れるのは「自分の当番日」かつ「今日以前の空き枠」
  （逃した日は追いつける／未来の日は撮れない）
- 設定の **自由撮影モード** を ON にすると、当番に関係なく空き枠を撮れます
  （体験を短時間で試すための検証用スイッチ）

---

## 構成

```
Rotash/
  App/          RotashApp.swift
  Models/       RotashModels.swift          … Member / Slot / RotashWeek / RotashGroup
  Services/     RotashStore.swift           … 保存層（protocol + ローカルJSON実装）
                PhotoStore.swift            … 写真の実体・サムネイル
                CameraController.swift      … AVFoundation
                InviteCode.swift
                WorkExporter.swift          … 共有
                BatonTransfer.swift         … .rotash の書き出し / 読み込み
  ViewModels/   AppViewModel.swift          … 当番判定・撮影・週送り・合流
  Views/        RootView.swift              … 縦横で体験を分ける
                Portrait/ …                 … 作成 / 参加 / 招待 / Memories / 設定
                Landscape/ …                … THIS WEEK（7分割）
                Components/ …
  Design/       Theme.swift
Supporting/     Info.plist
```

MVVM。保存層は `RotashStore` protocol 越しなので、
あとから Firebase / 自前API の実装に差し替えれば、そのまま同期版にできます。

---

## 今回作っていないもの

アカウント登録 / Firebase / 通知 / チャット / コメント / いいね / フォロー /
タイムライン / 複数Rotash管理 / 課金 / AI加工 / 写真編集 / 権限管理

---

## この試作で見たいこと

- 横7分割の写真は本当に楽しいか
- 友達が自然に続けるか
- 完成するまで待ちたいと思うか
- Instagram に共有したくなるか
- 通知なしでも戻ってくるか
