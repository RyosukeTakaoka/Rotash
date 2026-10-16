# 事例研究：ユーザーフィードバックにどう向き合ったか（耳を傾けた／無視した／従って失敗した）

> 【訳注】本書は `feedback_case_studies.md`（英語原文）の全文和訳です。URL・固有名詞・数値は原文のままにしてあります。「確度」「要点」などの見出し語は、原文の Confidence / Takeaway などに対応しています。

調査範囲の注記：2026年10月に、ウェブ検索といくつかのページ取得で調査しました。主要な一次情報ページの一部（coca-colacompany.com と arxiv.org）は、この環境からは DNS の解決に失敗して取得できませんでした。そのため、一部の事実は、それらのページの検索結果の要約か、信頼できる二次報道に基づいています。確度の評価は次のとおりです。**高** ＝ 一次情報があるか、複数の信頼できる媒体が一致している。**中** ＝ 二次報道どうしは整合しているが、一次情報は確認していない。**低／係争中** ＝ 情報が食い違っている、またはたどれない。

---

## Q1. グループA：ユーザー、とくに「観察された行動」に耳を傾けた製品（Instagram/Burbn、YouTube、Slack/Glitch、Discord、Twitter/Odeo）

### 要点
5つの誕生秘話は、いずれも大筋では事実です。共通するパターンは「ユーザーがXを求めた」ではありません。チームは**少人数のグループが実際に何をしているかを観察**し（Burbn のユーザーが写真を投稿していた、Fates Forever のプレイヤーがチャットを使っていた、Tiny Speck 自身のチームが社内チャットツールを使っていた、YouTube のアップロード者が出会い系という枠組みを無視した）、**その行動に絞り込みました**。Slack は、少人数のベータ版コホート（同じ条件で分けた利用者グループ）を使った構造的な反復改善として、最も記録が充実した事例です。YouTube の出会い系という起源と、Twitter の功績の帰属（Noah Glass）は、細部に誤りが混じるリスクがもっとも高い部分です。

### 引用付きの調査結果

