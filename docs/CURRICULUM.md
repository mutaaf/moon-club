# Moon Club curriculum

This is the research, the design principles and the scope and sequence behind Moon Club's lessons. It also covers how mastery is measured on the device. The lessons themselves live in the **Core lesson pack** (metaphases `packs/core/pack.json`; format in [PACKS.md](PACKS.md)). Two expert reviewers wrote and signed them off with us:

- **Ms. Rivera**, a veteran elementary teacher and reading specialist
- **Dr. Okafor**, a former equity analyst and finance educator

Both reviewers are AI personas, run as separate reviewing agents. A human still signs the checklist in PACKS.md before any pack goes on the remote channel.

The rules for kids content haven't changed:
- pretend money only, and never advice;
- patterns are clues, not promises;
- reading at grade 5 or below, checked by `fkGrade` in tests;
- no links out (except behind the parental gate), and no ads, analytics or SDKs;
- no emoji drawn as pictures;
- every lesson step fits one card on iPhone SE and on iPhone 17.

## What the research says

Every source below was fetched during this work (Nov 2026). Where something couldn't be fetched, the "Could not verify" section says so.

### Standards: what a 4th–8th grader should know

**Jump$tart and Council for Economic Education, National Standards for Personal Financial Education (2021)** [1][2]
- **Topics.** There are six: Earning Income, Spending, Saving, Investing, Managing Credit and Managing Risk. Financial decision-making is woven through all six rather than being a topic of its own.
- **Benchmarks.** Each topic has benchmarks at the end of grades 4, 8 and 12.
- **Grade 4, Investing.**
  - 4-1: "People invest their money so that it can grow over time and help them achieve their long-term financial goals."
  - 4-2: savings accounts suit short-term goals because they are low risk, while "for longer-term financial goals, people often invest in riskier assets."
- **Grade 4, other topics.**
  - Spending 4-3a: "Define the concept of opportunity cost."
  - Saving 4-1a: "Explain why it is often harder to save than to spend money."
- **Grade 8.** Owning stock ("part-owners of a business"), dividends, diversification and ranking investments by risk are **Grade 8** standards. So for 6–11 year olds they are enrichment, not core. That is why they sit in the **Big Moons** track.

**CEE Voluntary National Content Standards in Economics (2010)** [6], grade 4 benchmarks
- Standard 7: "A price is what people pay when they buy a good or service".
- Standard 11: "Money makes trading easier by replacing barter".
- Standard 14: entrepreneurs "take risks, to develop new products, and start new businesses".
- Supply and demand schedules start at grade 8.

**OECD PISA 2022 financial literacy framework** [5]
- **Content areas:** money and transactions, planning and managing finances, risk and reward, and the financial landscape (including "information … from education to advertising").
- **Processes:** identify, analyse, evaluate and apply.
- **Contexts:** education and work, home and family, individual, and societal.
- **Pretend money:** PISA uses a pretend currency, the zed, for fair comparison. That is a precedent for our pretend coins.
- **Age:** PISA tests 15-year-olds, so we borrow its structure, not its targets.

### How children build money skills (CFPB, 2016) [3][4]

The CFPB's three building blocks are executive function, financial habits and norms, and financial knowledge and decision-making skills.
- **Ages 6–12.** "Financial habits and norms are the primary focus of financial development during middle childhood [ages 6−12]."
- **Executive function** "continues to develop".
- **Knowledge and decisions.** Full decision-making skills "typically do not emerge until adolescence", but children pick up "simple money management knowledge and skills during middle childhood".
- **Milestone question:** "Does the child show the ability to plan ahead and delay gratification?"

### How children learn best

- **Retrieval practice.**
  - Testing beats restudying on delayed tests [7].
  - Across 50 classroom experiments, 57% of effects were medium or large, from K-12 to medical school [8].
  - The IES practice guide rates "quizzing to re-expose students to key content" as **strong** evidence [11].
- **Spacing.**
  - Spaced study beats massed study across 839 assessments [9].
  - The best gap grows with how long you need to remember [10].
  - IES rates it as moderate evidence [11].
