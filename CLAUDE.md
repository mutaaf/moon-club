# Moon Club: working notes

Native SwiftUI (iOS 17+, iPhone + iPad) kids app; the native twin of mutaafaziz.com/metaphases/kids. Read README.md and docs/ARCHITECTURE.md first. Same kids rules as metaphases AGENTS.md: pretend money only, nothing about the child leaves the device, no ads/analytics/SDKs, no links out except behind the parental gate (GrownUps.swift only — `scripts/check-rules.sh`), Luna = one of three brains picked by a grown-up behind the gate (on-device Apple Intelligence by default when available; free kid-safe brain with no key; or the grown-up's own key, ONLY after per-provider consent, see `Brain.swift`), the same kid-safe prompt plus `LunaGuard` on every answer, a grown-up voice key only ever speaks app copy or Luna's answer, reading grade ≤ 5, never advice.

## Commands
`make up` (idempotent: xcodegen + Metal toolchain check + rules + core tests + app tests + sims), `make test`, `make shots`, `make device`, `make testflight`, `make content`, `make icon`. App Store: `make appstore-validate`, `make appstore-build`, `make appstore`, then `node scripts/asc.mjs submit --yes` only when the user says go (`docs/APPSTORE.md`).

## Release notes
Every version needs `release-notes/<MARKETING_VERSION>.md` in the house style (`release-notes/README.md`): fun, at least 3 family-friendly pop-culture nods, never lyrics, no links, ≤ 4000 chars. It feeds TestFlight "What to Test", the GitHub release and the in-app What's new. `check-rules.sh` fails without it.

## Market World, art and motion
- The World tab is the map (`Features/WorldMap.swift`, games in `WorldGames.swift`, bosses in `WorldBosses.swift`); rules in MoonClubCore `World.swift` + `Charts.swift`. New chart lessons come from metaphases (`units` candles/trends/patterns/signals) via `make content`; the map drops nodes whose content is missing.
- **Never draw an emoji as a picture.** Use `Glyph(key)` (`Design/Art.swift`); add new emoji keys to `Art.map` (CardFitTests fails on any content emoji without art, or any symbol that doesn't exist). No brand logos (`apple.logo` etc.).
- **No ScrollView inside a card.** Make the page scroll, page the content, or shorten copy. CardFitTests measures every lesson step at SE (xxLarge)/17/Duo/iPad (xxxLarge); from xxxLarge the lesson page itself may scroll as a fallback.
- Animations use `Motion` tokens; appear animations use `enterOnce`.
- Debug launch args for screenshots: `-world mid|all` (seed map progress), `-play <node id>` (open a game/boss), `-step <n>` (lesson step), `-conquer` (win the current land after 2 s, for recording the conquer animation).

## Game On (0.10): play screens
- Every lesson, chart game, boss and quest uses `Design/GameKit.swift`: `RunModel` (hearts, combo, coins, Luna's mood), `GameHUD`, `AnswerButton`/`ChunkyStyle`, `CoinBurst`, `RunResults`, `OutOfFuel`, `BossBackdrop`, and `.playChrome()` (hides the tab and navigation bars; the HUD's X closes, with a "Leave? Your stars stay" confirm mid-run). New play screens use these, not ad-hoc buttons.
- Play screens are fixed full-screen layouts: no ScrollView at standard text sizes (LessonPlayer falls back to a page scroll from `.xxxLarge` up). `CardFitTests.testEveryPlayScreenFitsWithoutScrolling` lays every game, boss and lesson out at its minimum height on iPhone SE and 17.
- Out of hearts is never punitive ("Luna's rocket needs fuel"); sorting never costs a heart; the speed ring only gives bonus coins and is off with Relaxed play (grown-ups → Games; `PlayPrefs`).
- Today's missions, chest, play streak and rocket skins are pure in MoonClubCore `Missions.swift`. State fields `played` / `chests` (union) and `skin` ("<millis>|<id>", max wins) are optional. Log plays with `state.play(kind, id, today:)`; kinds are lesson, game, boss, node, quest, guess.
- On the map a tap plays an open stop directly. Long-press (or the VoiceOver action) opens the info sheet.
- `Art.neverAgain` lists emoji→symbol pairs that were misleading (cow/lemon drawn as water drops). The art test keeps them out, and prints `Art.reviewList` for review.
- Lesson quiz steps (check/sort) put the last "say" picture in a spare-room `ArtPanel` (min 0, hides under 72 pt) above the question, so answers sit low and the card never has a dead band. Quiz bosses (`GameShell(arena: true)`) show `BossArena` above a compact dark question card.
- Quests are play screens too: on a phone, the stepper caption names the chapter (no big hero). Long stages are decks (one goal, card or question at a time). `CardFitTests.testEveryQuestStageFitsWithoutScrolling` measures `QuestView(start:, scrolls: false)` for every stage on SE and 17. **Don't measure through a NavigationStack or ScrollView**: `sizeThatFits` just returns the proposed height, so the first version of the quest test passed while every stage overflowed.
- `-play <node id>` goes through the same `play(_:)` as a tap. Setting `playing` directly rendered lessons, units and quests blank.

## Party Moon (0.12): celebrations, Liquid Glass, engagement
- **Celebrations** have three tiers (MoonClubCore `Party.swift` `PartyMoment.tier`): small (right answer: `Sparkle` on the button, coins, `LunaBounce`), medium (combo 3/6, perfect round, badge tier: confetti + `EdgeGlow` + Luna flip), large (boss, land, rank, chest, streak 3/7/30: fireworks + cannons + `PartyShake` + `Chime.rising()`). Fire them with `PartyCenter.shared.fire(_:title:)`; `PartyOverlay` sits over the root. **Root overlays don't show over `fullScreenCover`s** (quests, rank ceremony, Game Night), so those use a local `Celebrate(trigger:tier:)`. Reduce Motion: glow + haptic only.
- **Liquid Glass** goes through `Design/Glass.swift` only: `.moonGlass(shape|radius:, tint:, interactive:, weight:, dark:)` (glass on iOS 26+, material before, solid with Reduce Transparency), `GlassGroup`, `.glassStage()` (one container + namespace per play screen) and `GlassMorphID("points")` (HUD points pill → results card). Map stop → game uses the iOS 18 zoom transition (`zoomSource`/`zoomFrom`). Don't call `glassEffect` directly; the deployment target is still iOS 17.
- **Luna's lines** (`LunaLine`, ~50, grade ≤ 5, tested for no "buy/hurry/lose") show in the HUD bubble from `RunModel.record` (first win of the day, comeback, combo, every other miss) and on Duo moments.
- **Mystery Stop**: `Mystery.node` picks one open game per day (seeded, same on every device); finishing it banks `bonus["day|game|mystery"]` (max-merge, can't be farmed). **Nudges** (`Nudge.after`) on results; **sticker book** (`Stickers`, derived from map stars, no saved state); **goodnight** (`Bedtime`, 20 min then 10 min snooze, never during play: `PlayActivity.playing`).
- Debug/demo args: `-party small|medium|large`, `-sleepy`, `-duocoach`.

## iPhone Duo
Made for iPhone Duo. `docs/IPHONE_DUO.md` covers every feature → purpose → code.
- The hinge drives effects only: Luna's moon, the piggy lid, tuck-in.
- Layout comes from the fold's reserved region (`Storybook` / `TwoPage` / `FoldColumns` in `Design/Duo.swift`) and size classes. Never branch on device.
- Pose logic is pure and tested in `MoonClubCore/Duo.swift` (+ `Party.swift`: `HingeDial`, `HingeLaunch`, `DuoUse`).
- **Duo features are gated on `DuoModel.hasHinge`** (capability), never a model string. Duo-only trophies/shop items go through `Trophies.visible(hinge:)` / `Shop.visible(hinge:)`; What's New lines mentioning "iPhone Duo" show only with a hinge. `KidsState.duo` counts uses (max per key).
- Tabletop layouts use `TabletopStage` (a wide, *active* division region). Debug `-pose tabletop` synthesizes a horizontal center fold on tall sims.

## Environment nuances (found the hard way)
- **XcodeGen** generates `MoonClub.xcodeproj` (gitignored); edit `project.yml`, never the project.
- **Xcode 27.1 ships without the Metal toolchain**: the first build fails with "cannot execute tool 'metal' due to missing Metal Toolchain". `xcodebuild -downloadComponent MetalToolchain` (≈840 MB, once). `make gen` does it. **Every Xcode update needs its own toolchain build** (Xcode 27A9275 → 27B52 mid-session flipped `xcodebuild -showComponent MetalToolchain` back to "uninstalled"): rerun the download.
- **Simulators**: this Mac's iOS 17/18 runtimes have iPhone 15 / iPad M4 names, but the Xcode 27.1 SDK only targets iOS 26.5+ sims (iPhone 17, iPad Pro 11-inch (M5)…). Names are duplicated across runtimes, so scripts accept `PHONE_ID`/`PAD_ID`.
- **A fresh iOS 27.1 iPad image can hang on `simctl launch`** (install took 50 s, launch never returned). The iOS 27.0 iPad Pro 11-inch (M5) works; `scripts/shots.sh` wraps every simctl call in a timeout.
- Core package is Swift 6 tools with Swift 5 language mode; use `lock.withLock {}` (plain `lock()` is an error from async contexts in Swift 6 mode).
- `ProcessInfo` launch args drive demo mode for screenshots (`-demo -tab … -quest … -lesson …`).
- The kids content JSON must also be copied into `Packages/MoonClubCore/Tests/MoonClubCoreTests/Resources/` (sync-content does both).
- Device signing: paid team Z73865R687 ("Apple Development: Mutaaf Aziz"). User's phone UDID 00008130-001614883021401C.
- **App Store Connect API**: `scripts/asc.mjs`, with zero deps (Node crypto ES256 JWT). Apps can't be created through the API: the "Moon Club" app record must be made once in the web UI. Xcode has no Apple ID signed in on this Mac, so archive/upload signing goes through the API key (`-allowProvisioningUpdates -authenticationKey*`).
- Debug-only launch arg `-demo -grownups` opens the grown-ups corner without the gate, for screenshots. `#if DEBUG`, so release builds always use the gate.
- **Physical UDIDs are 8-16 hex** (`00008130-001614883021401C`), not the 8-4-4-4-12 simulator form; `device.sh` once matched only the latter and found no phone. Once paired over a cable, the phone shows as `available (paired)` over Wi-Fi too (CoreDevice `*.coredevice.local` over Bonjour): it needs the same network, and the phone unlocked or recently used. `transportType` in `devicectl device info details --json-output` says `wired` or `localNetwork`.
- **TestFlight signing:** the team API key (C3BA4X5S97, App Manager) gets "Cloud signing permission error" at export. `asc.mjs signing` creates our own Apple Distribution cert (CSR and key in `~/.appstoreconnect/signing/`) plus the "Moon Club App Store" profile, and the export plist signs manually.
- **TestFlight `whatsNew` rejects emoji** (409 "invalid characters"). `notesFor()` strips them; the in-app What's new keeps them.
- Agent worktrees live in `.claude/worktrees/` and are gitignored. Never `git add -A` before that's ignored.
- **Luna brains**: `MoonClubCore/Brain.swift` (pure: router, prompt, guard, BYOK request builders) + `MoonClub/Live/Brains.swift` (live brains, FoundationModels behind `#if canImport(FoundationModels)` + `#available(iOS 26, *)`; the deployment target stays 17). Keep `LunaPrompts.kidsSystem` in sync with metaphases `worker/ai/prompts.ts` `KIDS_SYSTEM`. BYOK calls providers directly, NOT through the worker, because the web's `kids` task is FREE_ONLY and ignores keys. Demo: `-demo -grownups -brain byok` presets the picker for screenshots (DEBUG only).
- **Apple Intelligence in the Simulator** follows the host Mac's Apple Intelligence state: it shows `available` only if the Mac has it on and its model downloaded. On-device answers are unverified until run on an eligible device (iPhone 15 Pro+ / M-series iPad).
- **Sync** (`docs/ARCHITECTURE.md`, "Sync across devices"):
  - `KidsState.merged(with:)` must stay a join; `SyncTests` property-checks it. Never filter or cap inside the merge: filtering "me" out of the league there broke associativity, so `leaguePlayers` filters at read time and `Sync.payload` caps at write time.
  - New `KidsState` fields must be optional or have a merge rule, or old saves fail to decode and progress resets (`resetEpoch` is `Int?` for this reason).
- **iCloud capability:** `asc.mjs capabilities` enables ICLOUD on the bundle id; `asc.mjs signing` runs it before making the App Store profile. The entitlement is in `project.yml` (generated to `MoonClub/MoonClub.entitlements`). `GET /v1/bundleIds/{id}/bundleIdCapabilities` rejects `limit=`.
- **Web transfer codes** (`MOONP1-`) come from metaphases `shared/kidsTransfer.ts`; the app's `Transfer.swift` is checked against the `transfer` vectors. Change both together and re-run `make content`.
- Debug screenshot args: `-demo -grownups -syncOn -scrollSync` shows the "Your devices" section.

- **iPhone Duo simulator**: device type `com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`, iOS 27.1 runtime only. `scripts/shots.sh` creates "Moon Club Duo".
  - Displays: outer is `--display=primary` (1398×2034), inner is `--display=primary-1` (2007×2853).
  - It boots **closed**, and `onHingeChange` really reports `.closed`.
  - **`simctl` has no hinge control.** Folding happens in Device Hub's window. UI scripting and screen capture of Device Hub aren't permitted on this Mac (Accessibility / Screen Recording off), so automation can't fold it, and powering off a display with `simctl io screenConfig` doesn't open it.
  - Debug builds take `-pose closed|book|tabletop|flat [-hinge deg]` (pins a reading and synthesizes a center fold on wide sims) and `-gamenight`.
  - The TV output (`external-0`) times out on screenshot until a display is attached in Device Hub.
- Layout that measures itself (the fold probe) must lay out at the **proposed** width (`PageSplit` Layout), never at fixed measured widths. Fixed widths fed back into the measured frame and cut the right page off when the iPad sidebar appeared.
- **Widgets / Live Activities**: the `MoonClubWidgets` extension (bundle `com.mutaafaziz.moonclub.widgets`) shares `Shared/` + `MoonClub/Design/Theme.swift` with the app. App ↔ widget data goes through a **shared keychain group** (`$(AppIdentifierPrefix)com.mutaafaziz.moonclub.shared`, Info.plist key `MoonKeychainGroup`), NOT an App Group. Reasons:
  - the App Store Connect API has no App Groups endpoint (`/v1/appGroups` → 404);
  - Xcode's automatic provisioning with our App Manager API key fails ("Authentication failed … bearer token");
  - the wildcard "iOS Team Provisioning Profile: *" has no App Groups;
  - but every team profile, wildcard and App Store, already grants `Z73865R687.*` keychain groups.
  Keychain items survive app deletion (still on-device only; "Reset all progress" clears them).
- `asc.mjs signing` makes one App Store profile per bundle id (`TARGETS`: app + widgets) and deletes stale local copies of each profile name; `testflight.sh` maps both in the export plist. `asc.mjs call <METHOD> <path> [json]` is a debug passthrough.
- `scripts/provision.sh` (Xcode automatic provisioning via the API key) currently fails with "Authentication failed" for the App Manager key. Kept for an Admin key.
- **Widget design review**: `make widgets` (`scripts/widget-shots.sh`) renders every widget family and Live Activity view with `ImageRenderer` to `build/widget-shots/` (light + dark).
  - The widget view files also compile into `MoonClubTests` with the `WIDGET_RENDER_TESTS` condition, which adds `@testable import MoonClub`.
  - Views take a `forced:` family so they render outside WidgetKit.
  - `ProgressView` renders as a placeholder in ImageRenderer, hence the drawn `MoonBar`.
  - `Text(timerInterval:)` counts against the real clock even in ImageRenderer, so render fixtures use `Date()`.
- **The first `xcodebuild` after `xcodegen generate` sometimes fails** with "the following command failed with exit code 0 but produced no further output". Rerunning it succeeds.
- **Update reel:** `WhatsNewModal` appears once per version on the first launch after an update. Its lines come from `## Luna's news` in `release-notes/<version>.md`, which is required and linted by `asc.mjs notes`, and stripped from TestFlight. A fresh install records the version and shows nothing. Debug: `-demo -whatsnewFrom 0.5.0`.
- `candles.json` (app bundle) must also be copied to `Packages/MoonClubCore/Tests/MoonClubCoreTests/Resources/`. Refresh it with real prices: see `docs/ARCHITECTURE.md` (Market World); the live app also refreshes from `/api/kids/candles`.
- **0.8.0 TestFlight crash** (EXC_BREAKPOINT in `PiggyBank.body`, `Piggy.swift:94`): `app.state.piggy!` trapped when the piggy was cleared while the view was on screen. Never force-unwrap state or content lookups in views. Use `app.company(_:)` and `if let`; `check-rules.sh` rule 5 enforces it. To pull crash logs off the phone: `xcrun devicectl device info files --device <udid> --domain-type systemCrashLogs`, then `device copy from`, then `atos` against `build/archive/MoonClub.xcarchive/dSYMs`.
- **Points that matter (0.11)** — `MoonClubCore/Rewards.swift` (pure) + `MoonClub/Features/Rewards.swift` (Moon Locker: Badges · Moon Shop · My points; rank ceremony; reward toast; Luna's look).
  - One currency, earned only: **Moon points**. `points(c)` = the web's `pointsFor` + map stars + trophy tiers + chests × 30 + banked bonuses (`bonus`, "day|source|id" → max). Never change `pointsFor`/`levelFor` (VectorTests pin them to the web); add app-only points as new derived terms.
  - The wallet is **derived** (`earned − price of owned`), never a synced counter. `owned` is a set (an item is paid once even if two devices buy it); streak savers are unique `freeze#<millis>` ids. Every new field has a merge rule in Sync.swift and is in SyncTests' generator.
  - Ranks: `Ranks.levels(c)` = the web's 5 moons + app moons. Anything that indexes a level name must use `Ranks.levels`, not `content.levels` (a Supermoon index overflows the web list).
  - Trophy tiers are celebrated through `seenBadges` with `t:<id>:<tier>` keys. Demo mode marks current tiers seen; `-toast` keeps them fresh.
  - Run "coins" are Moon points (2 × combo per right answer, +1 fast); `RunResults(source:earnId:)` banks them. Pretend dollars stay Piggy-only ("coins" in Piggy copy).
  - `Palette.accent` is computed from `ThemeColor.hex` (the App colors pick); the root re-ids its content on change. Widgets keep the default.
  - `PlayActivity.shared` counts open play screens (via `playChrome()`): toasts move to the top during play; the rank ceremony waits until play ends.
  - Debug/demo args: `-points <n>` (bank spendable points), `-rank` (show the current rank's ceremony), `-equip id,id` (own + wear shop items), `-locker badges|shop|points` with `-slot rocket|hat|flag|trail|theme|frame|freeze`.
- **Lesson packs and the curriculum** ([docs/CURRICULUM.md](docs/CURRICULUM.md), [docs/PACKS.md](docs/PACKS.md)):
  - **Editing lessons.** Lessons are edited ONLY in metaphases `packs/<id>/pack.json`, then `make content`. Never hand-edit `kids-content.json`.
  - **Sync from a worktree.** Pass the path: `scripts/sync-content.sh <metaphases worktree>`. The default `../metaphases` points at the main checkout, which may be on another branch.
  - **Keep both sides in step.** `PackRules.validate` (Swift) must stay a port of `validatePack` (TS). The `packValidate` vectors fail on any drift. The same goes for `Why.explain`/`whyMoved`, `Coach`/`kidsCoach`, `with(packs:)`/`composePacks`. Change both sides together.
  - **Card fit is in the validator** (`Fit`, `FIT`): title 40, say 110, question 90, option 42, why 100 characters; 2–3 options. `WorldTests.testEveryCardStepFitsOneCard` uses the same numbers for Core.
  - **Map.** The map comes from `content.regions` when present (`World.builtIn` is only the fallback). Review stops are `.practice` nodes: `isOptional` means they never gate the trail or the boss, and they don't count toward star totals.
  - **Review state.** `KidsState.review` stores misses and Review-stop answers only (a right answer in a lesson records nothing). Merge: max of `"day|box"` per question. It is in SyncTests' generator.
  - **Pack choices.** `AppModel.content` is a `var`: `setPack` recomposes Core with the enabled packs. `baseContent` is Core as shipped. Debug/demo: `-packs guest-coach-nova`.
  - **Remote packs are off** (`PackChannel.remoteEnabled = false`). The trusted Ed25519 key is `channel.publicKey` in our own content. The private key is on the operator's Mac at `~/.config/metaphases/kids-pack-signing.jwk` (back it up; a new key needs an app build).
  - **New emoji** in a pack need an `Art.map` entry first. CardFitTests checks Core's and every bundled pack's `glyphs`.
  - **Done in 0.13 (Ms. Rivera's note):** candles show direction by shape too (`CandleInk`: hollow up, filled down, arrows on big candles). See "iPad layout and performance (0.13)".

- **App Store (docs/APPSTORE.md)**:
  - App Store builds compile with `STORE_BUILD` (`Distribution.allowsOwnKeys` is false: no BYOK brain, no voice keys) and are numbered `<timestamp>.1`, which is how `store-check` tells them from family builds. `check-rules.sh` rule 6 keeps every own-key entry point gated.
  - Not in the Kids Category (Education, 4+); see the decision in APPSTORE.md before changing that.
  - Screenshot display types: there's no `APP_IPHONE_69`. 6.9" (1320×2868) goes in `APP_IPHONE_67`; iPhone Duo is `APP_IPHONE_DUO` (earns the "Made for iPhone Duo" badge with a 27.1+ SDK build). POST a bogus `screenshotDisplayType` and the API lists every valid one.
  - Apple has no "Games › Educational" subcategory; the secondary category is Games › Family + Trivia.
  - The first App Store version can't take `whatsNew` (`store-meta` adds it from the 2nd release on). PATCHing a localization must not include `locale`.
  - App Privacy (nutrition label) and agreements aren't in the API: click-by-click in APPSTORE.md.
  - Store simulators: "Store 69" (iPhone 17 Pro Max), "Store iPad 13" (iPad Pro 13-inch (M5)) on iOS 27.0, and "Store Duo" (iOS 27.1). A fresh simulator image can take ~3 minutes for its first `simctl install`.
- **App icon**: `scripts/brand/icon.mjs` writes the Icon Composer bundle `MoonClub/AppIcon.icon` (background fill + Sky/Luna/Rocket glass groups; dark fill; halo hidden when tinted) and the opaque fallback `AppIcon.appiconset/icon-1024.png`. Both are named AppIcon, and actool prefers the `.icon` (it also bakes the legacy PNGs from it). XcodeGen 2.46 adds `.icon` to Resources as `wrapper.icon` automatically. Rendering is dependency-free: `sips` uses CoreSVG, which **ignores `clip-path`**, so draw shapes explicitly. `--preview <dir>` renders every appearance with Icon Composer's `ictool` (`/Applications/Xcode.app/Contents/Applications/Icon Composer.app/Contents/Executables/ictool … --export-image --rendition Default|Dark|TintedLight|TintedDark|ClearLight|ClearDark`). `xcrun ictool` is a different tool, and `--help` on it hangs.


## Moon Garden (0.13): planting Moon points
- Pure rules in MoonClubCore `Garden.swift`; screens in `Features/Garden.swift` (the Piggy Bank tab has two sides, Moon Garden and Pretend coins, so the two currencies never mix).
- **Event-sourced.** `KidsState.garden` is a list of `GardenEvent`s (plant `p` / harvest `h`, unique id `"<15-digit millis>-<4 hex>"`, the day, the points, micro-seeds `u`, and the price `px` used). Merge = set union. Holdings, payouts, gains and badges come from `Garden.book(events)`, which replays in one canonical order (day, then id). A harvest takes at most what's growing at that point in the replay, so two devices harvesting the same planting offline get paid once. Never store a holding or a balance.
- **The ledger** (`Garden.balance`): `wallet = earned + harvest gains − Moon Shop − planted now`, never below 0. `Shop.wallet` uses it, so planted points can't be spent in the shop. "My points" shows it line by line (`PointsLedger`).
- **Prices** are daily closes only (`Garden.close(candles[s], onOrBefore: today)`), from the same candles as Market World (bundled, refreshed from `/api/kids/candles`). Only companies with a candle series can be planted. Nothing ticks.
- **Guardrails:** at least 5 points; today's allowance = `limit`% of (balance + planted today) − planted today (`Garden.allowance`; default 50%, 0 pauses). The grown-up picks it in the grown-up corner (`gardenLimit`, `"<millis>|<pct>"`, max-merge: the later pick wins).
- **Teaching:** "Why did it move?" is the curriculum's `WhyCard` (MoonClubCore `Why.swift`, `/api/kids/why`) in each planting's sheet; `Garden.basketNudge` ("one basket"); `Garden.wisdom` ("check less often"). Copy is tested: no bet/gamble/loot/cash/money/advice words (`GardenTests.testCopyIsKidSafe`).
- **Badges:** Spread it out (most companies at once: 3/5/8) and Patient planter (longest a planting grew: 7/30/90 days, counted up to `state.lastActiveDay`). Both only go up.
- **`String(format: "%015d", Int)` is 32-bit** and printed negative millis. Use `%015ld` (fixed for equipped picks too in 0.13).
- Debug/demo args: `-garden` (seed plantings and a harvest), `-plant` (open the plant sheet), `-plot <SYM>` (open a planting), `-coins` (show the pretend-coins side).

## iPad layout and performance (0.13)
- **Layout follows the room, never the device.** Story: a fold → the two-card book pager (Duo); ≥ 600 pt wide with no fold → `StoryColumns` (all cards in 1–3 balanced columns, readable width 1040); narrower → the swipe pager. World: a landscape-shaped window with no fold → map + a fixed 300–440 pt stop panel (portrait-shaped ones keep the even split, ≥ 360 pt a side); the header stacks (`ViewThatFits`) instead of truncating. Big names use `lineLimit` + `minimumScaleFactor` so words never break ("McDon-ald's").
- `CardFitTests.testIPadLayoutsStayInsideTheirWindow` lays the wide layouts out at 320–1376 pt; `testMoonGardenFitsWithoutScrolling` covers the plant sheet and the points page on SE/17.
- **Performance:** `AppModel.derived` memoizes points, level, wallet, trophies and the garden once per state change (`version` bumps in `commit`; the memo is `@ObservationIgnored`). The aurora drifts for 6 s when a screen appears, then rests: a moving background made every glass card re-blur each frame (Story idled at ~10 fps on the iPad sim). `BossBackdrop` is capped at 30 fps and pauses off screen. Map stops and banners are `Equatable`. Cards skip the extra shadow under Liquid Glass. Ambient loops on the map (current-stop pulse, rocket bob and flame, flags, the Mystery tag) play a few cycles and rest: each endless loop made SwiftUI rebuild the whole map's display list every frame (Time Profiler). New ambient loops should use `repeatCount`, not `repeatForever`, unless they're on a play screen.
- **Measuring:** `-bench` (debug) runs a fixed script (idle, every tab, ten point bankings, Piggy, World, settled Story) and prints `BENCH <phase> bodies=… <view>=… frames=… avg=… p95=… hitches=… hitchRatio=…` to stdout: `xcrun simctl launch --console-pty <sim> com.mutaafaziz.moonclub -demo -bench`. Count a view with `let _ = Perf.body("Name")`. `-aurora full|still` compares the old always-drifting aurora.
- **The simulator can't rotate or resize from the command line** (`requestGeometryUpdate` is ignored with iPadOS windowing; `simctl io screenConfig geometry` has no landscape mode). Debug `-window WxH` lays the app out in a window of that size, scaled to fit (landscape `1376x1032`, Split View `688x1032`, Slide Over `450x1032`, Stage Manager `900x700`). `-sidebar shown|hidden` sets the split view's sidebar.
- **Screenshot readiness:** debug + `-demo` builds append `root` / `play` to `Library/Caches/moonclub.ready` (`Ready.mark`); `scripts/shots.sh` waits for the token instead of sleeping.
- **Colour-blind candles:** every candle goes through `CandleInk` (ChartViews.swift): up = hollow green, down = filled red, big candles add an arrow, thin ones a tick. The widget sparkline ends in an up/down triangle. `testCandlesShowDirectionWithoutColour` checks it in grayscale at 60–300 pt.