**Burbn から生まれた Instagram（確度：高）**
- Burbn は位置情報チェックインアプリ（HTML5／iPhone）で、予定や写真も投稿できました。Systrom は NPR の *How I Built This* で、ユーザーは約100人しかいなかったと語っています。Eric Ries の助言（使い続ける人がなぜ使い続けるのかを問う）に従った結果、「ユーザー全員が写真の部分を気に入っていた」ことが分かり、写真に集中したそうです。 — [NPR 書き起こし](https://www.npr.org/transcripts/493923472)
- Systrom 自身の説明（Inc. 経由）：Burbn は「ごちゃごちゃ」して「機能だらけ」で、写真が圧倒的に人気の機能でした。そこで、ほぼすべてを捨てて作り直し、写真・コメント・「いいね」の機能だけを残しました。 — [Inc.](https://inc.com/eric-markowitz/life-and-times-of-instagram-the-complete-original-story.html)；[TechCrunch「A Pivotal Pivot」](https://techcrunch.com/?p=241149)
- TechCrunch Disrupt 2011 で Systrom は「ピボットの日」について語りました。チームは、このプロダクトを唯一無二にしている機能はどれかを問い、その答えが写真でした。「人々は Burbn で写真を投稿するのが大好きだった」からです。 — [CNN Money、2011-09-13](https://money.cnn.com/2011/09/13/technology/startups/instagram_burbn/)
- 作り直しには約8週間かかったと伝えられており、Instagram は2010年10月に iOS で公開されました。 — [TechCrunch](https://techcrunch.com/?p=241149)（二次的なサイトも繰り返し報じていますが、「8週間」の確度は「中」とします）
- 教訓：少人数の利用者基盤から得た利用データ（実際に使われた機能はどれか）が、創業者たちの機能ロードマップに勝ちました。ただし、これは Systrom 自身の説明によれば、**リーン・スタートアップに影響を受けた**物語である点に注意してください。

**出会い系ビデオサイトだった YouTube（確度：コンセプトは中〜高、色彩豊かな細部は低）**
- 共同創業者の Jawed Karim は、2007年のイリノイ大学の卒業式講演で、出会い系という起源を「Tune in, Hook up」というスローガンも含めて語っています。Steve Chen も SXSW 2016 で、出会い系が起源だったことを認めました。 — [Vice「10 years ago today YouTube launched as a dating website」](https://vice.com/en/article/10-years-ago-today-youtube-launched-as-a-dating-website)；[Founder Fragments](https://founderfragments.substack.com/p/did-you-know-youtube-was-a-dating)
- ユーザーは出会い系の動画をアップロードせず、あらゆる種類の動画をアップロードしたので、創業者たちは一般的な動画共有に門戸を開きました。 — [Vice](https://vice.com/en/article/10-years-ago-today-youtube-launched-as-a-dating-website)
- **注意：**「Craigslist で女性に20ドル払って出会い系動画を投稿してもらおうとしたが、誰も投稿しなかった」という細部は広く出回っています（SXSW 2016 の Chen の発言とされます）が、二次情報でしか確認できていません。また「Me at the zoo」（2005年4月23日）を「仮のもの（placeholder）」とする位置づけには異論があり、Karim 自身はテスト用の投稿だったとしています。 — [Founder Fragments](https://founderfragments.substack.com/p/did-you-know-youtube-was-a-dating)；[MakeTechEasier](https://maketecheasier.com/mte-when-youtube-launched-in-april-2005-its-first-video-was-a-19-second-clip-of-co-founder-jawed-karim-standing-in-front-of-elephants-at-san-diego-zoo-the-site-was-originally-built-as-a-dating-service/)

**Glitch から生まれ、ベータ版で反復改善した Slack（確度：高）**
- Slack は、Tiny Speck のチームがオンラインゲーム Glitch を作る中で構築した社内チャットツールから生まれました。 — [First Round Review による Stewart Butterfield へのインタビュー](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/)
- Butterfield の言葉による反復の過程：社内での利用は2013年3月から。2013年5月までに、自分たちは「たった1つのチームの力学」しか表していなかったので、社外のチームを求めました。他社の友人たちに「頼み込んで」、最初は**6〜10社**ほど（例：Cozy、Rdio）に使ってもらいました。Rdio では、ツールが数人のフロントエンド開発者から、約120人の全社員にまで広がりました。この規模になると、製品は「かなりひどい見た目」になったため、変更を加え、徐々に大きなコホートで「最初からやり直す」ことを繰り返しました。 — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/)
- 2013年8月に「プレビュー版」を公開しました（あえて「ベータ」とは呼びませんでした）。最初の報道日に**8,000人が招待をリクエストし、2週間後には15,000人に増えました**。Butterfield は、月あたり約8,000件の Zendesk チケットと約10,000件のツイートがあり、すべてに返信したと述べています。 — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/)；[Quartz](https://qz.com/335321/slack-is-everywhere-growing-fast-and-still-works-great-heres-how-they-did-it)
- Butterfield の社内メモ「We Don't Sell Saddles Here」（2013年7月31日。プレビュー公開の約2週間前）は、Slack が売っているのはチャットではなく組織の変革だと論じました。その核心的な洞察は次のとおりです。人々がすでに何かを強く欲しがっているときは、欠点を我慢してくれる。一方、欲しいとまだ気づいていないときは、我慢の度合いがずっと低い。 — [A Letter a Day による再掲](https://aletteraday.substack.com/p/letter-155-stewart-butterfield-2013)；[NFX Podcast](https://podcast.nfx.com/episodes/slack-memo)
- **食い違い：**一部の情報源は「24時間で8,000社が登録した」と言っています。インタビューに基づく情報源は、8,000「人」が招待をリクエストしたとしています。「人」を採用してください。 — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/) 対 [Stacksync blog](https://www.stacksync.com/blog/the-video-game-that-failed-the-origin-story-of-slack)

**Fates Forever から生まれた Discord（確度：中〜高）**
- Jason Citron（OpenFeint を売却した人物）と Stan Vishnevskiy は Hammer & Chisel を立ち上げ、MOBA の *Fates Forever*（2014年公開）を作りました。ゲーム内の音声／テキストチャットが際立っていました。Citron は後に、リテンション（継続率）と成長の数字から、このゲームは「十分に大きなゲームにはなりそうにない」と分かったので、チャット製品に方向転換した、と語っています。ゲーム開発を終了し、従業員の約30%を解雇しました。 — [Contrary Research](https://research.contrary.com/report/discord)；[Launched ニュースレター](https://readlaunched.substack.com/p/-how-discord-dominated-gaming)
- Discord は2015年5月に公開されました。初期のブレイクスルーは、Final Fantasy XIV の subreddit のスレッド（2015年5月13日）で、ギルドの招待を通じて約600人が登録したとされています。Discord は2015年末までに約300万ユーザーに達しました。 — [Launched](https://readlaunched.substack.com/p/-how-discord-dominated-gaming)；[Contrary Research](https://research.contrary.com/report/discord)（登録者数は二次情報。確度は中）
- 教訓：製品指標（ゲームのリテンション）と、副次的な機能に対して観察された熱意が、方向転換の決め手になりました。

**Odeo から生まれた Twitter（確度：概略は高、功績の帰属は係争中）**
- Odeo はポッドキャスト関連のスタートアップ（Evan Williams、Noah Glass）で、2005年に Apple が iTunes にポッドキャストを追加したことで、見通しが崩れました。Williams は社内ハッカソンを開き、Jack Dorsey が SMS ステータスのアイデアを提案しました。「twttr」は2006年初めにプロトタイプが作られ、Dorsey の最初のツイートは2006年3月21日、一般公開は2006年7月15日でした。 — [HISTORY.com](https://www.history.com/this-day-in-history/july-15/twitter-launches)；[Mental Floss](https://www.mentalfloss.com/culture/internet/what-was-first-ever-tweet)
- **係争中：**Noah Glass の役割（命名や初期の推進）は長年過小評価され、後に Business Insider の報道で表に出ました。 — [Fast Company「Noah Glass, Twitter's long-lost Winklevoss」](https://www.fastcompany.com/1747118/noah-glass-twitters-long-lost-winklevoss)
- 注意点：これは「ユーザーの声を聴いた」話というより、市場が動いた後の社内でのピボットです。フィードバックの話ではなく、ピボットの話として扱ってください。

### 推論
- これらの事例から読み取れる最も強い「傾聴」の教訓は、意見のアンケートを取ることではなく、**継続して使っている少人数のグループが繰り返す行動を観察すること**です。Instagram（写真の利用）、Discord（チャットの利用とリテンションデータ）、YouTube（人々が実際にアップロードしたもの）は、いずれもこれに当てはまります。
- Slack のプロセス（6〜10チームのコホート → より大きなチーム → 大きなチームで製品が壊れたらリセット）は、最も応用しやすい**方法**です。観察された採用（Rdio の中で広まったか）と、直接の不満（サポートチケット、ツイート）を組み合わせています。

### 調査の空白
- Steve Chen の SXSW 2016 での Craigslist「20ドル」の逸話には、一次の書き起こしが見つかっていません。
- Butterfield の Medium 投稿の本文は直接取得できず、再掲と要約だけを見ました。
- Discord の一次情報（Citron のインタビュー）は取得しておらず、数字は調査レポートやニュースレターの記事によります。

---

## Q2. グループB：ユーザーの強い要望を無視または覆して成功した製品（iPhone のキーボード、Snapchat の消える仕組み、Facebook ニュースフィード2006、Twitter 140/280文字、BeReal のルール、Instagram の正方形）

### 要点
「ユーザーを無視して成功した」話の多くは、同じパターンを共有しています。企業は、**中核となる制約や設計上の賭けを維持**しつつ、**ユーザーが不満を述べた具体的な害を直しました**（ニュースフィードのプライバシー管理）。あるいは、**行動データが裏づけた段階で初めて制約を緩めました**（Instagram は投稿の約20%が正方形以外になった段階で、Twitter は英語ツイートの9%が上限に達した段階で緩和）。純粋に反抗しただけの事例（Messenger の分離、Instagram のアルゴリズム型フィード）は、指標の上ではうまくいきましたが、長く続く反感を残しました。BeReal は反面教師です。ルールを守り続けても、目新しさのピークを過ぎると利用は急落しました。

### 引用付きの調査結果

**物理キーボードをやめた iPhone（2007年）（確度：批判については高。社内の過程については「調査の空白」を参照）**
- Steve Ballmer（Microsoft CEO）は2007年1月に CNBC でこう述べました。iPhone は「キーボードがないので、ビジネス顧客には魅力がなく、メールマシンとしてあまり優れていない」。また500ドルという価格も批判しました。 — [CNBC](https://www.cnbc.com/id/16671712)
- 同時期の USA Today のインタビューで、Ballmer は「iPhone が有意な市場シェアを獲得する見込みはない」と述べたとされています。USA Today への帰属は二次報道に依拠しています。TechRadar は、彼がよく売れるかもしれないとも言っていたと指摘しています。 — [TechRadar](https://techradar.com/pro/quote-of-the-day-by-former-microsoft-ceo-steve-ballmer-theres-no-chance-that-the-iphone-is-going-to-get-any-significant-market-share-a-staggering-misread-of-the-future-of-consumer-devices)；[ComputerWoche](https://www.computerwoche.de/article/2674612/microsoft-chef-steve-ballmer-das-apple-iphone-wird-ein-flop.html)
- Ballmer は後に、自分が間違っていたと認めました。 — [PhoneArena](https://phonearena.com/news/Ballmer-I-was-wrong-about-the-iPhone_id87502)
- ニュアンス：Thurrott は、*初代* iPhone がビジネス用途に弱かったという点では Ballmer は部分的に正しかったが、その原因はキーボードではなく Exchange 対応の貧弱さだったと論じています。 — [Thurrott](https://www.thurrott.com/?p=84810)
- 注意：この事例は、*業界や専門家* の期待（スマートフォン購入者が使っていたのはキーボードだった）を覆したという話であり、Apple が無視した、記録のあるユーザーリサーチの結果ではありません。

**消える仕組みを維持した Snapchat と、保存機能が登場した時期（確度：高）**
- Spiegel の考え方：「消えることがデフォルトであるべきだ」。AP のインタビューで彼は、すべてがデフォルトで消去され、大事なものだけを人が保存するほうがよい、と論じました。これは業界の他の流れに逆行するものでした。 — [MIT Technology Review のプロフィール](https://www.technologyreview.com/innovator/evan-spiegel/)；[KSL/AP のインタビュー](https://www.ksl.com/article/27464994/snapchat-ceo-evan-spiegel-talks-sexts-and-growth)
- 2014年1月の AXS での Spiegel の基調講演（Snap のブログに掲載）は、「消えること」を、どこでもつながるインターネット、簡単なメディア制作と並ぶ製品の中核として挙げています。 — [TechCrunch、2014-01-25](https://techcrunch.com/2014/01/25/how-snapchat-thinks-about-snapchat)
- 2016年より前は、保存とはスクリーンショットを撮るか、カメラロールに書き出すことでした。**Memories は2016年7月6日に公開**され、保存した Snap や Stories をアプリ内で検索できるアーカイブとして、パスコードで守られる「My Eyes Only」も付いていました。これは「アプリの代名詞である一時性からの逸脱」と位置づけられました。 — [Snap Newsroom、2016-07-06](https://newsroom.snap.com/memories)；[TechCrunch](https://techcrunch.com/2016/07/06/snapchat-memories/)；[CNBC](https://www.cnbc.com/2016/07/06/snapchat-launches-new-timeline-called-memories.html)
- 教訓：Snap は約5年間（アプリ公開は2011年）、「消える」をデフォルトに保ち、保存を**任意（オプトイン）の層**として追加しました。「残る」をデフォルトにはしませんでした。
- **注意：**「talking, not storing（保存ではなく会話）」のような表現を含む、広く引用される「2012年のブログ記事」は、確認できませんでした。これらの引用は未検証として扱ってください。

**Facebook ニュースフィード、2006年9月（確度：抗議と謝罪については高、エンゲージメントの数字については中）**
- ニュースフィードとミニフィードは2006年9月5日に公開されました。「Students Against Facebook News Feed」グループは急速に膨らみ、メンバー数は初期の約20万人から約70万〜75万人まで、報道によってまちまちです。不満の中心はプライバシーでした（「ストーキングが簡単になりすぎる」）。 — [Cornell Sun、2006-09-14](https://cornellsun.com/2006/09/14/c-u-students-upset-at-facebook)；[The Dartmouth](https://www.thedartmouth.com/article/2006/09/facebook-changes-spark-controversy)；[Ball State Daily](https://www.ballstatedaily.com/article/2006/09/facebook-news-feed-upsets-angers-students-across-country)
- Zuckerberg は約3日後に公開書簡を投稿しました：「私たちはこの件で本当に失敗しました」。適切なプライバシー管理を作っていなかった、という内容です。Facebook はその後、管理機能（たとえば、ミニフィードが活動を知らせないようにする設定）を追加しました。**ニュースフィード自体は維持しました。**学生新聞は、抗議が収まり、ボイコットの呼びかけが撤回されたと報じました。 — [Ball State Daily](https://www.ballstatedaily.com/article/2006/09/feed-angers-facebook-users)；[Pepperdine Graphic](https://pepperdine-graphic.com/news-feed-irks-users-causes-facebook-rift/)
- 皮肉な点（Boz こと Andrew Bosworth の指摘）：抗議グループは、ニュースフィード*そのものを通じて*広まりました。誰かが参加するたびに、その友達にそれが表示されたからです。 — [Cornell INFO 2040 blog](https://nsdl.library.cornell.edu/websites/expertvoices/info2040/archives/1729.html)；[Reason「The Great Facebook Revolt of 2006」](https://reason.com/?p=115457)
- エンゲージメント：抗議にもかかわらず、エンジニアたちはユーザーの利用が約「2倍」になったのを見た、と報じられています。**これは未検証です。**Facebook 自身による一次の数字は見つかっていません。 — [Deccan Chronicle](https://deccanchronicle.com/technology/in-other-news/070916/facebook-news-feed-turns-10.html)
- 教訓：**ユーザーが欲しいと言うもの**（「フィードを消せ」）と、**根底にある害**（誰に何を見られるかの制御を失うこと）を切り分けます。害を直して機能は維持し、確認には行動（利用状況）を使います。

**Twitter の140文字制限と2017年の280文字への切り替え（確度：高）**
- 起源：140文字は、SMS の160文字という上限に収まり、かつユーザー名の分の余裕を残すように選ばれました。 — [Global News (Reuters)](https://globalnews.ca/news/3771455/twitter-character-limit-280)；[ReasonWhy (ES)](https://www.reasonwhy.es/actualidad/social-media/por-que-twitter-solo-deja-escribir-140-caracteres-2015-09-30)
- 変更の根拠（2017年9月26日のテスト、Aliza Rosen と Ikuhiro Ihara による）：**英語のツイートの9%が140文字に達していたのに対し、日本語のツイートでは0.4%**でした。日本語・中国語・韓国語は、1文字あたりの情報量が多いため除外されました。 — [Tech.co](https://tech.co/news/rip-140-twitter-testing-280-character-tweets-2017-09)；[Yahoo Finance](https://finance.yahoo.com/news/twitter-tests-new-280-character-limit-users-210006742.html)
- テスト結果（2017年11月7日に全ユーザーへ展開）：テスト中、**140文字を超えたツイートは5%、190文字を超えたのは2%**にとどまりました。280文字に達したのは約1%だけでした。 — [ZDNet](https://www.zdnet.com.au/article/twitter-opens-floodgates-on-280-character-tweets-after-few-use-it/)；[Marketing Mag](https://www.marketingmag.com.au/social-digital/twitter-rolls-280-character-tweets-users/)；[MobileSyrup](https://mobilesyrup.com/2017/11/07/twitter-is-rolling-out-280-character-limit-to-all-users/)
- 1年後：英語ツイートの約1%が280文字に達し、12%が140文字より長く、5%が190文字より長くなりました。 — [TechCrunch](https://techcrunch.com/?p=1739154)
- 学術研究（arXiv 1804.02318「How Constraints Affect Content: The Case of Twitter's Switch from 140 to 280 Characters」）：切り替え後、140文字以下のツイートは、切り替え前の同じ長さのツイートに比べて「はるかに人気がなく」なりました。総エンゲージメントはおおむね一定で、増えたのではなく、長さの間で**再配分された**ように見えました。 — [arXiv PDF](https://arxiv.org/pdf/1804.02318)
- 初期のエンゲージメントに関する主張（SocialFlow：長いツイートのほうがリツイートや「いいね」が多い）は、短期間の観測で、媒体によって数字の報じ方も一貫していません。**確度は低い。** — [Inverse](https://inverse.com/article/39205-twitter-280-characters-study)；[IAB UK](https://www.iabuk.com/news-article/280-characters-more-engaging-twitter-users-140)
- 教訓：Twitter は、あれほど揶揄された制約を約11年間守り続け、**計測された行動**（誰が上限に達しているか）に基づいて、まず標本でテストしてから緩和しました。簡潔さの文化はおおむね生き残りました。

**「実写（no-filter）」「1日1回」のルールを守った BeReal（確度：ルールと衰退については高、数字については中）**
- ルール：1日1回、ランダムな時刻に通知が届き、2分以内に前面・背面カメラの写真を投稿します（遅れた投稿には表示が付きます）。フィルターなし。自分が投稿しないと友達の投稿は見られません（「No lurking（見るだけ禁止）」）。同社は、ほとんどの取材を断っています。 — [Wikipedia: BeReal](https://en.wikipedia.org/wiki/BeReal)；[CUHK Varsity](https://varsity.com.cuhk.edu.hk/?p=21643)；[TheWrap](https://www.thewrap.com/innovators-2022-bereal-alexis-barreyat-kevin-perreau/)
- 競合が模倣しました（Instagram「Dual Camera」2022年7月、「Candid Challenges」テスト 2022年8月、TikTok Now）。 — [Wikipedia: BeReal](https://en.wikipedia.org/wiki/BeReal)；[Sensor Tower](https://sensortower.com/blog/monday-mobile-memo-2024-06-17)
- 利用状況：Sensor Tower のデータ（NYT 経由）によると、DAU（1日あたりのアクティブユーザー数）は**2022年10月から2023年3月にかけて約61%減少**しました（約1,500万人から600万人未満へ）。BeReal 自身は、2023年4月に DAU が2,000万人だと主張しました。MAU（月間アクティブユーザー数）は、前年比で約2%減（2023年11月〜2024年5月）でした。 — [Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html?src=rss)；[Tubefilter](https://www.tubefilter.com/?p=180594)；[Sensor Tower](https://sensortower.com/blog/monday-mobile-memo-2024-06-17)
- BeReal は中核ルールを守りつつ、機能を追加しました：Bonus BeReals（追加投稿）、RealMojis、RealPeople（著名人／ブランド）、RealBrands、RealEvents。**Voodoo は2024年6月に約5億ユーロで BeReal を買収し**、約4,000万の「アクティブユーザー」を主張しました（DAU ではないので、比較はできません）。創業者の Alexis Barreyat は CEO を退き、Aymeric Roffé が後任となりました。 — [Tubefilter](https://www.tubefilter.com/?p=180594)；[PetaPixel](https://petapixel.com/2024/06/11/anti-instagram-photo-sharing-app-bereal-purchased-for-537-million)；[Primetel](https://primetel.com.cy/bereal-is-acquired-by-voodoo-for-euro500-million-6005)
- 教訓：厳格なルールを守ったことで、独自性があり拡散しやすい製品ができましたが、**ルールだけではリテンションは生まれませんでした**。これは「B」の中でも混合型の事例です。同社は制約を守って生き残りましたが、繁栄はしませんでした（2022年のピーク時の評価額の約半分での売却とされますが、これは他所での報道で、ここでは未検証です）。

**2015年まで正方形のみだった Instagram（確度：高）**
- Instagram は2010年から**2015年8月27日**まで正方形のみを維持し、その日に縦長と横長を追加しました。公式ブログは、「投稿される写真や動画の**ほぼ5枚に1枚**は正方形ではない」こと、そして切り抜きによって人やランドマークが切れてしまうことを理由に挙げました。プロフィールのグリッドのサムネイルは、正方形のままでした。 — [Instagram blog、2015-08-27](https://about.instagram.com/post/127722429412/150827-portrait-and-landscape)；[The Next Web](https://thenextweb.com/apps/2015/08/27/instagram-photos-no-longer-have-to-be-square/)；[Macworld](https://www.macworld.com/article/2977000/social-media/instagram-steps-out-of-the-box-allows-posts-in-landscape-and-portrait-orientation.html)
- 教訓：この制約は、**観察された行動**（正方形から逃れるために、人々がサードパーティのアプリで写真に余白を足していたこと。「5枚に1枚」という統計から推察される）が、制約がユーザーの邪魔になっていることを示したときに緩和されました。不満だけを受けて緩められたわけではありません。正方形は、グリッド上でブランドの署名として残りました。

**その他のB事例（激しい抗議を押し切り、指標は上がった）**
- *Instagram のアルゴリズム型フィード（2016年）：* 2016年3月のテスト発表に対し、30万人以上の署名を集める Change.org の請願と、「投稿の通知をオンにして」というパニックが起きました。Instagram は、ユーザーは投稿の約70%を見逃していると述べ、Systrom は見られる30%を「最高の30%」にしたいと語りました。2016年6月までに全ユーザーへ展開され、テスト中は「いいね」とコメントが増えたと主張しました。2018年には、継続的なフィードバックを受けて、フィードを新着順寄りに調整しました。 — [WTVR](https://www.wtvr.com/2016/03/28/instagram-users-are-speaking-out-against-possible-change-to-news-feed)；[Nieman Lab](https://www.niemanlab.org/2016/06/instagram-now-shows-you-the-moments-you-care-about-first-how-should-news-orgs-react/)；[MediaNama 2018](https://www.medianama.com/2018/03/223-instagram-algorithm-changes-to-make-feed-more-timely/)（70%という数字は Instagram 自身の主張）
- *Facebook Messenger の分離（2014年）：* ユーザーは別アプリのインストールを強いられ、怒りの1つ星レビューが殺到しました。Zuckerberg はこれを「大きなお願い」で「多くの摩擦」を生んだと認め、「もっとスムーズにやれたかもしれない」と述べました。Messenger は、2億人（2014年4月）から5億 MAU（2014年11月）に成長しました。 — [The Drum](https://www.thedrum.com/news/2014/11/08/mark-zuckerberg-admits-he-didn-t-handle-facebook-messenger-transition-smoothly)；[YourStory](https://yourstory.com/2014/11/facebook-messenger-grows-to-500-million-amus/)；[Fierce Network](https://www.fierce-network.com/wireless/facebook-s-zuckerberg-explains-why-users-were-forced-to-download-separate-messenger-app)

### 推論
- 「ユーザーを無視して成功した」話の多くは、実際には**「ユーザーが述べた解決策は無視し、根底にある必要に応え、行動で検証する」**ということです。ニュースフィードがその典型例です。
- 制約（140文字、正方形、消える仕組み、1日1回）は、製品のアイデンティティです。成功したパターンは、**制約をデフォルトとして守り、広範な回避行動（余白を足す、上限に達する、スクリーンショットを撮る）がデータで示されたときに慎重に緩め、元のものをデフォルトまたは署名として残す**ことでした。
- 生存者バイアスは大きいです。ニュースフィードのような成功例の裏には、単に失敗した覆し方もたくさんあります（グループC、2018年の Snapchat を参照）。Facebook や Instagram のように強いネットワークの囲い込みがあると、小さなアプリよりも、反抗のリスクはずっと小さくなります。

### 調査の空白
- Apple がキーボードをやめた際の社内の理屈やユーザーリサーチは、情報源が見つかっていません。Jobs の2007年のキーノートでの、固定された樹脂製キーボードへの批判はよく知られていますが、書き起こしは取得していません。
- 2006年のニュースフィードのエンゲージメントについて、Facebook の一次データはありません。
- BeReal：フィルターや「いいね」を拒んだ理由を説明する創業者インタビューはありません。理由は、同社のファクトシートとマーケティングからしか分かりません。2024年以降の DAU データもありません。

---

## Q3. グループC：要望や調査に従って失敗した、または撤回を余儀なくされた事例（New Coke、2018年の Snapchat、2022年の Instagram、機能の肥大化／Evernote）

### 要点
New Coke は、**間違ったものを測った調査**の典型例です。ブラインドの一口テストが測ったのは味であって、ブランドへの感情的な愛着ではありませんでした。2018年の Snapchat と2022年の Instagram は、「ユーザーの要望に従った」例ではありません。いずれも、**段階的なテストが不十分なまま展開した、会社主導のリデザイン**で、どちらも反発と悪い利用データの下で、部分的に撤回されました。Evernote の機能の乱立は実在しますが、事実の扱いには注意が必要です。Evernote Food は2015年に終了しましたが、「機能が多すぎた」という物語のほとんどは論評です。

### 引用付きの調査結果

**New Coke（1985年）（確度：日付と概略は高、数字はばらつきあり）**
- **1985年4月23日**に発表されました。99年ぶりの配合変更で、Pepsi に対する Coke のシェア低下が背景にありました。同社は、味覚テストでほぼ**20万人の消費者**が新配合を好んだと述べています。 — [ABC7「Beverage Backlash」](https://abc7news.com/post/new-coke-ii-coca-cola-classic-history-of/5266029/)；[Live 5 News](https://www.live5news.com/2026/04/23/this-day-history-april-23-1985-coca-cola-announces-new-coke-formula-change/)
- 元の味は**1985年7月11日（79日後）**に「Coca-Cola Classic」として戻り、首位を取り戻しました。 — [Coca-Cola Company の歴史ページ](https://www.coca-colacompany.com/about-us/history/new-coke-the-most-memorable-marketing-blunder-ever)（検索結果の要約。ページ自体の取得は失敗）；[ABC7](https://abc7news.com/post/new-coke-ii-coca-cola-classic-history-of/5266029/)
- 反発の規模：**数字は食い違っています。**電話と手紙が40万件以上という情報源もあれば、Wikipedia の Coke II の記事は4万件以上、人気ブログは1日1,500件としています。「数万件、場合によっては数十万件」とするか、会社のページを直接引用してください。 — [Damn Interesting](https://www.damninteresting.com/the-american-gustation-crisis-of-1985) 対 [Wikipedia: Coke II](https://www.wikipedia.org/wiki/Coke_II)
- 社長の Don Keough は、これが話題づくりの仕掛けだったという陰謀論について、こう述べました：「われわれはそこまで愚かではないし、そこまで賢くもない」。 — [Damn Interesting](https://www.damninteresting.com/the-american-gustation-crisis-of-1985)（広く引用されており、会社のページにも載っているとされます）
- 教訓：味覚テストが答えたのは「どちらの一口がおいしいか」であって、「あなたの Coke を取り上げたらどう感じるか」ではありませんでした。人工的なテストでの表明された好みは、現実世界での愛着や行動とずれていたのです。

**2018年の Snapchat リデザイン（確度：高）**
- このリデザイン（2017年後半から2018年2月にかけて展開）は、友達のコンテンツをメディア／クリエイターのコンテンツから分離し、アルゴリズム型の Friends フィードを導入しました。Change.org の請願は**120万人の署名**を超えました。Snap は Change.org で「皆さんの声は届いています……新しい Snapchat は、多くの人にとって居心地が悪いものでした」と返信しました。 — [Fox13 Seattle](https://www.fox13seattle.com/news/snapchat-stock-loses-1-3-billion-after-kylie-jenner-tweet)；[9to5Google](https://9to5google.com/2018/02/23/snapchat-share-price/)
- Kylie Jenner は**2018年2月21日**に、もう Snapchat を開かなくなったとツイートしました。広く引用される文面は「sooo does anyone else not open Snapchat anymore? Or is it just me... ugh this is so sad」ですが、ここで取得した情報源では正確な文面を再確認できていません。Snap の株価は翌日に**約6%下落**して終え、時価総額で**約13億ドル**が失われました。アナリストは過剰反応だと評し、Fast Company は、下落の一部は直前の Citi の格下げによるものだとしました。 — [Fox13 Seattle](https://www.fox13seattle.com/news/snapchat-stock-loses-1-3-billion-after-kylie-jenner-tweet)；[BreakingNews.ie](https://www.breakingnews.ie/business/kylie-jenner-tweet-sends-snapchat-stock-tumbling-829519.html)（因果関係には異論あり）
- 部分的な撤回（2018年5月）：Snap とチャットは時系列順に戻り、友達の Stories はチャットの横に戻り、Subscriptions フィードが追加されました。Spiegel：「Stories を見ることと友達とやり取りすることを同じ場所にまとめたことで、競合する2つの行動を両方とも最適化するのが難しくなった」。 — [BusinessLIVE / Reuters](https://www.businesslive.co.za/bd/companies/2018-05-14-snapchat-relents-on-software-changes-amid-backlash/)；[TheWrap](https://www.thewrap.com/snapchat-rolls-out-redesigned-redesign)
- 利用への影響：**2018年第2四半期の DAU は、1億9,100万人から1億8,800万人に減少**しました（前四半期比 −2%）。これは初めての減少で、Snap の 10-Q（四半期報告書）はこれをリデザインのせいだとしています。 — [Snap 10-Q、2018年第2四半期（SEC）](https://www.sec.gov/Archives/edgar/data/0001564408/000156459018020094/snap-10q_20180630.htm)；[TechCrunch](https://techcrunch.com/?p=1687498)
- 2018年9月26日の Spiegel の社内メモ（Cheddar にリーク）：リデザインは「急ぎすぎた」。「コミュニティのより小さな割合で反復とテストを行う」ための十分な時間を取らなかった。「製品を遅くし」、「中核となる製品価値を損なった」。アルゴリズム型の Friends フィードは、友達を見つけにくくした。それでも彼は、ソーシャルとメディアの分離自体は擁護しました。 — [Engadget](https://www.engadget.com/2018-10-05-snap-evan-spiegel-app-redesign-rushed.html)；[Cheddar](https://cheddar.com/media/snap-ceo-evan-spiegel-company-memo-on-2019-strategic-goals-and-profitability)
- 分類上の注記：これは「ユーザーの要望に従った」例では**ありません**。ユーザーを無視して失敗した、トップダウンのリデザインです。グループBの対比として使ってください。「自分たちのほうが分かっている」という姿勢は同じですが、こちらは堀（Instagram Stories）が弱く、段階的な展開もありませんでした。

**2022年の Instagram「Make Instagram Instagram Again」撤回（確度：高）**
- 2022年7月：「Instagram を再び Instagram に」と求め、「TikTok になろうとする」のをやめさせる請願は、23万人以上の署名を集めました。Kylie Jenner と Kim Kardashian がこのスローガンを共有しました。問題となったテストには、フルスクリーンのフィード、アルゴリズムによるおすすめの増加、Reels の重視が含まれていました。 — [Today](https://www.today.com/today/amp/rcna40717)；[Euronews](https://www.euronews.com/2022/07/29/instagram-gives-in-to-users-complaints-and-drops-tiktok-like-updates)；[Mediaite](https://www.mediaite.com/media/tech/instagram-chief-pledges-to-reverse-changes-after-everyone-and-the-kardashians-complained/)
- 2022年7月28日、Adam Mosseri は Platformer に、Instagram はフルスクリーンのテストを縮小し、おすすめを一時的に減らすと語りました。「**人々は不満を抱いており、利用データも芳しくない**」からです。動画は時間とともに伸びていくだろうとも述べました。 — [Platformer](https://platformer.news/p/-instagram-walks-back-its-changes)；[Engadget](https://www.engadget.com/instagram-full-screen-feed-recommended-posts-185859342.html)
- 教訓：撤回の根拠は、抗議**と**行動データの**両方**でした。Mosseri が利用データに明示的に言及したことが重要な点です。2016年のアルゴリズム型フィードは、怒りだけでは覆りませんでした。
- 請願の発起人（写真家の Tati Bruening、@illumitati）は広く報じられていますが、ここでは再確認していません。

**機能の肥大化：Evernote（確度：中、慎重に）**
- 確認済み：Evernote は2011年に独立した **Evernote Food** アプリを公開し、**2015年8月**に終了しました。Chris O'Neill が Phil Libin に代わって CEO になってから約1か月後のことです。TechCrunch は、中核製品が停滞する中で、中核ではない領域の優先度を下げたものと位置づけました。メインのサービスは、登録ユーザー1億5,000万人を主張していました。 — [TechCrunch「The Feast Is Over」、2015-08-26](https://techcrunch.com/2015/08/26/the-feast-is-over)
- O'Neill（2015〜2018年）は、中核となるノート機能への再集中、機能の絞り込み、持続可能性を公に強調しました。2015年には人員削減が報じられ、10拠点のうち3拠点が閉鎖されました。2018年には従業員の15%が解雇されました。 — [Engadget のインタビュー、2016](https://www.engadget.com/2016-07-29-evernotes-ceo-on-unlocking-the-potential-of-every-idea.html)；[MobileSyrup 2018](https://mobilesyrup.com/2018/09/19/evernote-lay-off-15-percent-staff-death-spiral/)
- Bending Spoons が Evernote を買収し（2022年11月発表、2023年1月完了）、2023年2月に Evernote の従業員129人を解雇しました。 — [Wikipedia: Evernote Corporation](https://en.wikipedia.org/wiki/Evernote_Corporation)；[The Next Web](https://thenextweb.com/news/evernote-acquired-how-new-owner-can-fix-it)
- **注意：** Libin の「機能が多すぎる」といった発言の一次情報は見つかりませんでした。副次的な製品（Hello、Food、Penultimate、Skitch、物販の Evernote Market）は、乱立の例としてよく挙げられますが、「Evernote はユーザーの機能要望に従って失敗した」という主張は、**記録された事実ではなく論評**です。問題は、中核からの多角化と、中核製品の信頼性・停滞として捉えるほうが適切です。 — [Woshipm（意見記事、ZH）](https://www.woshipm.com/operate/6459540.html)

**ソーシャル面でのもう1つのC事例：IMVU（*The Lean Startup* より）**
- IMVU（3Dアバターチャット）は、既存の IM ネットワーク向けのアドオンを最初に作りました。ユーザーは友達リストを引き継ぎたがるはずだ、という想定でした。顧客との面談で、あるティーンエイジャーが、友達が知らないものをなぜ使うのかと尋ね、すでに複数の IM クライアントを使っていると指摘しました。IMVU は約4万行のコード（約6か月分の作業）を捨て、独立したネットワークへピボットしました。それは2007年に約1,000万ドルの売上に達しました。 — [Venture Hacks（Ries の講演の要約）](https://venturehacks.com/lean-startup)；[Eric Ries への Mixergy インタビュー](https://mixergy.com/interviews/ries-lean/)
- ここでの失敗は、*チーム自身の*思い込みに従ったことでした。ユーザーとのセッションで観察された行動が、それを正しました。

### 推論
- 「ユーザーに従って失敗した」本当の事例は、一般に言われるよりも少ないです。New Coke は明快な例ですが、その失敗は「傾聴」ではなく、**調査設計**の失敗（人工的な状況での表明された好み）でした。2018年の Snapchat と2022年の Instagram は、**「ユーザーを無視し、段階的なテストを欠き、撤回した」**例と分類するほうが適切です。
- 繰り返し現れる教訓は、大きな UX の変更は小さな割合のユーザーに展開し、利用データを見て、撤回の道を残しておくことです。Spiegel 自身のメモが、これを明示しています。

### 調査の空白
- Coca-Cola 自身の歴史ページを取得できなかったため、電話と手紙の正確な件数は確認できていません。
- 2022年のテスト期間中の Instagram の利用指標について、Mosseri の定性的な「利用データは芳しくない」を超える情報はありません。
- 機能の肥大化についての Libin の一次の発言は見つかっていません。

---

## Q4. Henry Ford の「もっと速い馬」という言葉は本物か？

### 要点
ほぼ確実に**偽の帰属（apocryphal）**です。Ford の存命中（彼は1947年に死去）に、この言葉が彼と結びついていたことを示す証拠はありません。見つかった最も古い関連づけは1999年のもの、最も古い明示的な帰属は2001年のものです。Henry Ford 博物館自身も、彼のものだと確かめられたことはないと述べています。

### 引用付きの調査結果
- Quote Investigator：Ford との最初の関連づけは、1999年の *Cruise Industry News Quarterly* の記事で、クルーズ船デザイナーの John McNeece が、Ford の顧客なら何と言っただろうかと推測したものです。Ford への直接の帰属で最も古いのは、英国の *Marketing Week* への2001年の投書です。QI は、この帰属を非常に弱いと判断しています。 — [Quote Investigator、2011-07-28](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- 漸進的な思考を表す、関連した「もっと速い馬」のイメージは、*The Quarterly Review of Biology* の1930年の Edward J. v. K. Menge の記事に見られます。 — [Quote Investigator](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- Ford のひ孫である William Clay Ford Jr. は、2006年にこの言葉を本物であるかのように使いました。 — [Quote Investigator](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- The Henry Ford（博物館およびアーカイブ）は、この言葉が Henry Ford のものだと十分にたどれたことはないと述べています。 — [The Henry Ford「Henry Ford's Quotations」](https://www.thehenryford.org/collections/explore/articles/henry-fords-quotations)
- American Dialect Society のメーリングリストでの言語学者の議論（2011年）も、同じ結論に達しました。 — [ADS-L](https://listserv.linguistlist.org/pipermail/ads-l/2011-July/111053.html)

### 推論
- 使うなら「Henry Ford のものと誤って伝えられている言葉」としてだけにしてください。根底にある考え方（顧客は現在の枠組みの中で解決策を語る）は、New Coke や IMVU のセッションのような、記録のある事例のほうが、よく裏づけています。

### 調査の空白
- 重要なものはありません。

---

## Q5. ソーシャル／写真／友達アプリ：初期テスターの意見が誤解を招いた例、あるいは行動データが意見と食い違った例

### 要点
**行動が表明された意見と食い違った**例として最も記録が充実しているのは、Facebook ニュースフィード（2006年）、Instagram のアルゴリズム型フィード（2016年）、Messenger の分離（2014年）です。声高な抗議があったのに、利用は増えました。Instagram/Burbn と IMVU は、**行動が本当の製品を明らかにした**例です。2022年の Instagram と2018年の Snapchat は、その逆で、**行動が不満を裏づけ**（利用データが下降）、企業は元に戻しました。写真アプリや友達アプリで、*初期ベータテスターの意見*が特にチームを誤らせた、記録の充実した事例は、IMVU（チームの思い込みに誤導され、観察で正された）を除いて見つかりませんでした。

### 引用付きの調査結果
- ニュースフィード：抗議そのものが、ユーザーが嫌っていると主張したまさにその機能を通じて広まりました。Facebook はフィードを維持し、プライバシー管理を追加しました。 — [Cornell INFO 2040](https://nsdl.library.cornell.edu/websites/expertvoices/info2040/archives/1729.html)；[Ball State Daily](https://www.ballstatedaily.com/article/2006/09/feed-angers-facebook-users)
- 2016年の Instagram：アルゴリズム型フィードに反対する30万人以上の請願があった一方で、Instagram はテストで「いいね」とコメントが増えたと報告しました。 — [WTVR](https://www.wtvr.com/2016/03/28/instagram-users-are-speaking-out-against-possible-change-to-news-feed)；[Nieman Lab](https://www.niemanlab.org/2016/06/instagram-now-shows-you-the-moments-you-care-about-first-how-should-news-orgs-react/)
- Messenger：1つ星レビューの嵐が起きた一方で、利用は約7か月で2億から5億 MAU に増えました。 — [YourStory](https://yourstory.com/2014/11/facebook-messenger-grows-to-500-million-amus/)
- 2022年の Instagram：撤回が起きたのは、抗議と利用データの*両方*が否定的だったとき（「利用データは芳しくない」）でした。 — [Platformer](https://platformer.news/p/-instagram-walks-back-its-changes)
- 2018年の Snapchat：抗議の後に、初めての DAU 減少（1億9,100万人から1億8,800万人）が続き、Snap 自身の提出書類がそれをリデザインのせいだとしました。 — [Snap 10-Q](https://www.sec.gov/Archives/edgar/data/0001564408/000156459018020094/snap-10q_20180630.htm)
- Twitter の280文字：多くのユーザーは、長いツイートは Twitter を台無しにすると言いましたが、行動を見ると、ほとんどのツイートは140文字以下のままでした（テストで140文字超は5%のみ）。また arXiv の研究は、エンゲージメントは増えたのではなく再配分されたことを見出しました。 — [ZDNet](https://www.zdnet.com.au/article/twitter-opens-floodgates-on-280-character-tweets-after-few-use-it/)；[arXiv](https://arxiv.org/pdf/1804.02318)
- Burbn：約100人のユーザーがいて、その行動（写真の利用）が Instagram を決定づけました。 — [NPR](https://www.npr.org/transcripts/493923472)
- Instagram の正方形：行動（アップロードの5枚に1枚が正方形でない、つまりユーザーがルールを回避していた）が、緩和を促しました。 — [Instagram blog](https://about.instagram.com/post/127722429412/150827-portrait-and-landscape)
- IMVU：ティーンエイジャーのユーザーとの対面セッションが、チームの IM アドオンの想定を覆しました。 — [Mixergy](https://mixergy.com/interviews/ries-lean/)
- BeReal：2022年の強い初期の熱狂と急速な拡散は、リテンションを予測しませんでした。DAU は5か月で約61%減りました。 — [Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html?src=rss)

### 推論
- これらの事例が裏づける実践的な判断ルール：**抗議があっても利用が増えている → 具体的な害に対処し、変更は維持する**（ニュースフィード、Messenger）。**抗議があり利用も減っている → すばやく撤回する**（2018年の Snapchat、2022年の Instagram）。**広範な回避行動がある → デフォルトまたは署名を保ちながら、制約を緩める**（Instagram の正方形、Twitter の140文字、Snapchat の Memories）。
- ネットワークの囲い込みがない、友達グループ向けの小さな写真アプリにとっては、Facebook の「抗議をやり過ごす」よりも、2018年の Snapchat の教訓（小さな段階的展開、計測、撤回の道を残す）のほうが関係が深いでしょう。Facebook の立場は、小さなアプリにはないネットワーク効果に支えられていました。
- 初期の熱狂（BeReal）は、弱い証拠です。信頼すべき行動シグナルは、リテンションのコホート（D1/D7/D30、週ごとのアクティブなグループ）です。

### 調査の空白
- これらの出来事について、引用された会社の声明と Snap の 10-Q を超える、Instagram・Facebook・Snap の厳密で公開された A/B データはありません。
- 写真アプリのベータテスターの*意見*がチームを誤らせた、記録の充実した事例（たとえば Path、Google+、Instagram Stories の社内テスト）は見つかりませんでした。創業者のポッドキャスト（たとえば *How I Built This*、*Lenny's Podcast*）を探せば、もっと出てくるかもしれません。
