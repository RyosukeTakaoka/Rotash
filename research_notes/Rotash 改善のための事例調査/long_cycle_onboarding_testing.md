# Long-cycle engagement, onboarding a novel concept, and early testing (for Rotash)

Context: Rotash is a small-group iOS app. One friend takes one photo per day, and 7 photos make a weekly collage. Three early testers (friends) thought it meant "drawing one picture together", called it boring before the first week ended, and said there was "only one reason to open per day".

Research note: several primary sites (nngroup.com, paulgraham.com, business.columbia.edu) failed to load (DNS errors) during this session. Where a primary text could not be read, the finding is marked "(secondary)" or "(not verified against primary)". Items I know only from background knowledge and could not source here are listed under Gaps, not presented as findings.

## Q1. Long-cycle reward design: what intermediate rewards and progress signals keep people engaged before the weekly payoff?

### Takeaway
The best-supported finding is the goal-gradient / endowed-progress family: people speed up as a visible goal gets closer, and pre-filled progress raises completion. So a 7-slot collage that visibly fills up, perhaps starting with a slot already filled, is a sound mechanic. The Zeigarnik "unfinished tasks stick in memory" claim did NOT hold up in a 2025 meta-analysis and should not be used as a justification. Daily-cadence social apps built around one notification (BeReal) and delayed-reveal apps (Dispo) show that a single daily trigger loses pull once the novelty fades.

