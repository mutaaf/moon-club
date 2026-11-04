# Moon Club curriculum

This is the research, the design principles and the scope and sequence behind Moon Club's lessons. It also covers how mastery is measured on the device. **0.15 (Core 3.0.0)** deepened it from 54 lessons in 13 units to **93 lessons in 20 units**. The new units are earning, saving goals, spending, borrowing, prices over time, baskets of companies and staying safe. They come from a gap analysis against the national standards (below). 0.15 also added worked examples, growth pictures, an optional challenge track, lesson refreshes and dinner-table talk for grown-ups. The lessons themselves live in the **Core lesson pack** (metaphases `packs/core/pack.json`; format in [PACKS.md](PACKS.md)). Two expert reviewers wrote and signed them off with us:

- **Ms. Rivera**, a veteran elementary teacher and reading specialist
- **Dr. Okafor**, a former equity analyst and finance educator

Both reviewers are AI personas, run as separate reviewing agents. A human still signs the checklist in PACKS.md before any pack goes on the remote channel.

The rules for kids content haven't changed:
- pretend money only, and never advice;
- patterns are clues, not promises;
- reading at grade 5 or below, checked by `fkGrade` in tests;
- no links out (except behind the parental gate), and no ads, analytics or SDKs;
- no emoji drawn as pictures;
- every lesson step fits one card on iPhone SE and on iPhone 17, with no scrolling, including the new worked-example and grow steps.

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
- **Every grade-4 benchmark**, by topic (verbatim excerpts, fetched Nov 2026) [1]. These drove the 0.15 gap analysis.
  - **Earning Income.**
    - 4-1: "People have different job choices depending on their knowledge, skills, interests, and experience."
    - 4-2: income can improve with "new knowledge, skills, and experience".
    - 4-3: "wages, salaries, commissions, and tips".
    - 4-4: "starting a new business as an entrepreneur"; 4-4c: "Estimate how much income could be earned from a business operated by children (such as a lawn service or lemonade stand)".
    - 4-5: "lending money or by renting their property".
    - 4-6: "gifts or as an allowance".
    - 4-7: "Most income is taxed by the government to pay for government-provided goods and services."
  - **Spending.**
    - 4-1: preferences and priorities.
    - 4-2: money can increase "another individual's personal satisfaction" or "share the cost of goods and services".
    - 4-3: opportunity cost.
    - 4-4: costs and benefits.
    - 4-5: "Price, spending choices of others, peer pressure, and advertising"; 4-5c: "Identify reliable sources of information".
    - 4-6: "cash, checks, debit cards, and credit cards"; 4-6b: "Compare the effects of using debit versus credit cards".
  - **Saving.**
    - 4-1: "choosing not to spend money today to be able to buy something in the future"; 4-1a: "Explain why it is often harder to save than to spend money"; 4-1c: ads "designed to influence people to spend money right away".
    - 4-2: "A savings plan is a plan for setting aside money to pay for a future need, goal, or emergency."
    - 4-4: "Safety and ease of access"; 4-4a: "advantages of saving money in an account at a financial institution rather than keeping the money at home".
    - 4-5: "Financial institutions often pay interest on deposit accounts to attract customers".
  - **Investing.** 4-1 and 4-2, quoted above.
  - **Managing Credit.**
    - 4-1: "Interest is the price a borrower pays for using someone else's money, and the income earned by the lender"; 4-1a: "Explain why a person who borrows $100 … often must pay back more than $100".
    - 4-2: buying with credit means "agreeing to repay the lender in the future with interest".
    - 4-3: lenders favor borrowers "who have a history of paying back loans as promised".
  - **Managing Risk.**
    - 4-1: "Risk is an unavoidable part of daily life."
    - 4-2: people "try to reduce or avoid the negative consequences".
    - 4-3: "save for emergencies".
    - 4-4: "Insurance is often purchased to limit financial losses due to risk."
- **What waits until grade 8 or 12** [1]:
  - **Grade 8:** compound vs simple interest (Saving 8-5) and the Rule of 72 (Saving 8-4c), funds and diversification (Investing 8-5), deposit insurance (Saving 8-6), credit card rates and the cost of a long loan (Managing Credit 8-3, 8-4), insurance premiums (Managing Risk 8-2) and identity theft (Managing Risk 8-7).
  - **Grade 12:** inflation eroding savings (Saving 12-4), fees, expense ratios and index funds (Investing 12-7), charitable giving (Spending 12-7) and online scams (Spending 12-8c).
  - **Our approach.** We teach these as enrichment: in Big Moons when the idea needs no percent, and in the **Full Moons challenge** when it does.

**CEE National Standards for Financial Literacy (2013)** [31], grade 4 benchmarks
- These match Jump$tart, with a few useful extra phrasings:
  - "People can earn interest income from letting other people borrow their money" (I.4).
  - "Entrepreneurs … do not know if their new businesses will be successful" (I.7).
  - "People set savings goals as incentives to save" (III.4).
  - "banks are safe places to keep their savings" (III.6).
  - "A reputation for not repaying a loan as promised can result in higher interest charges" (IV.4).
  - "Individuals can either choose to accept risk or take steps to protect themselves by avoiding or reducing risk" (VI.3).

