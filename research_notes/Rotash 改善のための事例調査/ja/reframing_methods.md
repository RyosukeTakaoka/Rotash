# ユーザーフィードバックの裏にある本当の問題を見つける：リフレーミング、JTBD、マザー・テストと関連する手法

> 【訳注】本書は `reframing_methods.md`（英語原文）の全文和訳です。URL・固有名詞・数値は原文のままにしてあります。

> 調査過程についての注記：今回のセッションでは、WebFetch と直接の HTTP は、試したすべてのドメイン（hbr.org、nytimes.com、review.firstround.com、library.hbs.edu、psychologicalscience.org、therewiredgroup.com）で、外向き通信のプロキシに遮断されました。以下の調査結果はすべて、挙げたページから検索ツールが要約した、検索結果のスニペットに基づいています。一次のページは、全文を**開いていません**。**[背景知識。再検証なし]** と印をつけた項目は、調査者の事前の知識によるものです。レポートを書く人は、これらを確度を下げて示すか、省くべきです。

---

## 1. 「遅いエレベーター／鏡」の話（Wedell-Wedellsborg）と、彼のリフレーミングの手法

### 要点
エレベーターと鏡の話は、Thomas Wedell-Wedellsborg の HBR の記事「Are You Solving the Right Problems?」（2017年1〜2月号）の冒頭の例で、彼はそれを *What's Your Problem?*（HBR Press、2020年）で拡張しました。彼はこの話を、*述べられた*問題（「エレベーターが遅い」）と、*本当の*問題（「待つのが嫌だ」）を切り分けるために使っています。これは教えるための寓話であり、記録された事例ではありません。その由来は逸話的で、彼が考案したものではありません。

