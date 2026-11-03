# Lesson packs

Moon Club's curriculum is made of **lesson packs**. A pack can add to the built-in course or replace it without code changes.

- **The built-in course** is the **Core** pack, the curriculum described in [CURRICULUM.md](CURRICULUM.md).
- **Guest and creator packs** extend Core. They add units, lessons, words and an island on the map.
- **Replace packs** swap in a whole new course.

## Where packs live

| What | Where |
|---|---|
| Format (types, validator, composer) | metaphases `shared/kidsPacks.ts`; Swift port `Packages/MoonClubCore/Sources/MoonClubCore/Packs.swift` |
| JSON Schema | metaphases `packs/pack.schema.json` (draft 2020-12, checked with ajv in `npm run check`) |
| Core | metaphases `packs/core/pack.json` + `packs/core/reviews/` |
| Sample guest pack | metaphases `packs/guest-coach-nova/` (a **fictional** creator) |
| Into the app | `npm run export:kids` → `kids-content.json`. Core is the top level (`units`, `lessons`, `terms`, `regions`, `guessCourse`, `piggyCourse`, `review`, `assessments`, `glyphs`, `pack`), and every other pack goes in `packs`. `make content` copies it into the app and the core tests. |
| Turning packs on | Grown-up corner → **Lesson packs** (behind the gate). The choice is stored only on this device (`PackPrefs`, UserDefaults); progress and sync are unchanged. The demo/screenshot argument is `-packs id,id`. |

## Format (`format: 1`)

```jsonc
{
  "format": 1,                          // pack format version
  "id": "guest-coach-nova",             // folder name, lowercase-dashed
  "title": "Coach Nova's Maker Lab",
  "version": "1.0.0",                   // semver; bump on every content change
  "kind": "extend",                     // core | extend | replace
  "requires": { "content": 1, "app": "0.12.0", "core": "2.0.0" },  // required content version (+ app / core it was made for)
  "ages": { "min": 6, "max": 11 },
  "tracks": [{ "id": "6-8", "title": "Little Moons (ages 6–8)", "blurb": "…" }],
  "curators":  [{ "name": "…", "role": "author|creator" }],
  "reviewers": [{ "name": "Ms. Rivera", "role": "teacher", "signedOff": "2026-11-03" },
                { "name": "Dr. Okafor", "role": "markets", "signedOff": "2026-11-03" },
                { "name": "…",          "role": "human",   "signedOff": null }],
  "creator": { "name": "Coach Nova", "fictional": true, "bio": "…", "voice": "…" },   // null for Core
  "objectives": [{ "id": "nova.cost", "text": "Work out profit per item…", "standards": ["CEE Econ 14: Entrepreneurship"] }],
  "units": [{ "id": "nova-lab", "title": "…", "emoji": "🚀", "blurb": "…", "track": "6-8", "objectives": ["…"],
              "lessons": [{ "id": "nova-cost", "title": "…", "emoji": "🧾", "track": "6-8", "objectives": ["nova.cost"],
                            "steps": [ { "t": "say", "emoji": "🚀", "text": "…" },
                                       { "t": "check", "q": "…", "options": ["right", "wrong", "wrong"], "answer": 0, "why": "…" },
                                       { "t": "sort", "q": "…", "buckets": ["A", "B"], "items": [{ "emoji": "✨", "text": "…", "b": 0 }], "why": "…" } ] }] }],
  "glossary": { "cost": { "word": "Cost", "emoji": "🧾", "means": "…", "example": "…" } },   // tap-a-word cards
  "words": [],                          // word of the day
  "games": [{ "id": "buildCandle", "unit": "candles", "rounds": 5 }],   // chart games used (ids are fixed in the app)
  "guess": { "unit": "report", "ladder": ["…"], "tips": { "<lesson>": "…" }, "reveal": { "beatUp": "…", "beatDown": "…", "missDown": "…", "missUp": "…", "unknown": "…", "inLine": "…", "tryAgain": "…" } },  // Core
  "piggy": { "unit": "piggy", "ladder": ["…"], "peekLimit": 3, "tips": { "oneBasket": "…", "fewBaskets": "{n} …", "manyBaskets": "…", "newBank": "…", "longTime": "{days} …", "bigDrop": "{pct} …", "bigRise": "…", "peekMany": "{n} …" } },  // Core
  "review": { "intervals": [0, 1, 3, 7], "retireAt": 4, "perStop": 5, "pass": 0.8 },   // Core: spaced review
  "assessments": [{ "id": "nova-lab-check", "unit": "nova-lab", "title": "…", "pass": 0.8 }],  // mastery check per unit
  "regions": [{ "id": "nova-cove", "name": "Comet Cove", "blurb": "…", "art": "🚀", "hue": "teal",
                "nodes": [{ "id": "nova-lab-trail", "title": "…", "art": "🚀", "kind": "unit", "ref": "nova-lab" },
                          { "id": "nova-practice", "title": "Review stop", "art": "🔁", "kind": "practice" },
                          { "id": "nova-boss", "title": "…", "art": "👑", "kind": "review", "ref": "nova-cove" }] }],
  "glyphs": ["🚀", "🧾", "…"]           // every emoji the pack draws (each needs art in the app's Art.map)
}
```