- **Worked examples first, then matched practice and self-explanation.** These help most early on [12]. IES also recommends linking concrete and abstract representations [11].
- **Concrete → pictures → abstract (CRA).** CRA is evidence-based for students with learning disabilities in math computation [13]. Evidence beyond that group is thinner.
- **Interleaving.** Mixed practice beat blocked practice for 7th graders after 30 days (d = 0.79) [15][14].
- **Feedback.**
  - Hard or new tasks and low achievers benefit from immediate feedback, and delayed feedback helps transfer [16].
  - Praise should be used "sparingly, if at all" because it pulls attention to the self [16].
- **Growth mindset.** Effort praise beats intelligence praise in the classic studies [17]. But mindset interventions average d ≈ 0.08, with very little data on children [18][19]. We praise the process and don't promise it will boost results.
- **Games and simulations.**
  - Digital games beat non-game teaching, g = 0.33 [20].
  - Serious games help learning (d = 0.29) but were *not* more motivating, and they work best alongside other teaching and over several sessions [21].
- **Financial education.**
  - It moves knowledge more than behaviour [22].
  - In school programmes, knowledge rose by +0.33 SD, but only about +0.15 SD in the randomized trials [23].
  - In a randomized study, Stock Market Game players scored higher in math and financial literacy. That study was industry-funded, so read it with care [24].

### What to avoid

- **Random paid rewards (loot-box mechanics).**
  - Buying loot boxes is linked to problem-gambling severity in adults [25].
  - The link is moderate to large in 16–18 year olds [26].
  - 27% of UK young people had paid to open loot boxes [27].
- **Frequent checking.** People who look at their returns more often take less risk and react to losses more strongly, a pattern called myopic loss aversion [28][29]. That evidence is from adults; applying it to children is our inference.
- **Loss framing.** Children are loss-sensitive like adults [30], so "you lost" framing is a real risk.

## Design principles (and where each one lives)

| # | Principle | In Moon Club |
|---|---|---|
| 1 | **Scope to grade 4, with grade 8 as enrichment** [1][6] | Little Moons (6–8) covers money, trade-offs, companies, saving vs investing and spreading out. Big Moons (9–11) adds owning shares, dividends, report cards, charts and why prices move. Tracks are cumulative: every 6–8 lesson is for everyone. |
| 2 | **Every lesson is retrieval** [7][8][11] | Each micro-lesson has at least one `check` or `sort`, and options are shuffled on screen. The validator rejects a lesson without one. |
| 3 | **Space it** [9][10][11] | **Review stops** on every land of the map (MoonClubCore `Review.swift`). <br>• A missed question comes back at the next stop. <br>• Right answers climb boxes that come back after 0, 1, 3 and 7 days. <br>• Every finished lesson comes back once, a day later. |
| 4 | **Interleave** [14][15] | A Review stop mixes questions round-robin across units. Each land's stop covers that land and every earlier one. |
| 5 | **Concrete before abstract; worked example first** [11][12][13] | Examples come before the idea: the lemonade stand, then shares; jellybeans in a jar, then beat or miss; $1/$2/$3, then "the average is the number to beat"; a money-in/money-out sort, then the profit math. Say cards come before every check. |
| 6 | **Immediate, specific feedback** [16] | Every check has a `why` shown at once. A wrong answer gets the explanation, never a bare "try again". |
| 7 | **Praise the habit, not luck or smarts** [16][17][18] | Piggy tips praise spreading out, not gains ("Prices can fall again too. Spreading out is still a good habit."). Guess: "Good thinking! Even experts guess wrong a lot." Coach Nova's "My big oops" normalizes mistakes. |
| 8 | **No gambling-like mechanics** [25][26][27] | Points are earned only, with no random paid rewards and no loot boxes. Guess scoring is deterministic. The chest is a daily-missions reward with fixed contents. |
| 9 | **Discourage frequent checking** [28][29] | The Piggy course lesson "Don't peek every minute". The piggy tip counts today's opens on the device and suggests once a day. "Zoom out" and "Time and ups and downs". The Piggy chart shows the whole line. |
| 10 | **No loss framing** [30] | "Your pretend coins are down 12% since you started. Big drops happen to everyone. It is not your fault." A down day is "like a rainy day", never "you lost". |
| 11 | **Explain moves with honest, incentive-based clues** [6] | Why did it move? (below): ranked clues from data we have, and "we're not sure" when they don't explain the move. |
| 12 | **Games supplement teaching; bring in the grown-up** [3][21][22] | Lessons, games and quests run in short sessions. The grown-up corner shows what the child is learning, with conversation starters and printable worksheets on the web. |

