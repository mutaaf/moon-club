# Release notes: house style

Every TestFlight build, GitHub release and in-app "What's new" note comes from `release-notes/<MARKETING_VERSION>.md`.
`make testflight` refuses to ship without it, and `scripts/check-rules.sh` lints it.

**Two audiences per file:**
- **`## Luna's news`** (required) has 1–4 kid lines. Each is `- [sf.symbol.name] Text`, ≤ 90 characters, written in Luna's voice at a grade-≤5 reading level. These power the in-app update reel that pops up once after each update. It's stripped from TestFlight.
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
- **Keep the promises line every time:** no ads, no accounts, no tracking, everything stays on the device.
- **No links.** Kids rules: links live only behind the grown-ups gate.
- **4000 characters max** (TestFlight's limit). Markdown is stripped for TestFlight.

Bumping the version (`MARKETING_VERSION` in `project.yml`) means writing a new file. Builds within one version share that version's notes, so edit the file as features land.