### 引用付きの調査結果
- HBR の記事で語られている状況設定：あなたはオフィスビルのオーナーで、テナントが、エレベーターが古くて遅く、よく待たされると不満を言っています。何人かは、賃貸契約を解約すると脅しています。ほとんどの人は「解決策の空間」の修正に飛びつきます。エレベーターの交換、より強力なモーター、アルゴリズムの改良です — [HBR 2017年の記事の検索要約と二次的な記事。Medium/nyc-design](https://medium.com/nyc-design/reframing-the-problem-200f6c966dfc)；[Katie Martin](https://katielmartin.com/2020/04/26/are-we-solving-the-right-problems/)；[HBR ポッドキャスト「The Secret to Better Problem Solving」（2016年12月）](https://hbr.org/podcast/2016/12/the-secret-to-better-problem-solving)
- リフレーム：ビルの管理者は、エレベーターの横に鏡を置きました。著者は、これで「エレベーターが速くなるわけではない」と強調します。これは、待ち時間がどう*感じられるか*を問題として扱います。人は、見ていて面白いもの（ここでは自分自身）があると、時間の感覚を失うからです — [上記と同じ情報源](https://medium.com/nyc-design/reframing-the-problem-200f6c966dfc)
- 中心となるリフレーミングの問い：「エレベーターの速度は、本当に問題なのか。それとも、ほかに何かが起きているのか？」著者はまた、リフレーミングは「上達するのに時間と練習が必要」だとも述べています — [Katie Martin の要約](https://katielmartin.com/2020/04/26/are-we-solving-the-right-problems/)
- エレベーターと鏡の由来の語り直し（ニューヨークのホテルやオフィスビルが舞台であることが多い）は、逸話的です。ある情報源は鏡を「百年前のマーケティングの策略」と呼んでおり、日付のある最初の事例を示すものはありません — [Elevator World blog](https://elevatorworld.com/blog/elevators-best-asset-and-illusion/)；[Laughing Squid](https://laughingsquid.com/why-elevators-have-mirrors/)
- 本（*What's Your Problem?*、2020年）の構成：「問題を枠づける（Frame the Problem）」、それからリフレーミングのループ。章には「枠の外を見る（Look Outside the Frame）」「ゴールを考え直す（Rethink the Goal）」「ブライトスポットを調べる（Examine Bright Spots）」が含まれます。最後は「前へ進む（Move Forward）」です。本は、「枠を探る」（元の問題の記述を掘り下げる）ことと、「枠を壊す」（そこから離れる）ことを区別しています — [本のノート、vejdani.org](https://vejdani.org/books/wyproblem/)；[Leadership Now の書評](https://www.leadershipnow.com/leadingblog/2020/03/whats_your_problem.html)
- リフレーミング・キャンバスは、問題の最初の枠づけから始まり、次にリフレーミングのループを回します。ある確認項目は、問題の記述が中立的に書かれているか、それとも、ある解決策に有利なように狭く書かれていないかを問います — [dyanwilliamslaw.com の要約](https://dyanwilliamslaw.com/2020/10/how-to-think-clearly-part2/)
- 無料のキャンバス、チェックリスト、入門書は、著者のサイト howtoreframe.com にあります — [vejdani.org](https://vejdani.org/books/wyproblem/)
- 同じ著者の *Leader to Leader* の記事（2020年）「Facing a tough problem? Try reframing it」は、製品を超えて状況全体を見ることで、誰も気づいていなかった痛点を見つけるよう主張しています — [Wiley Online Library](https://onlinelibrary.wiley.com/doi/10.1002/ltl.20506)
- **[背景知識。再検証なし]** 2017年の HBR の記事にある7つの実践は次のとおりです。(1) 正当性を確立する（診断が重要だと、グループに受け入れさせる）、(2) 部外者を議論に加える、(3) 問題についての人々の定義を書面で出してもらう、(4) 何が欠けているかを問う、(5) 複数の種類の問題を検討する、(6) 肯定的な例外（ブライトスポット）を分析する、(7) 目的を疑う。2020年の本は、これらを、枠づけ（Frame）、それからリフレーム（枠の外を見る、ゴールを考え直す、ブライトスポットを調べる、鏡を見る、相手の視点に立つ）、そして前へ進む（Move forward）に組み替えています。
- **[背景知識。再検証なし]** エレベーターの寓話の古い版は、Russell Ackoff の問題解決についての著作（たとえば *The Art of Problem Solving*、1978年）に現れ、そこでは心理学者が鏡を提案します。Wedell-Wedellsborg は、これを自分の事例ではなく、古典的な話として示しています。

### 推論
- この手法は、アプリのフィードバックにそのまま対応します。友達の「写真を大きくして」は、「遅いエレベーター」です。何かを作る前に、実際に何の体験が悪いのかを尋ねてください（たとえば「友達の顔が見えない」「グリッドが空っぽに感じる」「何を見ればいいか分からない」）。
- 学生にとって最も持ち運びやすいステップ：問題を一文で書き出す。その記述に何が欠けているかを問う。2〜3種類の問題の分類を試す（UI か。モチベーションか。社会的な気まずさか。タイミングか）。ブライトスポットを探す（毎日使っている友達は、なぜそうなのか）。そして、ゴールを疑う（ゴールは「写真を増やす」ことか、それとも「友達との近さを感じる」ことか）。
- この話は、例示のための寓話として語ってください。記録された歴史的事例として示さないでください。

### 調査の空白
- 正確な文言を引用したり、7つの実践のリストを確認したりするために、HBR の記事や本を開くことはできませんでした。上のリストは、背景知識によるものです。
- 鏡がこの目的で最初にいつ、どこで使われたかを確認できる一次の情報源はありません。この逸話は検証できません。

---

## 2. ヒューストン空港の手荷物受取（NYT 2012年「Why Waiting Is Torture」；David Maister）

### 要点
この話は、NYT の1本のオピニオン記事（2012年8月、「Why Waiting Is Torture」）に由来します。数字（平均待ち時間8分、徒歩約1分、カルーセルのそばに立つのが約7分、歩く距離が約6倍になった、苦情が「ほぼゼロ」に減った）は、すべてその1本の記事に行き着きます。空港の記録がこれを独立して裏づけているわけではありません。何もしていない時間は長く感じられる、という Maister の原則をよく表す例ですが、正確な数字は、「NYT の報道によれば」として引用すべきです。

### 引用付きの調査結果
- ヒューストン空港の担当者は、手荷物受取での待ち時間について、多くの苦情を受けました。最初の対策は手荷物係の増員で、平均待ち時間は約8分に短縮されましたが、苦情は続きました — [NYT 記事を再掲した APS](https://www.psychologicalscience.org/news/why-waiting-is-torture.html)
- 診断：乗客は、ゲートから手荷物受取まで約1分歩き、その後さらに約7分間、カルーセルのそばに立っていました。待ち時間のほとんどは、ただ立っているだけでした — [NYT を再掲した APS](https://www.psychologicalscience.org/news/why-waiting-is-torture.html)
- 対策：到着ゲートをメインターミナルから遠くに移し、荷物を最も遠いカルーセルに回したため、歩く距離は約6倍に長くなりました。苦情は「ほぼゼロ」に減りました — [APS の再掲](https://www.psychologicalscience.org/news/why-waiting-is-torture.html)；[Your Mileage May Vary のファクトチェック記事](https://yourmileagemayvary.com/2024/06/30/the-sneaky-way-this-texas-airport-stopped-passengers-complaints-about-long-waits/)
- このバイラルなミームをファクトチェックした Your Mileage May Vary の記事は、同じ NYT の記述を引用しており、空港の独立したデータは示していません — [Your Mileage May Vary](https://yourmileagemayvary.com/2021/09/20/the-sneaky-way-this-texas-airport-stopped-passengers-complaints-about-long-waits/)
- David Maister の「The Psychology of Waiting Lines」（1985年）は、8つの命題を示しています。それらは、何もしていない時間、サービス開始前の待ち、不安、不確実性、説明のない待ち、不公平な待ち、サービスの価値、一人で待つかグループで待つか、が、それぞれ待ち時間の感じ方をどう変えるかを扱っています。Maister はまた、サービスを受けている間よりも、サービスを待っている間のほうが、不安がずっと高いと述べています — [davidmaister.com](https://davidmaister.com/blog/201/The-Psychology-of-Waiting-Lines.html)；[davidmaister.com の記事](https://davidmaister.com/articles/5/52/index.html)
- Jones & Peppiatt（1996）は、Maister の命題のうち2つを、一般の人300人で実験的に検証し、修正案を提案しました。したがって、これらの原則には、限定的ながら、ある程度の実証的な検証があります — [Emerald, Int'l Journal of Service Industry Management](https://www.emerald.com/insight/content/doi/10.1108/09564239610149957/full/ris)
- **[背景知識。再検証なし]** NYT の筆者は Alex Stone で、Sunday Review の2012年8月18日号に掲載されました。Maister の第1の命題は「何かをしている時間は、何もしていない時間より短く感じられる」です。空港は、ヒューストンの George Bush Intercontinental とされるのが通例ですが、語り直しの中には、単に「ヒューストンの空港」とするものもあります。

### 推論
- エレベーターの話と同じ教訓です。苦情（「荷物が遅い」）は症状に名前をつけていました。本当の問題は、何もしていない、不確実な待ち時間でした。どちらの対策も、測定された指標ではなく、*知覚*を変えました。
- 写真アプリについて：「アプリが遅い」や「何も起きない」のような苦情は、実は不確実性（自分の写真は送られた？友達はいつ投稿する？）や、空白の時間のことかもしれません。純粋な速度の改善よりも、進捗のインジケーター、プレビュー、「X さんが撮影中」というシグナルのほうが役立つかもしれません。
- 学生向けに触れておくべき倫理上の注意：人に意図的により遠くを歩かせるのは、この逸話ではうまくいった操作です。製品に置き換えるなら、ユーザーの時間を埋め、情報を伝えるといった、正直な対策を選んでください。

### 調査の空白
- NYT の記事を開いて、逐語的に引用したり、筆者や日付を確認したりすることはできませんでした。空港側の情報源が、数字を独立して裏づけてもいません。
- 語り直しの中には「6倍長い」と言うものがあります。算術（1分の徒歩が約6分に）は整合しますが、同じ1つの情報源に依拠しています。

---

## 3. Jobs to Be Done：ミルクシェイクの話、Moesta のスイッチインタビューと進歩の力、消費者向けソーシャルアプリへの応用

### 要点
ミルクシェイクの話は、概略は実話です。Bob Moesta（Rick Pedi と共に）は、あるファストフードチェーンのためにフィールドワークを行い、ミルクシェイクの約40%が早朝に、一人で通勤するドライバーによって買われていることを見つけました。彼らは、長くて退屈な運転のために、ミルクシェイクを「雇って」いたのです。細部は語り直しの中で異なったり、脚色されたりします。チェーンの名前（McDonald's とされることが多いが未確認）、割合（40%か「8時半前に50%」か）、主張される売上の結果（「7倍」）などです。Moesta のスイッチインタビューと4つの力（プッシュ、プル、不安、習慣）は、「なぜ友達はアプリを使い続けた／使い続けなかったのか」に当てはめられる、具体的なインタビューの構造を与えてくれます。

### 引用付きの調査結果
- 中核の話：あるファストフードチェーンのミルクシェイクの売上は、人口統計によるセグメント化と、フィードバックに基づく製品の調整の後も、改善しませんでした。ある研究者が、ミルクシェイクの40%が、朝一番に、持ち帰りを注文する通勤客に買われていることを見つけました。インタビューから、彼らは長くて退屈な通勤に直面し、手を使うものが欲しく、まだお腹は空いていないが、午前10時には空くと分かっていました。薄いストローで飲む濃いシェイクは通勤の間もち、ベーグル、ドーナツ、バナナと違って、汚れませんでした — [HBS Working Knowledge「Clay Christensen's Milkshake Marketing」（2011）](https://www.library.hbs.edu/working-knowledge/clay-christensens-milkshake-marketing)；[Chris Dixon、2011](https://cdixon.org/2011/12/21/what-jobs-are-users-hiring-your-product-to-perform/)
- Christensen 自身の抜粋（*Competing Against Luck*、2016年）：デトロイトのコンサルタントである Bob Moesta と Rick Pedi が関わっていました（1990年代半ば）。朝の客は、共通のジョブ、つまり通勤の長くて退屈な道のりを持っていて、人口統計上の特徴ではありませんでした。同じ客が、午後には別のジョブ（たとえば子どもへのご褒美）のために、ミルクシェイクを「雇う」ことがあります — [StartupNation の書籍抜粋](https://startupnation.com/books/competing-against-luck-book-excerpt/)
- 引用された Christensen の教材ノートによる手法：研究者は丸一日、購入の様子（時間、一人かどうか、ほかに何を買ったか、店内で食べたかどうか）を観察しました。翌朝、シェイクを持って店を出る客に、どのジョブのためにそれを雇ったのかをインタビューしました — [The TRIZ Journal](https://the-trizjournal.com/?p=15024)
- 競合は、他のミルクシェイクではなく、ベーグル、バナナ、そして退屈です — [PDMA による Competing Against Luck の書評](https://www.pdma.org/review_competing_aga)
- **食い違いと脚色：** 一部の要約は、教材ノートの40%に対して、「50%が午前8時半前に買われる」としています。複数の二次的な記事は McDonald's の名前を挙げていますが、見つかった HBS や Christensen の情報源はチェーンの名前を挙げていません。「売上が7倍に増えた」という主張は、二次的な記述に現れ、一次の資料では確認されていません — [検索による統合；JD Prater の歴史](https://jdprater.substack.com/p/a-brief-history-of-jobs-to-be-done)；[Yu-kai Chou の批評](https://yukaichou.com/gamification-analysis/jobs-to-be-done-christensen-consumer-hiring/)
- Moesta の会社である ReWired Group には、独自のケーススタディのページ「Milkshakes in the Morning」があります（未確認） — [therewiredgroup.com](https://therewiredgroup.com/case-studies/milkshakes/)
- JTBD には、競い合う流派があります。Tony Ulwick の Outcome-Driven Innovation は、ジョブを、Christensen/Moesta の「進歩」の見方とは別の形で扱い、誰が何を始めたかという歴史には争いがあります — [Myles Innovation の歴史](https://myles-innovation.com/blog/jtbd-history-christensen-ulwick/)；[Roman Kir、Medium](https://medium.com/@roman-kir/above-the-frameworks-jtbd-how-a-brilliant-idea-turned-into-a-civil-war-30d60f727df5)
- 進歩の4つの力（Moesta/Spiek）：現状の**プッシュ**（苦労）と新しい解決策の**プル**が、変化を駆り立てます。新しいものへの**不安**と現状の**習慣**が、それを妨げます。プッシュ＋プルが、不安＋習慣を上回ったとき、人は乗り換えます。Moesta は、プルと不安は一緒にやって来ると述べています。新しい選択肢が魅力的になった瞬間に、それは自己不信も生みます — [JTBD Radio「Pull & Anxiety」](https://jobstobedone.org/radio/pull-and-anxiety/)；[JTBD Radio「Unpacking the Progress Making Forces Diagram」](https://jobstobedone.org/radio/unpacking-the-progress-making-forces-diagram/)；[Elemental Concept](https://elementalconcept.com/insights/moesta-four-forces-of-progress-jtbd/)
- スイッチインタビュー：実際の過去の意思決定を、時系列として再構成します（最初の思いつき、受け身の探索、積極的な探索、決め手となったきっかけ、購入／登録、最初の使用、継続的な使用）。どこにいたか、誰と一緒にいたか、ほかに何が起きていたかを尋ね、抽象的な意見は聞きません。実務家の中には、具体的な登録や購入の瞬間から始めて、さかのぼる人もいます — [Gavel のガイド](https://usegavel.com/bob-moesta/switch-interview)；[Bob Moesta との Lenny's Podcast の要約](https://podpulse.ai/podcast/lennys-podcast-product-growth-career/lennys-podcast-product-growth-career-the-ultimate-guide-to-jtbd-bob-moesta-co-creator-of-the-framework)；[JTBD 公式サイト](https://jobstobedone.org/)
- あるガイドは、45分のセッションのうち約20分を、「最初の思いつき」を突き止めることに使う、と主張しています。これは、権威の低い、単一の情報源によるものです — [innovation-creativity.com](https://innovation-creativity.com/bob-moesta-switch-interview-45-minute-script-guide/)
- Des Traynor（Intercom）は、JTBD をソフトウェア向けに取り入れ、広めました。考え方は、機能はジョブに従うべきで、先導してはならない、というものです — [JTBD Radio: JTBD at Intercom](https://jobstobedone.org/?p=1816)；[Antoine Buteau による Des Traynor の教訓](https://www.antoinebuteau.com/lessons-from-des-traynor/)

### 推論
- **JTBD を社会的な写真アプリに応用すると：** ジョブは、たいてい「写真を撮ること」ではありません。より可能性が高いジョブは、「見せびらかすプレッシャーなしに、親しい友達とつながっていると感じる」「毎日チェックインする、軽い理由を持つ」「今週の共有された思い出を作る」です。競合は、他の写真アプリではありません。LINE／Instagram のストーリーズ、グループチャット、あるいは単に何もしないことです。
- **試してくれた友達向けに調整したスイッチインタビュー：**「最初にアプリを開いた日を思い出してください。どこにいましたか。誰に招待されましたか。何を期待していましたか。最後に開いたのはいつですか。その直前は何をしていましたか。投稿するつもりだったのに投稿しなかった日はありましたか。何があったのですか」
- **アプリを試す際の力：** プッシュ ＝ 今の写真の共有の仕方で不満なこと。プル ＝ 何が惹きつけたか。不安 ＝「自分の写真がつまらなかったら／友達に評価されたら／自分の番を忘れたら」。習慣 ＝ すでにグループチャットで投稿している。友達のリテンションの低さは、機能の不足ではなく、習慣と不安から来ることが多いです。
- **「解雇」インタビュー**（なぜやめたか）は、ごく小さなテストグループにとっては、乗り換えて入ってきたときのインタビューと同じくらい役立ちます。

### 調査の空白
- レストランチェーン、朝の正確な割合、売上の結果は、一次の情報源からは確認できませんでした。**[背景知識。再検証なし]** Moesta はポッドキャストで、チェーンは提案を完全には実行しなかったと述べています。「売上が X 倍に増えた」という主張は、未検証として扱ってください。
- 消費者向けの社会的な写真アプリを扱った、出典のある JTBD の公開事例は、今回の検索では見つかりませんでした。

---

## 4. マザー・テスト（Rob Fitzpatrick）：ルール、悪い質問と良い質問、称賛と機能の要望

### 要点
マザー・テストの3つのルール：(1) あなたのアイデアではなく、相手の生活について話す。(2) 一般論や将来についての意見ではなく、過去の具体的なことを尋ねる。(3) 話すのを減らし、聞くのを増やす。称賛、フラフ（一般論、仮定、将来についての発言）、機能のアイデアは「悪いデータ」に分類されます。機能の要望は「従うのではなく、理解する」べきもので、「なぜそれが欲しいのですか。それがあれば何ができますか」と掘り下げます。コミットメント（時間、評判、お金）だけが、本物のシグナルです。

### 引用付きの調査結果
- 3つのルール：あなたのアイデアではなく、相手の生活について話す。一般論や将来についての意見ではなく、過去の具体的なことを尋ねる。話すのを減らし、聞くのを増やす — [mtlynch.io の読書レポート](https://mtlynch.io/book-reports/the-mom-test/)；[Unusual VC の要約](https://www.unusual.vc/rob-fitzpatricks-mom-test/)；[Pushers: 例つきの3つのルール](https://wepushers.com/frameworks/the-mom-test/)
- 悪い質問の例：「Y をする製品に X を払いますか？」人は将来について過度に楽観的で、あなたを喜ばせたがります。より良い質問は、現在何をしていて、いくら使っているかを尋ねるか、実際にお金を求めることです — [mtlynch.io](https://mtlynch.io/book-reports/the-mom-test/)；[Medium の要約](https://medium.com/@poloniothais/book-summary-the-mom-test-by-rob-fitzpatrick-8440986cd92c)
- 仮定の上での「はい」は「架空のコミットメント」です。人は、仮定のお金には一日中「はい」と言います — [Koji blog（2026）](https://www.koji.so/blog/mom-test-customer-interviews-2026)
- 良い代替案：「それが最後に起きたときのことを聞かせてください」「ほかに何を試しましたか」「現在これを解決するのに、いくら使っていますか（ツール、外注、自分の時間）」 — [Koji](https://www.koji.so/blog/mom-test-customer-interviews-2026)；[Castan.ai の質問リスト](https://castan.ai/blog/customer-interview-questions)
- 悪いデータの3種類：称賛、フラフ、アイデア／機能の要望。機能のアイデアは、最も危険だとされます — [HelloPM の要約](https://hellopm.co/book-summary-the-mom-test-by-rob-fitzpatrick/)；[Unusual VC](https://www.unusual.vc/rob-fitzpatricks-mom-test/)
- 称賛（「それは面白そうですね」「大好きです！」）は、言う側に何のコストもかからず、データとしては価値がありません。受け流して、事実に話を戻します。たとえば、それが置き換えるワークフローについて尋ねます — [Unusual VC](https://www.unusual.vc/rob-fitzpatricks-mom-test/)；[Wedgescout の要約](https://wedgescout.com/blog/the-mom-test)
- フラフ（「私はたいてい……」「私なら……」「たぶん……」）は、具体的な1つの場面に結びつけるべきです：「先週の金曜に、正確に何があったか、順を追って教えてもらえますか」 — [Bala Vishal、Medium](https://bala-vishal.medium.com/mastering-customer-conversations-the-mom-test-for-entrepreneurs-and-pms-23f7be4367ae)；[Business Floss](https://www.businessfloss.com/books/the-mom-test)
- 機能の要望：従うのではなく、理解する。「なぜそれが欲しいのですか。それがあれば何ができますか。それが必要だった最後の場面を見せてもらえますか」と掘り下げます。感情には「それについてもっと聞かせてください」と掘り下げます — [Wedgescout](https://wedgescout.com/blog/the-mom-test)；[Field Notes by Nick](https://fieldnotesbynick.substack.com/p/the-mom-test-by-rob-fitzpatrick)
- コミットメントと前進：本物のシグナルは、相手に時間、評判のリスク、現金を負担させます（たとえば、他の人への紹介、再び使うこと、お金を払うこと）。あいまいな「また連絡してください」は、丁寧な「ノー」です — [Unusual VC](https://www.unusual.vc/rob-fitzpatricks-mom-test/)；[HelloPM](https://hellopm.co/book-summary-the-mom-test-by-rob-fitzpatrick/)
- 過去の行動は、述べられた意図よりも、将来の行動をよく予測します。「解決策を試しましたか。どうでしたか」は、「〜するアプリを使いますか」よりも優れています — [Medium の要約](https://medium.com/@poloniothais/book-summary-the-mom-test-by-rob-fitzpatrick-8440986cd92c)
- 本の題名は、*The Mom Test: How to talk to customers & learn if your business is a good idea when everyone is lying to you* です — [Goodreads](https://www.goodreads.com/book/show/52283963-the-mom-test)
- **[背景知識。再検証なし]** 本の名前は、あなたを愛していて、あなたの気持ちを守るために嘘をつくだろうあなたの母親でさえ、良い質問をすれば、あなたに嘘をつけない、という考えから来ています。これは、友達へのインタビューに直接対応します。Fitzpatrick のサイトは momtestbook.com です。彼はまた、会話をカジュアルに保つこと（正式な「インタビュー」にしない）、事前に「大事な3つ」の学習目標を決めること、苦痛、目標、障害を示す記号でメモを取ることを勧めています。

### 推論
- **学生の写真アプリのテストでの、悪い質問と良い質問：**
  - 悪い：「アプリは気に入りましたか」／「毎日使いますか」／「フィルターがあれば使いますか」／「グリッドのレイアウトは良いですか」
  - 良い：「最後に開いたのはいつですか。何がきっかけで開きましたか」／「投稿しなかった日はありましたか。代わりに何をしていましたか」／「友達が投稿したという通知が来たとき、次に何をしましたか」／「今、この友達とは、どうやって写真を共有していますか。最後にそうしたのはいつですか」
- **友達から「X を追加して」と言われたとき：** お礼を言い、それから「X があれば何ができますか」「それがあったらいいなと最後に思ったのはいつですか」と尋ねます。機能ではなく、根底にある必要を記録してください（たとえば「誰が自分の写真を見たか知りたい」→ 安心感やリアクションへの必要）。
- 友達は、「お母さん」の極端な例です。肯定的な発言は膨らんでいると仮定し、意見よりも、観察された行動（5日目に、リマインドなしで投稿したか）を、はるかに重く見てください。

### 調査の空白
- 本の正確な引用は確認できませんでした。上の文言は、おおむね一致する二次的な要約によります。

---

## 5. その他の有用な道具：5つのなぜ、Levitt の「1/4インチの穴」、狩野モデル、「機能の要望は解決策である」、Superhuman の PMF 調査

### 要点
それぞれの道具は、別の角度を扱います。5つのなぜは因果の連鎖（既知の限界あり）、ドリルと穴の格言は機能よりも成果を重視する考え方（帰属は曖昧）、狩野モデルは要望を基本と魅力に仕分けるため、「要望は解決策であり、問題を見つける」という実践（Intercom、Shape Up）、そして Sean Ellis／Superhuman の「非常にがっかりする」調査（40%のベンチマーク）。PMF 調査は、3人の友達ではなく、数十人の回答があって初めて意味を持ちます。

### 引用付きの調査結果
**5つのなぜ**
- 大野耐一による、トヨタの古典的な例：溶接ロボットが止まった → 過負荷でヒューズが切れた → ベアリングの潤滑が不十分だった → オイルポンプの循環が不十分だった → ポンプの軸が摩耗していた → ストレーナー（フィルター）がなかったので、くずが入った。根本的な対策：ストレーナーを付ける — [ThinkReliability のケーススタディ](https://thinkreliability.com/toyota-welding-robot-5-why/)；[Lean Blog（2026年4月）「Even Ohno's classic 5 Whys example deserves another why」](https://www.leanblog.org/2026/04/ohno-5-whys-actually-seven/)
- 限界：「5」は恣意的です。元トヨタ社員の Art Smalley は、その事例で必要だったのが5回だったから5なのだ、と述べたと伝えられています。5番目のなぜは「原因であって、*その*原因ではない」。単一の連鎖の分析は、複数の因果要因を見逃しがちで、しばしば「ヒューマンエラー」で止まります。批評家の中には、競合する根本原因分析ツールを売っている人も多いので、その批判は割り引いて見てください — [ThinkReliability](https://blog.thinkreliability.com/case-study-5-why-toyota-welding-robot)；[TapRooT](https://taproot.com/?p=99165)；[Scaler blog](https://scaler.com/blog/root-cause-analysis)
- 擁護：この数は、表面の下を掘るための目安です。異なる枝に沿って、何度か適用できます — [No Jitter](https://www.nojitter.com/telecommunication-technology/the-five-whys-of-problem-solving)

**「人は1/4インチのドリルを欲しいのではなく、1/4インチの穴を欲しいのだ」**
- Quote Investigator：最も強く一致する最古の例は、1942年のペンシルベニア州 Somerset の新聞広告です（生命保険の代理人 C.C. Wagner のものとされる）。Percy Whiting の1947年の本がこれを広め、Leo McGivena（NY Daily News の広報部長）の言葉としました。Theodore Levitt は、*The Marketing Mode*（1969年）でこれを繰り返し、McGivena に帰したので、Levitt のものと誤って伝えられることが多いのです — [Quote Investigator（2019）](https://quoteinvestigator.com/2019/03/23/drill/)；[Barry Popik](https://www.barrypopik.com/index.php/new_york_city/entry/dont_sell_drills_sell_holes)
- プロダクトマネージャーによる反論：顧客は、穴さえ欲しくないかもしれません。欲しいのは棚を取り付けることや、片付いた部屋の誇りです。したがって、「それで、その先は？」と問い続けてください — [Dean on Delivery](https://www.deanondelivery.com/product_management/a-product-managers-response-to-the-story-of-the-%C2%BC-drill-bit/)

**狩野モデル**
- 狩野紀昭、1984年（東京理科大学）。カテゴリー：当たり前品質（なければ強い不満、あっても満足は大きく増えない）、一元的品質（満足度が品質に比例する）、魅力的品質（あれば喜ばれ、なくてもペナルティはない）、無関心品質、逆品質（一部のユーザーが嫌う） — [Microsoft Research「KANO Best Practices」PDF](https://microsoft.com/en-us/research/uploads/prod/2022/01/KANO-Best-Practices.pdf)；[Agile Brand Guide](https://agilebrandguide.com/wiki/models/kano-model/)
- 魅力的品質は、ユーザーが慣れ、競合がコピーするにつれて、一元的品質、さらに当たり前品質へと移っていきます。これは広く繰り返されていますが、時期は例示的であり、きちんと測られてはいません — [Checkbox（2026年3月）](https://www.checkbox.com/blog/kano-model)；[Think Insights](https://thinkinsights.net/consulting/kano-model)
- **[背景知識。再検証なし]** 狩野の質問票は、各機能を、機能的／非機能的のペア（「アプリに X があったらどう感じますか」／「X がなかったらどう感じますか」）で、5つの回答選択肢とともに尋ね、機能を分類するには、ある程度のサンプルが必要です。

**機能の要望は解決策である：問題を見つける**
- Intercom のブログ記事「Start with the problem to achieve better solutions」（集約サイトによれば Stephen Forbes のもの）は、あらゆる機能の要望は提案された解決策であり、チームはその裏にある問題を見つけなければならない、と論じています — [echai.ventures の Intercom 索引](https://echai.ventures/startingup/from/intercom)（帰属は又聞き）
- Des Traynor の「Product strategy means saying no」：1人の声の大きな顧客のために機能を追加すると、ほかのすべてのユーザーに静かにコストがかかります。彼のフィルターは、ほとんどのユーザーが使うか、収益になるか、保守できるか、を問います — [Antoine Buteau による Des Traynor の教訓](https://www.antoinebuteau.com/lessons-from-des-traynor/)；[Business of Software の要約](https://businessofsoftware.org/2015/01/google-hangout-des-traynor-recap-highlights/)
- Shape Up（Basecamp、Ryan Singer）：バックログはありません。生のアイデアは、境界のある提案に「形づくられ」、6週間のサイクルのために「ベッティングテーブル」で賭けられます。本は basecamp.com/shapeup で無料で読めます — [Rework の要約](https://resources.rework.com/libraries/project-management/shape-up-method)；[Signal v. Noise](https://signalvnoise.com/svn3/shape-up-with-ryan-singer/)；[Ryan Singer との Pendo Product Love ポッドキャスト](https://www.pendo.io/pendo-blog/product-love-podcast-ryan-singer-head-of-strategy-at-basecamp-and-author-of-shape-up/)
- **[背景知識。再検証なし]** Shape Up の「Bets, Not Backlogs」の章は、Basecamp は要望の中央バックログを持たない、と述べています。要望は、それを耳にした人（サポート、営業）が非公式に追跡し、重要なアイデアは「また戻ってくる」。形づくりは、要望が本当は何についてのものかを問うことから始まります：「問題は何か。それはなぜ重要か」

**Superhuman／Sean Ellis のプロダクト／マーケット・フィット調査**
- 質問：「もし [製品] が使えなくなったら、どう感じますか」（非常に／やや／がっかりしない）。Sean Ellis のベンチマーク：40%超が「非常にがっかりする」と答えれば、その製品はおそらく PMF があります。このベンチマークは、約100社以上のスタートアップの比較から来ています（ある情報源は「150社超」と言っています） — [Founders Network](https://foundersnetwork.com/superhuman-product-market-fit/)；[Rahul Vohra による Business of Software の講演](https://businessofsoftware.org/talks/product-market-fit-engine/)
- Superhuman の最初のスコア（2017年）は、「非常にがっかりする」が22%でした。Vohra は、しばらく製品を使ってきたユーザーに調査を行いました。ある情報源によれば、使い始めて約21日です — [0-to-traction ミラー経由の First Round Review の記事](https://0-to-traction.com/articles/review.firstround.com/superhuman-product-market-fit-engine)；[Founders Network](https://foundersnetwork.com/superhuman-product-market-fit/)
- エンジン：「非常にがっかりする」グループに絞って、高い期待を持つ顧客を定義する。「がっかりしない」ユーザーは丁寧に無視する。主な便益が熱心なファンと一致する「やや がっかりする」ユーザーに注力する。ロードマップを約50/50に分け、ファンが愛するものを倍にすることと、様子見のユーザーを引き止めているものを直すことに充てる — [Postulate の要約](https://postulate.us/@samsonzhang/frameworks/p/2021-04-15-How-Superhuman-Used-a-Four-Question-oGqEg8zUriGRekTfnBUHwD)；[0-to-traction ミラー](https://0-to-traction.com/articles/review.firstround.com/superhuman-product-market-fit-engine)
- スコアは、1年足らずで22%から58%に上がったと報じられています（ポッドキャストの要約。First Round の原文と照合のこと） — [SaaS Club ポッドキャスト](https://saasclub.io/podcast/rahul-vohra-superhuman-342/)
- **[背景知識。再検証なし]** 4つの調査の質問：(1) Superhuman が使えなくなったら、どう感じますか。(2) Superhuman から最も恩恵を受けるのは、どんな人だと思いますか。(3) Superhuman から得ている主な便益は何ですか。(4) Superhuman をあなたにとってより良くするには、どうすればよいですか。Ellis は、コア製品を最近体験した人（たとえば、少なくとも2回、直近2週間以内に使った人）に調査するよう提案しています。Vohra は、方向性のある結果が見え始めるには、約40件の回答で十分だと述べました。

### 推論
- 友達のフィードバックには、5つのなぜを軽く使ってください（「それがあなたにとってなぜ大事なの？」を2〜4回）が、枝分かれさせてください。1つの苦情には、複数の原因（UX、社会的な気まずさ、通知のタイミング）があるかもしれません。
- 狩野は、要望の仕分けに役立ちます：「写真が失われてはならない」＝当たり前品質、「アップロードが速く」＝一元的品質、「驚きの週ごとのコラージュ」＝魅力的品質。当たり前品質が壊れている間は、魅力的品質を作らないでください。
- 友達にも、PMF の質問は尋ねてください。会話のきっかけとして（「このアプリが明日なくなったら、どう感じる？」）、続けて「なぜ？」と。ただし3人では、指標ではなく、定性的な探りです。

### 調査の空白
- First Round、Intercom、Shape Up のページを直接開いて、正確な文章を引用することはできませんでした。Intercom の記事の著者と正確な題名は、又聞きです。
- Sean Ellis の正確なサンプルサイズのルールは、背景知識によるものです。

---

## 6. 小さなサンプル（3人の友達）と行動データの見分け方と、落とし穴

### 要点
3人の友達は、使いやすさの問題を明らかにし、「本当の問題」についての仮説を生み出せます。需要の検証、リテンションの予測、機能の優先順位づけはできません。彼らが述べる意見には、バイアスがあります。友達は礼儀正しく、人は自分の将来の行動を予測するのが下手で、実際に使う前に報告される好みは信頼できません。彼らが*したこと*（起動、投稿、離脱した日、自発的な招待）を、彼らが*言うこと*よりもはるかに重く見て、述べられた各要望を、行動やより大きなサンプルで確かめるべき仮説に変えてください。

### 引用付きの調査結果
- Jakob Nielsen の「First Rule of Usability? Don't Listen to Users」（2001年）：ユーザーが課題に取り組んでいるとき、実際に何をするかを観察する。自己申告は信頼できず、将来の行動についてのユーザーの推測も同様。好みのデータは、ユーザーがデザインを使い、実感を持ってから集める — [Alertbox 2001 の再掲、blueskyonmars](https://www.blueskyonmars.com/2001/08/13/first-rule-of-usability-dont-listen-to-users)；[downes.ca](https://downes.ca/post/2684)；[NN/g の動画：User Feedback vs. Innovation](https://www.nngroup.com/videos/user-feedback-vs-innovation/)
- Nielsen による後の明確化：彼は顧客を無視することを主張しているのではなく、「彼らが言うことを聞くのではなく、彼らがすることを見ろ」と述べています。彼はこれを、顕示選好と、質問をすることでその人が持っていなかった意見を生み出してしまう「問い合わせ効果（query effect）」の対比と呼んでいます — [Jakob Nielsen Substack「Say vs. Do」](https://jakobnielsenphd.substack.com/p/say-vs-do)；[UX Tigers](https://uxtigers.com/post/say-vs-do)
- Jeff Atwood（Coding Horror）も同じ原則について：ユーザーの要望やフィードバックに盲目的に従うと、おそらく面倒なことになる — [Coding Horror](https://blog.codinghorror.com/i-repeat-do-not-listen-to-your-users/)
- マザー・テスト：人はあなたを喜ばせたがり、将来の行動について過度に楽観的なので、仮定の「〜しますか」という答えは信頼できません。友達や家族は、その極端な例です — [mtlynch.io](https://mtlynch.io/book-reports/the-mom-test/)；[Unusual VC](https://www.unusual.vc/rob-fitzpatricks-mom-test/)
- Superhuman／Ellis の PMF の採点は、回答者を明示的に分類し、がっかりしないユーザーを無視します。つまり、シグナルは、分類できるだけの十分な回答者がいるかどうかにかかっています — [First Round の 0-to-traction ミラー](https://0-to-traction.com/articles/review.firstround.com/superhuman-product-market-fit-engine)
- JTBD の調査は、意見よりも、実際の過去の行動と文脈（どこで、いつ、誰と）を再構成することを重視します — [Gavel のスイッチインタビューのガイド](https://usegavel.com/bob-moesta/switch-interview)
- **[背景知識。再検証なし]** Nielsen の「5人のユーザーで使いやすさの問題の約85%が見つかる」（2000年）は、均質なユーザーグループによる、単一のデザインの*使いやすさ*テストに当てはまります。需要、満足度、機能の優先順位の推定には当てはまりません。したがって、3人のテスターは、明らかな摩擦は見つけられても、「人々は使い続けるか？」には答えられません。

### 推論
- **3人のテスターがいる学生のための、実践的なトリアージ：**
  1. **述べられたことと、証拠を分ける。** 各フィードバックを、*述べられた要望* → *根底にある問題の仮説* → *行動からの証拠* → *次のテスト*、として記録します。例：「フィルターを追加して」→「自分の写真が他の人のと並んで退屈に見えるのが心配（不安）」→「7日のうち2日は投稿をスキップした」→「自分が投稿した後にだけ友達の写真を見せる／『評価しない』という枠組みのテスト」。
  2. **数ではなく、収束を信頼する。** 3人のうち2人が、あなたが見ている間に、独立して同じ摩擦の瞬間に出会ったなら、おそらく本物です。1人の友達が機能を求めたなら、それは掘り下げる手がかりであって、要件ではありません。
  3. **行動は意見に勝つ。** 後押しなしで開いたか。何日目にやめたか。誰かを招待したか。（マザー・テストの「前進」）可能なら、分析を見てください。
  4. **予測は割り引く。**「たぶん飽きる」や「毎日使うと思う」は予測であり、どちらに転んでも信頼できません。似たアプリに最後に飽きたときのこと、そのとき何が起きたかを尋ねてください。
  5. **友達効果に注意する。** 彼らは否定的なことを隠し、肯定的なことを膨らませます。見せてもらい（画面共有か、スマートフォンを渡してもらう）、「気に入った？」ではなく「何が分かりにくかった？」と尋ねてください。
  6. **声の大きな友達に、ロードマップを決めさせない。**（Traynor の、声の大きな顧客1人についての指摘）
  7. **解決する前にリフレームする。** 最上位の苦情ごとに、2〜3の別の問題の記述を書き（エレベーターの手法）、ブライトスポット（使い続けた友達。なぜ？）を探します。
- サンプルが増えたら（実際のユーザー20〜40人以上）、Ellis／Superhuman の調査や狩野の質問票を、定量的な確認として加えてください。

### 調査の空白
- この種の定性的な発見のインタビューについて、最小のサンプルサイズを示す厳密な情報源は見つかりませんでした。実務家の助言はまちまちです。
- 製品フィードバックにおける「友達は礼儀正しい」バイアスを、とくに数量化した査読付きの研究は見つかりませんでした。この主張は、実務家の本（マザー・テスト）と、一般的な自己報告の研究（Nielsen）に依拠しています。