## Scope and sequence

There are 54 lessons in 13 units, generated from `packs/core/pack.json`. Every lesson takes about a minute and has 3–7 steps.

**Tracks:**
- **Little Moons (6–8)** lessons are for everyone.
- **Big Moons (9–11)** lessons build on them.

**Unit order:** Money basics → Companies → Shares → Piggy Bank school (the hands-on activity comes early) → Saving and investing (risk before the snowball) → Dividends → Money-smart → Report cards (the Guess course) → Why did it move? → Candles → Trends → Floors and ceilings → Busy days and smooth lines.

### Little Moons (ages 6–8): everyone starts here

| # | Unit | Lesson | Objective (the kid can…) | Standards |
|---|---|---|---|---|
| 1 | Money basics | What is money? (`money`) | Explain why people use money instead of trading things. | CEE Econ 11: Money; Jump$tart: Saving |
| 2 | Money basics | Where does money come from? (`earn`) | Say that most people earn money by working. | Jump$tart: Earning Income |
| 3 | Money basics | Needs and wants (`needs`) | Sort needs from wants. | CFPB: Habits & norms; Jump$tart: Saving |
| 4 | Money basics | Make a money plan (`budget`) | Describe a budget as a plan made before spending. | CFPB: Executive function; Jump$tart: Saving |
| 5 | Money basics | Every choice has a trade-off (`choose`) | Name what you give up when you choose (a trade-off). | CEE Econ 1: Scarcity; Jump$tart: Spending |
| 6 | Companies | What is a company? (`company`) | Describe a company as a team that sells goods or services. | CEE Econ 14: Entrepreneurship |
| 7 | Companies | Money in, money out (`profit`) | Work out profit as money in minus money out. | CEE Econ 14: Entrepreneurship |
| 8 | Shares and the market | What is a share? (`share`) | Explain that a share is a small piece of a company. | Jump$tart: Investing |
| 9 | Shares and the market | The stock market (`market`) | Say where shares are traded. | Jump$tart: Investing; OECD: Financial landscape |
| 10 | Shares and the market | Why do prices go up and down? (`prices`) | Explain that prices move when buyers or sellers are more eager. | CEE Econ 7: Markets & prices; CEE Econ 8: Role of prices |
| 11 | Piggy Bank school | Your pretend piggy bank (`piggy-start`) | Say that Piggy Bank coins are pretend and follow real prices. | CFPB: Habits & norms |
| 12 | Piggy Bank school | Spread your coins (`piggy-spread`) | Work out how spreading coins limits the hurt from one company. | Jump$tart: Managing Risk |
| 13 | Piggy Bank school | Ups and downs are normal (`piggy-updown`) | Treat a down day as normal, not a mistake. | CFPB: Executive function |
| 14 | Piggy Bank school | Don't peek every minute (`piggy-peek`) | Choose to check now and then instead of every minute. | CFPB: Executive function; CFPB: Habits & norms |
| 15 | Saving and investing | Saving vs investing (`saving`) | Tell saving (stays the same) from investing (can grow or shrink). | Jump$tart: Investing; Jump$tart: Saving |
| 16 | Saving and investing | Save it or invest it? (`which`) | Choose saving for soon and investing for a long time away. | Jump$tart: Investing; OECD: Planning & managing finances |
| 17 | Money-smart | Don't put all your eggs in one basket (`baskets`) | Explain why spreading money across many companies lowers the risk from any one company. | Jump$tart: Managing Risk; OECD: Risk & reward |
| 18 | Money-smart | Be patient like the moon (`patience`) | Explain why long-term investors don't react to one bad day. | CFPB: Executive function; Jump$tart: Investing |
| 19 | Money-smart | Too good to be true (`too-good`) | Spot a too-good-to-be-true promise and ask a grown-up. | Jump$tart: Managing Risk; Jump$tart: Spending |
| 20 | Money-smart | Clues, not promises (`clues`) | Treat chart shapes as clues, never promises. | Jump$tart: Spending |
| 21 | Report cards | What is a report card? (`report-card`) | Describe a company report card (earnings report) and how often it comes. | Jump$tart: Investing |
| 22 | Report cards | The grown-ups' guess (`guess`) | Explain that experts estimate profit per share before the report. | Jump$tart: Investing |
| 23 | Report cards | What does "beat" mean? (`beat`) | Decide beat or miss by comparing the result with the estimate. | Jump$tart: Investing |
| 24 | Report cards | Why prices jump on report day (`after`) | Explain why prices move fast on report day. | CEE Econ 7: Markets & prices |

