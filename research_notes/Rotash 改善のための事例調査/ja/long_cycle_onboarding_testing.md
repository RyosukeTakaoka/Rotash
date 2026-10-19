# 長いサイクルでのエンゲージメント、新しいコンセプトのオンボーディング、初期テスト（Rotash 向け）

> 【訳注】本書は `long_cycle_onboarding_testing.md`（英語原文）の全文和訳です。URL・固有名詞・数値は原文のままにしてあります。

背景：Rotash は少人数グループ向けの iOS アプリです。友達の1人が1日1枚写真を撮り、7枚の写真で週ごとのコラージュができます。3人の初期テスター（友達）は、これを「みんなで1枚の絵を描くこと」だと受け取り、最初の1週間が終わる前に「つまらない」と言い、「1日に開く理由が1つしかない」と述べました。

調査メモ：この調査の途中で、複数の一次情報サイト（nngroup.com、paulgraham.com、business.columbia.edu）が読み込めませんでした（DNS エラー）。一次の本文を読めなかった箇所は、「（二次情報）」または「（一次情報では未検証）」と記しています。私の背景知識にはあっても、ここで出典を確認できなかった項目は、調査結果として示さず、「調査の空白」に挙げています。

## Q1. 長いサイクルの報酬設計：週ごとの見返りの前に、どんな中間報酬や進捗のシグナルが人を引きとめるか？

### 要点
最も裏づけの強い知見は、ゴール勾配（goal-gradient）／付与された進捗（endowed progress）の仲間です。見えている目標が近づくほど人はペースを上げ、あらかじめ埋められた進捗は達成率を高めます。したがって、目に見えて埋まっていく7スロットのコラージュは、できればスロットが1つ埋まった状態から始めると、筋のよい仕組みです。ツァイガルニク効果（「未完了のことは記憶に残る」）は、2025年のメタ分析では支持されなかったため、正当化の根拠として使うべきではありません。1つの通知を軸にした1日1回のアプリ（BeReal）や、遅延して見られるアプリ（Dispo）は、目新しさが薄れると、1つのきっかけだけでは引力が失われることを示しています。