Map node kinds:
- `unit`, `lesson`, `quest` (`lemonade`, `save` or `dividends`)
- `game` (a fixed chart-game id)
- `guess`
- `practice` (a Review stop: optional, never blocks the trail)
- `review` (the quiz boss for a region)
- `timeMachine` (a chart boss for a ticker)

A region must end with a boss.

### Composition
- **Core** is always on.
- **An extend pack** appends its units, lessons, words, glossary, regions (islands after Core's) and assessments. Its ids must not collide with Core's.
- **A replace pack** swaps the units, lessons, regions and assessments, and swaps the words if it has any. Quests, games, companies, points and badges stay.
- **Invalid packs** are skipped, never shown broken.
- The same composer is in `composePacks` (TS) and `KidsContent.with(packs:)` (Swift). The `compose` vector proves they agree.

## The validator: kids rules as code

`validatePack` (TS) and `PackRules.validate` (Swift) return error codes. The `packValidate` vectors prove the two agree on every code.

| Code | Rule |
|---|---|
| `format` `id` `version` `kind` `requires` `ages` | Manifest sanity. `requires.content` must be ≤ what this build understands. |
| `unit.dup` `lesson.dup` `collide` `node.dup` | Ids are unique. Extend packs don't shadow Core. |
| `lesson.steps` `check.answer` `check.options` `sort.buckets` `sort.items` `say.long` | 3–7 steps with at least one check or sort; answers in range; 2–3 options; 4+ sort items in both buckets; say cards ≤ 22 words. |
| `fit` | Every step fits one card on iPhone SE: title ≤ 40, say ≤ 110, question ≤ 90, option ≤ 42, why ≤ 100 characters. |
| `readability` | Flesch–Kincaid ≤ 5 for each lesson's say cards, ≤ 5.5 with its questions; each glossary card ≤ 5. |
| `glyphs` | Every emoji drawn is declared. The app test checks each one has designed art. |
| `link` | No URLs, domains, @handles or #hashtags anywhere, not even in a wrong answer. |
| `banned` | No advice or promotion: "buy now", "you should buy", "guaranteed", "to the moon", "subscribe", "follow me", "promo code", "sponsored", "my channel", "merch", and the rest of the list. These are allowed only inside "double quotes" (a hype example being taught) or as a wrong answer. |
| `emoji.text` | Emoji go in glyph fields, never in the words. The app never draws an emoji as a picture. |
| `track` `objective.ref` `course` `assessment` `node.kind` `node.ref` `region.boss` `region.hue` `regions` | Everything a pack points at exists. |
| `creator` `review` | A non-core pack names its creator and carries **teacher and markets sign-offs**. |

## The remote channel (curated, signed, off by default)

```
mutaafaziz.com/metaphases/api/kids/packs        → { format, publicKey, packs: [{ id, version, title, kind, creator, ready, sha256, sig }] }
mutaafaziz.com/metaphases/api/kids/packs/<id>   → the pack's exact bytes (header x-pack-sig)
```

**Signing.**
- `npm run packs:sign` (metaphases) signs every non-core pack with **Ed25519** over the exact bytes the worker serves (`JSON.stringify(pack)`), and writes `packs/channel.json`.
- The private key never enters the repo. It lives at `~/.config/metaphases/kids-pack-signing.jwk` on the operator's Mac, or in the env var `KIDS_PACK_KEY`. **Back it up:** the public key ships in the app's content (`channel.publicKey`), so a new key means a new app build.
- A unit test fails if a committed signature is stale, so re-run `packs:sign` after editing a pack.

**What gets listed.**
- The worker lists a pack only when it is `ready`, meaning `channelReady()`: it validates **and** the teacher, the markets expert **and a human** have signed it off.
- Today the sample guest pack is signed but **not ready**: its human sign-off is empty. So the channel is empty, which is correct.

**What the app does** (`PackChannel.accept`, MoonClubCore). A downloaded pack must:
1. verify against **the app's own key**, never the one the server sends;
2. decode;
3. pass the validator against Core;
4. be `channelReady`.

Only then is it shown to a grown-up, who turns it on behind the gate.

**The flag.** `PackChannel.remoteEnabled` is `false` in this build. The fetch, verify and validate path is implemented and unit-tested (CardFitTests also lays out every bundled pack). Wiring a "Get more packs" row into the grown-up corner is the remaining step when the first human-signed pack exists. Until then, packs ship in the app bundle.

## Creator packs (influencers and celebrities)

Creators may bring their voice and their favorite *kinds* of companies to a curated, reviewed pack. The kids rules don't bend.

### Rules for every creator pack
1. **Same kids rules.** Pretend money, never advice, clues not promises, reading grade ≤ 5, cards that fit. The validator enforces these.
2. **No links, handles, hashtags, channel names, promo codes or "follow / subscribe / like".** The validator rejects them.
3. **No product promotion or sponsorship inside kids content.** No brand deals, no merch, and no apps or games to download.
4. **No asking kids to do anything outside the app.** That includes no "ask your parents to buy".
5. **Disclosed on screen.** The guest host says who they are in the first card. The app shows a "Guest host" badge (or "Made-up guest host" for a fictional one) wherever the pack is turned on.
6. **The no-advice line, in their own voice.** For example: "I'm not telling you to buy anything. Check facts with a grown-up."
7. **No tickers the creator holds or promotes, and no "my favorite stock".** A creator may talk about a *kind* of company ("a rocket-toy company"). Real companies appear only as neutral examples in Core's style.
8. **Expert review.** Both expert reviewers (teacher and markets) run at least two rounds, and their notes go in `packs/<id>/reviews/`. **Then a human signs the checklist below.**
9. **A grown-up turns it on.** Packs are never on by default.

### Human sign-off checklist (fill in `reviewers[role=human].signedOff`)
- [ ] I read every card aloud. Nothing is advice, a promise, an ad, a link or a call to follow.
- [ ] The creator's on-screen disclosure and no-advice line are present.
- [ ] The pack names no ticker the creator holds, promotes or is paid by, and no sponsor.
- [ ] Both expert reviews are attached and every must-fix is applied.
- [ ] The legal items below are cleared for **this creator** (written agreement on file).
- [ ] `npm run check` and `make test` are green with the pack in place.
- [ ] I ran `npm run packs:sign` after signing off. The channel lists the pack as `ready`.

### Legal and compliance (for the operator, before any real creator)
These are not handled by code. Clear them with counsel before the first real creator pack:
- **COPPA (US).** Moon Club collects no personal data, and packs must not change that. Packs may not add sign-ups, contests, user-generated content or anything that could collect data. Review the FTC's COPPA rule updates as they come.
- **Apple Kids Category (App Review 1.3 and 5.1.4).** No external links or purchase opportunities without a parental gate, no third-party analytics or ads, and content appropriate for the age band. Creator packs inherit this. Re-check before shipping a pack in an app update.
- **FTC Endorsement Guides (16 CFR Part 255) and the influencer disclosure guidance.** A creator speaking about products or companies is endorsement territory, and children are a vulnerable audience.
  - Any material connection (payment, free product, equity) must be clear and conspicuous, in words a child understands.
  - Our policy goes further: **no paid promotion at all inside kids content**.
- **Right of publicity and likeness.** Using a real person's name, voice, image or catchphrases needs a written license, which differs by state. A license from the creator does **not** cover third parties they mention.
- **Trademarks.** Brand names inside lessons (as in Core's ticker lesson) are descriptive. A creator pack must not imply that a brand endorses it.
- **Financial promotion and advice rules.** Even educational content about real securities can be "advice" in some jurisdictions (e.g. the UK FCA financial promotions regime). Our rules (no tickers held, no buy or sell, clues not promises) are designed to stay clear of this. Confirm per market.
- **Contracts.** The agreement covers content approval rights (ours is final), takedown, how the creator may talk about the pack (never "link in bio" for kids), revenue (none from kids), and moral rights.

## Authoring template

Copy `packs/guest-coach-nova/` to `packs/guest-<name>/`, then:

1. Set `id` (same as the folder), `title` and `version: "1.0.0"`, and `kind: "extend"`. Set `creator` (with `fictional` true or false), `curators`, and `reviewers` with `signedOff: null`.
2. Write 1–2 units of 3–5 lessons. Each lesson is one idea with a worked, concrete example first, 2–3 say cards, and a check or sort with real-misconception distractors. Tag each lesson with a `track` and an `objectives` entry.
3. Add `glossary` cards for any new word. Add a `region` with the unit trail, a `practice` Review stop and a `review` boss.
4. List every emoji in `glyphs`. Use emoji the app already draws (see `Art.map` in `MoonClub/Design/Art.swift`). A new one needs art and a symbol added there first.
5. `npm test` until `validatePack` is clean. The sign-off codes stay until the reviews are done.
6. Run both expert reviews (two rounds minimum), apply the fixes, and write `reviews/rivera.md` and `reviews/okafor.md`.
7. `npm run export:kids` → `make content` → `make test`. CardFitTests lays the pack out at iPhone SE size.
8. A human signs the checklist, and the pack ships in the bundle. When the remote channel is on, run `npm run packs:sign` too.

The **sample guest pack**, "Coach Nova's Maker Lab", is a fictional science-show host:
- a cookie stand: cost, price and profit;
- "Two stands, one street": competition;
- "Being a fan is not a fact": the creator-pack anti-endorsement lesson;
- "My big oops": she put all her coins in one company and learned to spread out.

Her first card says she is "a made-up guest host".