**CEE Voluntary National Content Standards in Economics (2010)** [6], grade 4 benchmarks
- Standard 7: "A price is what people pay when they buy a good or service".
- Standard 11: "Money makes trading easier by replacing barter".
- Standard 14: entrepreneurs "take risks, to develop new products, and start new businesses".
- Supply and demand schedules start at grade 8.
- Standard 11.5, the only grade-4 benchmark on inflation: "Inflation is an increase in most prices; deflation is a decrease in most prices." That is why `prices-rise` is a Big Moons lesson, not a challenge one.
- Standard 16, grade 4: "Governments pay for the goods and services they use or provide by taxing or borrowing."
- Standard 12 (interest rates) has **no** grade-4 benchmark.

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
- **Milestone questions** for middle childhood (Table 6):
  - "Does the child show the ability to plan ahead and delay gratification?"
  - "Does the child begin to show a positive attitude toward savings, frugality, planning, and self-control?"
  - "Can the child make spending and saving decisions aligned with his or her goals and values?"
  - "Does the child understand core basic financial processes and concepts?"
- **Money as You Grow** (CFPB, ages 6–12) [32] lists what to say:
  - "You can earn money through an allowance or by doing jobs…"
  - "Try shopping around and comparing prices…"
  - "Taking out a loan means you pay back what you borrow, plus more—because of charges called interest."
  - "You need to keep important personal information private."
  - Each one has a lesson now (`gifts`, `compare`, `owe-interest`, `private`).
- **Grown-ups as the main teachers.** Habits and norms form at home, so every unit now ends in **dinner table talk** for the grown-up (below), not just more app time.

### How children learn money ideas (new in 0.15)

- **Delay of gratification.**
  - In the large replication of the marshmallow test (900+ children), the link between waiting and later achievement was small. It "disappeared after the researchers controlled for characteristics of the child's family" [33].
  - So `wait` teaches *strategies*: put the money out of sight, draw the goal, count how close you are. It never tells a child that waiting predicts success.
- **Exponential growth bias.**
  - Adults reason about compounding as if it were linear. They underestimate loan costs and how much savings grow, and the more biased borrow more and save less [34].
  - This is an adult finding; applying it to children is our inference.
  - The new `grow` step shows compound growth next to simple growth ("the same $10 a year") year by year, so the gap is something a child *sees* grow. It is also used for money owed.
- **Banking concepts are hard but teachable.**
  - Children's ideas about banks, loans and interest come late, "even for adolescents".
  - Yet a 10-unit curriculum on banking and shop profit brought most fourth graders to full understanding, and they still had it 8 months later [35].
  - So we teach both directions of interest: `interest` (saving) and `owe-interest` (borrowing), with `lender` explaining why banks pay interest at all.

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

## Gap analysis and coverage (0.15)

We checked Core 2.0.0 against every grade-4 Jump$tart benchmark [1], the CEE financial-literacy [31] and economics [6] benchmarks, and the CFPB building blocks and milestones [3][32]. We didn't assume the gaps; this is what we found:

| Area | Before (Core 2.0.0) | After (Core 3.0.0) |
|---|---|---|
| Earning income (J$ EI 4-1…4-7) | One lesson (`earn`): "grown-ups work" | **Earning money** unit: jobs and skills, wages/salary/tips with hours × pay, starting a business (a kid's lemonade-stand profit, EI 4-4c), taxes paying for shared things (EI 4-7), allowance and gifts (EI 4-6). Lending income lives in `lender` (EI 4-5). |
| Needs and wants | `needs` sort | Unchanged (it met the benchmark) |
| Saving goals, delay of gratification (J$ Saving 4-1, 4-2; CFPB "plan ahead and delay gratification") | Budget jars only | **Saving goals** unit: pick a goal and a weekly plan (worked example), waiting strategies, why saving is hard, a rainy-day fund, a bank vs a jar (with deposit insurance) |
| Spending choices, opportunity cost (J$ Spending 4-3…4-6) | `choose` (trade-off) | **Smart spending** unit: compare prices, ads and peer pressure, cash/debit/credit, game coins cost real money, giving; plus `borrow` |
| Giving and sharing (J$ Spending 4-2, 12-7) | A "Give" jar named in `budget` | `give`: money, things or time |
| Borrowing and interest, both ways (J$ Credit 4-1…4-3, 8-3, 8-4) | Interest earned only (`interest`) | **Borrowing and interest** unit: interest as the price of borrowing (worked example), why lenders lend and trust, credit cards (challenge), debt growing (challenge, grow step) |
| Compound growth (J$ Saving 8-4, 8-5; Investing 8-7) | `snowball` in words | `compound`: a grow step, compound vs simple, tied to the Moon Garden; `double`: the Rule of 72 (challenge). Garden School ladder on the Moon Garden. |
| Inflation (CEE Econ 11.5; J$ Saving 12-4) | One sentence in `interest` | **Prices over time** unit: prices creep up (grow), what money can buy, can savings keep up (challenge, grow vs rate) |
| What a company is, owning a slice | `company`, `share`, `owner` | Unchanged; plus `per-share` (profit for each share), which links slices to what experts estimate |
| Earnings reports and why prices jump (Metaphases' calendar) | 6 lessons | + `calendar` (report dates, before the open / after the close, after hours), `per-share`, `sales-profit`, `surprise` (challenge). Guess ladder 6 → 10 steps. |
| Dividends | 4 lessons | + `div-yield` (challenge: payout per $100, and that it can be cut) |
| Funds and index funds as "a basket" (J$ Investing 8-5, 12-7) | Glossary word only | **Baskets of companies** unit: a fund, spreading across groups, fees (grow step), index funds (challenge) |
| Risk and spreading out | `baskets`, `piggy-spread`, `risk` | + `spread-groups` (sectors move together; its limit in a market drop) and a Piggy tip when every company is in one group |
| Scams, "too good to be true", privacy (J$ Risk 8-7; Spending 12-8c) | `too-good`, `hype` | **Staying safe** unit: keep info private, "free gems" scams, scam red flags; plus risk in daily life and insurance (J$ Risk 4-1…4-4) |
| Fees (J$ Investing 12-7) | None | `fees` (challenge) |
| Retrieval and spacing | Review stops (missed questions return) | + **Luna's refresh**: a lesson forgotten later returns *as a whole lesson* to replay |
| Worked examples, CRA [11][12][13] | Say cards only | + `example` steps (11) and `grow` steps (6) |
| Grown-up involvement (CFPB: habits form at home) [3] | 4 general conversation starters | 1–3 **dinner table talk** prompts in every unit |

**Coverage by Jump$tart topic (grade 4 benchmarks with at least one lesson):**

| Topic | Grade-4 benchmarks | Covered before | Covered now |
|---|---|---|---|
| Earning Income | 7 | 1 (4-1, partly) | 7 |
| Spending | 6 | 2 (4-3, 4-5 partly) | 6 |
| Saving | 5 | 2 (4-1 partly, 4-5) | 4, plus 4-3 ("people differ in values and attitudes about saving") in dinner table talk only |
| Investing | 2 | 2 | 2 |
| Managing Credit | 3 | 0 | 3 |
| Managing Risk | 4 | 1 (4-2 partly, via spreading out) | 4 |

"Covered" means a lesson whose objective cites the benchmark and that has a quiz on it. The "before" column is our reading of the 2.0.0 lessons, whose objectives cited topics but not benchmark codes; objectives and their standards are in the pack (`objectives[].standards`). The pack test `fills the gaps against the grade-4 standards` fails if a Jump$tart topic, Managing Credit 4-1, Managing Risk 4-4, Earning Income 4-7, Saving 4-2, Spending 4-6 or CEE Econ 11.5 loses its last lesson.

**Is a third, harder tier warranted? Yes, as an optional challenge.**
- **What it is.** Full Moons (track `challenge`, 8 lessons) holds the ideas that need percents or multi-step money math: credit cards, debt growth, savings vs inflation, index funds, fees, the Rule of 72, beat size and dividend yield.
- **Why it's separate.** Percent is grade-6 math, and these are Jump$tart grade 8 and 12 benchmarks. Reading stays at grade 5 or below; it's the math that makes them harder.
- **No ages in the name.** The track title has no age: Ms. Rivera warned that age labels can shame a struggling 11-year-old or hold back a strong 9-year-old.
- **Always optional.** The pack marks the track `optional: true`, so these lessons never gate map stars, unit mastery or a land's boss quiz. They join a boss quiz only after the child has played them. They come last in each unit and are tagged "Challenge".

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
| 12 | **Games supplement teaching; bring in the grown-up** [3][21][22] | Lessons, games and quests run in short sessions. The grown-up corner shows what the child is learning, with **dinner table talk** for every unit and printable worksheets on the web. |
| 13 | **Worked example, then practice** [11][12] | `example` steps: the setup, then 2–4 lines of working the child reveals with a tap ("Let's work it out"), then a matched check. Little Moons examples use counting and adding only, never × or ÷. |
| 14 | **Concrete → pictures → numbers** [13] | `grow` steps draw growth year by year as the child taps: a Moon Garden plant for savings, a price tag for inflation, an IOU for money owed, with a faint comparison row (a jar, the same extra each year, or another rate). This is the pictorial step between the snowball story and the Rule of 72. |
| 15 | **Show compounding, don't just say it** [34] | Compound vs simple, debt vs what was borrowed, and fees side by side, on the same picture. |
| 16 | **Re-study after a failed retrieval** [7][11] | **Luna's refresh** brings a whole lesson back when its question was missed *after* it was learned (at a Review stop or a later replay), or when most of it was missed the day it was played. Replaying clears it. |
| 17 | **Challenge without labels or gates** | The Full Moons track is optional and never blocks progress (see the gap analysis above). |
| 18 | **Never take away what a child earned** | A unit that grows keeps the stars a child had. Lessons added later (`since`) count as a bonus. A stop with stars never locks again when new stops appear before it. The rocket stays in the first land not yet conquered. |

## Scope and sequence

There are 93 lessons in 20 units, generated from `packs/core/pack.json` (the tables below are generated from it too). 39 lessons are new in 0.15 (marked **new**). Every lesson takes about a minute and has 3–7 steps; 11 worked examples and 6 growth pictures are spread through them.

**Tracks:**
- **Little Moons (6–8)** lessons are for everyone.
- **Big Moons (9–11)** lessons build on them.
- **Full Moons (challenge)** is optional, for any age that wants percents and fees.

**Unit order:** Money basics → Earning money → Saving goals → Smart spending → Staying safe with money → Companies → Shares and the market → Piggy Bank school → Saving and investing → Prices over time → Borrowing and interest → Dividends → Baskets of companies → Money-smart → Report cards → Why did it move? → Candles → Trends → Floors and ceilings → Busy days and smooth lines.
- **Why this order.** Earning, goals, spending and staying safe come right after money basics, so Little Moons meet them before companies. Prices over time and borrowing come right after saving and investing, so interest is taught both ways back to back. Baskets of companies follows dividends.

### Little Moons (ages 6–8): everyone starts here

| # | Unit | Lesson | Objective (the kid can…) | Standards |
|---|---|---|---|---|
| 1 | Money basics | What is money? (`money`) | Explain why people use money instead of trading things. | Jump$tart: Saving; CEE Econ 11: Money |
| 2 | Money basics | Where does money come from? (`earn`) | Say that most people earn money by working. | Jump$tart: Earning Income; CEE FinLit I.2 |
| 3 | Money basics | Needs and wants (`needs`) | Sort needs from wants. | Jump$tart: Saving; CFPB: Habits & norms; J$ Spending 4-1 |
| 4 | Money basics | Make a money plan (`budget`) | Describe a budget as a plan made before spending. | Jump$tart: Saving; CFPB: Executive function; CEE FinLit II.7 |
| 5 | Money basics | Every choice has a trade-off (`choose`) | Name what you give up when you choose (a trade-off). | Jump$tart: Spending; CEE Econ 1: Scarcity; J$ Spending 4-3; J$ Spending 4-4; CEE Econ 1.5 |
| 6 | Earning money | Jobs and skills (`jobs`) **new** | List jobs and the skills they need, and how new skills can raise pay. | J$ Earning Income 4-1; J$ Earning Income 4-2; CEE FinLit I.1; CEE Econ 1.10 |
| 7 | Earning money | Allowance and gifts (`gifts`) **new** | Name gifts and allowance as income that may need no work, and plan it too. | J$ Earning Income 4-6; CEE FinLit I.8 |
| 8 | Earning money | Start a business (`boss`) **new** · worked example | Explain that an entrepreneur starts a business, takes a risk, and earns a profit only if money in is more than money out. | J$ Earning Income 4-4; CEE FinLit I.6; CEE FinLit I.7; CEE Econ 14.1 |
| 9 | Saving goals | Pick a saving goal (`goal`) **new** · worked example | Make a savings plan: a goal, an amount each week, and how many weeks. | J$ Saving 4-2; CEE FinLit III.4; CEE FinLit III.5; CFPB: Executive function |
| 10 | Saving goals | Wait for it (`wait`) **new** | Use simple tricks to wait for something better later (delay gratification). | J$ Saving 4-1; CFPB: Executive function; CFPB: Habits & norms |
| 11 | Saving goals | Where to keep savings (`bank-safe`) **new** | Compare keeping savings at home with a bank or credit union (safe, tracked, may pay interest). | J$ Saving 4-4; J$ Saving 4-5; CEE FinLit III.3; CEE FinLit III.6 |
| 12 | Smart spending | Compare before you buy (`compare`) **new** · worked example | Compare prices for the same thing before buying. | J$ Spending 4-5; CEE FinLit II.5; CFPB: Money as You Grow |
| 13 | Smart spending | Game coins cost real money (`in-game`) **new** | Know that game coins and gems are often bought with real money, and ask a grown-up first. | J$ Spending 4-5; CFPB: Habits & norms |
| 14 | Smart spending | Giving and sharing (`give`) **new** | Describe giving money, things or time to help others. | J$ Spending 4-2; J$ Spending 12-7 |
| 15 | Smart spending | Borrowing means paying back (`borrow`) **new** | Explain that borrowed money or things must be paid back. | J$ Managing Credit 4-2; CEE FinLit IV.2 |
| 16 | Staying safe with money | Risk is everywhere (`risk-life`) **new** | Give examples of risk and ways to make it smaller. | J$ Managing Risk 4-1; J$ Managing Risk 4-2; CEE FinLit VI.1; CEE FinLit VI.3 |
| 17 | Staying safe with money | Keep your info private (`private`) **new** | Keep passwords, codes and addresses private. | J$ Managing Risk 8-7; CFPB: Money as You Grow |
| 18 | Staying safe with money | Free gems? It's a trick (`free-gems`) **new** | Spot scam red flags (rushing, secrets, prizes you pay for) and tell a grown-up. | J$ Spending 12-8; J$ Managing Risk 8-7 |
| 19 | Companies | What is a company? (`company`) | Describe a company as a team that sells goods or services. | CEE Econ 14: Entrepreneurship |
| 20 | Companies | Money in, money out (`profit`) | Work out profit as money in minus money out. | CEE Econ 14: Entrepreneurship |
| 21 | Shares and the market | What is a share? (`share`) | Explain that a share is a small piece of a company. | Jump$tart: Investing |
| 22 | Shares and the market | The stock market (`market`) | Say where shares are traded. | Jump$tart: Investing; OECD: Financial landscape |
| 23 | Shares and the market | Why do prices go up and down? (`prices`) | Explain that prices move when buyers or sellers are more eager. | CEE Econ 7: Markets & prices; CEE Econ 8: Role of prices |
| 24 | Piggy Bank school | Your pretend piggy bank (`piggy-start`) | Say that Piggy Bank coins are pretend and follow real prices. | CFPB: Habits & norms |
| 25 | Piggy Bank school | Spread your coins (`piggy-spread`) | Work out how spreading coins limits the hurt from one company. | Jump$tart: Managing Risk |
| 26 | Piggy Bank school | Ups and downs are normal (`piggy-updown`) | Treat a down day as normal, not a mistake. | CFPB: Executive function |
| 27 | Piggy Bank school | Don't peek every minute (`piggy-peek`) | Choose to check now and then instead of every minute. | CFPB: Executive function; CFPB: Habits & norms |
| 28 | Saving and investing | Saving vs investing (`saving`) | Tell saving (stays the same) from investing (can grow or shrink). | Jump$tart: Saving; Jump$tart: Investing; J$ Investing 4-2 |
| 29 | Saving and investing | Save it or invest it? (`which`) | Choose saving for soon and investing for a long time away. | Jump$tart: Investing; OECD: Planning & managing finances; J$ Investing 4-1; J$ Investing 4-2 |
| 30 | Money-smart | Don't put all your eggs in one basket (`baskets`) | Explain why spreading money across many companies lowers the risk from any one company. | Jump$tart: Managing Risk; OECD: Risk & reward; J$ Investing 8-5 |
| 31 | Money-smart | Be patient like the moon (`patience`) | Explain why long-term investors don't react to one bad day. | Jump$tart: Investing; CFPB: Executive function |
| 32 | Money-smart | Too good to be true (`too-good`) | Spot a too-good-to-be-true promise and ask a grown-up. | Jump$tart: Managing Risk; Jump$tart: Spending; J$ Spending 12-8 |
| 33 | Money-smart | Clues, not promises (`clues`) | Treat chart shapes as clues, never promises. | Jump$tart: Spending |
| 34 | Report cards | What is a report card? (`report-card`) | Describe a company report card (earnings report) and how often it comes. | Jump$tart: Investing |
| 35 | Report cards | The report card calendar (`calendar`) **new** | Explain that report dates are set ahead, and when the price can react (before the open or after the close). | CEE Econ 7.2; Enrichment: earnings reports |
| 36 | Report cards | The grown-ups' guess (`guess`) | Explain that experts estimate profit per share before the report. | Jump$tart: Investing |
| 37 | Report cards | What does "beat" mean? (`beat`) | Decide beat or miss by comparing the result with the estimate. | Jump$tart: Investing |
| 38 | Report cards | Why prices jump on report day (`after`) | Explain why prices move fast on report day. | CEE Econ 7: Markets & prices |

### Big Moons (ages 9–11): builds on Little Moons

| # | Unit | Lesson | Objective (the kid can…) | Standards |
|---|---|---|---|---|
| 1 | Earning money | Ways to get paid (`paid`) **new** · worked example | Tell wages, salaries and tips apart, and work out pay for hours worked. | J$ Earning Income 4-3; CEE FinLit I.3 |
| 2 | Earning money | Taxes pay for what we share (`taxes`) **new** | Explain that taxes come out of income and pay for things a community shares. | J$ Earning Income 4-7; J$ Spending 4-2; CEE FinLit I.9; CEE Econ 16.2 |
| 3 | Saving goals | Why saving is hard (`hard-save`) **new** | Explain why saving is often harder than spending, and how ads push spending now. | J$ Saving 4-1; CEE FinLit III.2 |
| 4 | Saving goals | A rainy day fund (`rainy-day`) **new** | Explain an emergency (rainy day) fund. | J$ Saving 4-2; J$ Managing Risk 4-3; CEE FinLit VI.4 |
| 5 | Smart spending | Ads and friends (`ads`) **new** | Spot how ads and friends push us to buy, and find reliable facts. | J$ Spending 4-5; CEE FinLit II.6 |
| 6 | Smart spending | Cash, debit and credit (`pay-ways`) **new** | Tell cash, debit cards and credit cards apart. | J$ Spending 4-6; CEE FinLit IV.2 |
| 7 | Staying safe with money | Scam red flags (`scam-signs`) **new** | Spot scam red flags (rushing, secrets, prizes you pay for) and tell a grown-up. | J$ Spending 12-8; J$ Managing Risk 8-7 |
| 8 | Staying safe with money | Insurance shares the risk (`insurance`) **new** | Explain insurance as many people paying a little so one person isn't hurt a lot. | J$ Managing Risk 4-4; J$ Managing Risk 8-2 |
| 9 | Companies | How companies grow (`grow`) | Explain that companies can sell shares to raise money to grow. | Jump$tart: Investing |
| 10 | Shares and the market | Being an owner (`owner`) | Describe what being a part owner means, including that value can rise or fall. | Jump$tart: Investing |
| 11 | Shares and the market | Ticker nicknames (`ticker`) | Recognize a ticker as a company's short name on the market. | Jump$tart: Investing |
| 12 | Piggy Bank school | Time and ups and downs (`piggy-time`) | Explain why time can smooth out ups and downs, without a promise. | Jump$tart: Investing; OECD: Risk & reward |
| 13 | Saving and investing | Interest: a little extra (`interest`) | Describe interest as extra money a bank pays. | Jump$tart: Saving; J$ Saving 4-5 |
| 14 | Saving and investing | Risk: ups and downs (`risk`) | Sort choices by low and high risk. | Jump$tart: Managing Risk; OECD: Risk & reward |
| 15 | Saving and investing | The money snowball (`snowball`) | Explain why starting early helps growth pile up. | Jump$tart: Investing; J$ Investing 8-7 |
| 16 | Saving and investing | Growth on growth (`compound`) **new** · grow | Compare growth on growth (compound) with the same extra each year (simple). | J$ Saving 8-5; J$ Investing 8-7 |
| 17 | Prices over time | Prices creep up (`prices-rise`) **new** · grow | Define inflation as most prices going up over time. | CEE Econ 11.5 |
| 18 | Prices over time | What money can buy (`buy-less`) **new** · worked example | Explain that money kept the same buys less when prices rise. | CEE Econ 11.3; J$ Saving 12-4 |
| 19 | Borrowing and interest | Interest when you borrow (`owe-interest`) **new** · worked example | Explain interest as the price of borrowing, so a borrower pays back more. | J$ Managing Credit 4-1; CEE FinLit IV.1; CFPB: Money as You Grow |
| 20 | Borrowing and interest | Why lenders lend (`lender`) **new** | Explain why lenders lend (they earn interest) and why paying back on time builds trust. | J$ Managing Credit 4-1; J$ Managing Credit 4-3; J$ Earning Income 4-5; CEE FinLit I.4; CEE FinLit IV.4 |
| 21 | Dividends | What is a dividend? (`dividend`) | Explain a dividend as profit shared with owners. | Jump$tart: Investing |
| 22 | Dividends | Why some don't pay (`no-dividend`) | Explain why some companies keep profit to grow. | Jump$tart: Investing |
| 23 | Dividends | Spend it or plant it? (`replant`) | Compare spending a dividend with reinvesting it. | Jump$tart: Investing |
| 24 | Dividends | Dividend day dip (`div-day`) | Explain why the price can drop by about the dividend on its cut-off day. | Jump$tart: Investing |
| 25 | Baskets of companies | Spread across groups (`spread-groups`) **new** | Explain spreading across groups, since companies in one group often move together. | J$ Investing 8-5; J$ Managing Risk 4-2 |
| 26 | Baskets of companies | A fund is a basket (`fund`) **new** | Describe a fund as a basket holding many companies. | J$ Investing 8-5 |
| 27 | Money-smart | Hype vs facts (`hype`) | Tell hype from facts and ask who is talking and why. | Jump$tart: Spending; OECD: Financial landscape |
| 28 | Report cards | Profit for each share (`per-share`) **new** · worked example | Work out profit for each share (earnings per share). | CEE FinLit I.6; Enrichment: earnings reports |
| 29 | Report cards | Sales vs profit (`sales-profit`) **new** · worked example | Tell sales (revenue) from profit, and why more sales can still mean less profit. | CEE FinLit I.6; CEE Econ 14.1; Enrichment: earnings reports |
| 30 | Report cards | Why a beat can still drop (`expectations`) | Explain why a price can fall on a beat (expectations). | CEE Econ 7: Markets & prices |
| 31 | Report cards | What comes next: guidance (`guidance`) | Explain guidance as a company's own guess about what comes next. | Jump$tart: Investing |
| 32 | Why did it move? | Normal wiggles (`why-wiggle`) | Compare a move with its normal size. | OECD: Risk & reward |
| 33 | Why did it move? | The whole market moves (`why-market`) | Use the whole market's move as a clue. | CEE Econ 7: Markets & prices |
| 34 | Why did it move? | Groups move together (`why-group`) | Use a group's (sector's) move as a clue. | CEE Econ 7: Markets & prices |
| 35 | Why did it move? | Sometimes we don't know (`why-unsure`) | Say "we're not sure" when there are no clues. | Jump$tart: Spending |
| 36 | Candles | What's a candle? (`candle`) | Read a candle's body and color. | Jump$tart: Investing |
| 37 | Candles | Wicks and colors (`wicks`) | Read a candle's high and low from its wicks. | Jump$tart: Investing |
| 38 | Candles | Tug-of-war days (`tug-of-war`) | Recognize a tug-of-war day (small body, long wicks). | Jump$tart: Investing |
| 39 | Trends | What's a trend? (`trend`) | Tell an up trend from a down trend. | Jump$tart: Investing |
| 40 | Trends | Sideways days (`sideways`) | Recognize a sideways trend, and that trends can change. | Jump$tart: Investing |
| 41 | Trends | Zoom out (`zoom-out`) | Zoom out instead of judging by one day. | CFPB: Executive function |
| 42 | Floors and ceilings | Floors and ceilings (`floor-ceiling`) | Find a floor (support) and a ceiling (resistance), and that they can break. | Jump$tart: Investing |
| 43 | Floors and ceilings | Breakouts (`breakout`) | Recognize a breakout and that many fail. | Jump$tart: Investing |
| 44 | Floors and ceilings | Looking back is easy (`hindsight`) | Explain why chart shapes look obvious only after the fact. | Jump$tart: Investing |
| 45 | Busy days and smooth lines | Volume (`volume`) | Explain volume as how many shares were traded. | Jump$tart: Investing |
| 46 | Busy days and smooth lines | The smooth line (`moving-average`) | Explain a moving average as a smooth, backward-looking line. | Jump$tart: Investing |
| 47 | Busy days and smooth lines | Report day on a chart (`report-jump`) | Explain why report day can bring big moves either way. | CEE Econ 7: Markets & prices |

### Full Moons (challenge): optional, any age

| # | Unit | Lesson | Objective (the kid can…) | Standards |
|---|---|---|---|---|
| 1 | Saving and investing | How long to double? (`double`) **new** · worked example, grow | Use the Rule of 72 to guess how long growth takes to double. | J$ Saving 8-4 |
| 2 | Prices over time | Can savings keep up? (`beat-prices`) **new** · grow | Compare a savings rate with rising prices. | J$ Saving 12-4; J$ Investing 12-4 |
| 3 | Borrowing and interest | How credit cards work (`credit-card`) **new** | Explain that a credit card is a loan, and when it usually costs no interest. | J$ Managing Credit 8-4; J$ Spending 4-6 |
| 4 | Borrowing and interest | When owing grows (`debt-snowball`) **new** · grow | Show how unpaid debt grows with interest on interest. | J$ Managing Credit 8-3; J$ Managing Credit 8-7 |
| 5 | Dividends | How big is the payout? (`div-yield`) **new** · worked example | Compare dividends as dollars paid for each $100 of share price, and know they can be cut. | J$ Investing 8-5; Enrichment: dividends |
| 6 | Baskets of companies | Fees nibble (`fees`) **new** · grow | Show how a yearly fee lowers what you end up with. | J$ Investing 12-7 |
| 7 | Baskets of companies | Index funds follow a list (`index`) **new** | Explain an index fund as buying every company on a list, often with low fees. | J$ Investing 8-5; J$ Investing 12-7 |
| 8 | Report cards | How big was the surprise? (`surprise`) **new** · worked example | Judge the size of a beat or miss compared with the guess. | CEE Econ 7.1; Enrichment: earnings reports |

### Map (Market World), in order

| Land | Stops |
|---|---|
| Lemonade Coast | Luna's Lemonade Stand → Money basics → Earning money → Saving goals → Smart spending → Staying safe → Companies → Shares and the market → Piggy Bank school → Review stop → Captain's Quiz |
| Saver's Isle | Saving and investing → Save or Grow? → Prices over time → Borrowing and interest → Dividends → Your Slice Pays You → Baskets of companies → Money-smart → Review stop → Island Quiz |
| Candle Canyon | What's a candle? → Build the candle → Wicks and colors → Read the day → Tug-of-war days → Candle match → Review stop → Chart Time Machine |
| Trend Trails | What's a trend? → Spot the trend → Sideways days → Draw the trendline → Zoom out → Review stop → Chart Time Machine |
| Pattern Peaks | Floors and ceilings → Find the floor → Breakouts → Pattern detective → Clues, not promises → Review stop → Chart Time Machine |
| Signal Sea | Volume → Busy day? → The smooth line → Smooth it out → Report-day jumps → Review stop → Chart Time Machine |
| Report Card Castle | Report cards → Guess the Report Card → Why did it move? → Review stop → Chart Time Machine |

- **New units become new map stops** on Lemonade Coast (Earning money, Saving goals, Smart spending, Staying safe) and Saver's Isle (Prices over time, Borrowing and interest, Baskets of companies).
- **Why inside existing lands.** A new land in the middle would have locked every later land for children who had already passed it, so we added stops to lands they already have.

### The Guess the Report Card course

The ladder has 10 steps:
1. `report-card`
2. `calendar`: report dates are set ahead (this is Metaphases' earnings calendar), and a report before the open or after the close moves the price the next time the market is open.
3. `guess`: estimates, per share, and their average.
4. `beat`
5. `after`: why report day jumps.
6. `per-share`: profit split across shares, the number experts estimate.
7. `sales-profit`: sold more, kept less.
8. `expectations`: why a beat can still drop ("those hopes are in the price").
9. `guidance`: the company's own guess about next time.
10. `surprise` (challenge): the size of a beat.

On the Guess screen, a **Guess School** card offers the next lesson on the ladder, with a one-line tip.

After a reveal, the kid sees:
- the hedged coach line, e.g. "It beat the guess, but the price went down. People may have hoped for even more, or worried about what comes next";
- a matched-guess line (beat, in line or miss are judged with a 1% tolerance);
- a kind line for a wrong guess;
- **Learn why** (0.15): the pack's `guess.learn` maps each reveal to the lesson that explains it, and the reveal shows a button that plays it in place:
  - a beat that dropped, or a miss that rose → `expectations`;
  - in line → `guidance`;
  - a beat up or a miss down → `after`;
  - not reported yet → `calendar`.
- the "Why did the price move?" card.

### The Pretend Piggy Bank course

The ladder is `piggy-start` (this piggy is different from a jar: pretend coins that follow real prices) → `piggy-spread` → `piggy-updown` → `piggy-peek` → `piggy-time` (Big Moons) → `spread-groups` (0.15: companies in one group move together).
- **`piggy-spread`:** with 200 coins in each of 5 companies, one company halving costs 100 coins. With all 1,000 in it, the same drop costs 500.
- **`piggy-updown`:** a down day is like a rainy day.
- **`piggy-peek`:** don't check every minute.
- **`piggy-time`:** in the past, the US market went up in more years than down. That is history, not a promise.

The Piggy screen shows one coach tip (`Coach.piggyTip`). The priority order is:
1. too many peeks today
2. a big drop or rise (±10%)
3. one basket
4. **one group** (0.15): 2+ companies that are all in the same group (sector, from the Why engine's groups). "Groups often move together, so they may all have a bad day at once."
5. a brand-new bank
6. an old bank
7. baskets

It also shows the next Piggy School lesson and a "Why did X move?" card for the biggest mover. The points-investing work builds on `Coach` and `Why`.

### The Moon Garden course (0.15)

The Moon Garden side of the Piggy tab has its own **Garden School** card (`piggy.garden`): `snowball` → `compound` → `patience` → `fund` → `fees` → `double`. Growth on growth is the idea behind planted points, so the lesson that draws it uses the garden's own picture (a `grow` step with `show: "garden"`).

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
- **Optional lessons don't count.** Challenge-track lessons, and their questions, never count toward mastery (`KidsContent.requiredLessons`).
- **Luna's refresh** (`Review.refresh`, 0.15). A finished lesson comes back as a whole lesson to replay when either:
  - one of its questions is in box 0 with a miss dated *after* the lesson was last played (forgotten at a Review stop, or on a replay); or
  - more than half its questions were missed on the day it was played.
  It sits at the top of Moon School and in the grown-up report, at most 3 at a time. The play log (`played`) records the replay, which clears it. Nothing new is stored.
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

**Each clue links to its lesson** (0.15, `learn` on every cause):
- report → `after`, `expectations` (the price "disagreed" with the result), `guidance` (in line) or `report-card` (no numbers yet);
- market → `why-market`;
- not the whole market → `prices`;
- group → `why-group`;
- dividend → `div-day`;
- wiggle → `why-wiggle`;
- not sure → `why-unsure`.

The app and the web show a "Learn it" button that plays the lesson. The engine's words and weights didn't change.

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

**Round 4 (0.15), highlights.** The full notes are in `packs/core/reviews/rivera.md` and `okafor.md`.
- **Accuracy (Dr. Okafor):**
  - every number recomputed;
  - spreading across groups doesn't protect in a whole-market drop;
  - "sales" is money from customers, not all money in;
  - one toy going up is not inflation;
  - why banks pay interest (they lend savings out), plus deposit insurance;
  - index funds can fall too;
  - after-hours trading.
- **Learning (Ms. Rivera):**
  - percent is defined before it's used;
  - no × or ÷ for 6–8;
  - `borrow` moved before credit cards;
  - the debt lesson ends with what helps;
  - no fire;
  - scam lessons don't teach trust by sender;
  - no age labels on the challenge track;
  - giveaway answers and joke distractors removed again.

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
- 0.15 adds:
  - the gap-coverage test;
  - ladder order;
  - every unit has talk;
  - at least 10 worked examples and 5 grow steps;
  - validator vectors for both new step types, `talk`, `since` and the Garden ladder;
  - the `grow`/`growSteps` vectors (the numbers both platforms draw).

**MoonClubCore:**
- `CurriculumTests` checks the validator, composition, the Ed25519 signatures, the engine and the coach against the web's vectors. It also covers spaced review, mastery, the review merge and Review stops on the map.
- `CardFitTests` lays out every lesson step of Core plus every bundled pack at iPhone SE, 17, Duo and iPad sizes, and checks every pack glyph has art. That includes worked examples with every line shown and grow steps fully grown.
- 0.15 adds:
  - `Growth` against the web;
  - every lesson has retrieval;
  - Luna's refresh;
  - challenge lessons never gate;
  - a unit that grows keeps its stars;
  - starred stops never lock;
  - the rocket stays in the first unconquered land.

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

31. Council for Economic Education (2013). *National Standards for Financial Literacy*. https://www.councilforeconed.org/wp-content/uploads/2013/02/national-standards-for-financial-literacy.pdf
32. CFPB. *Money as You Grow*, school-age children and preteens, money milestones. https://www.consumerfinance.gov/consumer-tools/money-as-you-grow/school-age-children-preteens/money-milestones/
33. Watts, Duncan & Quan (2018). Revisiting the marshmallow test. *Psychological Science* 29(7). Via the APS Observer summary: https://www.psychologicalscience.org/publications/observer/obsonline/a-new-approach-to-the-marshmallow-test-yields-complex-findings.html
34. Stango & Zinman (2009). Exponential growth bias and household finance. *Journal of Finance* 64(6), 2807–2849. https://econpapers.repec.org/RePEc:bla:jfinan:v:64:y:2009:i:6:p:2807-2849
35. Berti, A. E. (1999). Knowledge restructuring in an economic subdomain: banking. In *New Perspectives on Conceptual Change*. https://research.unipd.it/handle/11577/158346

### Could not verify
- **OECD.** oecd.org returned 403, so we used a university-hosted copy of the same publication. The 2024/2025 PISA framework wasn't fetched.
- **PubMed and PMC** were blocked. Abstracts for [7][9][10][17][19][20][26] came from the Europe PMC API.
- **Yeager et al. 2019.** The full text wasn't fetched, so we cite no effect sizes from it.
- **Wouters et al. 2013.** The figures come from an abstract reproduced on a secondary page.
- **Stock Market Game [24].** Only the industry summary was read, not the full report.
- **Adults only.** Myopic loss aversion [28][29] was studied in adults. Applying it to children is our design inference.
- **Watts et al. 2018 [33].** The journal page returned 403, so we relied on the APS Observer write-up.
- **Stango & Zinman [34].** We read only a paraphrased abstract. It is an adult study, and applying it to children is our inference.
- **Older work on children and banks.** We could not verify Jahoda (1981) or Ng (1983/1985) on children's stages of understanding banks, so we cite only Berti [35].
- **Money as You Grow [32].** Its parent "Say:" prompts came through a fetch tool's summary. The milestones list was fetched raw.