### Big Moons (ages 9–11): builds on Little Moons

| # | Unit | Lesson | Objective (the kid can…) | Standards |
|---|---|---|---|---|
| 1 | Companies | How companies grow (`grow`) | Explain that companies can sell shares to raise money to grow. | Jump$tart: Investing |
| 2 | Shares and the market | Being an owner (`owner`) | Describe what being a part owner means, including that value can rise or fall. | Jump$tart: Investing |
| 3 | Shares and the market | Ticker nicknames (`ticker`) | Recognize a ticker as a company's short name on the market. | Jump$tart: Investing |
| 4 | Piggy Bank school | Time and ups and downs (`piggy-time`) | Explain why time can smooth out ups and downs, without a promise. | Jump$tart: Investing; OECD: Risk & reward |
| 5 | Saving and investing | Interest: a little extra (`interest`) | Describe interest as extra money a bank pays. | Jump$tart: Saving |
| 6 | Saving and investing | Risk: ups and downs (`risk`) | Sort choices by low and high risk. | Jump$tart: Managing Risk; OECD: Risk & reward |
| 7 | Saving and investing | The money snowball (`snowball`) | Explain why starting early helps growth pile up. | Jump$tart: Investing |
| 8 | Dividends | What is a dividend? (`dividend`) | Explain a dividend as profit shared with owners. | Jump$tart: Investing |
| 9 | Dividends | Why some don't pay (`no-dividend`) | Explain why some companies keep profit to grow. | Jump$tart: Investing |
| 10 | Dividends | Spend it or plant it? (`replant`) | Compare spending a dividend with reinvesting it. | Jump$tart: Investing |
| 11 | Dividends | Dividend day dip (`div-day`) | Explain why the price can drop by about the dividend on its cut-off day. | Jump$tart: Investing |
| 12 | Money-smart | Hype vs facts (`hype`) | Tell hype from facts and ask who is talking and why. | Jump$tart: Spending; OECD: Financial landscape |
| 13 | Report cards | Why a beat can still drop (`expectations`) | Explain why a price can fall on a beat (expectations). | CEE Econ 7: Markets & prices |
| 14 | Report cards | What comes next: guidance (`guidance`) | Explain guidance as a company's own guess about what comes next. | Jump$tart: Investing |
| 15 | Why did it move? | Normal wiggles (`why-wiggle`) | Compare a move with its normal size. | OECD: Risk & reward |
| 16 | Why did it move? | The whole market moves (`why-market`) | Use the whole market's move as a clue. | CEE Econ 7: Markets & prices |
| 17 | Why did it move? | Groups move together (`why-group`) | Use a group's (sector's) move as a clue. | CEE Econ 7: Markets & prices |
| 18 | Why did it move? | Sometimes we don't know (`why-unsure`) | Say "we're not sure" when there are no clues. | Jump$tart: Spending |
| 19 | Candles | What's a candle? (`candle`) | Read a candle's body and color. | Jump$tart: Investing |
| 20 | Candles | Wicks and colors (`wicks`) | Read a candle's high and low from its wicks. | Jump$tart: Investing |
| 21 | Candles | Tug-of-war days (`tug-of-war`) | Recognize a tug-of-war day (small body, long wicks). | Jump$tart: Investing |
| 22 | Trends | What's a trend? (`trend`) | Tell an up trend from a down trend. | Jump$tart: Investing |
| 23 | Trends | Sideways days (`sideways`) | Recognize a sideways trend, and that trends can change. | Jump$tart: Investing |
| 24 | Trends | Zoom out (`zoom-out`) | Zoom out instead of judging by one day. | CFPB: Executive function |
| 25 | Floors and ceilings | Floors and ceilings (`floor-ceiling`) | Find a floor (support) and a ceiling (resistance), and that they can break. | Jump$tart: Investing |
| 26 | Floors and ceilings | Breakouts (`breakout`) | Recognize a breakout and that many fail. | Jump$tart: Investing |
| 27 | Floors and ceilings | Looking back is easy (`hindsight`) | Explain why chart shapes look obvious only after the fact. | Jump$tart: Investing |
| 28 | Busy days and smooth lines | Volume (`volume`) | Explain volume as how many shares were traded. | Jump$tart: Investing |
| 29 | Busy days and smooth lines | The smooth line (`moving-average`) | Explain a moving average as a smooth, backward-looking line. | Jump$tart: Investing |
| 30 | Busy days and smooth lines | Report day on a chart (`report-jump`) | Explain why report day can bring big moves either way. | CEE Econ 7: Markets & prices |

