# Release notes: house style

Every TestFlight build, GitHub release and in-app "What's new" note comes from `release-notes/<MARKETING_VERSION>.md`.
`make testflight` refuses to ship without it, and `scripts/check-rules.sh` lints it.

**Two audiences per file:**
- **`## Luna's news`** (required) powers the in-app "What's new" modal that pops up once after an update. It's stripped from TestFlight and the App Store. Since 0.17.0 it is:
  ```
  ## Luna's news
  > Moon Club got a super suit!
  - [hand.point.up.left.fill] **Super button!** Not sure what's next? Tap it. I pick for you!
  - [sparkles] **Lights, camera, lessons!** Every lesson card is a little show. I act it out!
  ```
  - One `> headline` (≤ 40 characters) and 2–4 cards. Each card is `- [art] **Title** line`: art is an SF Symbol, a `custom.*` mark or an `Art` emoji key; the title is ≤ 4 words (26 characters); the line is ≤ 64 characters. Luna's voice, grade-≤5 words.
  - Cover everything since the last **App Store** release: that's all an App Store update shows. A card that says "iPhone Duo" shows only on a Duo, so keep at least two other cards.
  - **Original nods only:** superheroes, space adventures, fairy tales, and light news like moon phases, eclipses, meteor showers, seasons and launches. No real characters, brands, logos, quotes or people (the name-drops below are for the grown-up part only). Nothing scary, no politics, and every claim must be true.
  - Older files (before 0.17.0) have 1–4 plain `- [sf.symbol.name] Text` lines (≤ 90 characters); they still parse.
- **Everything else** is for grown-ups and testers.

**The vibe:** fun, warm and full of pop-culture nods. Picture a trailer voice-over written by a Pixar intern who reads the patch notes.
- **At least three pop-culture references per release.** Movies, games, cartoons, sports, space missions.
- **Family-friendly only.** Pick things a 9-year-old *and* their parent would get: Pixar, Star Wars, Marvel, Mario, Pokémon, Minecraft, Bluey, Harry Potter, Back to the Future, Apollo 13, Shark Tank, Indiana Jones…
  - Nothing scary or PG-13 punchlines.
  - Nothing that mocks a real person.
- **Nods, not copies.** A short famous line (well under 15 words) or a name-drop is fine.
  - Never song lyrics.
  - No long quotes.
  - No logos or brand art.
- **Every feature line still says what to test.** The joke comes first and the instruction rides along: e.g. "Wax on, wax off: tap through a Moon School lesson."
- **Never say the app is for kids or children** in the grown-up part: it becomes the App Store "What's New" (Guideline 2.3.8, docs/APPSTORE.md).
- **Keep the promises line every time:** no ads, no accounts, no tracking, everything stays on the device.
- **No links.** Kids rules: links live only behind the grown-ups gate.
- **4000 characters max** (TestFlight's limit). Markdown is stripped for TestFlight.

Bumping the version (`MARKETING_VERSION` in `project.yml`) means writing a new file. Builds within one version share that version's notes, so edit the file as features land.