### 引用付きの調査結果
**ゴール勾配効果（Kivetz, Urminsky & Zheng 2006、Journal of Marketing Research 43(1):39–58）**
- 実際のカフェの「10杯買うと1杯無料」のカードプログラムで、無料のコーヒーに近づくほど、客はコーヒーをより頻繁に買いました — [Columbia Business School の研究ページ](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)；[Columbia の解説要約](https://business.columbia.edu/insights/chazen-global-insights/goal-gradient-hypothesis-resurrected-purchase-acceleration)
- 2つ目のフィールド研究では、報酬証明書をもらうために曲を評価していたインターネットユーザーが、報酬のしきい値に近づくにつれて、より頻繁に訪れ、1回の訪問でより多くの曲を評価し、セッションをやめにくくなりました — [Columbia の研究ページ](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)；[Chicago Booth Review](https://www.chicagobooth.edu/review/going-goal)
- 「見せかけの目標進捗」：2つのボーナススタンプがすでに押された12スタンプのカード（あと10回の購入が必要）は、ふつうの10スタンプのカードより、早く達成されました — [Columbia の研究ページ](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)
- 最初の報酬に向けてよりペースを上げた人ほど、その後プログラムに素早く再び関与する傾向がありました。著者らは、この勾配は、慣れ、期限切れの心配、時間的な傾向、個人差では説明できないと報告しています — [Columbia の研究ページ](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)
- 論文の全文 PDF（今回のセッションでは取得できなかったため、正確な効果量は未検証）：[goalgradient.pdf](https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf)

**付与された進捗効果（Nunes & Drèze 2006、Journal of Consumer Research 32(4):504–512、DOI 10.1086/500480）**
- 定義：目標に向けて人為的な進捗を与えられた人は、その目標に向けてより粘り強くなります。洗車場でのフィールド実験では、1つのグループには白紙の8スタンプのカード、もう1つには2スタンプがあらかじめ押された10スタンプのカードが渡されました。どちらも、無料にするには8回の洗車が必要でした — [IDEAS/RePEc の記録](https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html)
- この効果は、無料のスタンプを「無駄にしたくない」という気持ちではなく、課題が部分的に終わっているという感覚を通じて働くようです。付与の理由づけと、進捗を数える単位に左右されます — [IDEAS/RePEc の要旨](https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html)
- よく引用される達成率は、34%（あらかじめ押されたカード）対19%（白紙のカード）です。二次的なメモ（*Hooked* の読者ノート）は、これを「達成率82%増」としており、34/19 ≈ 1.79 と合います — [Hooked の Goodreads ノート](https://www.goodreads.com/notes/23567071-hooked/26090533-ankur-jhaveri/3175af60-5eb8-4f2a-b970-88401aa6c512)。注意：34%／19%という数字は、今回のセッションでは論文の全文と照合できませんでした。

**ツァイガルニク効果 — 弱い。頼らないこと**
- Ghibellini & Meier による2025年のメタ分析（DOI 10.1057/s41599-025-05000-w）は、未完了の課題に対する一般的な記憶の優位性を見出しませんでした。一方で、中断された課題に戻って完了させる一般的な傾向（オフシアンキナ効果）は見出しました。著者らは、ツァイガルニク効果には「普遍的な妥当性がない」と結論づけています — [IDEAS/RePEc の記録](https://ideas.repec.org/a/pal/palcom/v12y2025i1d10.1057_s41599-025-05000-w.html)；[University of Bern PDF](https://www.kog.psy.unibe.ch/e48276/e1785865/s41599-025-05000-w1_ger.pdf)；[Wikipedia の要約](https://en.wikipedia.org/wiki/Zeigarnik_effect)
- 掲載誌の表記は一貫していません。RePEc は「Palgrave Communications」とし、他の情報源は *Humanities and Social Sciences Communications* としています（同じ雑誌が改称されたもの） — [IDEAS/RePEc](https://ideas.repec.org/a/pal/palcom/v12y2025i1d10.1057_s41599-025-05000-w.html)
- 二次的なブログは、59件の研究が含まれ、d≈0.15、再開率は約67%と報告しています。どちらの数字も、一次の要旨では確認されていません — [Yu-kai Chou のブログ（二次）](https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/)

**遅延して見られる仕組み：Dispo**
- Dispo の App Store の掲載ページによると、写真は毎日午前9時に「現像」されます。使い捨てカメラの仕組みです — [App Store の掲載ページ](https://apple.co/3qCRWpk)
- あるユーザーレビューは、翌日まで待つことがアプリをダウンロードした主な理由だったと述べ、アップデートでそれが削除されたことに不満を述べています。開発者は、ユーザーが写真をすぐに受け取るか午前9時に受け取るかを選べるようになったと返信しており、同社が純粋な「待つ」仕組みから離れたことがうかがえます — [App Store の掲載ページのレビュー](https://apple.co/3qCRWpk)（レビュー1件のみ。弱い証拠）
- Dispo は、待ち時間を、ユーザーにより多くの「喜び」を与えるものとして位置づけました — [dot.la](https://dot.la/dispo-2648134232.html)
- Spark Capital は、共同創業者の David Dobrik をめぐる騒動の後、出資を引き上げ、アプリはその後ソーシャル機能と有料コンテンツの方向へ動きました。リテンションのデータは公開されていません — [PetaPixel のタグページ](https://petapixel.com/tag/dispo/)；[tuapppara（2026年、スペイン語）](https://tuapppara.com/redes/dispo/)

**1日1回のきっかけ：BeReal — 「1日に開く理由が1つしかない」への警告例**
- NYT が報じた Apptopia のデータ：2022年10月に約1,500万人だった日次ユーザーが、2023年3月までに600万人未満に落ちました。報道は、この減少の理由を、Z世代の間で目新しさが薄れたことに求めました — [Platformer](https://platformer.news/how-bereal-missed-its-moment)
- PetaPixel は、DAU が約2,000万人のピークからほぼ半減し、2023年2月までに1,040万人になったと報じました — [PetaPixel](https://petapixel.com/2023/02/22/bereal-may-be-on-the-out-users-have-nearly-halved-since-peak)
- BeReal は第三者の推計に異議を唱え、DAU は2,000万人以上、後に2,500万人以上だと主張しました。したがって、減少の大きさには争いがあります — [Platformer](https://platformer.news/how-bereal-missed-its-moment)
- 論評は、毎日のプロンプトが緊急性を生んだ（友達の投稿は自分の投稿をした後でしか見られない）が、ユーザーが「見逃している」ものは、長期的に引きとめるほど魅力的ではなかった、と論じています — [Stack Influence（マーケティングブログ、弱い）](https://stackinfluence.com/what-is-bereal-why-gen-zs-photo-app-matters/)

**週ごとのサイクル：Duolingo のリーグ**
- リーグとは、無作為に分けられた約30人のユーザーが、7日間の XP で順位を競う週ごとのリーダーボードで、ティア（ブロンズ → ダイヤモンド）の間で昇格と降格があります — [Deconstructor of Fun の Duolingo 分解](https://duolingo.deconstructoroffun.com/mechanics/leagues)；[We Got This Covered](https://wegotthiscovered.com/fyi/all-duolingo-leagues-explained/)
- 批評家は、リーグが、ポイント目当てに簡単なレッスンをひたすらこなすよう人を駆り立てることがあり、活動が増えることが必ずしも価値の増加を意味しない、と述べています — [Desirability Lab](https://desirabilitylab.com/backfill/backfill-2023-278-duolingo-social-features)

### 推論
- **週の進捗を、目に見えて数えられるようにする。** 日ごとに埋まっていく7スロットのグリッドは、教科書どおりのゴール勾配です。Kivetz のデータは、エンゲージメントが5〜7日目に向けて上がるはずだと示唆しています。したがって、危険地帯は1〜3日目で、これはまさに Rotash のテスターが興味を失った時期です。「3/7 — コラージュまであと4枚」を目立つように表示してください。
- **最初から付与された進捗を与える。** 最初の週は、すでに1スロットが埋まった状態で始めます。オンボーディング中に撮るグループ写真や、招待者が撮る「0日目」の写真です。Nunes & Drèze の調整要因が、ここでは重要です。先行分には、もっともな理由（「あなたのグループの最初の写真」）と、同じ単位（写真）が必要です。
- **サスペンスやツァイガルニク効果だけで人を呼び戻せるとは期待しない。** 再開（オフシアンキナ）の傾向のほうが、より裏づけのある効果です。したがって、毎日を、コラージュを覚えているかどうかではなく、グループの未完成のコラージュを再開することとして位置づけてください。
- **BeReal と Dispo はどちらも、1つの毎日のきっかけが薄れていくことを示している。** 開くたびに、変化のあるものが必要です。誰の番か、友達の新しい写真、リアクションなどです。「1日に開く理由が1つしかない」は、テスターの短気というだけでなく、既知の失敗パターンです。
- **Rotash は Dispo／BeReal と違う。** 毎日撮るのは1人だけなので、7人のうち6人はその日の閲覧者です。彼らが毎日開く理由は、友達の写真を見てリアクションすること、そしてコラージュが埋まっていくのを見ることになります。自分の番は、およそ週に1回です。

### 調査の空白
- Kivetz らの正確な効果量（たとえば、報酬に向けて購入間隔がどれだけ縮むか）は、PDF が取得できなかったため、確認していません。
- Nunes & Drèze の34%対19%という数字は広く引用されていますが、今回のセッションでは論文の全文で確認していません。
- 今回のセッションでは調べておらず、出典も確認していないため、使う前に検証が必要なもの：Spotify Discover Weekly（毎週月曜に更新されるプレイリスト）と Spotify Wrapped（年1回）という「期待の儀式」。Wordle の1日1回のパズルとシェアできる結果のグリッド。Strava の週次サマリー。Slowly（距離に応じて遅れて届く手紙）。1 Second Everyday（モンタージュの見返りが数週間から数か月後にようやく届く）。それぞれ、関連するパターンです（決まった配信時刻、希少な1日単位、シェアできる成果物、価値を感じさせる遅延）が、そのリテンション効果について出典のあるデータは持っていません。
- リーグが、レッスン数やリテンションにどう影響するかについて、Duolingo の一次データは見つかりませんでした。Duolingo はリーグやストリークについて公に語っていますが、今回のセッションでは引用できる数字を見つけられませんでした。
- Dispo のリテンションデータは見つかりませんでした。

## Q2. フックモデル（Nir Eyal）：きっかけ、行動、変動報酬、投資 — 友達の写真への当てはめ方と、批判

### 要点
フックモデルは有用な設計チェックリストですが、直接の実験的検証はありません。その「変動報酬」の段階は、オペラント条件づけの研究に基づいており、倫理的に議論があります。Rotash にとって自然な変動報酬は、社会的なもの（「友達は今日何を撮った？」）です。投資の段階（各写真が、共有される週ごとの成果物に蓄えられる）は、ゴール勾配の研究に最もはっきり裏づけられている部分です。

### 引用付きの調査結果
- モデルの報酬の段階は、行動を強化するドーパミンを放出するものとして説明されます。その行動的な基盤は、動物での間欠強化の研究（たとえば Olds & Milner）にあります。これを製品の利用に拡張するのは推論です — [Thoughtworks](https://www.thoughtworks.com/en-sg/insights/blog/addicted-industry-matures)；[SuperSummary の背景](https://www.supersummary.com/hooked/background/)
- 批評家は、変動報酬をスロットマシンの設計にたとえます。Johann Hari（*Stolen Focus*、2022年）は、Eyal の立場を略奪的なビッグテックの代表だとし、Guardian の書き手は、エンゲージメントを促すために心理学を使うことの倫理に疑問を呈しました — [SuperSummary](https://www.supersummary.com/hooked/background/)；[Thoughtworks](https://www.thoughtworks.com/en-sg/insights/blog/addicted-industry-matures)
- Big Think は、変動報酬はスロットマシンや FarmVille のようなゲームには合うが、Google のような実用ツールには意味をなさない、と論じています。つまり、この仕組みは製品の種類に左右されます — [Big Think](https://bigthink.com/?p=54491)
- Eyal 自身も倫理に言及しています（「Manipulation Matrix」／倫理的に作ること） — [Goodreads 経由の Eyal のブログ](https://www.goodreads.com/author_blog_posts/18729825-the-hook-model-and-how-to-build-it-ethically)
- *Hooked* は、付与された進捗の洗車の研究を、「投資」の段階の例として引いています — [Hooked の Goodreads 読者ノート](https://www.goodreads.com/notes/23567071-hooked/26090533-ankur-jhaveri/3175af60-5eb8-4f2a-b970-88401aa6c512)
- フックモデル全体を検証した査読付きのテストは見つかりませんでした — [Behavioral Scientist](https://www.thebehavioralscientist.com/?p=2407)；[Ivy の書評](https://ivy0.substack.com/p/book-review-hooked)

### 推論
- **きっかけ（Trigger）：** 今日の写真が撮られたときのプッシュ通知（Rotash にはすでにあります）が、外的なきっかけです。時間とともに、内的なきっかけは、友達が今日見たものへの好奇心になるべきです。
- **行動（Action）：** 写真を見るための、ワンタップでの起動。摩擦をなくしてください。ログインの壁はなしです。
- **変動報酬（Variable reward）：** Eyal の「部族の報酬」（社会的承認）は、友達の写真を見ることに当てはまります。変動性はすでに組み込まれています。毎日、撮る人も、被写体も、時間も違います。手軽な反応（リアクション、一行のキャプション、撮影場所当て）を加えれば、倫理的に疑わしいスロットマシン的な仕組みを足さずに、1回開くごとの変動報酬を増やせます。
- **投資（Investment）：** 閲覧しリアクションした写真の1枚1枚が、共有コラージュを築いていきます。週ごとのコラージュと過去の週のアーカイブは、蓄積された価値であり、乗り換えコストを高めます。「付与された進捗」の論理が当てはまるのはここです。
- **倫理的な姿勢：** 小さく親密なグループでは、落ち着いたリズムが売りになります。偽の緊急性は避けてください。操作的だと見られる製品にとって、その評判上のコストは増しています。

### 調査の空白
- フックモデルで設計された製品のほうがユーザーを保持できる、と示す対照研究はありません。
- 今回のセッションでは *Hooked* の一次の本文を読んでいないため、章レベルの主張（たとえば報酬の3種類：部族、狩り、自己）は、私の背景知識によるもので、本で確認する必要があります。

## Q3. 完成した例がまだないときの、なじみのない概念のオンボーディング：サンプル作品、シード（仕込み）コンテンツ、アハ体験、価値到達までの時間、空の状態

### 要点
テスターの誤解（「みんなで1枚の絵を描くこと」）は、典型的な空の状態（empty state）の問題です。完成した成果物こそが説明であり、それは7日目まで存在しません。標準的な対処は、スターターまたはデモのコンテンツ、つまり完成したコラージュのサンプルで、できれば個別化されたものと、ガイド付きの最初の行動です。Facebook の「10日間で7人の友達」や Slack の「2,000件のメッセージ」のような「アハ体験」の指標は、広く繰り返されていますが、一次の出典は弱いです。

### 引用付きの調査結果
**空の状態とスターターコンテンツ**
- スターターコンテンツは、コンテンツを保存する機能やテンプレートに沿った機能で最もよく機能します。広く受け入れられ、主な機能を見せ、削除や置き換えができるものであるべきです — [ServiceTitan Anvil デザインシステム](https://anvil.servicetitan.com/docs/web/patterns/empty-states)
- サンプルデータを個別化すると、体験が良くなります。スターターコンテンツがあれば、ユーザーは機能を実際に触って学び、その後で削除できます — [Emplifi Soul デザインシステム](https://soul.emplifi.io/latest/patterns/patterns/empty-states-Q4JtHNtG)
- Grammarly のデモ文書は、やってみることで機能を教えます — [Wix Studio blog](https://www.wix.com/studio/blog/empty-states-ux-design)
- 空の状態は、教育だけでなく、次に何をすべきかを伝え、行動を促すべきです — [Smashing Magazine (2017)](https://smashingmagazine.com/2017/02/user-onboarding-empty-states-mobile-apps)
- Vercel の Geist デザインシステムは、空の状態への4つのアプローチを挙げています：ブランクスレート、情報提供、教育、ガイド（いじって試せるスターターコンテンツ） — [Vercel Geist](https://vercel.com/geist/empty-state)
- 教育的なコンテンツは、短く、スキップできるものであるべきです — [ServiceTitan Anvil](https://anvil.servicetitan.com/docs/web/patterns/empty-states)

**アハ体験：検証状況**
- Facebook の「10日間で7人の友達」：Chamath Palihapitiya 自身の Quora の回答（転載）は、Facebook が、一定期間内にユーザーが持つ友達の数と、離脱する確率との間に、初期のうちに関連を見つけ、新規ユーザーをすばやく「アハ」の瞬間に到達させるためにそれを使った、とだけ述べています。この文章には、「10日で7人」という具体的な数字は含まれていません — [Chamath archive](https://chamatharchive.com/?p=608)。「10日間で7人の友達」という正確な表現は、一次の引用のない二次的な記事に現れます — [Notion のケーススタディ（二次）](https://scratch-puffin-363.notion.site/Facebook-s-7-friends-activation-story-a-PM-case-study-33dec508b5118053bff8e0233fedd0f3)；[Airtribe Substack（二次）](https://airtribe.substack.com/p/pm-growth-lessons-for-2024)。注意：この数字は伝承として扱ってください。根底にある原則（友達の数のしきい値がリテンションを予測する）は、Chamath が認めています。
- Slack の「2,000件のメッセージ」：Stewart Butterfield は（Andrew Chen の *The Cold Start Problem* 経由で）、2,000件のメッセージをやり取りしたチームは Slack を「本当に試した」と言え、そうした顧客の93%がその後も使い続けていた、と述べたと引用されています。約10人のチームでは、およそ1週間分のメッセージです — [The Cold Start Problem の Goodreads ハイライト](https://www.goodreads.com/notes/56962799-the-cold-start-problem/84411704-mikko-ikola/435bc888-c6a7-45f1-83c2-6c66617e1ab2)。注意：二次情報（読者のハイライト経由の書籍の引用）で、時期は過去（2014〜2015年ごろ）であり、観察された相関であって、因果的なしきい値ではありません。

### 推論
- **最初の写真の前に、完成した例を見せる。** 初回起動時や招待時に、完成した7枚のコラージュのサンプル（シード）を、できればスロットが1つずつ埋まっていくアニメーションで見せ、「毎日、別の友達が1枚の写真を加えます。7日目には、これができあがります」といった文言を添えます。これは「みんなで1枚の絵を描く」という誤解を、直接正します。
- **できる範囲でサンプルを個別化する。** スロットにグループの名前やアバターを載せます（「月：Aki、火：あなた……」）。こうすれば、ローテーションが明確になります。
- **価値到達までの時間を短くする。** 本当の見返りは7日目に来るので、1日目に小さな見返りを作ります。スロット0としてのオンボーディングのグループ写真（付与された進捗）、3日目か4日目の途中までできたコラージュのプレビュー、あるいは最初の週を「短い週」（たとえば3枚のミニコラージュ）にして、最初の成果物が数日以内に届くようにする、などです。
- **Rotash 自身のアハ体験の仮説を、Slack／Facebook 流に定義する。** たとえば「最初の10日以内に、友達の写真を3枚以上見て、完成したコラージュを1つ見たメンバー」。そして、2回目のテストグループでリテンションと突き合わせてテストします。法則ではなく、確かめるべき相関として扱ってください。

### 調査の空白
- Nielsen Norman Group の空の状態やオンボーディングの記事は、取得できなかった（DNS の失敗）ため、NN/g 固有のガイダンスは引用していません。
- 「10日間で7人の友達」の一次の出典（講演や動画のタイムスタンプ）は見つかりませんでした。
- 「完成した例がない」問題を解決した写真コラージュ型やスローソーシャル型のアプリの公開事例は、見つかりませんでした。Reforge や Lenny's Newsletter の価値到達までの時間に関するコンテンツには、今回のセッションではアクセスできませんでした。

## Q4. 初期テスト：サンプルサイズ、コンシェルジュ／オズの魔法使いテスト、リテンションのベンチマーク、Sean Ellis テスト、撤退基準、YC/PG の助言

### 要点
3人の友達は、理解のしやすさと使いやすさの問題を見つけるには十分ですが（「一緒に絵を描く」という誤解は、有効な発見です）、需要やリテンションについては、ほとんど何も教えてくれません。使いやすさの検証には、約5人の定性テストを使います。需要については、より多くのグループで、少なくとも週次サイクルを2回通して実施し、称賛ではなく行動（起動、閲覧率、2週目の再訪）を測ります。よく知られたベンチマークの数字（D1/D7/D30 で 40/20/10）は、上位の成績を示すものであって、典型的なアプリのものではなく、小さなグループには当てはめにくいです。

### 引用付きの調査結果
**サンプルサイズ**
- 「5人」のルールは、Nielsen & Landauer の問題発見モデル、found = N(1−(1−L)^n) に由来します。L は、1人のユーザーが特定の問題に当たる確率です。5人で問題の約85%が見つかるのは、L ≈ 31% のときだけです。これは定性的な発見のためのルールであり、測定のためのものではありません — [MeasuringU](https://measuringu.com/category/sample-size/page/5/)；[UX Planet](https://uxplanet.org/sample-size-for-usability-study-part-1-about-nielsen-and-probability-efffecdbfa95)
- シミュレーションでは、5人で平均85%の問題が見つかりましたが、その割合はほぼ100%から55%までばらつきました — [W3C WAI リストの投稿（Slatin、2004）](https://lists.w3.org/Archives/Public/w3c-wai-gl/2004AprJun/0572.html)；[Human Factors International](https://www.humanfactors.com/newsletters/enough_is_enough.html)
- 異なるユーザーグループや定量的な目標には、より大きなサンプルが必要です — [Koji blog（ベンダー、弱い）](https://www.koji.so/blog/how-many-users-usability-testing-2026)
- NN/g の一次の記事（今回のセッションでは未取得）：https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/

**リテンションのベンチマーク**
- Lenny Rachitsky と Casey Winters は、実務家に調査をしました。コンシューマー向けソーシャルでは、6か月のユーザーリテンションが約25%なら「良い」、約45%なら「素晴らしい」。コンシューマー向けトランザクション系は約30%／50%、コンシューマー向け SaaS は約40%／70%です — [Lenny's Newsletter](https://www.lennysnewsletter.com/p/what-is-good-retention-issue-29)；[Casey Accidental](https://www.caseyaccidental.com/p/what-is-good-retention-an-exhaustive-benchmark-study-with-lenny-rachitsky)
- 批判：これらのベンチマークは、象徴的で大規模なビジネスを築いた人たちから来ています。リテンション曲線が横ばいになれば、これらを下回っていても、ビジネスは成り立ちえます — [Founders Fuel](https://foundersfuel.beehiiv.com/p/good-great-retention)
- Andrew Chen（Quettra のデータ経由）：平均的なアプリは、インストールから3日以内に DAU の77%を、30日以内に90%を失います — [andrewchen.com](https://andrewchen.com/new-data-shows-why-losing-80-of-your-mobile-users-is-normal-and-that-the-best-apps-do-much-better/amp/)
- 「D1 40%／D7 20%／D30 10%」というコンシューマー向けソーシャルの経験則は、見つかった情報源では、Andrew Chen によるベンチマークとして述べられては**いません**。第三者の用語集に現れ、そこでは「良い」ベンチマークの数字は、通常、上位10%または上位25%のアプリを表している、とも注記されています。同じ情報源は、2026年4月の中央値として D1 27.3%、D7 9.2%、D30 3.9% を挙げています — [MWM glossary](https://mwm.ai/glossary/retention)。注意：二次情報で、方法論も不明です。
- 別の2026年の集約サイトは、ソーシャルおよびメッセージングの中央値を D1 48%／D7 28%／D30 14% としています — [Unstar](https://unstar.app/fr/blog/app-retention-benchmarks-2026)。注意：MWM の、より低い全体の中央値とは食い違っており、どちらも一次のデータセットではありません。

**Sean Ellis テスト**
- ユーザーに「この製品が使えなくなったら、どう感じますか？」と尋ねます。40%以上が「非常にがっかりする」と答えるなら、その製品はおそらくプロダクト／マーケット・フィットがあります。2009年ごろに導入されました — [Learning Loop](https://learningloop.io/glossary/sean-ellis-score)
- Ellis は、標準的な最小サンプル数を示していません。実務家は、中核の価値を体験した回答者を少なくとも40人とし、盛り上がっているユーザーだけに調査するバイアスに注意を促しています。25%未満は弱いと読みます — [KPI Clarity](https://kpiclarity.beehiiv.com/p/testing-product-market-fit-customers-life-without-product)；[Koji](https://www.koji.so/docs/sean-ellis-test-product-market-fit)

**コンシェルジュ／オズの魔法使い**
- コンシェルジュ MVP：サービスを手作業で、目に見える形で、少数の初期採用者に提供します。オズの魔法使い：ユーザーは自動化されていると信じていますが、裏で人間が作業をしています。Zappos（オンライン注文のたびに小売店で靴を買う）が、オズの魔法使いの古典的な事例です。DoorDash の創業者たちは自分たちで注文を届け、「Food on the Table」は手作業の食事の執事（コンシェルジュ）として始まりました — [Koji コンシェルジュガイド](https://www.koji.so/docs/concierge-mvp-guide)；[Synodus MVP の例](https://synodus.com/blog/mvp-software-development-example)；[mobilespoon](https://www.mobilespoon.net/2019/06/10-shades-of-mvp.html)

**Paul Graham「Do Things That Don't Scale」（2013年）**（二次情報。paulgraham.com は取得できなかった）
- 最も一般的な「スケールしないこと」は、初期ユーザーを1人ずつ手作業で集めることです（Airbnb、Stripe、Pinterest）。「Collison installation」とは、リンクを送るのではなく、その場でユーザーをセットアップする（「ノートパソコンを貸して」）ことです。創業者がためらうのは、気恥ずかしさと怠惰のせいです — [Glasp の要約](https://glasp.co/articles/do-things-that-dont-scale)；[Alexander Jarvis による Stripe の話](https://www.alexanderjarvis.com/stripe-doing-things-that-dont-scale)；[Medium のノート](https://medium.com/@edisipka/my-notes-on-do-things-that-dont-scale-the-reality-check-i-needed-e986bad14620)
- 初期ユーザーに、並外れた体験を与えます。たとえば Wufoo の手書きのお礼状です — [Glasp の要約](https://glasp.co/articles/do-things-that-dont-scale)
- 一次のエッセイ：https://paulgraham.com/ds.html

### 推論
- **3人のテスターから何が分かるかを分類する。**「一緒に絵を描く」という誤解と「開く理由が1つしかない」は、有効な定性的な発見です（L の高い問題です）。「最初の1週間が終わる前に退屈した」は、見返りを一度も体験していないので、需要のシグナルとしては弱いです。それを理由に切り捨てないでください。かといって、そこから多くを結論づけることもしないでください。
- **これ以上作る前に、仕組みのオズの魔法使いテストを実施する。** たとえば LINE や Instagram のグループチャットで、進行役がローテーションの予定表（「今日：Aki」）を投稿し、割り当てられた人が写真を1枚投稿し、進行役が7日目に手作業でコラージュ（たとえば Canva で）を組み立てて投稿します。3〜4日目に途中までのプレビューを出してもよいでしょう。これは、ローテーションとコラージュが求められているかを、iOS アプリとは切り離して検証します。
- **テストの前に、撤退／改善／ピボットの基準を決めておく。** 事前に書いておく基準の例（説明用であり、出典のあるベンチマークではありません）：
  - 理解が解消された（オンボーディング後に80%以上がルールを説明できる）のに、毎日の閲覧が少ないなら、改善する。
  - 割り当てられた撮影者の70%以上が自分の日に投稿し、ほとんどのグループが自発的に2週目を始めるなら、続ける。
  - 投稿は問題ないのに、メンバーが自分の番の合間に戻ってこないなら、サイクルをピボットする（たとえば全員が毎日撮る、あるいは3日コラージュにする）。
  - 半数未満のグループしか、促されずに3週目を始めず、Sean Ellis 流の「非常にがっかりする」の回答が25〜40%を大きく下回ったままなら、撤退する、あるいは考え直す。
  - Lenny の、コンシューマー向けソーシャルの6か月約25%のようなベンチマークは、長期の目標であって、2週間の関門ではありません。

### 調査の空白
- 初期のリテンションに関する YC Startup School の一次資料は読んでいません（Paul Graham も二次の要約のみ）。リテンション曲線は横ばいになる必要があり、ユーザーと毎週話すべきだ、という YC の一般的な助言は、背景知識であって、ここで出典を確認したものではありません。
- 小さな非公開グループのアプリ（Locket、BeReal の友達限定、グループ写真アプリ）に固有のリテンションのベンチマークを示す情報源はありません。公開されているベンチマークは、広いコンシューマー向けソーシャルのものです。
- Sean Ellis テストには約40人以上の回答者が必要ですが、少数の小さなグループでは現実的ではなく、出典のある小サンプル向けの代替策はありません。

## Q5. 2回目のテストグループの設計：規模、募集、測定項目、期間、お世辞バイアスと目新しさバイアスの回避

### 要点
実在する友達グループを複数集めます。できれば創業者の親しい友達ではない人たちで、グループの内側にいる人に運営を任せます。最初のコラージュという見返りの後、そして目新しさが薄れた後の行動を観察できるよう、少なくとも週次サイクルを2〜3回通して実施します。意見ではなく行動を測り、仮定の質問ではなく過去の行動について尋ねます（「マザー・テスト」）。

### 引用付きの調査結果
- 称賛は「愚者の黄金」です。人は、励ますため、あるいは会話を丁寧に終わらせるために称賛を口にします。本当のシグナルは、コミットメント（時間、お金、評判）です。「使いますか……」のような仮定の質問は、過度に楽観的な答えを招くので、具体的な過去の行動について尋ねます — [Sachin Rekhi による The Mom Test](https://www.sachinrekhi.com/the-mom-test-rob-fitzpatrick)；[Yevgeniy Brikman による The Mom Test](https://www.ybrikman.com/blog/2023/03/29/the-mom-test/)；[guptadeepak の要約](https://guptadeepak.com/books/the-mom-test/)
- 実際の目新しさ効果：BeReal の衰退は、最初の急上昇の後に目新しさが薄れたことによる、と広く説明されました — [Platformer](https://platformer.news/how-bereal-missed-its-moment)；[Mancunian Matters](https://www.mancunianmatters.co.uk/?p=170610)
- 異なるユーザーグループでテストするには、定性的な発見のために、グループごとに約3〜5人の別々のサンプルが必要です — [Koji（ベンダー、弱い）](https://www.koji.so/blog/how-many-users-usability-testing-2026)；[UX Planet](https://uxplanet.org/sample-size-for-usability-study-part-1-about-nielsen-and-probability-efffecdbfa95)
- Slack のしきい値は、10人のチームで約1週間分のメッセージでした。したがって、「グループがしきい値に達したか」を測ることは、週次サイクルに合います — [Cold Start Problem のハイライト](https://www.goodreads.com/notes/56962799-the-cold-start-problem/84411704-mikko-ikola/435bc888-c6a7-45f1-83c2-6c66617e1ab2)

### 推論（提案する設計。1つの情報源から取ったものではない）
- **分析の単位は、個人ではなくグループ。** Rotash の価値は集団的なものなので、4〜7人のグループを4〜6つ（約20〜40人）にすることを計画してください。そうすれば、グループ単位の比較がいくらかでき、Sean Ellis の調査に必要な約40人の回答者にも近づきます。
- **募集：** すでに存在するグループ（サークル仲間、寮の仲間、同僚）を、グループ内の「チャンピオン」1人を通じて募集し、その人が他のメンバーを、Collison installation 流の対面のセットアップで招待します。お世辞バイアスを減らすため、少なくとも半数のグループは、創業者の交友圏の外から入れてください。マザー・テスト流のシグナルとして、小さなコミットメント（たとえば、各自が自分の撮影日を引き受ける）を得ます。
- **期間：** 7日間の完全なサイクルを、少なくとも2回、できれば3回。1週目には目新しさとオンボーディングが含まれます。2週目は、最初のコラージュという見返りが人々を呼び戻すかを示します。3週目は、目新しさが薄れた後の行動を示します。最終的な測定の日付は、あらかじめ決めておきます。
- **測定項目（Rotash の分析から）：** メンバーごとの、撮影者ではない日の1日の起動率。割り当てられた撮影者が自分の日に投稿した割合。投稿から閲覧までの時間。グループ週ごとのコラージュ完成率。コラージュのシェア率または保存率。創業者の促しなしに、グループが2週目や3週目を始めるか。オンボーディング後の理解度チェック（「Rotash を一文で説明して」）。テスト終了時の Sean Ellis の質問。そして、実際に何をしたかについての、マザー・テスト流の終了インタビュー（「最後に開いたのはいつで、なぜ？」）。
- **バイアスの管理：** テスト中は創業者による後押しを避けます（起きたものは記録します）。オンボーディングの別バージョンをグループ間で比較します（A：現行、B：サンプルコラージュと付与された0日目のスロット）。グループに「正しい」行動を教えないでください。
- **サイクルの長さの変種：**「週ごとの見返りは遠すぎる」という中核の仮説を直接検証するため、1〜2グループを、より短いサイクル（たとえば3枚または4枚のコラージュ）で実施します。変種間で、1〜3日目の活動を比べます。

### 調査の空白
- 週次サイクルのアプリで、目新しさと定常状態の行動を切り分けるのに必要な最小サイクル数について、学術的な情報源は見つかりませんでした。「2〜3サイクル」は、出典のあるルールではなく、理屈に基づく経験則です。
- 小さな非公開ソーシャルアプリの、グループ単位のベータテストの運営に特化した、出典のあるガイダンスは見つかりませんでした。
