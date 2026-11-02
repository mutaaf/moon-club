# Moon Club 🌙

**Metaphases Kids as a native iPhone + iPad app.** Kids (about 8–12) learn how money and the stock market *work* with pretend money that follows real prices. They play Luna's quests (Lemonade Stand, Save or Grow?, Your Slice Pays You), take one-minute Moon School lessons, guess company report cards, run a pretend piggy bank and ask Luna, a kid-safe AI helper.

No accounts, no ads, no analytics, no third-party SDKs. Progress lives only on the device.

The web version lives at <https://mutaafaziz.com/metaphases/kids>; its content is this app's single source of truth (see *Content* below).

## Quick start
```sh
make up        # generate the Xcode project, run every test, build, launch on iPhone + iPad simulators
make shots     # screenshot every main screen (demo mode) on iPhone + iPad → build/shots
make device    # build + install on a paired iPhone/iPad (team Z73865R687)
make testflight  # archive + upload (needs .env.testflight, see docs/TESTFLIGHT.md)
make content   # re-export kids content + test vectors from ../metaphases
```
Launch arguments for development: `-demo` (offline fakes + a lived-in week), `-fresh` (with `-demo`, empty progress), `-tab story|guess|piggy|school|luna`, `-quest lemonade|save|dividends|save:tree|…`, `-lesson <id>`, `-today YYYY-MM-DD`.

## Layout
| Path | What |
|---|---|
| `Packages/MoonClubCore` | Pure Swift: content model + validation, all kid logic (ported 1:1 from the web), weekly recap, Family League codec, quest math, state reducers, service protocols, request builders, layered cache. `swift test` on macOS. |
| `MoonClub/App` | Composition root (`MoonClubApp`) and the single `AppModel`. |
| `MoonClub/Live` | Live services (market data, Luna, voice, progress store) + fakes for previews/demo. |
| `MoonClub/Design` | Palette, type, Luna, the Metal `AuroraField`, celebration particles, shared components. |
| `MoonClub/Features` | Story, Guess (+ Family League board, recap), Piggy Bank, Moon School (lesson player), Quests, Ask Luna, Grown-ups (gate, voice, League codes). |
| `scripts/` | `sync-content.sh`, `check-rules.sh`, `shots.sh`, `device.sh`, `testflight.sh`. |
| `docs/` | `ARCHITECTURE.md`, `TESTFLIGHT.md`, `COMPLIANCE.md`. |

## Content
`MoonClub/Resources/kids-content.json` is exported from the metaphases repo (`npm run export:kids`, mutaaf/metaphases#32): lessons, terms, quests, companies, badges, levels — plus **test vectors** for every pure function. `MoonClubCoreTests/VectorTests` proves the Swift port reproduces the web exactly, so Family League codes made on an iPad paste into the website and back.