### Map (Market World), in order

| Land | Stops |
|---|---|
| Lemonade Coast | Luna's Lemonade Stand → Money basics → Companies → Shares and the market → Piggy Bank school → Review stop → Captain's Quiz |
| Saver's Isle | Saving and investing → Save or Grow? → Dividends → Your Slice Pays You → Money-smart → Review stop → Island Quiz |
| Candle Canyon | What's a candle? → Build the candle → Wicks and colors → Read the day → Tug-of-war days → Candle match → Review stop → Chart Time Machine |
| Trend Trails | What's a trend? → Spot the trend → Sideways days → Draw the trendline → Zoom out → Review stop → Chart Time Machine |
| Pattern Peaks | Floors and ceilings → Find the floor → Breakouts → Pattern detective → Clues, not promises → Review stop → Chart Time Machine |
| Signal Sea | Volume → Busy day? → The smooth line → Smooth it out → Report-day jumps → Review stop → Chart Time Machine |
| Report Card Castle | Report cards → Guess the Report Card → Why did it move? → Review stop → Chart Time Machine |

### The Guess the Report Card course

The ladder is `report-card` → `guess` (estimates, per share, and their average) → `beat` → `after` (why report day jumps) → `expectations` (why a beat can still drop: "those hopes are in the price") → `guidance` (the company's own guess about next time).

On the Guess screen, a **Guess School** card offers the next lesson on the ladder, with a one-line tip.

After a reveal, the kid sees:
- the hedged coach line, e.g. "It beat the guess, but the price went down. People may have hoped for even more, or worried about what comes next";
- a matched-guess line (beat, in line or miss are judged with a 1% tolerance);
- a kind line for a wrong guess;
- the "Why did the price move?" card.

### The Pretend Piggy Bank course

The ladder is `piggy-start` (this piggy is different from a jar: pretend coins that follow real prices) → `piggy-spread` → `piggy-updown` → `piggy-peek` → `piggy-time` (Big Moons).
- **`piggy-spread`:** with 200 coins in each of 5 companies, one company halving costs 100 coins. With all 1,000 in it, the same drop costs 500.
- **`piggy-updown`:** a down day is like a rainy day.
- **`piggy-peek`:** don't check every minute.
- **`piggy-time`:** in the past, the US market went up in more years than down. That is history, not a promise.

The Piggy screen shows one coach tip (`Coach.piggyTip`). The priority order is:
1. too many peeks today
2. a big drop or rise (±10%)
3. one basket
4. a brand-new bank
5. an old bank
6. baskets

It also shows the next Piggy School lesson and a "Why did X move?" card for the biggest mover. The points-investing work builds on `Coach` and `Why`.

## How mastery is measured (on the device, nothing collected)

- **Item.** Every `check` step is a review item, `"<lesson>#<step>"`.
- **What gets recorded.** Only two things, both kept in `KidsState.review` (item → `"day|box"`; it syncs through the family's own iCloud like the rest of progress, and merges as a max per item):
  - a miss in a lesson (box 0);
  - each answer at a Review stop. A right answer moves the item up a box; a first spaced review starts at box 2. A wrong answer sends it back to box 0.
- **What is not recorded.** A right answer in a lesson records nothing.
- **When items come back.** Box *b* comes back after `review.intervals[b]` days (0, 1, 3, 7), and at `retireAt` (4) the item is learned. Lessons finished at least a day ago come back once even with no miss.
- **Unit mastery** (`Review.mastery`), one of four levels:
  - *Not started:* no lessons done.
  - *Learning:* some lessons done.
  - *Practicing:* all lessons done, but under the pass mark (80%, from the pack's `assessments`) of the unit's questions known. "Known" means never missed, or recovered to box 2 or higher.
  - *Mastered:* all lessons done and the pass mark reached.
- **Where grown-ups see it.** The grown-up corner shows "What your child is learning" for each unit, with its track, plus how many questions are waiting at a Review stop. It is worked out locally; nothing is sent anywhere.

## "Why did it move?"

The engine is metaphases `shared/kidsWhy.ts` and MoonClubCore `Why.swift`, pinned by the `why`, `whyBuild` and `reportResult` vectors. The worker route is `/api/kids/why?s=SYM&range=1d|5d`.

**Inputs.** All come from data we already use:
- Yahoo daily **raw** closes for the stock, SPY and its **equal-weight** sector fund (RSPT, RSPC, RSPD, RSPS), with dividend cut-off days;
- Nasdaq's report-card history;
- one Finnhub calendar call per company per day (cached 24 h), only for the report's session. That keeps us far inside the free 60/min.

**Measuring the move.** Every move is measured over the **same dates**. The move size is compared with the company's normal move, the mean absolute 1-day or 5-day move over about 3 months. The size bands are tiny below 0.5×, normal up to 1.5×, big up to 3×, and huge beyond that.

**Ranked clues:**
1. **Report card day:** beat, in line or miss (1% tolerance), each with a hedged line. A report counts only when its first trading reaction falls in the window: a before-the-open report counts on its own day, an after-the-close one on the next.
2. **The whole market moved:** this is weighted by how much of the move the market covers. If the market moved less than half as much: "…but not nearly this much".
3. **Not the whole market:** when the market went the other way, "this move was probably about Disney itself".
4. **Its group moved together:** only when the group moved more than the market.
5. **Dividend cut-off day:** only on drops, and weighted by the payout's % of the price.
6. **A normal wiggle:** only for small moves with no report.
7. **We're not sure:** for a big move the clues don't explain.

It never invents news. Every line is hedged ("may have"), and every card ends: *"These are clues from the numbers, not the whole story. Nobody knows for sure what comes next."*

**Time words** are always true: "today" (only if the last close was today), "on Friday", or "over the past week".

**Where it appears.** On the web (`src/pages/KidsWhy.tsx`): Story, the Guess reveal and the Piggy Bank. In the app (`WhyCard` in `Features/Curriculum.swift`): Story, the Guess reveal and the Piggy Bank. The app re-runs the engine on the inputs, so the words always come from the build the child has.

## What the experts caught

Here is a selection. The full notes are in metaphases `packs/*/reviews/`, across 3 rounds on Core and 2 on the Guest Pack and the engine.

**Accuracy (Dr. Okafor):**
- **Dividend cut-off day.** You must own the share *before* the cut-off day to get the payout.
- **Trend.** A trend is higher highs and higher lows, not "most days end higher". "Start = end" isn't sideways either.
- **Moving average.** An average is "add and divide", not "the middle".
- **Who gets the money.** Buying a share pays the *seller*, not the company.
- **Diversification.** Spreading out protects against one bad company, not a whole-market drop.
- **Estimates.** They are per share, and the number to beat is their average. Quarterly reporting is a US rule.
- **History.** "Up more years than down" holds for the US market, and it's history, not a promise.
- **Candles.** A green candle can close below yesterday, and in some countries red means up.
- **Why engine.**
  - A cap-weighted sector clue was circular: Apple and Microsoft are about 40% of XLK.
  - Report timing ignored before-the-open and after-the-close reports.
  - An exact match counted as a beat.
  - The market clue over-explained moves.
  - The dividend look-up could pick a close from 3 months earlier, and adjusted closes hide the dividend drop.
  - "Today" was false on weekends.

**Learning (Ms. Rivera):**
- **"Piggy bank" meant two opposite things.** It was both money that stays the same and money that follows prices. Saving now uses a jar.
- **"Share" meant two things.** It was both the name of the budget jar and a slice of a company. The jar is now called Give.
- **Giveaway checks.** Correct answers were often the longest option, and wrong options were often jokes. Now the distractors are real kid misconceptions ("The bank gives it out for free").
- **One idea per lesson, concrete before abstract.** The Piggy unit moved before the lessons that mention it.
- **"Brave".** "Brave" framed buying as brave; market weather is now "hopeful or worried".
- **Guest pack.** Coach Nova applies the no-advice rule to herself, and her pack is clearly disclosed as a made-up guest host.
- **App note:** candle colors need an up or down arrow for color-blind kids. *Open: the chart games still use color plus position.*

## Content tests (both repos)

**metaphases:**
- `tests/unit/kidsPacks.test.ts` checks every pack against the JSON Schema (ajv) and the validator:
  - reading level (each lesson ≤ 5 and ≤ 5.5 with questions; each glossary card ≤ 5);
  - card fit;
  - glyph coverage;
  - no links or handles;
  - banned advice and promotion phrases (allowed only in "quotes" or as a wrong answer);
  - ids, tracks and objectives;
  - courses, the map and sign-offs;
  - signatures.
- `tests/unit/kidsWhy.test.ts` covers the engine and the coach.

**MoonClubCore:**
- `CurriculumTests` checks the validator, composition, the Ed25519 signatures, the engine and the coach against the web's vectors. It also covers spaced review, mastery, the review merge and Review stops on the map.
- `CardFitTests` lays out every lesson step of Core plus every bundled pack at iPhone SE, 17, Duo and iPad sizes, and checks every pack glyph has art.

## References

1. Jump$tart Coalition & Council for Economic Education (2021). *National Standards for Personal Financial Education*. https://www.jumpstart.org/wp-content/uploads/2023/04/2021_Natl_Standards_Downloadable_final.pdf
2. Jump$tart Coalition. National Standards for Personal Financial Education. https://jumpstart.org/education/national-standards/
3. CFPB (2016). *Building blocks to help youth achieve financial capability*. https://files.consumerfinance.gov/f/documents/092016_cfpb_BuildingBlocksReport_ModelAndRecommendations_web.pdf
4. CFPB. Learn about the building blocks of financial capability. https://www.consumerfinance.gov/consumer-tools/educator-tools/youth-financial-education/learn/
5. OECD (2023). *PISA 2022 Assessment and Analytical Framework*, financial literacy (university-hosted copy). https://www.fisme.science.uu.nl/publicaties/literatuur/2023_PISA_2022_Assessment_and_Analytical_Framework-en.pdf
6. Council for Economic Education (2010). *Voluntary National Content Standards in Economics*, 2nd ed. https://www.councilforeconed.org/wp-content/uploads/2012/03/voluntary-national-content-standards-2010.pdf
7. Roediger & Karpicke (2006). Test-enhanced learning. *Psychological Science* 17(3). Abstract via Europe PMC.
8. Agarwal, Nunes & Blunt (2021). Retrieval practice consistently benefits student learning. http://www.retrievalpractice.org/strategies/2019/10/28/database-of-retrieval-practice-research
9. Cepeda et al. (2006). Distributed practice in verbal recall tasks. *Psychological Bulletin* 132(3). Via Europe PMC.
10. Cepeda et al. (2008). Spacing effects in learning: a temporal ridgeline. *Psychological Science* 19(11). Via Europe PMC.
11. Pashler et al. (2007). *Organizing Instruction and Study to Improve Student Learning* (IES). https://ies.ed.gov/ncee/wwc/PracticeGuide/1
12. Atkinson, Derry, Renkl & Wortham (2000). Learning from examples. *Review of Educational Research* 70(2). https://assess.ucr.edu/media/741/download
13. Bouck, Satsangi & Park (2018). The CRA approach for students with learning disabilities. https://eric.ed.gov/?id=EJ1185546
14. Rohrer & Taylor (2007). The shuffling of mathematics problems improves learning. https://www.Gwern.net/doc/psychology/spaced-repetition/2007-rohrer.pdf
15. Rohrer, Dedrick & Stershic (2015). Interleaved practice improves mathematics learning. https://www.Gwern.net/doc/psychology/spaced-repetition/2014-rohrer-2.pdf
16. Shute (2008). Focus on formative feedback. https://myweb.fsu.edu/vshute/pdf/shute%202008_b.pdf
17. Mueller & Dweck (1998). Praise for intelligence can undermine children's motivation and performance. Via Europe PMC.
18. Sisk et al. (2018). Growth mind-sets and academic achievement. https://englelab.gatech.edu/articles/2018/Sisk,%20Burgoyne%20et%20al.%20(2018)%20-%20Mindset%20and%20Academic%20Achievement.pdf
19. Yeager et al. (2019). A national experiment reveals where a growth mindset improves achievement. *Nature* 573. Via Europe PMC.
20. Clark, Tanner-Smith & Killingsworth (2016). Digital games, design, and learning. *Review of Educational Research* 86(1). Via Europe PMC.
21. Wouters et al. (2013). A meta-analysis of the cognitive and motivational effects of serious games. https://research-portal.uu.nl/en/publications/a-meta-analysis-of-the-cognitive-and-motivational-effects-of-seri/
22. Kaiser & Menkhoff (2017). Does financial education impact financial literacy and behavior? https://www.diw.de/de/diw_01.c.529477.de/publikationen/diskussionspapiere/2016_1562/does_financial_education_impact_financial_literacy_and_financial_behavior__and_if_so__when.html
23. Kaiser & Menkhoff (2020). Financial education in schools: a meta-analysis of experimental studies. https://www.diw.de/de/diw_01.c.701080.de/publikationen/externe_referierte_aufsaetze/2020_0000/financial_education_in_schools__a_meta-analysis_of_experimental_studies.html
24. Learning Point Associates (2010). *The Study of The Stock Market Game* (summary). https://www.sifma.org/wp-content/uploads/2017/05/education_sifma-foundation_learning-point-study-summary.pdf
25. Zendle & Cairns (2018). Video game loot boxes are linked to problem gambling. https://journals.plos.org/plosone/article?id=10.1371/journal.pone.0206767
26. Zendle, Meyer & Over (2019). Adolescents and loot boxes. *Royal Society Open Science* 6(6). Via Europe PMC.
27. UK Gambling Commission (2024). *Young People and Gambling 2024*. https://www.gamblingcommission.gov.uk/report/young-people-and-gambling-2024-official-statistics/ypg-2024-online-gambling-paying-for-and-betting-with-in-game-items-in-video
28. Benartzi & Thaler (1993/1995). Myopic loss aversion and the equity premium puzzle. https://www.nber.org/papers/w4369
29. Gneezy & Potters (1997). An experiment on risk taking and evaluation periods. https://Rady.ucsd.edu/_files/faculty-research/uri-gneezy/risk-taking.pdf
30. Harbaugh, Krause & Vesterlund (2001). Are children better behaved than adults? https://ideas.repec.org/p/isu/genres/1950.html

### Could not verify
- **OECD.** oecd.org returned 403, so we used a university-hosted copy of the same publication. The 2024/2025 PISA framework wasn't fetched.
- **PubMed and PMC** were blocked. Abstracts for [7][9][10][17][19][20][26] came from the Europe PMC API.
- **Yeager et al. 2019.** The full text wasn't fetched, so we cite no effect sizes from it.
- **Wouters et al. 2013.** The figures come from an abstract reproduced on a secondary page.
- **Stock Market Game [24].** Only the industry summary was read, not the full report.
- **Adults only.** Myopic loss aversion [28][29] was studied in adults. Applying it to children is our design inference.