### Cited Findings
**Goal-gradient effect (Kivetz, Urminsky & Zheng 2006, Journal of Marketing Research 43(1):39–58)**
- In a real café's "buy 10, get 1 free" card program, customers bought coffee more often the closer they got to the free coffee — [Columbia Business School research page](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal); [Columbia insights summary](https://business.columbia.edu/insights/chazen-global-insights/goal-gradient-hypothesis-resurrected-purchase-acceleration)
- In a second field study, internet users rating songs for reward certificates visited more often, rated more songs per visit, and were less likely to stop a session as they neared the reward threshold — [Columbia research page](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal); [Chicago Booth Review](https://www.chicagobooth.edu/review/going-goal)
- "Illusionary goal progress": a 12-stamp card with 2 bonus stamps already filled (10 purchases still required) produced faster completion than a plain 10-stamp card — [Columbia research page](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)
- People who sped up more toward their first reward were more likely to re-engage quickly with the program afterwards. The authors report the gradient is not explained by habituation, expiration worries, time trends or heterogeneity — [Columbia research page](https://business.columbia.edu/faculty/research/goal-gradient-hypothesis-resurrected-purchase-acceleration-illusionary-goal)
- Full paper PDF (could not be fetched this session, so the exact effect sizes are not verified): [goalgradient.pdf](https://business.columbia.edu/sites/default/files-efs/pubfiles/1200/goalgradient.pdf)

**Endowed progress effect (Nunes & Drèze 2006, Journal of Consumer Research 32(4):504–512, DOI 10.1086/500480)**
- Definition: people given artificial progress toward a goal persist more toward it. In the car-wash field experiment, one group got a blank 8-stamp card and the other a 10-stamp card with 2 stamps pre-filled. Both needed 8 washes for a free one — [IDEAS/RePEc record](https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html)
- The effect seems to work through the feeling that the task is partly done, not through not wanting to "waste" the free stamps. It depends on the reason given for the endowment and on the units progress is counted in — [IDEAS/RePEc abstract](https://ideas.repec.org/a/oup/jconrs/v32y2006i4p504-512.html)
- The completion rates usually quoted are 34% (pre-filled card) vs 19% (blank card). A secondary note (a reader's notes on *Hooked*) gives this as an "82% higher completion rate", which matches 34/19 ≈ 1.79 — [Goodreads note on Hooked](https://www.goodreads.com/notes/23567071-hooked/26090533-ankur-jhaveri/3175af60-5eb8-4f2a-b970-88401aa6c512). FLAG: I could not confirm 34% / 19% against the paper's full text in this session.

**Zeigarnik effect — weak; do not rely on it**
- The 2025 meta-analysis by Ghibellini & Meier (DOI 10.1057/s41599-025-05000-w) found no general memory advantage for unfinished tasks. It did find a general tendency to go back to and finish interrupted tasks (the Ovsiankina effect). The authors conclude the Zeigarnik effect "lacks universal validity" — [IDEAS/RePEc record](https://ideas.repec.org/a/pal/palcom/v12y2025i1d10.1057_s41599-025-05000-w.html); [University of Bern PDF](https://www.kog.psy.unibe.ch/e48276/e1785865/s41599-025-05000-w1_ger.pdf); [Wikipedia summary](https://en.wikipedia.org/wiki/Zeigarnik_effect)
- The journal is listed inconsistently: RePEc says "Palgrave Communications" and other sources say *Humanities and Social Sciences Communications* (the same journal, renamed) — [IDEAS/RePEc](https://ideas.repec.org/a/pal/palcom/v12y2025i1d10.1057_s41599-025-05000-w.html)
- Secondary blogs report 59 studies included and d≈0.15, and a ~67% resumption rate. Neither figure was verified in the primary abstract — [Yu-kai Chou blog (secondary)](https://yukaichou.com/behavioral-analysis/zeigarnik-effect-incomplete-tasks-memory-tension/)

**Delayed reveal: Dispo**
- Dispo's App Store listing says photos "develop" every day at 9am, the disposable-camera mechanic — [App Store listing](https://apple.co/3qCRWpk)
- A user review says the next-day wait was the main reason they downloaded the app and complains an update removed it. The developer replied that users can now choose to get photos immediately or at 9am, which suggests the company moved away from a pure wait mechanic — [App Store listing reviews](https://apple.co/3qCRWpk) (single review; weak evidence)
- Dispo framed the waiting period as giving users more "joy" — [dot.la](https://dot.la/dispo-2648134232.html)
- Spark Capital pulled its funding after a controversy involving the co-founder David Dobrik, and the app later moved toward social features and paid content. No retention data is public — [PetaPixel tag page](https://petapixel.com/tag/dispo/); [tuapppara (2026, Spanish)](https://tuapppara.com/redes/dispo/)

**Single daily trigger: BeReal, a cautionary example for "only one reason to open per day"**
- Apptopia data reported by the NYT: about 15M daily users in Oct 2022, falling below 6M by March 2023. Coverage put the decline down to novelty wearing off among Gen Z — [Platformer](https://platformer.news/how-bereal-missed-its-moment)
- PetaPixel reported DAU nearly halving from a ~20M peak to 10.4M by Feb 2023 — [PetaPixel](https://petapixel.com/2023/02/22/bereal-may-be-on-the-out-users-have-nearly-halved-since-peak)
- BeReal disputed the third-party estimates and claimed 20M+, later 25M+, DAU. The size of the decline is therefore contested — [Platformer](https://platformer.news/how-bereal-missed-its-moment)
- Commentary argues the daily prompt created urgency (you only see friends' posts after posting your own), but that what users were "missing out on" was not compelling enough to keep them engaged long term — [Stack Influence (marketing blog, weak)](https://stackinfluence.com/what-is-bereal-why-gen-zs-photo-app-matters/)

**Weekly cadence: Duolingo leagues**
- A league is a weekly leaderboard of about 30 randomly grouped users ranked by XP over 7 days, with promotion and demotion between tiers (Bronze → Diamond) — [Deconstructor of Fun Duolingo teardown](https://duolingo.deconstructoroffun.com/mechanics/leagues); [We Got This Covered](https://wegotthiscovered.com/fyi/all-duolingo-leagues-explained/)
- Critics say leagues can push people to grind easy lessons for points, so more activity does not necessarily mean more value — [Desirability Lab](https://desirabilitylab.com/backfill/backfill-2023-278-duolingo-social-features)

### Inferences
- **Make the week's progress visible and countable.** A 7-slot grid filling day by day is a textbook goal gradient. Kivetz's data suggests engagement should rise toward days 5–7, so the risk zone is days 1–3, which is exactly when Rotash's testers lost interest. Show "3/7 — 4 more until the collage" prominently.
- **Endowed progress at the start.** Begin the first week with a slot already filled: a group photo taken during onboarding, or a "day 0" photo the inviter takes. Nunes & Drèze's moderators matter here: the head start needs a credible reason ("your group's first photo") and the same unit (photos).
- **Do not count on suspense or Zeigarnik alone to bring people back.** The resumption (Ovsiankina) tendency is the better-supported effect, so frame each day as resuming the group's unfinished collage, not as remembering it.
- **BeReal and Dispo both show one daily trigger wearing off.** Each open needs something that varies: whose turn it is, a new friend photo, a reaction. "Only one reason to open per day" is a known failure mode, not just tester impatience.
- **Rotash differs from Dispo/BeReal:** only one person shoots each day, so six of seven members are viewers on any given day. Their daily reason to open has to be seeing the friend's photo and reacting, plus watching the collage fill. Their own turn comes about once a week.

### Gaps
- Exact effect sizes in Kivetz et al. (e.g., how much purchase intervals shrink toward the reward) were not verified; the PDF could not be fetched.
- The 34% vs 19% Nunes & Drèze figures are widely quoted but were not verified against the paper's full text in this session.
- Not researched or sourced in this session, so needing verification before use: Spotify Discover Weekly (a Monday playlist refreshed weekly) and Spotify Wrapped (yearly) as anticipation rituals; Wordle's once-a-day puzzle and shareable result grid; Strava weekly summaries; Slowly (letters delivered with a delay based on distance); 1 Second Everyday (the montage payoff arrives only after weeks or months). Each is a relevant pattern (a fixed delivery time, a scarce daily unit, a shareable artifact, a delay that makes something feel valuable), but I have no sourced data on their retention effects.
- No primary Duolingo data on how leagues affect lessons or retention was found. Duolingo has spoken publicly about leagues and streaks, but I found no citable figure in this session.
- No retention data for Dispo was found.

## Q2. The Hook model (Nir Eyal): triggers, action, variable reward, investment — how it applies to friends' photos, and criticisms

### Takeaway
The Hook model is a useful design checklist, but it has no direct experimental validation. Its "variable reward" step rests on operant-conditioning research and is ethically contested. For Rotash, the natural variable reward is social ("what did my friend shoot today?"). The investment step (each photo stored in a shared weekly artifact) is the part most clearly supported by goal-gradient research.

### Cited Findings
- The model's reward step is described as releasing dopamine that reinforces the action. Its behavioural basis comes from intermittent-reinforcement studies in animals (e.g., Olds & Milner). Extending this to product use is an inference — [Thoughtworks](https://www.thoughtworks.com/en-sg/insights/blog/addicted-industry-matures); [SuperSummary background](https://www.supersummary.com/hooked/background/)
- Critics compare variable rewards to slot machine design. Johann Hari (*Stolen Focus*, 2022) calls Eyal's position representative of predatory Big Tech, and a Guardian writer questioned the ethics of using psychology to drive engagement — [SuperSummary](https://www.supersummary.com/hooked/background/); [Thoughtworks](https://www.thoughtworks.com/en-sg/insights/blog/addicted-industry-matures)
- Big Think argues variable rewards fit slot machines and games like FarmVille but make no sense in a utility like Google. In other words, the mechanic depends on the product type — [Big Think](https://bigthink.com/?p=54491)
- Eyal addresses ethics himself (the "Manipulation Matrix" / building it ethically) — [Eyal blog via Goodreads](https://www.goodreads.com/author_blog_posts/18729825-the-hook-model-and-how-to-build-it-ethically)
- *Hooked* cites the endowed progress car-wash study as an example of the "investment" phase — [Goodreads reader note on Hooked](https://www.goodreads.com/notes/23567071-hooked/26090533-ankur-jhaveri/3175af60-5eb8-4f2a-b970-88401aa6c512)
- No peer-reviewed tests of the Hook model as a whole were found — [Behavioral Scientist](https://www.thebehavioralscientist.com/?p=2407); [Ivy book review](https://ivy0.substack.com/p/book-review-hooked)

### Inferences
- **Trigger:** the push notification when today's photo is taken (Rotash already has this) is the external trigger. Over time, the internal trigger should become curiosity about what the friend saw today.
- **Action:** a one-tap open to see the photo. Keep it frictionless; no login walls.
- **Variable reward:** Eyal's "rewards of the tribe" (social validation) map onto seeing a friend's photo. The variability is already built in: different shooter, subject and time each day. Adding cheap responses (reactions, a one-line caption, guessing the location) multiplies the variable rewards per open without adding ethically doubtful slot-machine mechanics.
- **Investment:** each viewed and reacted-to photo builds up the shared collage. The weekly collage plus an archive of past weeks is stored value that raises switching costs. That is where the "endowed progress" logic fits.
- **Ethical stance:** with a small, intimate group, a calm cadence is a selling point. Avoid fake urgency, which has a growing reputational cost for products seen as manipulative.

### Gaps
- No controlled study shows that products designed with the Hook model retain users better.
- No primary text from *Hooked* was read in this session, so chapter-level claims (e.g., the three reward types: tribe, hunt, self) come from my background knowledge and need checking against the book.

## Q3. Onboarding an unfamiliar concept when there is no finished example yet: sample work, seeded content, aha moments, time-to-value, empty states

### Takeaway
The testers' misreading ("drawing one picture together") is a classic empty-state problem: the finished artifact is the explanation, and it doesn't exist until day 7. The standard remedy is starter or demo content — a sample finished collage, ideally personalised — plus a guided first action. "Aha moment" metrics like Facebook's "7 friends in 10 days" and Slack's "2,000 messages" are widely repeated, but their primary sourcing is weak.

### Cited Findings
**Empty states and starter content**
- Starter content works best for features that store content or follow a template. It should be broadly appealing, show the main features, and be deletable or replaceable — [ServiceTitan Anvil design system](https://anvil.servicetitan.com/docs/web/patterns/empty-states)
- Personalising sample data improves the experience. Starter content lets users learn a feature hands-on and then delete it — [Emplifi Soul design system](https://soul.emplifi.io/latest/patterns/patterns/empty-states-Q4JtHNtG)
- Grammarly's demo document teaches features by doing — [Wix Studio blog](https://www.wix.com/studio/blog/empty-states-ux-design)
- Empty states should tell users what to do next and drive an action, not only educate — [Smashing Magazine (2017)](https://smashingmagazine.com/2017/02/user-onboarding-empty-states-mobile-apps)
- Vercel's Geist design system names four empty-state approaches: blank slate, informational, educational, and guide (starter content to tinker with) — [Vercel Geist](https://vercel.com/geist/empty-state)
- Educational content should be brief and skippable — [ServiceTitan Anvil](https://anvil.servicetitan.com/docs/web/patterns/empty-states)

**Aha moments: verification status**
- Facebook "7 friends in 10 days": Chamath Palihapitiya's own Quora answer (reposted) says only that Facebook found an early link between the number of friends a user had within a certain time and their likelihood to churn, and used it to get new users to their "a-ha" moment quickly. That text does not include the specific "7 in 10" figure — [Chamath archive](https://chamatharchive.com/?p=608). The exact "7 friends in 10 days" phrasing appears in secondary write-ups without primary citation — [Notion case study (secondary)](https://scratch-puffin-363.notion.site/Facebook-s-7-friends-activation-story-a-PM-case-study-33dec508b5118053bff8e0233fedd0f3); [Airtribe Substack (secondary)](https://airtribe.substack.com/p/pm-growth-lessons-for-2024). FLAG: treat the number as folklore; the underlying principle (a friend-count threshold predicts retention) is attested by Chamath.
- Slack "2,000 messages": Stewart Butterfield is quoted (via Andrew Chen's *The Cold Start Problem*) as saying any team that has exchanged 2,000 messages has "really tried" Slack, and that 93% of those customers were still using it. For a team of about 10 people that is roughly a week of messages — [Goodreads highlight from The Cold Start Problem](https://www.goodreads.com/notes/56962799-the-cold-start-problem/84411704-mikko-ikola/435bc888-c6a7-45f1-83c2-6c66617e1ab2). FLAG: secondary (a book quote via a reader highlight), historical (around 2014–2015), and an observed correlation, not a causal threshold.

### Inferences
- **Show a finished example before the first photo.** On first launch or invite, show a sample completed 7-photo collage (seeded content), ideally animated filling slot by slot, with copy like "Each day a different friend adds one photo. On day 7 you get this." This directly fixes the "drawing one picture together" misreading.
- **Personalise the sample where possible:** put the group's names or avatars on the slots ("Mon: Aki, Tue: you...") so the rotation is clear.
- **Shorten time-to-value.** The real payoff comes on day 7, so create a mini payoff on day 1: an onboarding group photo as slot 0 (endowed progress), a preview of the half-built collage on day 3 or 4, or a first-week "short week" (e.g., a 3-photo mini collage) so the first artifact arrives within days.
- **Define Rotash's own aha-moment hypothesis** in Slack/Facebook style, e.g. "a member who has viewed at least 3 friends' photos and seen 1 completed collage within their first 10 days". Then test it against retention in the second test group. Treat it as a correlation to check, not a law.

### Gaps
- Could not fetch Nielsen Norman Group's empty-state or onboarding articles (DNS failure), so NN/g-specific guidance is not cited.
- No primary source (talk or video timestamp) for "7 friends in 10 days" was found.
- No published case of a photo-collage or slow-social app that solved the "no finished example" problem was found. Reforge and Lenny's Newsletter content on time-to-value could not be accessed in this session.

## Q4. Early testing: sample sizes, concierge / Wizard-of-Oz tests, retention benchmarks, the Sean Ellis test, kill criteria, YC/PG advice

### Takeaway
Three friends is enough to find comprehension and usability problems (the "drawing together" misreading is a valid finding) but tells you almost nothing about demand or retention. Use a qualitative test of about 5 people for usability. For demand, run more groups for at least 2 full weekly cycles and measure behaviour (opens, viewing rate, week-2 return), not compliments. Popular benchmark numbers (40/20/10 D1/D7/D30) describe top performers, not typical apps, and are hard to apply to small groups.

### Cited Findings
**Sample size**
- The "5 users" rule comes from Nielsen & Landauer's problem-discovery model, found = N(1−(1−L)^n), where L is the probability that one user hits a given problem. Five users find about 85% of problems only when L ≈ 31%. It is a rule for qualitative discovery, not for measurement — [MeasuringU](https://measuringu.com/category/sample-size/page/5/); [UX Planet](https://uxplanet.org/sample-size-for-usability-study-part-1-about-nielsen-and-probability-efffecdbfa95)
- In simulations, five users found on average 85% of problems, but the share ranged from nearly 100% down to 55% — [W3C WAI list post (Slatin, 2004)](https://lists.w3.org/Archives/Public/w3c-wai-gl/2004AprJun/0572.html); [Human Factors International](https://www.humanfactors.com/newsletters/enough_is_enough.html)
- Distinct user groups and quantitative goals need larger samples — [Koji blog (vendor, weak)](https://www.koji.so/blog/how-many-users-usability-testing-2026)
- Primary NN/g article (not fetched this session): https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/

**Retention benchmarks**
- Lenny Rachitsky and Casey Winters surveyed practitioners. For consumer social, 6-month user retention of about 25% is "good" and about 45% is "great". Consumer transactional is about 30% / 50%, and consumer SaaS about 40% / 70% — [Lenny's Newsletter](https://www.lennysnewsletter.com/p/what-is-good-retention-issue-29); [Casey Accidental](https://www.caseyaccidental.com/p/what-is-good-retention-an-exhaustive-benchmark-study-with-lenny-rachitsky)
- Critique: these benchmarks come from people who built iconic, massively scaled businesses. A flat retention curve can support a business even below them — [Founders Fuel](https://foundersfuel.beehiiv.com/p/good-great-retention)
- Andrew Chen (via Quettra data): the average app loses 77% of DAUs within 3 days of install and 90% within 30 days — [andrewchen.com](https://andrewchen.com/new-data-shows-why-losing-80-of-your-mobile-users-is-normal-and-that-the-best-apps-do-much-better/amp/)
- The "D1 40% / D7 20% / D30 10%" consumer-social rule of thumb is NOT stated as a benchmark by Andrew Chen in the sources found. It appears in a third-party glossary, which also notes that "good" benchmark numbers usually describe top-decile or top-quartile apps. The same source gives April 2026 medians of D1 27.3%, D7 9.2%, D30 3.9% — [MWM glossary](https://mwm.ai/glossary/retention). FLAG: secondary, and the methodology is unclear.
- Another 2026 aggregator gives social and messaging medians of D1 48% / D7 28% / D30 14% — [Unstar](https://unstar.app/fr/blog/app-retention-benchmarks-2026). FLAG: it conflicts with MWM's lower overall medians; neither is a primary dataset.

**Sean Ellis test**
- Ask users "How would you feel if you could no longer use this product?" If 40% or more answer "very disappointed", the product likely has product/market fit. Introduced in about 2009 — [Learning Loop](https://learningloop.io/glossary/sean-ellis-score)
- Ellis gave no canonical minimum sample. Practitioners suggest at least 40 respondents who have experienced the core value, and warn about bias from surveying only engaged users. Below 25% is read as weak — [KPI Clarity](https://kpiclarity.beehiiv.com/p/testing-product-market-fit-customers-life-without-product); [Koji](https://www.koji.so/docs/sean-ellis-test-product-market-fit)

**Concierge / Wizard of Oz**
- Concierge MVP: deliver the service manually, visibly, to a few early adopters. Wizard of Oz: users believe it is automated while humans do the work behind the scenes. Zappos (shoes bought at retail after each online order) is the classic Wizard-of-Oz case. DoorDash founders hand-delivered orders and "Food on the Table" began as a manual food butler (concierge) — [Koji concierge guide](https://www.koji.so/docs/concierge-mvp-guide); [Synodus MVP examples](https://synodus.com/blog/mvp-software-development-example); [mobilespoon](https://www.mobilespoon.net/2019/06/10-shades-of-mvp.html)

**Paul Graham, "Do Things That Don't Scale" (2013)** (secondary; paulgraham.com could not be fetched)
- The most common unscalable thing is recruiting early users manually, one at a time (Airbnb, Stripe, Pinterest). The "Collison installation" means setting a user up on the spot ("give me your laptop") instead of sending a link. Founders resist because of shyness and laziness — [Glasp summary](https://glasp.co/articles/do-things-that-dont-scale); [Alexander Jarvis on Stripe](https://www.alexanderjarvis.com/stripe-doing-things-that-dont-scale); [Medium notes](https://medium.com/@edisipka/my-notes-on-do-things-that-dont-scale-the-reality-check-i-needed-e986bad14620)
- Give early users an over-the-top experience, such as Wufoo's handwritten thank-you notes — [Glasp summary](https://glasp.co/articles/do-things-that-dont-scale)
- Primary essay: https://paulgraham.com/ds.html

### Inferences
- **Classify what 3 testers can tell you.** The "drawing together" misreading and "only one reason to open" are valid qualitative findings (they are problems with high L). "Boring before week 1 ended" is a weak demand signal because the payoff was never experienced. Don't kill on it, and don't conclude much from it either.
- **Run a Wizard-of-Oz test of the mechanic before more building.** For example, in a LINE or Instagram group chat, a facilitator posts a rotation schedule ("today: Aki"), the assigned person posts one photo, and the facilitator hand-assembles a collage (e.g., in Canva) on day 7 and posts it, maybe with half-built previews on days 3–4. This tests whether the rotation and collage are wanted, separately from the iOS app.
- **Set kill / iterate / pivot criteria before the test.** Example of criteria written in advance (illustrative, not sourced benchmarks):
  - Iterate if comprehension is fixed (≥80% can explain the rule after onboarding) but daily viewing is low.
  - Continue if ≥70% of assigned shooters post on their day and most groups voluntarily start week 2.
  - Pivot the cadence (e.g., everyone shoots daily, or 3-day collages) if posting is fine but members don't come back between their own turns.
  - Kill or rethink if fewer than half the groups start week 3 unprompted, and Sean-Ellis-style "very disappointed" answers stay well below 25–40%.
  - Benchmarks like Lenny's 6-month ~25% for consumer social are long-run targets, not 2-week gates.

### Gaps
- No primary YC Startup School material on early retention was read (only Paul Graham via secondary summaries). The common YC advice that the retention curve must flatten, and that you should talk to users weekly, is background knowledge, not sourced here.
- No source gives retention benchmarks specific to small private-group apps (Locket, BeReal friend-only, group photo apps); public benchmarks are for broad consumer social.
- The Sean Ellis test needs about 40+ respondents, which is impractical for a few small groups; there is no sourced small-sample alternative.

## Q5. Designing a second test group: size, recruiting, what to measure, duration, avoiding politeness and novelty bias

### Takeaway
Recruit several real friend groups, ideally people who are not the founder's close friends, each run by a person inside the group. Run for at least 2–3 full weekly cycles, so you observe behaviour after the first collage payoff and after the novelty wears off. Measure behaviour, not stated opinions, and ask about past behaviour, not hypotheticals ("Mom Test").

### Cited Findings
- Compliments are "fool's gold". People give them to be supportive or to end the conversation politely, while commitments (time, money, reputation) are the real signal. Ask about specific past behaviour rather than hypotheticals like "would you use...", which invite overly optimistic answers — [Sachin Rekhi on The Mom Test](https://www.sachinrekhi.com/the-mom-test-rob-fitzpatrick); [Yevgeniy Brikman on The Mom Test](https://www.ybrikman.com/blog/2023/03/29/the-mom-test/); [guptadeepak summary](https://guptadeepak.com/books/the-mom-test/)
- Novelty effect in practice: BeReal's decline was widely put down to novelty wearing off after the initial spike — [Platformer](https://platformer.news/how-bereal-missed-its-moment); [Mancunian Matters](https://www.mancunianmatters.co.uk/?p=170610)
- Testing with distinct user groups needs separate samples of about 3–5 per group for qualitative discovery — [Koji (vendor, weak)](https://www.koji.so/blog/how-many-users-usability-testing-2026); [UX Planet](https://uxplanet.org/sample-size-for-usability-study-part-1-about-nielsen-and-probability-efffecdbfa95)
- Slack's threshold was about one week of messages for a 10-person team, so measuring "did the group reach the threshold" fits a weekly cycle — [Cold Start Problem highlight](https://www.goodreads.com/notes/56962799-the-cold-start-problem/84411704-mikko-ikola/435bc888-c6a7-45f1-83c2-6c66617e1ab2)

### Inferences (proposed design; not taken from a single source)
- **Unit of analysis = the group, not the individual.** Rotash's value is collective, so plan for 4–6 groups of 4–7 people (about 20–40 people). That allows some group-level comparison and gets near the ~40 respondents needed for a Sean Ellis survey.
- **Recruiting:** recruit groups that already exist (club members, dorm mates, coworkers), through one in-group "champion" who invites the others with a Collison-installation-style in-person setup. Include at least half the groups from outside the founder's circle to reduce politeness bias. Get a small commitment (e.g., each person agrees to their shooting day) as a Mom-Test-style signal.
- **Duration:** at least 2, preferably 3, full 7-day cycles. Week 1 includes novelty and onboarding. Week 2 shows whether the first collage payoff brings people back. Week 3 shows behaviour after novelty fades. Decide on the date of the final measurement in advance.
- **Metrics (from Rotash's analytics):** per-member daily open rate on days when they are not the shooter; share of assigned shooters who post on their day; time from post to view; collage-completion rate per group-week; collage share or save rate; whether the group starts week 2 or 3 without a prompt from the founder; comprehension check after onboarding ("explain Rotash in one sentence"); Sean Ellis question at the end of the test; and a Mom-Test style exit interview about what they actually did ("when did you last open it, and why?").
- **Bias controls:** avoid founder nudges during the test (log any that happen); compare onboarding variants (A: current, B: sample collage plus endowed day-0 slot) across groups; don't tell groups what the "right" behaviour is.
- **Cycle-length variants:** test the core hypothesis "the weekly payoff is too far away" directly by running one or two groups on a shorter cycle (e.g., a 3- or 4-photo collage). Compare activity on days 1–3 between variants.

### Gaps
- No academic source was found on the minimum number of cycles needed to separate novelty from steady-state behaviour for weekly-cadence apps. "2–3 cycles" is a reasoned heuristic, not a sourced rule.
- No sourced guidance was found specifically on running group-level beta tests for small private social apps.
