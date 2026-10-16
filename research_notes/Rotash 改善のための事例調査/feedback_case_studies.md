# Case Studies: Acting on User Feedback (listen / ignore / followed-and-failed)

Scope note: Researched October 2026 with web search plus a few page fetches. Several primary pages could not be fetched (coca-colacompany.com and arxiv.org failed DNS from this environment), so some facts rest on search-result summaries of those pages or on reputable secondary coverage. Confidence ratings: **High** = primary source or several reputable outlets agree; **Medium** = consistent secondary reporting with no primary source checked; **Low / disputed** = conflicting or untraceable.

---

## Q1. Group A: products that listened to users, especially to observed behavior (Instagram/Burbn, YouTube, Slack/Glitch, Discord, Twitter/Odeo)

### Takeaway
All five origin stories are broadly real. The common pattern is not "users asked for X". The team **watched what a small group actually did** (Burbn users posting photos, Fates Forever players using the chat, Tiny Speck's own team using its internal chat tool, YouTube uploaders ignoring the dating frame) and **cut down to that behavior**. Slack is the best-documented case of structured iteration with small beta cohorts. YouTube's dating origin and Twitter's credit (Noah Glass) carry the most detail risk.

### Cited Findings

**Instagram from Burbn (confidence: High)**
- Burbn was a location check-in app (HTML5/iPhone) that also let users post plans and photos. Systrom said on NPR's *How I Built This* that it had only ~100 users, and that following Eric Ries's advice to ask why the people who keep using it keep using it, they found "each of the users loved the photo aspect", so they focused on photos. — [NPR transcript](https://www.npr.org/transcripts/493923472)
- Systrom's own account (via Inc.): Burbn was "cluttered" and "overrun with features", photos were by far the most popular feature, and they scrapped almost everything and rebuilt, keeping only the photo, comment, and like functions. — [Inc.](https://inc.com/eric-markowitz/life-and-times-of-instagram-the-complete-original-story.html); [TechCrunch "A Pivotal Pivot"](https://techcrunch.com/?p=241149)
- At TechCrunch Disrupt 2011, Systrom described a "pivot day" where the team asked which single feature made the product unique (photos), because "People loved posting pictures on Burbn". — [CNN Money, 2011-09-13](https://money.cnn.com/2011/09/13/technology/startups/instagram_burbn/)
- The rebuild reportedly took ~8 weeks, and Instagram launched on iOS in October 2010. — [TechCrunch](https://techcrunch.com/?p=241149) (secondary sites repeat this; treat "8 weeks" as Medium)
- Lesson: usage data from a small base (which feature people actually used) beat the founders' feature roadmap. Note that this is a **Lean Startup-inspired** story by Systrom's own account.

**YouTube as a video dating site (confidence: Medium-High for the concept, Low for colorful details)**
- Co-founder Jawed Karim described the dating origin in his 2007 University of Illinois commencement speech, including the slogan "Tune in, Hook up". Steve Chen confirmed the dating origin at SXSW 2016. — [Vice, "10 years ago today YouTube launched as a dating website"](https://vice.com/en/article/10-years-ago-today-youtube-launched-as-a-dating-website); [Founder Fragments](https://founderfragments.substack.com/p/did-you-know-youtube-was-a-dating)
- Users did not upload dating videos and instead uploaded all kinds of video, so the founders opened it to general video sharing. — [Vice](https://vice.com/en/article/10-years-ago-today-youtube-launched-as-a-dating-website)
- **Flag:** The "offered women on Craigslist $20 to upload dating videos, and nobody did" detail recurs widely (attributed to Chen at SXSW 2016), but I only found it in secondary sources. The framing of "Me at the zoo" (23 April 2005) as a "placeholder" is contested. Karim frames it as a test upload. — [Founder Fragments](https://founderfragments.substack.com/p/did-you-know-youtube-was-a-dating); [MakeTechEasier](https://maketecheasier.com/mte-when-youtube-launched-in-april-2005-its-first-video-was-a-19-second-clip-of-co-founder-jawed-karim-standing-in-front-of-elephants-at-san-diego-zoo-the-site-was-originally-built-as-a-dating-service/)

**Slack from Glitch, with beta iteration (confidence: High)**
- Slack grew out of the internal chat tool the Tiny Speck team built while making the online game Glitch. — [First Round Review interview with Stewart Butterfield](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/)
- Iteration process, in Butterfield's words: internal use from March 2013. By May 2013 they wanted outside teams because they "represented just one team dynamic". They "begged and cajoled" friends at other companies, with maybe **six to ten companies** to start (e.g., Cozy, Rdio). At Rdio the tool spread from a few front-end developers to all ~120 staff. At that size the product "looked pretty gnarly", so they made changes and "started the process over again" with progressively larger cohorts. — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/)
- "Preview release" in August 2013 (deliberately not called "beta"). On the first press day, **8,000 people requested invites, rising to 15,000 two weeks later**. Butterfield cited ~8,000 Zendesk tickets and ~10,000 tweets per month, all answered. — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/); [Quartz](https://qz.com/335321/slack-is-everywhere-growing-fast-and-still-works-great-heres-how-they-did-it)
- Butterfield's internal memo "We Don't Sell Saddles Here" (31 July 2013, about two weeks before the Preview Release) argued Slack sells organizational change, not chat. Its key insight: when people already want something badly they tolerate flaws, but when they do not yet know they want it, their tolerance is much lower. — [A Letter a Day reprint](https://aletteraday.substack.com/p/letter-155-stewart-butterfield-2013); [NFX Podcast](https://podcast.nfx.com/episodes/slack-memo)
- **Conflict:** Some sources say "8,000 companies" signed up in 24 hours. The interview-based source says 8,000 *people* requested invites. Use "people". — [First Round Review](https://review.firstround.com/from-0-to-1b-slacks-founder-shares-their-epic-launch-strategy/) vs. [Stacksync blog](https://www.stacksync.com/blog/the-video-game-that-failed-the-origin-story-of-slack)

**Discord from Fates Forever (confidence: Medium-High)**
- Jason Citron (who had sold OpenFeint) and Stan Vishnevskiy started Hammer & Chisel, which made the MOBA *Fates Forever* (released 2014). The in-game voice/text chat was the standout. Citron later said retention and growth numbers showed the game "was not going to become a big enough game", so they pivoted to the chat product, closing game development and laying off ~30% of staff. — [Contrary Research](https://research.contrary.com/report/discord); [Launched newsletter](https://readlaunched.substack.com/p/-how-discord-dominated-gaming)
- Discord launched in May 2015. An early breakthrough came from a Final Fantasy XIV subreddit thread (13 May 2015) reportedly driving ~600 signups via guild invites. Discord reached ~3M users by end of 2015. — [Launched](https://readlaunched.substack.com/p/-how-discord-dominated-gaming); [Contrary Research](https://research.contrary.com/report/discord) (signup counts are secondary; Medium)
- Lesson: product metrics (game retention) plus observed enthusiasm for a secondary feature drove the pivot.

**Twitter from Odeo (confidence: High on the outline, disputed on credit)**
- Odeo was a podcasting startup (Evan Williams, Noah Glass) whose prospects collapsed after Apple added podcasts to iTunes in 2005. Williams ran internal hackathons, and Jack Dorsey pitched an SMS status idea. "twttr" was prototyped in early 2006. Dorsey's first tweet came on 21 March 2006, with public launch on 15 July 2006. — [HISTORY.com](https://www.history.com/this-day-in-history/july-15/twitter-launches); [Mental Floss](https://www.mentalfloss.com/culture/internet/what-was-first-ever-tweet)
- **Disputed:** Noah Glass's role (naming, early championing) was minimized for years and surfaced later through Business Insider reporting. — [Fast Company, "Noah Glass, Twitter's long-lost Winklevoss"](https://www.fastcompany.com/1747118/noah-glass-twitters-long-lost-winklevoss)
- Caveat: this is less "listening to users" than an internal pivot after the market moved. Treat it as a pivot story, not a feedback story.

### Inferences
- The strongest "listening" lesson across these cases is **observing which behavior a small, retained group repeats**, not running opinion surveys. Instagram (photo usage), Discord (chat usage, retention data), and YouTube (what people uploaded) all fit this.
- Slack's process (cohorts of 6–10 teams, then larger teams, then reset when the bigger team broke the product) is the most transferable *method*. It mixes observed adoption (did it spread inside Rdio?) with direct complaints (support tickets, tweets).

### Gaps
- No primary transcript found for Steve Chen's SXSW 2016 Craigslist "$20" anecdote.
- Did not retrieve Butterfield's Medium post text directly, only reprints and summaries.
- No primary Discord source (Citron interview) was fetched; figures come from research and newsletter write-ups.

---

## Q2. Group B: products that ignored or overrode strong user requests and succeeded (iPhone keyboard, Snapchat ephemerality, Facebook News Feed 2006, Twitter 140/280, BeReal rules, Instagram square)

### Takeaway
"Ignoring users" success stories mostly share a pattern. The company **kept a core constraint or design bet** while **fixing the specific harm users complained about** (privacy controls for News Feed), or it **relaxed the constraint only once behavior data supported it** (Instagram's non-square posts once ~20% of uploads were non-square, Twitter's 280 once 9% of English tweets hit the limit). Pure defiance cases (Messenger split, Instagram algorithmic feed) worked on metrics but carried lasting resentment. BeReal is a cautionary counterexample: it kept its rules, and usage still collapsed after the novelty peak.

### Cited Findings

**iPhone (2007) dropping the physical keyboard (confidence: High on the criticism, see Gaps on internal process)**
- Steve Ballmer (Microsoft CEO) on CNBC, January 2007: the iPhone "doesn't appeal to business customers because it doesn't have a keyboard, which makes it not a very good e-mail machine", and he criticized the $500 price. — [CNBC](https://www.cnbc.com/id/16671712)
- A USA Today interview in the same period has Ballmer saying "There's no chance that the iPhone is going to get any significant market share". The attribution to USA Today rests on secondary reporting. TechRadar notes he also said it might sell well. — [TechRadar](https://techradar.com/pro/quote-of-the-day-by-former-microsoft-ceo-steve-ballmer-theres-no-chance-that-the-iphone-is-going-to-get-any-significant-market-share-a-staggering-misread-of-the-future-of-consumer-devices); [ComputerWoche](https://www.computerwoche.de/article/2674612/microsoft-chef-steve-ballmer-das-apple-iphone-wird-ein-flop.html)
- Ballmer later admitted he was wrong. — [PhoneArena](https://phonearena.com/news/Ballmer-I-was-wrong-about-the-iPhone_id87502)
- Nuance: Thurrott argues Ballmer was partly right that the *original* iPhone was weak for business, but because of poor Exchange support rather than the keyboard. — [Thurrott](https://www.thurrott.com/?p=84810)
- Caveat: this case is about overriding *industry and expert* expectations (keyboards were what smartphone buyers used), not a documented user-research result Apple ignored.

**Snapchat keeping ephemerality, and when saving arrived (confidence: High)**
- Spiegel's philosophy: "ephemeral should be the default". In an AP interview he argued it would be better if everything were deleted by default and people saved what mattered to them, which ran counter to the rest of the industry. — [MIT Technology Review profile](https://www.technologyreview.com/innovator/evan-spiegel/); [KSL/AP interview](https://www.ksl.com/article/27464994/snapchat-ceo-evan-spiegel-talks-sexts-and-growth)
- Spiegel's January 2014 AXS keynote (posted on Snap's blog) names ephemerality, with ubiquitous internet and easy media creation, as core to the product. — [TechCrunch, 2014-01-25](https://techcrunch.com/2014/01/25/how-snapchat-thinks-about-snapchat)
- Before 2016, saving meant screenshotting or exporting to the camera roll. **Memories launched 6 July 2016** as an in-app searchable archive of saved Snaps and Stories, with a passcode-locked "My Eyes Only". It was framed as "a departure from the app's hallmark ephemeral nature". — [Snap Newsroom, 2016-07-06](https://newsroom.snap.com/memories); [TechCrunch](https://techcrunch.com/2016/07/06/snapchat-memories/); [CNBC](https://www.cnbc.com/2016/07/06/snapchat-launches-new-timeline-called-memories.html)
- Lesson: Snap held ephemerality as the *default* for ~5 years (app launched 2011) and added saving as an **opt-in layer**. It never made permanence the default.
- **Flag:** I could not verify a widely quoted "2012 blog post" with phrases like "talking, not storing". Treat those quotes as unverified.

**Facebook News Feed, September 2006 (confidence: High on the protest and apology, Medium on engagement figures)**
- News Feed and Mini-Feed launched 5 September 2006. The "Students Against Facebook News Feed" group grew rapidly, with membership reported variously from ~200,000 early on to ~700,000–750,000. Complaints centered on privacy ("makes stalking too easy"). — [Cornell Sun, 2006-09-14](https://cornellsun.com/2006/09/14/c-u-students-upset-at-facebook); [The Dartmouth](https://www.thedartmouth.com/article/2006/09/facebook-changes-spark-controversy); [Ball State Daily](https://www.ballstatedaily.com/article/2006/09/facebook-news-feed-upsets-angers-students-across-country)
- Zuckerberg posted an open letter about three days later: "We really messed this one up", saying they had not built proper privacy controls. Facebook then added controls (e.g., stopping Mini-Feed from announcing activities). It **kept News Feed itself**. Student papers reported the protests subsiding and boycott calls withdrawn. — [Ball State Daily](https://www.ballstatedaily.com/article/2006/09/feed-angers-facebook-users); [Pepperdine Graphic](https://pepperdine-graphic.com/news-feed-irks-users-causes-facebook-rift/)
- The irony, as Boz (Andrew Bosworth) noted: the protest groups spread *through* News Feed. Each time someone joined, their friends saw it. — [Cornell INFO 2040 blog](https://nsdl.library.cornell.edu/websites/expertvoices/info2040/archives/1729.html); [Reason, "The Great Facebook Revolt of 2006"](https://reason.com/?p=115457)
- Engagement: reports say engineers saw users become roughly "twice as engaged" despite the protests. **This is unverified.** No primary Facebook figure was found. — [Deccan Chronicle](https://deccanchronicle.com/technology/in-other-news/070916/facebook-news-feed-turns-10.html)
- Lesson: separate **what users say they want** ("remove the feed") from **the underlying harm** (loss of control over who sees what). Fix the harm and keep the feature, with behavior (usage) as the check.

**Twitter's 140-character limit and the 2017 switch to 280 (confidence: High)**
- Origin: 140 was chosen to fit under SMS's 160-character cap, leaving room for the username. — [Global News (Reuters)](https://globalnews.ca/news/3771455/twitter-character-limit-280); [ReasonWhy (ES)](https://www.reasonwhy.es/actualidad/social-media/por-que-twitter-solo-deja-escribir-140-caracteres-2015-09-30)
- Rationale for change (26 Sept 2017 test, by Aliza Rosen and Ikuhiro Ihara): **9% of English tweets hit 140, vs 0.4% of Japanese tweets**. Japanese, Chinese, and Korean were excluded since those languages fit more per character. — [Tech.co](https://tech.co/news/rip-140-twitter-testing-280-character-tweets-2017-09); [Yahoo Finance](https://finance.yahoo.com/news/twitter-tests-new-280-character-limit-users-210006742.html)
- Test result (rolled out to all on 7 Nov 2017): only **5% of tweets in the test exceeded 140 and 2% exceeded 190**. Only ~1% hit 280. — [ZDNet](https://www.zdnet.com.au/article/twitter-opens-floodgates-on-280-character-tweets-after-few-use-it/); [Marketing Mag](https://www.marketingmag.com.au/social-digital/twitter-rolls-280-character-tweets-users/); [MobileSyrup](https://mobilesyrup.com/2017/11/07/twitter-is-rolling-out-280-character-limit-to-all-users/)
- One year on: ~1% of English tweets hit 280, 12% longer than 140, 5% longer than 190. — [TechCrunch](https://techcrunch.com/?p=1739154)
- Academic study (arXiv 1804.02318, "How Constraints Affect Content: The Case of Twitter's Switch from 140 to 280 Characters"): post-switch tweets of ≤140 characters were "vastly less popular" than same-length tweets before the switch. Total engagement looked roughly constant and was **redistributed** across lengths, not increased. — [arXiv PDF](https://arxiv.org/pdf/1804.02318)
- Early engagement claims (SocialFlow: longer tweets got more retweets/likes) are short-window, and the figures are reported inconsistently between outlets. **Low confidence.** — [Inverse](https://inverse.com/article/39205-twitter-280-characters-study); [IAB UK](https://www.iabuk.com/news-article/280-characters-more-engaging-twitter-users-140)
- Lesson: Twitter kept a much-mocked constraint for ~11 years and relaxed it **based on measured behavior** (who was hitting the limit), testing on a sample first. Brevity mostly survived.

**BeReal keeping no-filter / once-a-day rules (confidence: High on rules and decline, Medium on numbers)**
- Rules: a daily notification at a random time, 2 minutes to post front and back camera photos (late posts are labeled), no filters, and you must post to see friends' posts ("No lurking"). The company declines most press interviews. — [Wikipedia: BeReal](https://en.wikipedia.org/wiki/BeReal); [CUHK Varsity](https://varsity.com.cuhk.edu.hk/?p=21643); [TheWrap](https://www.thewrap.com/innovators-2022-bereal-alexis-barreyat-kevin-perreau/)
- Competitors copied it (Instagram "Dual Camera" July 2022, "Candid Challenges" test Aug 2022; TikTok Now). — [Wikipedia: BeReal](https://en.wikipedia.org/wiki/BeReal); [Sensor Tower](https://sensortower.com/blog/monday-mobile-memo-2024-06-17)
- Usage: Sensor Tower data (via NYT) showed DAUs **fell ~61% from Oct 2022 to Mar 2023** (≈15M to <6M). BeReal itself claimed 20M DAU in April 2023. MAU was down ~2% YoY (Nov 2023–May 2024). — [Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html?src=rss); [Tubefilter](https://www.tubefilter.com/?p=180594); [Sensor Tower](https://sensortower.com/blog/monday-mobile-memo-2024-06-17)
- BeReal added features while keeping the core rules: Bonus BeReals (extra posts), RealMojis, RealPeople (celebrities/brands), RealBrands, RealEvents. **Voodoo acquired BeReal for ~€500M in June 2024**, claiming ~40M "active users" (not DAU, so not comparable). Founder Alexis Barreyat stepped down as CEO in favor of Aymeric Roffé. — [Tubefilter](https://www.tubefilter.com/?p=180594); [PetaPixel](https://petapixel.com/2024/06/11/anti-instagram-photo-sharing-app-bereal-purchased-for-537-million); [Primetel](https://primetel.com.cy/bereal-is-acquired-by-voodoo-for-euro500-million-6005)
- Lesson: keeping strict rules created a distinct, viral product, but **rules alone did not create retention**. It is a mixed "B" case: the company held the constraints and survived (exit at roughly half its 2022 peak valuation is reported elsewhere, unverified here), but it did not thrive.

**Instagram square-only until 2015 (confidence: High)**
- Instagram kept square-only from 2010 until **27 August 2015**, when it added portrait and landscape. Its own blog cited that "**nearly one in five** photos or videos people post aren't in the square format", and that cropping cut out people and landmarks. Profile grid thumbnails stayed square. — [Instagram blog, 2015-08-27](https://about.instagram.com/post/127722429412/150827-portrait-and-landscape); [The Next Web](https://thenextweb.com/apps/2015/08/27/instagram-photos-no-longer-have-to-be-square/); [Macworld](https://www.macworld.com/article/2977000/social-media/instagram-steps-out-of-the-box-allows-posts-in-landscape-and-portrait-orientation.html)
- Lesson: the constraint was relaxed when **observed behavior** (people letterboxing photos with third-party apps to escape the square, implied by the 1-in-5 stat) showed it was working against users. It was not relaxed in response to complaints alone. The square remained a brand signature in the grid.

**Additional B cases (overrode loud protest, metrics went up)**
- *Instagram algorithmic feed (2016):* the March 2016 test announcement drew a Change.org petition of 300,000+ signatures and a "turn on post notifications" panic. Instagram said users missed ~70% of posts and Systrom wanted the 30% seen to be "the best 30%". It rolled out to all users by June 2016, claiming more likes and comments during testing. In 2018 it tweaked the feed toward recency after continued feedback. — [WTVR](https://www.wtvr.com/2016/03/28/instagram-users-are-speaking-out-against-possible-change-to-news-feed); [Nieman Lab](https://www.niemanlab.org/2016/06/instagram-now-shows-you-the-moments-you-care-about-first-how-should-news-orgs-react/); [MediaNama 2018](https://www.medianama.com/2018/03/223-instagram-algorithm-changes-to-make-feed-more-timely/) (70% figure is Instagram's own claim)
- *Facebook Messenger split (2014):* users were forced to install a separate app, prompting a flood of angry one-star reviews. Zuckerberg called it a "big ask" that caused "a lot of friction" and said "maybe we didn't handle that as smoothly as we could". Messenger grew from 200M (April 2014) to 500M MAU (November 2014). — [The Drum](https://www.thedrum.com/news/2014/11/08/mark-zuckerberg-admits-he-didn-t-handle-facebook-messenger-transition-smoothly); [YourStory](https://yourstory.com/2014/11/facebook-messenger-grows-to-500-million-amus/); [Fierce Network](https://www.fierce-network.com/wireless/facebook-s-zuckerberg-explains-why-users-were-forced-to-download-separate-messenger-app)

### Inferences
- "Ignore the users" successes are usually **"ignore the stated solution, address the underlying need, and verify with behavior"**. News Feed is the canonical example.
- Constraints (140 characters, square, ephemerality, once a day) are product identity. The successful pattern was to **hold them by default, relax them carefully when data showed widespread workaround behavior** (letterboxing, hitting the limit, screenshotting), and keep the original as the default or signature.
- The survivorship bias is large. For every News Feed there are overrides that simply failed (see Group C, Snapchat 2018). Strong network lock-in (Facebook, Instagram) makes defiance far less risky than it is for a small app.

### Gaps
- Apple's internal reasoning or user research on dropping the keyboard was not sourced. Jobs's 2007 keynote critique of fixed plastic keyboards is well known, but I did not fetch a transcript.
- No primary Facebook data on News Feed engagement in 2006.
- BeReal: no founder interview explaining why it refused filters or likes. The rationale comes only from its fact sheet and marketing. No post-2024 DAU data.

---

## Q3. Group C: followed requests or research and failed, or had to reverse (New Coke, Snapchat 2018, Instagram 2022, feature bloat/Evernote)

### Takeaway
New Coke is the classic case of **research that measured the wrong thing**: blind sips measured taste, not the brand's emotional attachment. Snapchat 2018 and Instagram 2022 were not "following user requests". They were **company-driven redesigns rolled out without enough staged testing**, and both partially reversed under backlash plus bad usage data. Evernote's feature sprawl is real, but the facts need careful handling: Evernote Food was shut down in 2015, and the "too many features" narrative is mostly commentary.

### Cited Findings

**New Coke (1985) (confidence: High on dates and outline, numbers vary)**
- Announced **23 April 1985**, the first formula change in 99 years, driven by Coke's falling share against Pepsi. The company says nearly **200,000 consumers** preferred the new formula in taste tests. — [ABC7 "Beverage Backlash"](https://abc7news.com/post/new-coke-ii-coca-cola-classic-history-of/5266029/); [Live 5 News](https://www.live5news.com/2026/04/23/this-day-history-april-23-1985-coca-cola-announces-new-coke-formula-change/)
- The original returned as "Coca-Cola Classic" on **11 July 1985 (79 days later)** and regained the top spot. — [Coca-Cola Company history page](https://www.coca-colacompany.com/about-us/history/new-coke-the-most-memorable-marketing-blunder-ever) (search-result summary; page fetch failed); [ABC7](https://abc7news.com/post/new-coke-ii-coca-cola-classic-history-of/5266029/)
- Backlash volume: **figures conflict**. Some sources say 400,000+ calls and letters. Wikipedia's Coke II article says 40,000+. A popular blog says 1,500 calls a day. Use "tens of thousands, possibly hundreds of thousands" or cite the company page directly. — [Damn Interesting](https://www.damninteresting.com/the-american-gustation-crisis-of-1985) vs. [Wikipedia: Coke II](https://www.wikipedia.org/wiki/Coke_II)
- President Don Keough on the conspiracy theory that it was a stunt: "We're not that dumb, and we're not that smart." — [Damn Interesting](https://www.damninteresting.com/the-american-gustation-crisis-of-1985) (widely quoted; the company page reportedly carries it too)
- Lesson: taste tests answered "which sip tastes better?" but not "how will you feel if we take your Coke away?" Stated preference in an artificial test diverged from real-world attachment and behavior.

**Snapchat 2018 redesign (confidence: High)**
- The redesign (rolled out late 2017 to Feb 2018) separated friends' content from media/creators and introduced an algorithmic Friends feed. A Change.org petition passed **1.2 million signatures**. Snap replied on Change.org: "We hear you... the new Snapchat has felt uncomfortable for many". — [Fox13 Seattle](https://www.fox13seattle.com/news/snapchat-stock-loses-1-3-billion-after-kylie-jenner-tweet); [9to5Google](https://9to5google.com/2018/02/23/snapchat-share-price/)
- Kylie Jenner tweeted on **21 Feb 2018** that she no longer opened Snapchat. The widely quoted wording is "sooo does anyone else not open Snapchat anymore? Or is it just me... ugh this is so sad", but the exact text was not re-verified in the sources fetched here. Snap shares closed **down ~6%** the next day, about **$1.3B of market value**. Analysts called it an overreaction, and Fast Company attributed part of the drop to a prior Citi downgrade. — [Fox13 Seattle](https://www.fox13seattle.com/news/snapchat-stock-loses-1-3-billion-after-kylie-jenner-tweet); [BreakingNews.ie](https://www.breakingnews.ie/business/kylie-jenner-tweet-sends-snapchat-stock-tumbling-829519.html) (causality is disputed)
- Partial reversal (May 2018): Snaps and Chats went back to chronological order, friends' Stories moved back alongside chats, and a Subscriptions feed was added. Spiegel: "combining watching Stories and communicating with friends into the same place made it harder to optimize for both competing behaviors". — [BusinessLIVE / Reuters](https://www.businesslive.co.za/bd/companies/2018-05-14-snapchat-relents-on-software-changes-amid-backlash/); [TheWrap](https://www.thewrap.com/snapchat-rolls-out-redesigned-redesign)
- Usage effect: **Q2 2018 DAU fell to 188M from 191M** (–2% QoQ), the first decline ever, which Snap's 10-Q attributes to the redesign. — [Snap 10-Q, Q2 2018 (SEC)](https://www.sec.gov/Archives/edgar/data/0001564408/000156459018020094/snap-10q_20180630.htm); [TechCrunch](https://techcrunch.com/?p=1687498)
- Spiegel's 26 Sept 2018 internal memo (leaked to Cheddar): the redesign was "rushed". They did not leave enough time to "iterate and test with a smaller percentage of our community", "slowed down our product and eroded our core product value", and the algorithmic Friends feed made it harder to find friends. He still defended separating social from media. — [Engadget](https://www.engadget.com/2018-10-05-snap-evan-spiegel-app-redesign-rushed.html); [Cheddar](https://cheddar.com/media/snap-ceo-evan-spiegel-company-memo-on-2019-strategic-goals-and-profitability)
- Classification note: this was **not** "following user requests". It was a top-down redesign that ignored users and failed. Use it as the counterweight to Group B: the same "we know better" stance, but with a weak moat (Instagram Stories) and no staged rollout.

**Instagram 2022 "Make Instagram Instagram Again" rollback (confidence: High)**
- July 2022: a petition to "make Instagram Instagram again" and stop "trying to be TikTok" drew 230,000+ signatures. Kylie Jenner and Kim Kardashian shared the slogan. The tests at issue included a full-screen feed, more algorithmic recommendations, and a Reels emphasis. — [Today](https://www.today.com/today/amp/rcna40717); [Euronews](https://www.euronews.com/2022/07/29/instagram-gives-in-to-users-complaints-and-drops-tiktok-like-updates); [Mediaite](https://www.mediaite.com/media/tech/instagram-chief-pledges-to-reverse-changes-after-everyone-and-the-kardashians-complained/)
- On 28 July 2022 Adam Mosseri told Platformer that Instagram would wind down the full-screen test and temporarily reduce recommendations, because "**people are frustrated and the usage data isn't great**". He said video would still grow over time. — [Platformer](https://platformer.news/p/-instagram-walks-back-its-changes); [Engadget](https://www.engadget.com/instagram-full-screen-feed-recommended-posts-185859342.html)
- Lesson: the reversal was justified by **both** protest **and** behavior data. Mosseri explicitly cited usage data, which is the key point: outrage alone had not reversed the 2016 algorithmic feed.
- Petition originator (photographer Tati Bruening, @illumitati) comes from widely reported coverage, but I did not re-verify it here.

**Feature bloat: Evernote (confidence: Medium, careful)**
- Verified: Evernote launched a standalone **Evernote Food** app (2011) and shut it down in **August 2015**, about a month after Chris O'Neill replaced Phil Libin as CEO. TechCrunch framed it as deprioritizing non-core areas while the core product stagnated. The main service then claimed 150M registered users. — [TechCrunch, "The Feast Is Over", 2015-08-26](https://techcrunch.com/2015/08/26/the-feast-is-over)
- O'Neill (2015–2018) publicly emphasized refocusing on the core note-taking product, trimming features, and sustainability. In 2015 there were reported layoffs and 3 of 10 offices closed. In 2018 15% of staff were laid off. — [Engadget interview, 2016](https://www.engadget.com/2016-07-29-evernotes-ceo-on-unlocking-the-potential-of-every-idea.html); [MobileSyrup 2018](https://mobilesyrup.com/2018/09/19/evernote-lay-off-15-percent-staff-death-spiral/)
- Bending Spoons acquired Evernote (announced November 2022, closed January 2023) and laid off 129 Evernote staff in February 2023. — [Wikipedia: Evernote Corporation](https://en.wikipedia.org/wiki/Evernote_Corporation); [The Next Web](https://thenextweb.com/news/evernote-acquired-how-new-owner-can-fix-it)
- **Flags:** I found no primary source for a Libin quote like "we have too many features". Side products (Hello, Food, Penultimate, Skitch, the Evernote Market physical goods store) are often cited as sprawl, but the "Evernote failed from following user feature requests" claim is **commentary, not documented fact**. The problem is better framed as diversification away from the core plus core-product reliability and stagnation. — [Woshipm (opinion, ZH)](https://www.woshipm.com/operate/6459540.html)

**Additional C example with a social angle: IMVU (from *The Lean Startup*)**
- IMVU (3D avatar chat) first built an add-on for existing IM networks, assuming users wanted to keep their buddy lists. In customer sessions, a teen asked why she'd use something her friends hadn't heard of, and noted she already ran multiple IM clients. IMVU threw away ~40,000 lines of code (~6 months' work) and pivoted to a standalone network. That reached about $10M revenue in 2007. — [Venture Hacks (Ries talk summary)](https://venturehacks.com/lean-startup); [Mixergy interview with Eric Ries](https://mixergy.com/interviews/ries-lean/)
- Here the failure was following the *team's* assumption. Observed behavior in user sessions corrected it.

### Inferences
- True "followed users and failed" cases are rarer than commonly claimed. New Coke is the clean example, and its failure was a **research design** failure (stated preference in an artificial context), not "listening". Snapchat 2018 and Instagram 2022 are better classified as **"ignored users, lacked staged testing, reversed"**.
- The repeated lesson is to roll out big UX changes to a small percentage, watch usage data, and keep a rollback path. Spiegel's own memo says this explicitly.

### Gaps
- Could not fetch Coca-Cola's own history page to confirm the exact call and letter counts.
- No sourced data on Instagram usage metrics during the 2022 test beyond Mosseri's qualitative "usage data isn't great".
- No primary Libin quotes on feature bloat.

---

## Q4. Is Henry Ford's "faster horse" quote real?

### Takeaway
Almost certainly **apocryphal**. No evidence ties it to Ford during his lifetime (he died in 1947). The earliest linkage found is from 1999, and the earliest explicit attribution is from 2001. The Henry Ford museum itself says it has never been traced to him.

### Cited Findings
- Quote Investigator: the earliest linkage to Ford is a 1999 *Cruise Industry News Quarterly* piece in which cruise-ship designer John McNeece speculated about what Ford's customers would have said. The earliest direct ascription to Ford is a 2001 letter to UK *Marketing Week*. QI judges the attribution very weak. — [Quote Investigator, 2011-07-28](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- A related "faster horses" image for incremental thinking appears in a 1930 article by Edward J. v. K. Menge in *The Quarterly Review of Biology*. — [Quote Investigator](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- Ford's great-grandson William Clay Ford Jr. used the line in 2006 as if it were authentic. — [Quote Investigator](https://quoteinvestigator.com/2011/07/28/ford-faster-horse/)
- The Henry Ford (museum and archive) says it has never been satisfactorily traced to Henry Ford. — [The Henry Ford, "Henry Ford's Quotations"](https://www.thehenryford.org/collections/explore/articles/henry-fords-quotations)
- Linguist discussion on the American Dialect Society list (2011) reached the same conclusion. — [ADS-L](https://listserv.linguistlist.org/pipermail/ads-l/2011-July/111053.html)

### Inferences
- Use it only as "a saying misattributed to Henry Ford". The underlying idea (customers describe solutions within their current frame) is better supported by documented cases like New Coke or the IMVU sessions.

### Gaps
- None material.

---

## Q5. Social/photo/friend apps: where early testers' opinions misled, or behavior data contradicted opinions

### Takeaway
The best-documented social-app examples of **behavior contradicting stated opinion** are Facebook News Feed (2006), Instagram's algorithmic feed (2016), and the Messenger split (2014): loud protest while usage rose. Instagram/Burbn and IMVU show **behavior revealing the real product**. Instagram 2022 and Snapchat 2018 show the reverse case, where **behavior confirmed the complaints** (usage data down) and the companies reverted. I found no well-documented case of a photo or friend app whose *early beta testers' opinions* specifically misled the team, beyond IMVU (which was misled by team assumptions, corrected by observation).

### Cited Findings
- News Feed: the protest itself spread through the very feature users claimed to hate. Facebook kept the feed and added privacy controls. — [Cornell INFO 2040](https://nsdl.library.cornell.edu/websites/expertvoices/info2040/archives/1729.html); [Ball State Daily](https://www.ballstatedaily.com/article/2006/09/feed-angers-facebook-users)
- Instagram 2016: a 300K+ petition against the algorithmic feed, while Instagram reported more likes and comments in the test. — [WTVR](https://www.wtvr.com/2016/03/28/instagram-users-are-speaking-out-against-possible-change-to-news-feed); [Nieman Lab](https://www.niemanlab.org/2016/06/instagram-now-shows-you-the-moments-you-care-about-first-how-should-news-orgs-react/)
- Messenger: one-star review storms, while usage went from 200M to 500M MAU in ~7 months. — [YourStory](https://yourstory.com/2014/11/facebook-messenger-grows-to-500-million-amus/)
- Instagram 2022: the reversal came when *both* protests and usage data were negative ("the usage data isn't great"). — [Platformer](https://platformer.news/p/-instagram-walks-back-its-changes)
- Snapchat 2018: protests were followed by the first-ever DAU decline (191M to 188M), which Snap's own filing attributed to the redesign. — [Snap 10-Q](https://www.sec.gov/Archives/edgar/data/0001564408/000156459018020094/snap-10q_20180630.htm)
- Twitter 280: many users said longer tweets would ruin Twitter, but behavior showed most tweets stayed under 140 (only 5% over 140 in the test), and the arXiv study found engagement redistributed rather than growing. — [ZDNet](https://www.zdnet.com.au/article/twitter-opens-floodgates-on-280-character-tweets-after-few-use-it/); [arXiv](https://arxiv.org/pdf/1804.02318)
- Burbn: ~100 users, and their behavior (photo use) defined Instagram. — [NPR](https://www.npr.org/transcripts/493923472)
- Instagram square: behavior (1 in 5 uploads non-square, i.e., users working around the rule) drove the relaxation. — [Instagram blog](https://about.instagram.com/post/127722429412/150827-portrait-and-landscape)
- IMVU: in-person sessions with teen users invalidated the team's IM add-on assumption. — [Mixergy](https://mixergy.com/interviews/ries-lean/)
- BeReal: strong early enthusiasm and viral growth in 2022 did not predict retention. DAU fell ~61% in five months. — [Engadget](https://engadget.com/bereal-the-buzziest-app-of-2022-has-been-bought-by-a-mobile-game-publisher-175016152.html?src=rss)

### Inferences
- A practical decision rule supported by these cases: **protest plus rising usage means address the specific harm and keep the change** (News Feed, Messenger). **Protest plus falling usage means roll back fast** (Snapchat 2018, Instagram 2022). **Widespread workaround behavior means relax the constraint while keeping the default or signature** (Instagram square, Twitter 140, Snapchat Memories).
- For a small friend-group photo app with no network lock-in, the Snapchat 2018 lesson (small staged rollouts, measure, keep a rollback path) is likely more relevant than Facebook's "ride out the protest". Facebook's position depended on network effects a small app lacks.
- Early hype (BeReal) is weak evidence. Retention cohorts (D1/D7/D30, weekly active groups) are the behavior signal to trust.

### Gaps
- No rigorous, published A/B data from Instagram, Facebook, or Snap on these episodes beyond the quoted company statements and Snap's 10-Q.
- Did not find well-documented cases of photo-app beta-tester *opinions* misleading teams (e.g., Path, Google+, Instagram Stories internal testing). Searching founder podcasts (e.g., *How I Built This*, *Lenny's Podcast*) might surface more.
