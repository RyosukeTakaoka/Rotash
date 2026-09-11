# Locket Widget — 成長事例の深掘りと Rotash への応用

[`ASKEN_GROWTH_CASE_STUDY.md`](ASKEN_GROWTH_CASE_STUDY.md)・[`TIMETREE_GROWTH_CASE_STUDY.md`](TIMETREE_GROWTH_CASE_STUDY.md)・
[`MIRO_GROWTH_CASE_STUDY.md`](MIRO_GROWTH_CASE_STUDY.md) の続き。

Locketは `GROWTH_STRATEGY.md` H-2 で既に一度扱われている
（「上限があるから価値がある」＝**7人を定員として扱う根拠**として引用済み）。
この資料はH-2を**繰り返さない**。H-2執筆時点では触れられていなかった3点——
**ウィジェットという配信形態そのもの・友達上限を実際に動かした運用・
TikTokでの意図的な種まき**——を深掘りする。

## 0. Locketの規模と概要（H-2未収録の事実を含む）

| 項目 | 内容 | 出典 |
|---|---|---|
| 実績 | 2022年ローンチ、**8,000万ダウンロード**、DAU 900万超、**2024年から黒字化** | [whatastartup.substack.com](https://whatastartup.substack.com/p/he-built-an-app-for-his-girlfriend-and-ended-up-having-80-million-total-downloads) |
| 誕生の経緯 | 開発者が**恋人へのギフトとして**個人開発したアプリが出発点 | 同上 |
| 資金調達 | 1,250万ドル | [Medium](https://medium.com/@jamelet/social-widget-locket-received-12-5-million-in-financing-led-by-ins-lianchuang-2fb80fffa86a) |
| **友達の上限** | **現在20人。以前は10人**からの引き上げ | [mrhack.io](https://mrhack.io/is-there-a-limit-of-friends-you-can-add-in-locket-widget-app/) |
| 専用ウィジェット | 「Crush」「Best Friend」など、**特定の1人だけの写真を表示する個別ウィジェット**を設定できる | [mrhack.io](https://mrhack.io/how-to-add-up-to-20-friends-in-locket-widget-app/) |
| マネタイズ | サブスクリプション＋広告。広告SDK導入後5か月で広告収益**+87%** | [Moloco事例](https://www.moloco.com/case-studies/locket-widget) |

---

## 1. ウィジェットという配信形態 — H-2が扱っていなかった最大の要素

H-2は「20人までの上限」だけを扱い、**Locketの成長を最も強く支えたもう1つの柱——
ホーム画面ウィジェットにリアルタイムで写真が届き、アプリを開く必要すらないこと**——
には触れていなかった。

これはあすけんのキャラクター、TimeTreeの共同編集、Miroのバイラル共有とも異なる、
**「体験の入り口を、アプリの中からホーム画面そのものに移した」**という配信形態の話である。

### Rotashへの示唆：適用するかどうかは、Rotashのコアと真っ向から緊張する

一見、「Rotashもウィジェットで担当者の写真をホーム画面に出せば、開く手間が減って
リテンションが上がるのでは」という発想が浮かぶ。**しかし、これは慎重に扱う必要がある。**

`GROWTH_STRATEGY.md` F章（「待つ時間」を価値に変える）の核心は、
**「今日は誰？」を確認しに、自分の意思でアプリを開く**という行為そのものに価値がある、
という設計である。ウィジェットで常時写真が見えている状態は、Locketにとっては
「開かなくても届く」という長所だが、Rotashにとっては：

```
Locketの場合：
  1人の相手からの1枚を待つ → ウィジェットに常時出ていても発見の喜びは薄れない
  （1対1の関係なので、いつ来たか分かればそれで十分）

Rotashの場合：
  「今日は誰？」という**7人分の不確実性**が体験の本体（F-2）
  → ウィジェットに常時「今日はMINA」が出ていると、
     朝の通知で得られる「今、初めて知った」という瞬間が薄まる
  → さらに横向きにした瞬間に現れる7分割という**儀式性**（README冒頭の設計）が、
     常時ホーム画面に見える状態と衝突する
```

**→ 判定：DON'T（現状）。** 「今日の担当者名」をウィジェットに常時表示することは、
F章・D-4が守ろうとしている「意図的に不確実性を保つ」設計と矛盾するため見送る。

ただし、**完成後の作品（Memories）を振り返るためのウィジェット**は話が別である。
これは「今日は誰？」の不確実性を壊さない（既に確定した過去の作品を見るだけ）。
**→ 判定：LATER。** Memoriesの積層（`GROWTH_STRATEGY.md` C-2・S1）が実装され、
かつグループの継続週数が十分に積み上がってから検討する程度でよい。

---

## 2. 友達上限を「10人→20人」に動かした事実 — 7人という数字の扱い方への示唆

Locketの友達上限は固定値ではなく、**10人から20人へ引き上げられた実績がある。**
[（出典）](https://mrhack.io/is-there-a-limit-of-friends-you-can-add-in-locket-widget-app/)

### Rotashへの示唆：7人は「データで動かしうる数字」ではなく「体験の定義」である

H-2は「上限が希少性を作る」という一般論の根拠としてLocketを引いたが、
**Locketの上限（10→20）とRotashの上限（3〜7、定員7）は、決定の性質が違う。**

| | Locketの上限 | Rotashの上限 |
|---|---|---|
| 上限の意味 | 「これ以上は関係が薄まる」という**経験則的な閾値** | 「7日間 = 7人 = 1人1日」という**構造そのもの**（`GROWTH_STRATEGY.md` 0-2） |
| 動かした場合 | 希少性の強さが変わるだけ（10でも20でも「上限がある」ことは変わらない） | **7を6や8に変えると、「1人1日」という体験の定義自体が壊れる** |
| 調整の余地 | データを見て柔軟に調整できる | **調整できない。7はパラメータではなく前提** |

**→ 判定：確認（数字を動かさない理由の明文化）。**
Locketの事例は「上限は運用で調整しうるもの」という誤解を招きかねないため、
**Rotashの7人だけは例外であり、Locketのような柔軟な引き上げの対象にしない**ことを
明記しておく。（一方、3人という下限は `GROWTH_DIAGNOSIS.md` 仮説の検証結果次第で
見直す余地があることは変わらない。）

---

## 3. TikTokでの意図的な種まき — Kを「待つ」のではなく「仕掛ける」運用

LocketはTikTokで、統一フォーマットの動画をナノ/マイクロインフルエンサーに大量発注し、
**「N本に1本はバズる」というTikTokのアルゴリズム特性を利用**して拡散した。
後には社内growth teamが自社の26アンバサダーアカウントで、毎日（時に1日複数回）
同じ「Locketフォーマット」を投稿し続ける体制に移行した。動画の10%が中央値の10倍再生、
3%以上が50倍のバイラル再生を記録している。
[（出典）](https://www.socialgrowthengineers.com/lockets-26-creators-298m-views-free-hook-dataset)

### Rotashへの示唆：K施策との相性は良くない。理由をRotash固有の言葉で説明する

一見、`GROWTH_STRATEGY.md` M2（9:16のブランド化されたシェア画像）を実際に
TikTokで拡散させるための「仕込み」戦略として魅力的に見える。**しかし採用しない。**

理由はRotash固有である。Locketが拡散したのは**インフルエンサー個人の日常写真**であり、
誰の写真を使っても成立する。一方Rotashの完成作品は**特定の7人が過ごした特定の1週間**
そのものであり、**第三者（インフルエンサー）に投稿させることが原理的にできない。**
7人の名前が載った作品を他人が「自分の投稿」として使うことは、
`GROWTH_STRATEGY.md` E-5（キャプションを提供しない。宣伝のための投稿にしない）が
守ろうとしている**「投稿の動機は自分たちの1週間が良かったから」という原則そのものを壊す。**

**→ 判定：DON'T。** ただし「大量投稿によるTikTokアルゴリズムの突破」という
戦術面の学びは、**7人自身がシェアした投稿の後押し**という形でなら応用できる余地がある
（例：完成作品を投稿した参加者に対して、Rotash公式アカウントがリポストで応援する等）。
これは新しいMUST/SHOULDには昇格させず、**LATER・要検討**にとどめる。
現段階（`GROWTH_DIAGNOSIS.md` Pre-PMF診断）でやることではない。

---

## 4. 広告によるマネタイズ — Rotashが選ばない理由の再確認

LocketはMoloco SDK導入で広告収益を87%伸ばした。
[（出典）](https://www.moloco.com/case-studies/locket-widget)

### Rotashへの示唆

`GROWTH_STRATEGY.md` J-2・[`TIMETREE_GROWTH_CASE_STUDY.md`](TIMETREE_GROWTH_CASE_STUDY.md) §4・
[`MIRO_GROWTH_CASE_STUDY.md`](MIRO_GROWTH_CASE_STUDY.md) §1 で既に**広告不採用**の結論は
出ており、Locketの事例もこの結論を変えない。7人の思い出の間に広告が挟まることは、
BeRealが壊れた道筋（H-1）と同種のリスクである。**→ 判定：DON'T（既存結論の維持）。**

---

## 5. まとめ

| 節 | 判定 | 既存資料との関係 |
|---|---|---|
| §1 ウィジェット配信 | **DON'T**（進行中の担当者表示）/ **LATER**（Memories振り返りのみ） | F章・D-4の不確実性設計と衝突するため見送り |
| §2 友達上限の可変性 | **確認**（7人は動かさない） | H-2の「上限」論を精緻化。数字の性質がLocketとは違うことを明記 |
| §3 TikTok意図的種まき | **DON'T**（インフルエンサー起用）/ **LATER**（自発シェアの後押し） | E-5と衝突。第三者が7人の作品を代弁できない |
| §4 広告マネタイズ | **DON'T** | J-2、他2資料と結論一致 |

**この資料の結論：**
LocketはH-2で既に一度参照された事例だが、深掘りすると**Rotashが真似るべきでない理由**
の方が多く見つかった。ウィジェット配信もTikTok種まきも、Locketでは機能する前提
（1対1の関係、個人の日常写真）が、**Rotashのコア（7人という単位、特定の週の作品）**
とは噛み合わない。これで4本の事例研究（あすけん・TimeTree・Miro・Locket）を通じて、
**Rotashが「他社の成功パターン」を表面的に真似た場合に何が壊れるか**を、
それぞれ異なる角度から具体的に説明できる資料が揃ったことになる。

---

## 出典

- [From A Gift For His Girlfriend To 80M Downloads — What A Startup (Substack)](https://whatastartup.substack.com/p/he-built-an-app-for-his-girlfriend-and-ended-up-having-80-million-total-downloads)
- [Social widget "Locket" received $12.5 million in financing — Medium](https://medium.com/@jamelet/social-widget-locket-received-12-5-million-in-financing-led-by-ins-lianchuang-2fb80fffa86a)
- [Is there a LIMIT OF FRIENDS you can add in Locket Widget app? — mrhack.io](https://mrhack.io/is-there-a-limit-of-friends-you-can-add-in-locket-widget-app/)
- [How to add up to 20 friends in Locket widget app? — mrhack.io](https://mrhack.io/how-to-add-up-to-20-friends-in-locket-widget-app/)
- [How Locket Widget grew Moloco ad revenue 87% — Moloco Case Study](https://www.moloco.com/case-studies/locket-widget)
- [Locket Used 26 Creators To Get 298M Views — Social Growth Engineers](https://www.socialgrowthengineers.com/lockets-26-creators-298m-views-free-hook-dataset)
- [Locketapp's TikTok Influencer Strategy For Gaining 250M Views — Shortimize](https://www.shortimize.com/blog/locketapps-tiktok-influencer-strategy-for-gaining-250m-views)
